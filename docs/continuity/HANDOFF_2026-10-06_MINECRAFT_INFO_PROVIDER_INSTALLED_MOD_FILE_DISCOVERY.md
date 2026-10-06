# Handoff — Minecraft Info Provider Installed Mod File Discovery

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
INSTALLED MOD FILE DISCOVERY FOUNDATION
IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Branch:

```text
feature/installed-mod-file-discovery
```

Starting main:

```text
a1f840d464fb3cafd4fc4a3b60cf48239b4f4465
Add mod loader discovery foundation
```

Package version:

```text
1.0.0-dev.24
```

## Goal

Discover directly installed mod JAR files under one Java Edition profile without
opening archives or interpreting mod metadata.

## Public surface

```dart
final class MtnMinecraftInfoMod {
  final File file;
  String get fileName;
}

Future<List<MtnMinecraftInfoMod>> MtnMinecraftInfoProvider.readMods()
```

`file` is the source of truth. `fileName` is derived from the file path.

## Discovery source

Only:

```text
<gameDirectory>/mods/
```

Direct files whose extension is `.jar` case-insensitively are returned.

## Locked behavior

- Missing `mods/` returns an empty immutable list.
- A present `mods` path that is not a directory is `invalidPath`.
- A missing/non-directory game directory is `invalidPath`.
- Directory listing failures are `readFailed`.
- Nested directories are not traversed.
- Non-JAR files are ignored.
- `.jar.disabled` is not interpreted as an installed active mod.
- Results are sorted deterministically by file name.
- JAR contents are not opened.

## Validation

Authoritative local validation supplied on 2026-10-06:

```text
dart analyze
No issues found!

dart test test/minecraft_mod_file_discovery_test.dart
00:00 +7: All tests passed!

dart test
00:03 +272: All tests passed!

git diff --check main...HEAD
PASS

git status
clean
```

## Real profile smoke passed

Target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
Mods: 54
```

All 54 direct JAR files were listed successfully.

The real directory contains mixed file-name conventions, including names that
mention Fabric, NeoForge, Minecraft versions, or no loader at all. File names
therefore remain discovery labels only and are not treated as authoritative
loader compatibility or mod metadata.

## Explicitly out of scope

- archive/JAR inspection
- Fabric `fabric.mod.json`
- Quilt `quilt.mod.json`
- Forge `META-INF/mods.toml`
- NeoForge `META-INF/neoforge.mods.toml`
- mod IDs, display names, versions, authors, licenses
- dependency and incompatibility metadata
- loader/version compatibility
- nested JARs
- disabled-mod conventions beyond ignoring non-`.jar` files
- namespace-to-mod ownership
- localization
- item model/texture resolution
- resource-pack precedence

## Next checkpoint

After this checkpoint is merged, the next independent target is mod metadata
discovery from the discovered JAR files. Metadata format handling must remain
loader/format aware and should not infer identity or compatibility from file
names.
