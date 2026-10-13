# Minecraft Content Package — CP-05 Hydration & Metadata Cache (2026-10-14)

## Status

- Repository: `nusretm/minecraft_tools`, target package: `minecraft_content_service/`.
- Baseline: `main` after merged Content Package Foundation PR #64, commit `d3ea29e180d6c8c78dfe19b903308e80e6318428`.
- Active branch: `feature/minecraft-content-package-hydration-cache`.
- **Implemented on branch; not yet validated by local Dart analyzer/tests or a live provider run.**
- Not merged; separate user approval required.
- Existing foundation evidence: user ran `dart analyze` with no issues, 8/8 focused tests and 265/265 full tests before PR #64 merge.

## Audit findings

- `MtnMinecraftContentService.getContent(provider, id)` and `getVersion(provider, id)` delegate directly to the registered provider; no existing general shared metadata cache was found.
- Modrinth and CurseForge already serialize their own provider HTTP calls, rate-limit handling and exact version lookups. Do not duplicate or override these.
- Foundation `MtnMinecraftContentPackageItem.hydrate()` previously checked project identity/content type only. It did not verify a locked provider version or selected artifact.
- Modrinth files generally expose SHA-1/SHA-512 hashes but no canonical generic provider file ID; CurseForge exposes numeric file IDs and hashes. Lock verification must accept both.

## Implemented scope

1. `MtnMinecraftContentPackageMetadataCache(service)`: explicit in-memory service-scoped cache for `provider + projectId` content metadata and `provider + versionId` exact version metadata. Cache hits avoid repeat calls; identical concurrent requests coalesce into one Future. Errors/mismatched IDs are not cached.
2. Cache supports `refresh: true`, `invalidateContent`, `invalidateVersion`, `clear`. Invalidation removes in-flight ownership: an old completion cannot put stale results back into the cache; existing awaiters still receive their original result.
3. `MtnMinecraftContentPackageLockedVersion.verify(provider, projectId, version)` validates the locked item and provider version identities, owning project, selected artifact name, optional file ID, optional recorded hash+algorithm, optional size and availability. Mismatch/ambiguity throws `FormatException`. It returns the **provider metadata artifact**, not downloaded bytes.
4. `MtnMinecraftContentPackageItem.hydrate(service, cache:, lock:, refresh:)` supports exact version verification, exposed read-only `version` and `file` metadata, retryable errors, and shared in-flight calls. Semantically identical lock values can reuse a successful hydrated result.
5. `MtnMinecraftContentPackage.hydrateSequential(service, cache:, refresh:)` automatically passes each item's exact lock; one item failure is isolated from other items. Optional supplied cache can be shared across package instances; absent cache is ephemeral to the call.
6. New focused synthetic tests and `example/content_package_hydration.dart` for a real Modrinth exact-version import/hydration round trip.

## Locked safety invariants

- All imported item runtime states start `notLoaded`; `version` and `file` are runtime-only and never enter portable JSON.
- Hydration **never** substitutes a newer/latest version or chooses a different file when the lock no longer matches.
- A failed lock verification leaves the item in `error` state with no published `content/version/file` data. `refresh: true` provides explicit retry after source metadata changes.
- Dependency enabled/disabled is **derived from active direct roots**, not a manual per-dependency flag; this checkpoint does not alter that behavior.
- Only provider metadata is checked here. Actual downloaded file byte integrity remains governed by the existing download/materialization integrity stack; no installed-state changes occur.

## Deferred

- Disk-backed durable cache, TTL/cache expiration policy, bounded memory eviction and cross-process coordination.
- Provider-internal HTTP reuse (for example, `getVersion()` invoking provider `getContent()` internally), without changing the existing provider API.
- Graph-to-lock generation, version update resolution, permission-aware revision changes, orphan cleanup and actual physical enable/disable.
- Dev.28 RemVibe installer and transactional recovery integration.
- Live CurseForge API validation, and a full real-world multi-root import-and-install.

## Required Windows validation

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-hydration-cache
git switch feature/minecraft-content-package-hydration-cache

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_hydration_cache_test.dart -r expanded
dart test test/content_package_foundation_test.dart -r expanded
dart test

# Real provider metadata-only smoke: use a canonical project ID and its exact version ID
dart run example/content_package_hydration.dart 'YOUR_PROJECT_ID' 'YOUR_EXACT_VERSION_ID' '1.21.11'

cd ..
git diff --check main...HEAD
git status
```

A successful local test run **is not** evidence of successful live API hydration; record these separately. Do not `dart format` pure Dart source. No merge without explicit approval.
