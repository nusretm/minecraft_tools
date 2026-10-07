# Minecraft Tools — Minecraft Content Multi-Provider Search Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-multi-provider-search
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Validated production HEAD:
7b36e4b890f71dc1a274a8ebb254972f02ea7c12
```

Baseline:

```text
main
a7fa25c1262b2ddbaa3fc76ac52c8116a544942f
Merge pull request #33 from nusretm/feature/minecraft-content-provider-readiness-rate-limit
```

Package version: `1.0.0-dev.6`.

## Goal

Add a minimal all-ready-providers search path without inventing cross-provider identity, deduplication, or global pagination.

The checkpoint builds directly on the provider-readiness foundation:

```text
registered
ready
searchable by searchAll()
```

Only registered providers that are currently ready participate.

## Public surface

`MtnMinecraftContentService` now exposes:

```dart
Future<List<MtnMinecraftContentSearchResult>> searchAll(
  MtnMinecraftContentSearchRequest request,
)
```

`MtnMinecraftContentSearchResult` now requires:

```dart
final String provider;
```

This makes provider provenance explicit at the result-group level rather than requiring callers to infer it from content metadata.

## Search orchestration

`searchAll(request)`:

- reads the registry's current `readyItems`
- dispatches the same generic request object to each ready provider
- skips registered providers that are not ready
- returns no provider groups when no provider is ready
- preserves provider registration order in the returned group list

The service does not unregister or hide unavailable providers.

## Result identity and separation

Every provider returns its own `MtnMinecraftContentSearchResult`.

The result group records the provider identity directly.

Example conceptual shape:

```text
modrinth
  Skyblocker
  ...

curseforge
  Skyblocker
  ...
```

Both `Skyblocker` entries remain valid independent results.

The service deliberately does not perform:

- name deduplication
- slug deduplication
- project-title matching
- heuristic Modrinth/CurseForge association
- winner selection
- provider preference
- automatic merge into one logical project

The caller/user chooses which provider result to use.

## Pagination

Pagination remains provider-local.

Each result group preserves its own:

```text
offset
limit
total
hasMore
```

No global page, total, offset, or has-more value is synthesized.

This avoids pretending that independently paginated provider catalogs form one stable ordered result space.

## Provider integrations

Modrinth mapper now tags search results with:

```text
modrinth
```

CurseForge mapper now tags search results with:

```text
curseforge
```

Provider identity continues to use the extensible string contract.

No provider enum was introduced.

## Tests

The package test suite now contains 33 tests.

New/updated coverage confirms:

- selected-provider search result exposes provider identity
- `searchAll()` queries only ready providers
- registered-but-not-ready providers receive no search call
- the exact same generic request object is dispatched to participating providers
- returned groups preserve registration order
- equal content names from different providers remain independent results
- no-ready-provider search returns an empty list
- invalid blank provider identity in a search result is rejected
- Modrinth mapped search result reports the Modrinth provider
- CurseForge mapped search result reports the CurseForge provider

## Validation

Authoritative local validation supplied by the user:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +33: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
7b36e4b890f71dc1a274a8ebb254972f02ea7c12
```

No `dart format` was run.

## Production files changed

```text
minecraft_content_service/lib/src/provider/minecraft_content_provider_models.dart
minecraft_content_service/lib/src/provider/modrinth/minecraft_content_provider_modrinth_mapper.dart
minecraft_content_service/lib/src/provider/curseforge/minecraft_content_provider_curseforge_mapper.dart
minecraft_content_service/lib/src/service/minecraft_content_service.dart
minecraft_content_service/pubspec.yaml
minecraft_content_service/README.md
minecraft_content_service/CHANGELOG.md
```

Tests changed:

```text
minecraft_content_service/test/content_provider_service_test.dart
minecraft_content_service/test/content_provider_modrinth_test.dart
minecraft_content_service/test/content_provider_curseforge_test.dart
```

## Deliberately not implemented

- cross-provider deduplication
- cross-provider association
- cross-provider project merging
- global multi-provider pagination
- global result ranking
- provider preference/winner rules
- partial-failure/error policy across multiple providers
- dependency solving
- artifact download/materialization
- CurseForge live smoke
- deferred item client-definition/model/texture rendering foundation

## Relationship to provider readiness

This checkpoint depends on the previously merged readiness foundation.

A provider can remain:

```text
registered = true
ready = false
```

and is then automatically excluded from `searchAll()`.

For example, CurseForge can remain registered without an API key and join future multi-provider searches automatically once its readiness prerequisite is satisfied.

## Next action

This branch is implementation-complete, locally validated, and continuity-closed.

Merge requires separate explicit user approval.

No next implementation checkpoint is automatically approved.

Potential later content-service work remains separate, including dependency solving, download/materialization, broader provider error policy, and any future cross-provider association only if a concrete requirement appears.
