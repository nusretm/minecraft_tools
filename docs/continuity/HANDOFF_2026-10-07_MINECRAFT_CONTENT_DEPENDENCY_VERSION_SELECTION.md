# Minecraft Tools — Minecraft Content Dependency Version Selection Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-version-selection
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
Baseline main:
6c2cae386bd0b4a825fd7330d093de01f43c82dd
Validated feature HEAD:
e64a5596817f4a174b1e5cb952ef619a04eaed15
```

Package version: `1.0.0-dev.8`.

No `dart format` was run.

## Goal

Add the smallest provider-independent version-selection layer on top of the completed dependency identity resolver.

This checkpoint selects a compatible version only after provider/content identity is known. It does not perform recursive dependency traversal, install policy, conflict policy, version-constraint interpretation, artifact selection, or downloads.

## Public surface

New immutable request:

```dart
MtnMinecraftContentVersionSelectionRequest({
  List<String>? gameVersions,
  List<MtnMinecraftModLoaderType>? modLoaders,
  List<MtnMinecraftContentVersionReleaseType>? releaseTypes,
})
```

New service operation:

```dart
Future<MtnMinecraftContentDependencyResolution> resolveDependencyVersion(
  MtnMinecraftContentDependency dependency,
  MtnMinecraftContentVersionSelectionRequest request,
)
```

The existing `resolveDependency()` identity-only behavior remains unchanged.

## Locked selection semantics

1. an already resolved dependency version is reused without provider version-list dispatch
2. an explicit `providerVersionId` is still exact identity and is resolved through the existing identity resolver; no latest/compatible selection overrides it
3. provider identity is never guessed
4. content identity is resolved first through `resolveDependency()`
5. selection runs only when content is resolved, version is unresolved, and the dependency names a provider
6. selection filters are Minecraft versions, mod loaders, and release types
7. public selection policy does not expose provider pagination
8. provider version-list pagination is an internal service detail
9. when the provider reports a total, the service can jump from the first page to the final page instead of replaying every intermediate page
10. when total is unavailable, the service advances pages until `hasMore == false`
11. provider-normalized ordering remains authoritative; the newest compatible version is the final version in the final normalized page
12. no compatible version is not an exception: content remains resolved while version remains unresolved
13. `versionConstraint` is deliberately not interpreted in this checkpoint
14. dependency relation type does not influence version selection
15. there is no cross-provider fallback, association, name/slug lookup, or filename heuristic
16. the original dependency object is not mutated

## Provider boundary

No Modrinth or CurseForge endpoint/wire behavior was added to generic core for this checkpoint.

The existing provider `getVersions()` implementations remain responsible for their provider-specific filtering and normalized version-list mapping.

Provider-specific limitations remain visible. For example, a concrete provider may reject a filter shape that its API cannot represent safely.

## Pagination behavior

The generic version-list contract remains bounded to 50 entries per page.

Selection starts with:

```text
offset = 0
limit = 50
```

If the first result has more pages and reports `total`, the final page offset is calculated from that total.

If `total` is unavailable, the service advances by the returned page limit and requires pagination to make forward progress.

This keeps provider pagination out of the public version-selection request.

## Deliberately not implemented

- recursive dependency traversal
- dependency graph construction
- cycle detection
- duplicate dependency graph collapse
- `versionConstraint` parsing/evaluation
- Minecraft version semantic-range interpretation beyond provider list filters
- required/optional install policy
- incompatible conflict policy
- embedded/included/tool relation policy
- artifact/file selection
- download/materialization
- cross-provider fallback or association
- broader provider-error aggregation policy
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

## Tests added/updated

Service coverage now includes:

- exact dependency version identity bypasses version-list selection
- content-only identity selects the newest compatible provider version
- Minecraft-version, loader, and release-type filters are passed through unchanged
- `versionConstraint` does not affect selection
- a 51-version result selects from the final page
- known-total pagination jumps to the final page
- no compatible result preserves content-only resolution
- no-provider dependency remains unresolved and does not dispatch to another provider
- selection request collections are immutable

The fake provider now applies generic compatibility filters and pagination so service tests exercise the intended contract rather than returning an unpaged list.

## Validation

Authoritative user-supplied local validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_service_test.dart
00:00 +17: All tests passed!

dart test
00:00 +41: All tests passed!

git diff --check main...HEAD
PASS

git status
On branch feature/minecraft-content-dependency-version-selection
Your branch is up to date with 'origin/feature/minecraft-content-dependency-version-selection'.
nothing to commit, working tree clean

git rev-parse HEAD
e64a5596817f4a174b1e5cb952ef619a04eaed15
```

No `dart format` was run.

## Next action

This checkpoint is implementation-complete, validated, and continuity-closed.

Merge is not yet requested and still requires separate explicit user approval.

Recursive dependency graph solving remains the likely next content-service checkpoint, but it is not automatically approved.
