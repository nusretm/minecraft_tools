# Minecraft Info Provider — NeoForge Mod Metadata Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/neoforge-mod-metadata-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.29
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

## Goal

Add a modern NeoForge metadata provider that normalizes `META-INF/neoforge.mods.toml` into the existing provider-independent `MtnMinecraftInfoMod` model without adding NeoForge-specific fields to core.

## Provider

Public provider:

```dart
MtnMinecraftModInfoProviderNeoForge
```

Stable provider name:

```text
neoforge
```

Recognition is based on root:

```text
META-INF/neoforge.mods.toml
```

A valid ZIP/JAR without this root metadata returns null for the NeoForge provider.

## Generic metadata mapping

NeoForge metadata is normalized into the existing generic model:

```text
modId          -> id
version        -> version
displayName    -> name
description    -> description
authors        -> authors
license        -> licenses
displayURL/modUrl -> urls.homepage
issueTrackerURL   -> urls.issues
iconFile       -> lazy getIcon()
```

No source repository URL is inferred.

The validated Armor HUD NeoForge JAR contains:

```text
homepage = https://modrinth.com/mod/armor-hud
issues   = https://github.com/SaolGhra/Armor-Hud/issues
source   = null
```

The issue tracker is not rewritten into a GitHub repository URL.

## Dependency semantics

The generic dependency enum gained:

```dart
MtnMinecraftInfoModDependencyType.discouraged
```

NeoForge mapping:

```text
type=required     -> required
type=optional     -> optional
type=incompatible -> incompatible
type=discouraged  -> discouraged

ordering=NONE   -> none
ordering=BEFORE -> before
ordering=AFTER  -> after

side=CLIENT -> client=true,  server=false
side=SERVER -> client=false, server=true
side=BOTH   -> client=true,  server=true
```

If dependency `type`, `ordering` or `side` is omitted, NeoForge defaults normalize to:

```text
required
none
both sides
```

NeoForge Maven-style `versionRange` values remain raw in generic `versionConstraints`.

## Mod-level side semantics

Dependency side and mod side remain intentionally separate.

A dependency entry such as:

```toml
side = "CLIENT"
```

only scopes that dependency.

This checkpoint does not inspect NeoForge `@Mod(dist=...)` bytecode annotations. Therefore local `neoforge.mods.toml` parsing alone does not claim client-only or server-only capability.

Current conservative result:

```text
clientSide=true
serverSide=true
```

This can later be enriched by a dedicated bytecode/provider checkpoint or authoritative remote project metadata without changing the generic model.

## Icon semantics

NeoForge icon lookup uses `iconFile`.

Precedence:

```text
mod-level iconFile
file-level iconFile
no icon
```

`logoFile` is intentionally not used as an icon fallback because modern NeoForge distinguishes icon and logo/banner semantics.

Icons use the existing lazy provider-independent API:

```dart
mod.hasIcon
await mod.getIcon()
```

Missing declared icon files do not invalidate otherwise valid metadata.

## Version substitution

Supported placeholders:

```text
${file.jarVersion}
${file.<property>}
```

`${file.jarVersion}` resolves from manifest `Implementation-Version`.

Other `file.*` placeholders resolve from file-level `properties`.

Unknown placeholders remain unmodified.

## NeoForge JarJar

NeoForge uses the shared JarJar metadata path:

```text
META-INF/jarjar/metadata.json
```

Declared embedded JARs are traversed recursively in memory.

Rules:

- no disk extraction
- missing declared embedded JARs are invalid data
- embedded JARs with NeoForge metadata become embedded logical mods
- embedded JARs without NeoForge metadata are libraries and do not create logical mods
- recursive chains are supported
- lazy embedded icon lookup follows the same archive chain

## Real Armor HUD validation

Input:

```text
armor_hud-neoforge-3.5.0+26.3.jar
```

Observed:

```text
armor_hud@3.5.0
name: Armor HUD
description: Displays the durability of your armor in a simple and clean way.
authors: SaolGhra
license: MIT
homepage: https://modrinth.com/mod/armor-hud
source: null
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: true
modTypes: neoforge
```

Dependencies:

```text
required neoforge [26.3,) ordering=none client=true server=false
required minecraft [26.3] ordering=none client=true server=false
```

The dependency-side values do not alter the mod-level side booleans.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_neoforge_mod_metadata_test.dart
18/18 passed

minecraft_forge_mod_metadata_test.dart
15/15 passed

minecraft_fabric_mod_metadata_test.dart
19/19 passed

minecraft_mod_list_test.dart
10/10 passed

dart test
334/334 passed

git diff --check
PASS

git status
clean
```

## Deliberately out of scope

This checkpoint does not add:

- bytecode `@Mod(dist=...)` scanning
- legacy NeoForge metadata variants outside `neoforge.mods.toml`
- Quilt provider
- Modrinth API integration
- CurseForge API integration
- dependency compatibility evaluation
- source URL inference
- remote project matching

## Next likely checkpoint

With Fabric, Forge and NeoForge providers now sharing one normalized model, the next high-value work can move toward remote project matching/enrichment or mod resource namespace/assets discovery without redesigning the local metadata surface.
