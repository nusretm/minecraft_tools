# Minecraft Info Provider — Mod Asset Resource Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/mod-asset-resource-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.30
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

## Goal

Establish a provider-independent foundation for discovering and lazily reading client resources from recognized mod archives before adding language, item-model or texture-resolution logic.

## Public model

New public class:

```dart
MtnMinecraftInfoModAssetSource
```

Public relationships:

```dart
MtnMinecraftInfoMod.assetSources
MtnMinecraftInfoMod.assetNamespaces

MtnMinecraftModList.assetSources
MtnMinecraftModList.assetNamespaces
MtnMinecraftModList.getAssetSources(namespace)
```

## Archive-level resource semantics

Asset sources represent physical root or embedded archives, not authoritative ownership by one logical mod.

Locked rules:

- namespaces are discovered from `assets/<namespace>/...`
- namespace is not assumed to equal mod ID
- one archive may expose multiple namespaces
- one archive may contain multiple logical mods
- a mod archive may intentionally contribute to `minecraft` or another mod's namespace
- namespace presence alone is not authoritative resource ownership
- the normalized list deduplicates identical physical archive sources exposed by multiple metadata providers
- `getAssetSources(namespace)` returns candidate sources rather than selecting an implicit winner
- pack/resource precedence remains outside this checkpoint

## Lazy reads

Raw client assets are read through:

```dart
await source.read(namespace, path)
```

Example:

```dart
await source.read(
  'armor_hud',
  'textures/gui/hotbar_texture.png',
);
```

Behavior:

- no eager archive-wide asset byte retention
- installed roots reopen their JAR lazily
- embedded sources retain the root JAR plus embedded archive-entry chain
- embedded archive chains are traversed in memory
- embedded JARs are not extracted to disk
- missing resource returns null
- namespace and relative path are validated before reading
- reads return copied bytes

## Namespace normalization

Public asset-source construction validates namespaces against Minecraft-compatible lowercase resource namespace characters.

Namespace lists are:

- validated
- de-duplicated
- sorted
- exposed as immutable lists

Asset paths must remain relative and use lower-case resource-path-compatible characters. Traversal such as `..`, leading slash and trailing slash are rejected.

## Provider integration

The existing metadata providers now attach archive resource sources to their normalized mods:

- Fabric
- Forge
- NeoForge

All three reuse the shared archive helper.

Embedded Fabric and JarJar parsing naturally produce embedded asset sources using the same archive-chain infrastructure already used for lazy icon access.

## Normalized list integration

When providers produce the same logical `id + version`, asset sources are merged into the canonical mod.

Duplicate source identity is based on:

```text
normalized root archive path
+ embedded archive-entry path chain
```

This prevents one physical archive recognized by more than one provider from appearing as duplicate asset sources.

Normalized visible-state comparison includes archive asset-source identity and discovered namespaces so list update events remain correct when resource availability changes.

## Example

Added:

```text
minecraft_info_provider/example/mod_assets.dart
```

One-argument mode lists discovered namespaces and physical/archive-chain sources.

Three-argument mode reads a specific namespace-relative resource from every candidate source and prints the byte count.

## Real Armor HUD validation

Input:

```text
D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

Observed:

```text
Asset namespaces: armor_hud
armor_hud@3.5.0: armor_hud
  D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

Targeted lazy read:

```text
namespace: armor_hud
path: textures/gui/hotbar_texture.png
result: source[0]: 1197 bytes
```

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_mod_asset_resource_test.dart
7/7 passed

minecraft_fabric_mod_metadata_test.dart
19/19 passed

minecraft_forge_mod_metadata_test.dart
15/15 passed

minecraft_neoforge_mod_metadata_test.dart
18/18 passed

minecraft_mod_list_test.dart
10/10 passed

dart test
341/341 passed

git diff --check
PASS

git status
clean
```

## Deliberately out of scope

This checkpoint does not add:

- language/locale parsing
- translation-key lookup
- item ID to translation-key synthesis
- `assets/<namespace>/items/*.json` interpretation
- legacy item model parsing
- model parent inheritance
- texture-reference resolution
- texture PNG decoding/rendering
- resource-pack precedence
- conflict winner selection
- namespace ownership attribution

## Next intended checkpoint

The next layer should be language resource lookup on top of this raw resource source:

```text
assets/<namespace>/lang/<locale>.json
```

That checkpoint can expose translation lookup without yet mixing in item-model or rendering logic. After that, item client definition/model/texture resolution can be built as separate layers.
