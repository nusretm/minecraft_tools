# CP-09 — Package Item Lifecycle (2026-10-14)

## Status and authorization

- User approved implementation in conversation following explicit API design review.
- Branch `feature/minecraft-content-package-item-lifecycle` from CP-08 merged, clean `main` at `4df323c56b17f76730734c9d0335bc56f05cfa76`.
- **IMPLEMENTED ON FEATURE BRANCH — Windows `dart analyze`, test suite and real Modrinth smoke PENDING; not merged.**
- Draft PR [#69](https://github.com/nusretm/minecraft_tools/pull/69). Merge requires a separate explicit approval after real Windows verification.
- Respect `docs/WORKING_RULES.md`: no `dart format` for pure Dart, few focused tests, real Windows smoke, separate merge approval.

## Exact API direction

- `package.add(MtnMinecraftContentVersion)` accepts a provider-selected **version object**, not arbitrary strings or manually assembled package items. The selected provider version and project must share canonical provider identity. Minecraft release compatibility, and mod loader for mods, are checked. Non-mod content, such as resource packs, is not forced to use the package mod loader.
- `package.remove(item)` permits removal of eligible local direct roots; when another item depends on a removed direct root, it is demoted to a dependency, not deleted.
- `package.items` remains a read-only view even though package-controlled add/remove changes the internal collection. `canAdd`, `canRemove`, `canSetEnabled` use existing policy, permissions, and source. Normal refused UI actions return `false` or silently retain enabled values rather than throwing.
- `item.package` is attached in Package construction/add, not serialized. Record construction attaches the local Record to its Package without duplicating `source`. `item.enabled` is the direct root's preferred switch; `item.effectiveEnabled` computes graph reachability **inside the Item** from active direct roots, including shared and cyclic dependency paths. Old Package-owned `effectiveEnabled`, `effectiveEnabledKeys`, `setDirectEnabled` APIs are removed before the first release.
- `item.canUpdate` is true only when `package.updateList.containsKey(item)`. The package's read-only `Map<Item, Version> updateList` is transient, not serialized. `package.checkUpdates(service)` queries compatible provider versions and only records versions whose trusted `publishedAt` is after the selected one. No auto-updates, no new update service, no duplicate update-version field on Item.

## Persistence and dependency limits

- `item.selectedVersionId` persists **only in encrypted local records**. Item hydration can load this exact provider version when no full lock exists. When Package add/remove invalidates a former exact lock, each original item's selected provider version ID is preserved before clearing the lock.
- Existing locked install-dependency edges are retained when converting to local unlocked draft, and serialized as **local-only** `dependencyEdges`. Direct-root reachability is not lost simply because the portable lock is invalidated.
- The new root's already-present *required/embedded* dependencies can be linked by explicit provider project identity. **Unresolved/new dependencies are not implicitly downloaded or made up**. An added root containing missing dependencies still requires the existing resolver, optional-selection policy, exact file selection, and Package Builder's full graph lock before portable publication. `toMap/toJson/encode` reject unlocked drafts.
- Portable Package schema remains **v2**. Existing encrypted Record schema remains **v2**, and the AES-GCM envelope is unchanged. No Content Server, installer, or publisher authorization implementation.
- No new Editor, Override, protected enum/flag, task service, download engine, or provider-specific helper.

## Focused verification (Windows PowerShell)

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-item-lifecycle
git switch feature/minecraft-content-package-item-lifecycle
cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_item_lifecycle_test.dart -r expanded
dart test test/content_package_foundation_test.dart -r expanded
dart test test/content_package_item_source_test.dart -r expanded
dart test test/content_package_record_codec_test.dart -r expanded
dart test
dart run example/content_package_add_modrinth.dart 1.21.11 0.16.14
cd ..
git diff --check main...HEAD
git status
```

The live example searches Modrinth for Fabric API, takes the most recently published compatible version from the provider result page, adds it, and saves/reopens a real AES-GCM encrypted local draft. It does NOT claim to resolve all dependencies or produce a publishable/downloaded modpack. A complete lock and existing installation pipeline are separate, next-stage work.

**No Dart SDK available in the GitHub-editing environment; no analyzer/test/smoke PASS is claimed here before user Windows evidence.**
