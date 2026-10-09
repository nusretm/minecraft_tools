# Minecraft Loader Version List — Foundation (2026-10-09)

## Ownership
- Repository: `nusretm/minecraft_tools`
- Package: `minecraft_loader_version_list/`
- Branch: `feature/minecraft-loader-version-list-foundation`
- Baseline main: `c2cae2caaca661d39b6ade9bc39508a010169b78`
- This is a separate pure-Dart library package. No changes to `mtn_launcher` in this checkpoint.

## Contract
- Public data model: `MtnLauncherGameLoaderVersion`, fields `mcVersion`, full `version`, source-provided `url`, `MtnLauncherGameVersionType type`.
- Public manager: `MtnLauncherGameLoaderVersionList`, with `cacheDirectory`, `filename`, `onLoadFromWeb(list)`, `onGenerateMinecraftVersionList(list, game)`.
- `onLoadFromWeb` must return the complete Minecraft *support catalog*; it does not create placeholder installer URLs.
- Supported game entry: Dart named record `MtnLauncherGameLoaderMinecraftVersion` `(mcVersion, versionId, type)`. Preserve exact upstream `versionId`.
- `load()` checks a one-hour cache then gets the catalog; `supportsMinecraftVersion(mcVersion, [types])` is a synchronous predicate over it.
- `loadMinecraftVersion(mcVersion, [types])` lazily retrieves compatible builds, which are returned later by `getFromMinecraftVersion(mcVersion, [types])`.
- Each provider has one JSON file with independently timestamped catalog and generated lists.
- `downloadUrl` sets error fields and throws; `load`/generation catch and preserve usable old data.
- Version types describe **Minecraft**, not loader build stability.
- Demo callbacks exist for Vanilla, Fabric, Quilt, Forge and NeoForge.

## Known constraints / audit notes
- Forge/NeoForge version compatibility is inferred from Maven metadata, not artifact validation.
- NeoForge legacy `net.neoforged:forge` is outside the example's scope.
- A week-numbered snapshot cannot be assigned to a later release without authoritative mapping; unknown IDs retain their original grouping.
- The enum name follows the agreed launcher API but lives in this standalone package; plan integration to avoid divergent duplicate enum types in launcher and package.
- General sorting is natural alphanumeric, not a complete Minecraft prerelease chronology.
- Real provider API and Windows runtime validation still required; only focused tests are included until the user runs `dart test` and `dart analyze` locally.
- No `dart format` performed.

## Suggested local validation
```powershell
git fetch origin feature/minecraft-loader-version-list-foundation
git switch feature/minecraft-loader-version-list-foundation
cd minecraft_loader_version_list
dart pub get
dart analyze
dart test
dart run example/loader_versions.dart 1.21.1
```

## Acceptance
Feature package is committed on a separate branch and ready for user validation/review.
Do not merge until checks and actual diff review are complete.
