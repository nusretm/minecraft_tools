# Handoff — Minecraft Info Provider Mod Loader Discovery Foundation

Date: 2026-10-06

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. `hypixel_api/` is unrelated.

## Checkpoint state

```text
MOD LOADER DISCOVERY FOUNDATION
IMPLEMENTED / DETERMINISTICALLY VALIDATED
REAL PROFILE SMOKE PENDING
```

Branch:

```text
feature/mod-loader-discovery-foundation
```

Starting main:

```text
56409742de70b965687aa1552d230ff28770f7a7
Close server health check continuity
```

Package version:

```text
1.0.0-dev.23
```

## Goal

Discover the recognized mod loader used by one Java Edition profile without
turning `version.json` into a general launcher-version parser.

## Public surface

```dart
enum MtnMinecraftInfoModLoaderType {
  fabric,
  forge,
  neoForge,
  quilt,
}

final class MtnMinecraftInfoModLoader {
  final MtnMinecraftInfoModLoaderType type;
  final String version;
  final String minecraftVersion;
}

Future<MtnMinecraftInfoModLoader?> MtnMinecraftInfoProvider.readModLoader()
```

## Discovery source

The provider checks only:

```text
<gameDirectory>/versions/version.json
```

Only these JSON fields are interpreted:

```text
id
inheritsFrom
```

No other launcher metadata is parsed.

## Locked behavior

- Missing `versions/` or `version.json` returns null.
- An unrecognized loader profile ID returns null.
- A recognized loader profile with malformed required data throws
  `MtnMinecraftInfoProviderException(invalidData)`.
- A non-directory game path or invalid `versions/version.json` filesystem
  shape remains `invalidPath`.
- File read failures remain `readFailed`.
- JSON syntax/root-shape failures remain `invalidData`.
- Loader JAR files are not used as discovery authority.
- Unknown/unrecognized loaders are not reclassified as vanilla.

## Current recognized loader families

- Fabric
- Forge
- NeoForge
- Quilt

The loader version is derived from the profile `id` while
`minecraftVersion` comes from `inheritsFrom`.

Known real target:

```text
id           = fabric-loader-0.19.5-26.1.2
inheritsFrom = 26.1.2
```

Expected discovery:

```text
type             = fabric
version          = 0.19.5
minecraftVersion = 26.1.2
```

## Example

```text
minecraft_info_provider/example/mod_loader.dart
```

Usage:

```powershell
dart run example/mod_loader.dart "C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb"
```

## Validation completed before example/continuity-only additions

Authoritative local validation supplied on 2026-10-06:

```text
dart analyze
No issues found!

dart test test/minecraft_mod_loader_discovery_test.dart
00:04 +9: All tests passed!

dart test
00:03 +265: All tests passed!

git diff --check main...HEAD
PASS

git status
clean
```

Because the example and continuity/package-version updates were added after
that validation run, rerun `dart analyze`, focused/full tests and
`git diff --check` before merge.

## Real profile smoke pending

Target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Expected result:

```text
Mod loader: fabric
Loader version: 0.19.5
Minecraft version: 26.1.2
```

## Explicitly out of scope

- general `version.json` model/parser
- launcher profile selection
- version inheritance resolution beyond reading `inheritsFrom`
- library/classpath reconstruction
- JVM/game arguments
- downloads/assets/runtime metadata
- scanning loader JARs
- scanning `mods/`
- reading mod JAR metadata
- mod dependency/compatibility resolution
- namespace-to-mod mapping
- localization
- item model/texture resolution
- resource-pack precedence

## Next checkpoint

After this checkpoint is smoke-validated and merged, the next independent
target is installed mod-file discovery under the profile's `mods/` directory.
Metadata parsing remains a separate checkpoint after file discovery.
