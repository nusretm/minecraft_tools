# Minecraft Info Provider — Mod Icon Lookup Handoff

Date: 2026-10-06

## Checkpoint

Branch:

```text
feature/mod-icon-foundation
```

Package version:

```text
1.0.0-dev.26
```

Status:

```text
IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

## Goal

Expose mod presentation icons from normalized `MtnMinecraftInfoMod` without storing all icon/archive bytes in memory and without leaking Fabric-specific archive rules into the generic mod model.

## Public API

```dart
mod.hasIcon

await mod.getIcon(
  size: 128,
)
```

`getIcon()` returns `Uint8List?`.

The requested size must be greater than zero.

## Lazy source model

Icons are not copied into every normalized mod object during discovery.

Provider-backed lazy resolvers are retained instead.

For installed mods:

```text
MtnMinecraftInfoMod.getIcon()
  -> reopen root JAR
  -> locate provider-declared icon entry
  -> return bytes
```

For embedded mods:

```text
MtnMinecraftInfoMod.getIcon()
  -> reopen root JAR
  -> follow embedded JAR path chain in memory
  -> locate icon inside final embedded archive
  -> return bytes
```

No embedded JAR or icon is extracted to disk.

## Fabric icon metadata

Supported `fabric.mod.json` forms:

```json
"icon": "assets/example/icon.png"
```

and:

```json
"icon": {
  "16": "assets/example/icon_16.png",
  "64": "assets/example/icon_64.png",
  "256": "assets/example/icon_256.png"
}
```

For a preferred size, the provider selects the smallest available size greater than or equal to the request. If no such size exists, it selects the largest available icon.

Missing declared files do not invalidate otherwise valid mod metadata. They simply result in no usable icon.

## Mod-list integration

`MtnMinecraftModList` preserves provider-backed icon resolvers while normalizing and merging logical mods.

This means icon access still works from:

```dart
modList.mods
```

rather than only on raw provider parse objects.

Icon availability participates in normalized visible-state comparison so add/update/remove event behavior remains coherent.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_fabric_mod_metadata_test.dart
15/15 passed

minecraft_mod_list_test.dart
9/9 passed

dart test
296/296 passed

git diff --check
PASS

git status
clean
```

## Real profile smoke

Profile:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Example:

```text
example/mod_icons.dart
```

Observed:

```text
Icons: declared=116 loaded=116
```

Successful reads included:

- directly installed mods
- embedded-only mods
- installed+embedded logical mods
- Fabric API embedded modules
- recursively embedded dependency mods

## Deliberately out of scope

This checkpoint does not yet add:

- Forge / NeoForge / Quilt icon parsing
- image decoding/resizing/rendering
- icon caching
- namespace ownership
- localization/resource lookup
- general asset/model/texture resolution
- richer contact/license/dependency metadata

## Next action

No next implementation checkpoint is automatically approved. Continue only after selecting the next narrow area.
