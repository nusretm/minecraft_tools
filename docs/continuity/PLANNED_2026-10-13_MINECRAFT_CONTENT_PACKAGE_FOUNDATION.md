# Minecraft Content Package — Portable Foundation (2026-10-13)

## Status

Feature branch: `feature/minecraft-content-package-foundation`.

Foundation code and focused tests have been authored. The repository owner executed the focused and full local Dart validation successfully on 2026-10-13; **live provider/download/install validation remains deferred**. PR #64 is a draft and has not been merged. This document records the approved product contract and the deliberate limits of the initial checkpoint.

## User-approved product contract

- Content Packages may describe Modrinth/CurseForge mods, resource packs, shader packs and data packs without embedding binary archives.
- A published package includes the exact selected version and file for every direct item and its selected transitive dependencies; importing it must not silently substitute provider "latest" versions.
- Dependency graphs are version-locked. One physical dependency may be required by several direct roots; do not duplicate the canonical installation identity.
- Package mutation policy: `none` (direct roots can be added/removed subject to item permission), `readOnly` (no direct-root additions/removals), `appendOnly` (addition only).
- Item permissions are an enum list: `enable`, `disable`, `remove`, `update`. Package-level and item-level guards must both permit direct-root mutations.
- Dependency-only items must **never** be manually enabled/disabled. Their effective activity is derived from reachability from active direct roots over the locked **selected installation edges**, including shared, transitive and cyclic dependencies.
- Direct items may also be dependencies of other roots. Disabling the direct preference must not deactivate an item still required by an active root.
- Only direct-root `enabled` preference persists. No item runtime `state`, hydrated `content`, pending request or `loadError` may enter the portable file.
- Imported item runtime state is always `notLoaded`. Hydration resolves `provider + projectId` and checks exact content identity/type. Hydration does not change the locked version/file choice.
- Three read-only UI snapshots are supported: `directItems`, `allItems` and `treeItems`. Flat displays sort alphabetically with a stable identity tie-breaker; sorting never mutates the canonical list or dependency graph. Shared children may repeat in the tree projection and cycles must terminate.
- New update resolutions create candidate revisions. Version updates and graph changes are explicit user-approved workflows; installation/recovery must use the existing dev.28 executor rather than another download/transaction engine.

## Initial feature checkpoint

The current code offers:
1. `MtnMinecraftContentPackageItem` with portable identity/presentation metadata, item permissions and transient hydration lifecycle.
2. `MtnMinecraftContentPackageLockedVersion`, `MtnMinecraftContentPackageLockedEdge` and `MtnMinecraftContentPackageLock` for exact file/version identities and selected dependency edges.
3. `MtnMinecraftContentPackage` for metadata-only JSON/UTF-8 export/import, schema v1, policy queries, direct enabled preference, graph-derived activity and sorted/tree snapshots.
4. Public exports through `minecraft_content_service.dart` and focused unit tests.

A lock contains one selected file per selected version. The file identity is pinned by provider file ID or a supported hash (MD5/SHA-1/SHA-256/SHA-512); file bytes and machine paths are excluded. Optional edges in this initial lock represent **selected** optional dependencies; unrelated optional candidates and incompatible/tool/bundled declarations are not installation edges.

A package can be drafted with no lock, but it **cannot be exported as a published package** until a complete lock has been provided. Import never calls providers automatically. An imported package is usable for metadata-only UI before hydration.

## Explicitly deferred checkpoints

- Authoritative transformation from existing `MtnMinecraftContentDependencyGraph` / multi-root install plans into a portable lock (with full non-install dependency declarations where needed).
- Durable provider/version metadata cache, deduplicated in-flight requests, cache invalidation policy, provider rate limit handling.
- Exact provider file/version hydration and canonical identity verification against locked artifact hashes before download.
- Direct root addition/removal/revision candidate workflow and permission-aware update planning.
- Orphan detection, removal protections, and an up-to-date multi-root desired state after a parent update or disable.
- File-level activate/deactivate semantics for each content type, installed-state reconciliation and RemVibe/dev.28 transaction integration.
- Published package signing and unforgeable publisher authority.
- Launcher UI, persistent user package registry and end-to-end Windows install/import validation.

## Important distinction: metadata hydration != installation

`loaded` means provider metadata has been obtained and identity-checked, **not** a JAR/ZIP was downloaded or installed. `effectiveEnabled` projects the locked graph for UI/planning; it does not mutate managed files. Installed state remains authoritative for physical files. Dependency `canRemove`/ `canUpdate` metadata is reserved for subsequent planner validation; dependencies remain non-user-toggleable.

## Local validation evidence — PASS (2026-10-13)

Evidence supplied by repository owner for branch `feature/minecraft-content-package-foundation` before this documentation-only update:

- `dart pub get`: succeeded. Dependency update notices were non-blocking.
- `dart analyze`: **No issues found!**
- `dart test test/content_package_foundation_test.dart -r expanded`: **8/8 passed**.
- `dart test`: **265/265 passed**.
- `git diff --check main...HEAD`: no errors.
- `git status`: working tree clean; local feature branch up to date with origin.

These results validate the Dart source and unit tests; they are **not** proof of live Modrinth/CurseForge hydration or an end-to-end installation. The checkpoint remains **merge pending explicit user approval**.

## Repeatable local validation commands



```powershell
cd D:\development\cross-platform\minecraft_tools\minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_foundation_test.dart -r expanded
dart test
cd ..
git diff --check main...HEAD
git status
```

Do not run `dart format` on this pure Dart package. Do not merge without separate user approval.
