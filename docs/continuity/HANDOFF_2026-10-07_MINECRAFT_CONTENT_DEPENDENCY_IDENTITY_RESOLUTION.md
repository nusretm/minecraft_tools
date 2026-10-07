# Minecraft Tools — Minecraft Content Dependency Identity Resolution Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-identity-resolution
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
Validated feature HEAD:
4323cfae7244d18ba3859ae4cdbbb37c2e3c74ed
Merge commit:
2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

Baseline:

```text
main
510620a5e22f60a1cb2cf5e90c6bd6e1d47d6d12
Merge pull request #35 from nusretm/docs/minecraft-content-multi-provider-search-post-merge-sync
Sync multi-provider search continuity after merge
```

Package version: `1.0.0-dev.7`.

No `dart format` was run.

## Goal

Add the smallest provider-independent identity-resolution layer needed before recursive dependency solving or artifact materialization.

The checkpoint resolves identities already supplied by a provider without inventing version-selection policy, cross-provider association, or filename heuristics.

## Public surface

`MtnMinecraftContentProvider` now requires:

```dart
Future<MtnMinecraftContentVersion> getVersion(String id);
```

`MtnMinecraftContentService` now exposes:

```dart
Future<MtnMinecraftContentVersion> getVersion(
  String providerName,
  String id,
);

Future<MtnMinecraftContentDependencyResolution> resolveDependency(
  MtnMinecraftContentDependency dependency,
);
```

New result model:

```dart
MtnMinecraftContentDependencyResolution
```

It preserves the original dependency declaration and separately exposes resolved `content` and `version` references.

## Locked resolution semantics

Resolution order is deliberately narrow:

1. an already resolved dependency version is returned without provider dispatch
2. no provider identity means no provider is guessed
3. an explicit `providerVersionId` is resolved through that exact registered ready provider
4. exact version lookup also resolves the version's owning content
5. when `providerContentId` exists, the resolved owning content must expose the same provider identity
6. without an exact version ID, an already resolved content reference remains content-only
7. with only `providerContentId`, the service resolves content only
8. `fileName` and `versionConstraint` remain declarations and are not heuristically interpreted

The resolver does not mutate `MtnMinecraftContentDependency`.

Provider registration/readiness behavior remains authoritative:

- unregistered provider => existing registry error
- registered but not ready => existing `MtnMinecraftContentProviderNotReadyException`
- no fallback to another provider

## Modrinth exact version lookup

`MtnMinecraftContentProviderModrinth.getVersion(id)`:

- reads the exact Modrinth version identity
- obtains its `project_id`
- resolves the owning project through the existing provider path
- maps the version using the existing generic version model
- validates that the returned version belongs to the resolved project

Modrinth wire details remain under `src/provider/modrinth/`.

## CurseForge exact version lookup

`MtnMinecraftContentProviderCurseForge.getVersion(id)`:

- requires a positive numeric CurseForge file identity
- resolves that file through the provider-specific batch-files API
- verifies exactly one requested file identity is returned
- reads the returned owning `modId`
- resolves the owning content through the existing provider path
- maps the file as the generic content version

The shared CurseForge request envelope now supports GET and POST while preserving the existing:

- API-key boundary
- provider readiness checks
- serialized request gate
- one bounded HTTP 429 retry when `Retry-After` is usable
- provider-specific HTTP exception behavior

CurseForge wire/API details remain under `src/provider/curseforge/`.

## Existing version-list behavior

`getVersions(content, request)` remains a separate operation.

Modrinth and CurseForge version-list mapping continues to attach versions to the exact caller-supplied content instance.

CurseForge mapping now shares the same version-mapping path with exact lookup while preserving the request loader hint when one is explicitly supplied.

## Deliberately not implemented

- recursive dependency traversal
- dependency graph construction
- cycle detection
- version-selection policy
- latest-version selection
- Minecraft-version compatibility choice
- loader compatibility choice
- release/beta/alpha preference
- required/optional install policy
- incompatible conflict handling
- `versionConstraint` evaluation
- artifact/file selection
- download
- integrity/materialization orchestration
- cross-provider lookup
- cross-provider association
- name/slug matching
- filename identity heuristics
- provider error aggregation policy
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

## Tests added/updated

Coverage now includes:

- service routing for exact version lookup
- exact-version dependency resolution
- content-only dependency resolution
- unresolved no-provider/file-name declaration behavior
- reuse of already resolved dependency versions without provider dispatch
- declared provider-content identity mismatch rejection
- unregistered and invalid exact-version lookup routing
- Modrinth exact version -> owning project mapping
- CurseForge exact file -> owning content mapping
- invalid CurseForge file identity rejection

## Validation

Authoritative user-supplied local validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_service_test.dart
00:00 +13: All tests passed!

dart test test/content_provider_modrinth_test.dart
00:00 +7: All tests passed!

dart test test/content_provider_curseforge_test.dart
00:00 +10: All tests passed!

dart test
00:00 +37: All tests passed!

git diff --check main...HEAD
PASS

git status
On branch feature/minecraft-content-dependency-identity-resolution
Your branch is up to date with 'origin/feature/minecraft-content-dependency-identity-resolution'.
nothing to commit, working tree clean

git rev-parse HEAD
4323cfae7244d18ba3859ae4cdbbb37c2e3c74ed
```

No `dart format` was run.

## Post-merge closure

The validated feature branch was merged locally with a normal two-parent merge commit and pushed to `origin/main`.

```text
main
2f9097e1cb1bf29bcede4709ab89d89ec43c6715
Merge dependency identity resolution foundation
```

Authoritative post-merge local state supplied by the user:

```text
Branch: main
origin/main: same
Working tree: clean
HEAD: 2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

## Next action

This checkpoint is implementation-complete, validated, continuity-closed, merged, and synchronized on local `main`.

No next implementation checkpoint is automatically approved.

Recursive dependency graph solving, version-selection policy, artifact download/materialization, broader provider-error policy, cross-provider association, CurseForge live smoke, and the deferred item client-definition/model/texture rendering plan remain separate future work.
