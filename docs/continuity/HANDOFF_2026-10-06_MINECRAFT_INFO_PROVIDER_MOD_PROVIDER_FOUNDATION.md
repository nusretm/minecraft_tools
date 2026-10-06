# Minecraft Info Provider — Fabric Mod Metadata / Dependency Graph Handoff

Date: 2026-10-06

## Checkpoint

Branch:

```text
feature/fabric-mod-metadata-foundation
```

Package version:

```text
1.0.0-dev.25
```

Status:

```text
IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

## Goal

Replace the temporary file-only mod representation with an extensible provider-driven normalized mod graph that can represent directly installed and embedded mods without hardcoding loader families into the core.

## Public architecture

```text
MtnMinecraftModInfoProvider
└─ MtnMinecraftModInfoProviderFabric

MtnMinecraftModList
├─ providers
├─ mods
├─ register / unregister
├─ add(File jarFile)
├─ remove(MtnMinecraftInfoMod mod)
├─ clear()
├─ getDependencyList(...)
└─ onItem(list, mod, event)

MtnMinecraftInfoMod
├─ id
├─ name
├─ version
├─ description
├─ authors
├─ modTypes
├─ parentMods
├─ installedFiles
├─ isInstalled
└─ isEmbedded
```

`MtnListEvent` values:

```text
add
update
remove
```

## Provider semantics

Each direct root JAR is offered to every registered provider.

```text
provider.parse(file) == null
```

means only that this provider did not produce a mod result for the JAR. Another provider must still be allowed to parse the same JAR.

Provider identity comes from:

```dart
provider.name
```

and recognized provider names are merged into:

```dart
mod.modTypes
```

The core does not maintain a Fabric/Forge/NeoForge/Quilt switch.

## Normalized identity and graph

Current canonical logical identity:

```text
id + version
```

The same logical mod may simultaneously be:

- directly installed under `mods/`
- embedded by one or more parent mods

Different versions of the same ID remain separate logical mods.

Shared embedded dependencies are not duplicated. Their `parentMods` list records every normalized parent.

## Fabric provider

`MtnMinecraftModInfoProviderFabric` reads root-level:

```text
fabric.mod.json
```

and currently normalizes:

- id
- name
- version
- description
- authors

Fabric `jars[].file` entries are treated as declared embedded archive entries.

For every declared embedded JAR:

1. the relative archive entry must actually exist
2. its bytes are read from the parent archive
3. those bytes are passed to `parseJarContent()`
4. nested Fabric metadata is parsed recursively
5. parent relationships are retained

Embedded JARs are never extracted to temporary files.

Root JARs use streaming archive input; embedded JARs use in-memory entry bytes.

## Removal semantics

`MtnMinecraftModList.remove(mod)` only removes directly installed roots.

An embedded-only mod:

```text
isInstalled == false
isEmbedded == true
```

cannot be removed directly and returns `false`.

After a root removal, the normalized graph is rebuilt from remaining root snapshots. Dependencies referenced by another parent remain. A mod that was both installed and embedded can remain as embedded-only after its installed source is removed.

## Events

```dart
onItem(
  MtnMinecraftModList list,
  MtnMinecraftInfoMod mod,
  MtnListEvent event,
)
```

Events represent normalized visible list changes:

- `add`: logical mod newly appears
- `update`: same `id + version` remains but visible state changes
- `remove`: logical mod disappears

Rebuilds do not emit `update` when normalized state is unchanged.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_mod_file_discovery_test.dart
7/7 passed

minecraft_mod_list_test.dart
8/8 passed

minecraft_fabric_mod_metadata_test.dart
10/10 passed

dart test
290/290 passed

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

Observed:

```text
54 physical JAR files
188 normalized logical Fabric mods
```

The smoke run confirmed:

- direct installed mods
- embedded-only mods
- installed+embedded coexistence
- shared dependencies with multiple parents
- separate versions of the same mod ID
- recursive embedded dependency discovery
- parent display disambiguated as `id@version`

## Important discoveries

A metadata file's presence alone must not be blindly equated with exclusive loader identity. Real legacy Forge JAR inspection showed that a JAR can contain `fabric.mod.json` while also carrying strong Forge/FML runtime metadata. The multi-provider architecture intentionally permits the same JAR/mod to be recognized by more than one provider.

JAR filenames are never metadata authority.

## Deliberately out of scope

This checkpoint does not yet implement:

- Forge / NeoForge / Quilt mod info providers
- full Fabric dependency/version-range modeling
- contacts, licenses, contributors, environment, entrypoints or custom metadata normalization
- mod icon byte lookup
- namespace ownership
- localization
- model/texture/resource resolution
- conflict policy or automatic dependency repair

## Next approved checkpoint

Mod icon lookup, likely surfaced from `MtnMinecraftInfoMod` (for example `getIcon()`) while keeping provider-specific metadata/archive rules behind the provider architecture.
