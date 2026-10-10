# Retire legacy minecraft_loader_version_list

Date: 2026-10-10
Repository: `nusretm/minecraft_tools`
Baseline `main`: `9c745dd86013d9cf4434d2571fa0ed65da4aadd4`
Branch (merged; deletion pending): `chore/remove-legacy-minecraft-loader-version-list`
PR: [#61](https://github.com/nusretm/minecraft_tools/pull/61) — **closed/merged**
Merge SHA: `2f60a20235f2bcdcdaab01f05a7237a2e9bd0408`
Docs-only closeout branch: `docs/legacy-version-list-removal-closure`
Status: **DELETION COMPLETE ON MAIN / WINDOWS VALIDATED (671 TESTS) / PR #61 SQUASH MERGED / FEATURE BRANCH CLEANUP PENDING**

## Why remove it?

The repository's old `minecraft_loader_version_list/` Dart package was a parallel catalog/cache/resolver implementation using `MtnLauncherGameLoaderVersionList` with provider callbacks. It duplicates the responsibility of the now-validated single public `MtnMinecraftGameLoaderVersionList` in `nusretm/minecraft_models` and depends on an older `minecraft_models` Git commit (`a083d402a13ef742d4968a161d2893f4f50482ff`).

The new cross-project authority is `minecraft_models` [consumer guide](https://github.com/nusretm/minecraft_models/blob/main/docs/continuity/CONSUMER_INTEGRATION.md), with validated implementation commit `1c4e346ed42bf9f15b0259c8efb2f7d3011758a3` (PR #7) and docs closure `dc41e3caf88aaad5967dec1462a3c75a5d1cf5dc` (PR #8).

### Scope of this branch

- Delete **every file** beneath `minecraft_loader_version_list/`: old public barrel, core, provider example, `pubspec.yaml`, cache/resolve/provider tests, README, CHANGELOG, package-specific rules and ignore file.
- Update the root `AGENTS.md`, `docs/WORKING_RULES.md` and `docs/continuity/CURRENT_TARGET.md` so they do not treat the deleted package as active.
- Keep historical `docs/continuity/HANDOFF_2026-10-09_MINECRAFT_LOADER_VERSION_LIST_FOUNDATION.md` and `docs/continuity/LVL_I3A2_VERSION_LIST_SHA1_CACHE_INTEGRATION.md` as **archived records** of the prior implementation and its validations. Their old contracts are not authoritative.
- Do **not** modify `minecraft_info_provider/`, `minecraft_content_service/`, `hypixel_api/`, `mtn_launcher` or `minecraft_models` in this branch. They have independent approval and validation gates.
- Sibling package `pubspec.yaml` files do **not** declare a dependency on the retired package. Windows `git grep` across the three remaining sibling packages returned no old VersionList references; all three analyzer/test suites passed after deletion (details below).

## Replacement contract — consumers

```yaml
dependencies:
  minecraft_models:
    git:
      url: https://github.com/nusretm/minecraft_models.git
      ref: 1c4e346ed42bf9f15b0259c8efb2f7d3011758a3
```

```dart
import 'dart:io';
import 'package:minecraft_models/minecraft_models.dart';

Future<void> queryFabric() async {
  final list = MtnMinecraftGameLoaderVersionList(
    cacheDirectory: Directory.systemTemp.path,
    loaderType: MtnMinecraftLoaderType.fabric,
  );
  final builds = await list.getFromMinecraftVersion('1.21.11');
  if (list.error != MtnMinecraftError.none) stderr.writeln(list.errorMessage);
  for (final build in builds) {
    stdout.writeln('${build.version} ${build.url}');
  }
}
```

Use the **same shared** `MtnMinecraftLoaderType`, `MtnMinecraftGameVersionType`, `MtnMinecraftGameLoaderChannel`, `MtnMinecraftGameLoaderVersion` and `MtnMinecraftGameLoaderVersionList` in every future consumer; never recreate old provider callbacks or duplicate canonical enums. Helper and specific provider classes inside `minecraft_models/lib/src/` are not public imports.

### Important capability differences — do not silently migrate

| Former `minecraft_loader_version_list` | Current `minecraft_models` |
| --- | --- |
| `MtnLauncherGameLoaderVersionList` with `filename` and provider callbacks | `MtnMinecraftGameLoaderVersionList` with `loaderType` and internal provider helpers |
| `loadMinecraftVersion()` followed by synchronous `getFromMinecraftVersion()` | `await getFromMinecraftVersion()`, which loads the catalog if needed |
| `supportsMinecraftVersion()`, `hasMinecraftVersionCatalog`, `catalogState` | No equivalent public authoritative support-state API; inspect results and typed `error` |
| `resolveVersion()` exact/automatic selection with channel policy and collision checks | No resolver; consumer selection policy must be separately specified and tested |
| Monolithic schema-1 JSON with backup/serialized writes | Per-loader / per-game-version cache files with best-effort stale fallback; not a disk schema migration |
| Old `MtnLauncherGameLoaderVersion.sha1` model metadata and cache round-trip | Current `MtnMinecraftGameLoaderVersion` has **no `sha1`**. Checksum/source verification and any SHA-1 field reintroduction need separate design and explicit approval |
| Numeric/HTTP status style `errorCode` | Typed `MtnMinecraftError` and `.code` with cache 1000 / download 2000 ranges |

`MtnMinecraftGameLoaderVersion.url` can be Mojang/Fabric/Quilt JSON or a Forge/NeoForge installer JAR *candidate*. It does not install, verify or run Minecraft. Fabric and Quilt `load()` catalogs contain supported *Minecraft versions*, not loader build versions. Do not treat `versions.first` as a globally authoritative newest/stable or installable build: Quilt upstream ordering can be non-semantic.

## Windows validation — user-executed on feature branch (2026-10-10)

- `git grep -n -e "minecraft_loader_version_list" -e "MtnLauncherGameLoaderVersionList" -- minecraft_info_provider minecraft_content_service hypixel_api`: **no matches**.
- `git diff --check origin/main...HEAD`: **clean**, both before and after local cleanup.
- `minecraft_info_provider`: `dart pub get` succeeded, `dart analyze` **No issues found**, `dart test` **361/361** passed.
- `minecraft_content_service`: `dart pub get` succeeded, `dart analyze` **No issues found**, `dart test` **257/257** passed.
- `hypixel_api`: `dart pub get` succeeded, `dart analyze` **No issues found**, `dart test` **53/53** passed.
- **Total: 671/671 passing tests.** All three checks were run on Windows with the old package removed from Git.
- `dart pub get` mentioned available newer dependencies; these are nonblocking dependency constraint notices, not analyzer/test failures.
- `dart test` changed a tracked generated file under `hypixel_api/.dart_tool/test/`, and the now-untracked old package directory remained locally. User restored that generated file and deleted the old directory; final `git status`: **clean**, branch synchronized with `origin/chore/remove-legacy-minecraft-loader-version-list`. `git diff --check origin/main...HEAD` remains clean.
- GitHub compared PR #61 with `main`: **13 files deleted** under the legacy package; only root `AGENTS.md`, `docs/WORKING_RULES.md` and two continuity documents added/updated. Other three package implementation sources untouched.
- User explicitly approved **squash merge and cleanup** of PR #61 after seeing the clean results. GitHub reports `merged=true` and `main` at `2f60a20235f2bcdcdaab01f05a7237a2e9bd0408`, with no old VersionList directory in the `main` tree. Feature remote branch deletion and local switch/pull/branch cleanup remain user-side post-merge steps; do not claim cleanup before those operations.

## Validation commands (already executed successfully; for future reproducibility)

From `D:\development\cross-platform\minecraft_tools` after switching to this feature branch:

```powershell
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git status
cd minecraft_info_provider
dart pub get
dart analyze
dart test
cd ..\minecraft_content_service
dart pub get
dart analyze
dart test
cd ..\hypixel_api
dart pub get
dart analyze
dart test
cd ..
git status
```

Do not run `dart format`. Also inspect `git grep -n "minecraft_loader_version_list\|MtnLauncherGameLoaderVersionList" -- ':!docs/continuity/*'` for unexpected active references, and verify no Dart package still declares the deleted dependency.

**Evidence boundary:** Windows validation of the three surviving `minecraft_tools` packages was reported by the user and passed as recorded above. The separately reported 40 tests and live five-provider queries belong to `minecraft_models`, not to this deletion. This removal does not itself validate any `mtn_launcher` consumer integration. **PR #61 squash merge was verified on GitHub; both feature-branch cleanup operations remain unverified until the user's PowerShell output.**
