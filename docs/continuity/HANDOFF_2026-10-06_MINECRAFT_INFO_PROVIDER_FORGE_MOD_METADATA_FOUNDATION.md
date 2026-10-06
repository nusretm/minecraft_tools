# Minecraft Info Provider — Forge Mod Metadata Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/forge-mod-metadata-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.28
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

## Goal

Add a modern Forge metadata provider that normalizes `META-INF/mods.toml` into the existing loader-independent `MtnMinecraftInfoMod` model without adding Forge-specific fields to core.

## Provider

Public provider:

```dart
MtnMinecraftModInfoProviderForge
```

Stable provider name:

```text
forge
```

Recognition is based on root:

```text
META-INF/mods.toml
```

A valid ZIP/JAR without this root metadata returns null for the Forge provider.

## Generic metadata mapping

Modern Forge metadata is normalized into the existing generic model:

```text
modId        -> id
version      -> version
displayName  -> name
description  -> description
authors      -> authors
license      -> licenses
displayURL   -> urls.homepage
issueTrackerURL -> urls.issues
logoFile     -> lazy getIcon()
```

No source repository URL is inferred.

The validated Armor HUD Forge JAR contains:

```text
homepage = https://modrinth.com/mod/armor-hud
issues   = https://github.com/SaolGhra/Armor-Hud/issues
source   = null
```

The issue tracker is not rewritten into a GitHub repository URL.

## Dependencies

The generic dependency model gained:

```dart
MtnMinecraftInfoModDependencyType.optional

MtnMinecraftInfoModDependencyOrdering.none
MtnMinecraftInfoModDependencyOrdering.before
MtnMinecraftInfoModDependencyOrdering.after
```

Forge mapping:

```text
mandatory=true  -> required
mandatory=false -> optional

ordering=NONE   -> none
ordering=BEFORE -> before
ordering=AFTER  -> after

side=CLIENT -> client=true,  server=false
side=SERVER -> client=false, server=true
side=BOTH   -> client=true,  server=true
```

Forge Maven-style `versionRange` values are preserved verbatim in generic `versionConstraints`.

## Mod-level side semantics

Dependency side and mod side are intentionally separate.

A dependency such as:

```toml
side = "CLIENT"
```

only scopes that dependency relationship. It does not make the owning mod client-only.

Forge `displayTest` is network/version compatibility behavior and is not used to infer physical installation side.

For this checkpoint:

```text
clientSideOnly=true -> clientSide=true, serverSide=false
otherwise           -> clientSide=true, serverSide=true
```

This is intentionally conservative rather than heuristic.

## Version substitution

Forge placeholders supported:

```text
${file.jarVersion}
${file.<property>}
```

`${file.jarVersion}` resolves from:

```text
META-INF/MANIFEST.MF
Implementation-Version
```

Other `file.*` properties resolve from file-level `properties` in `mods.toml`.

Unknown placeholders remain unmodified instead of being guessed.

## Icons

Forge `logoFile` plugs into the existing provider-independent lazy icon API:

```dart
mod.hasIcon
await mod.getIcon()
```

The icon is not retained eagerly in every normalized mod object.

Installed roots reopen the root JAR lazily. Embedded Forge mods follow their archive chain lazily in memory.

Missing declared logo files do not invalidate otherwise valid metadata.

## Shared archive infrastructure

Common provider archive behavior was extracted to internal helpers used by Fabric and Forge:

- JAR/ZIP signature validation
- exact archive entry lookup
- lazy root JAR reopening
- recursive embedded archive traversal
- error normalization

The Fabric provider retains its existing behavior through this shared infrastructure.

## Forge JarJar

Forge JarJar metadata is read from:

```text
META-INF/jarjar/metadata.json
```

Declared embedded JAR paths are followed recursively in memory.

Rules:

- no disk extraction
- declared missing JARs are invalid data
- embedded JARs with Forge `META-INF/mods.toml` become embedded logical mods
- embedded JARs without Forge metadata are libraries and do not create logical mods
- recursive JarJar chains are supported

## Real Armor HUD validation

Input:

```text
armor_hud-forge-3.5.0+1.20.1.jar
```

Normalized root:

```text
armor_hud@3.5.0
name: Armor HUD
authors: SaolGhra
license: MIT
homepage: https://modrinth.com/mod/armor-hud
source: null
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: true
modTypes: forge
```

Dependencies:

```text
required forge [47,)      ordering=none client=true server=false
required minecraft [1.20.1] ordering=none client=true server=false
```

JarJar also produced:

```text
mixinextras@0.4.1
name: MixinExtras
authors: LlamaLad7
license: MIT
homepage: https://github.com/LlamaLad7/MixinExtras
modTypes: forge
```

A deeper nested library without Forge mod metadata did not become an extra logical mod.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_forge_mod_metadata_test.dart
15/15 passed

minecraft_fabric_mod_metadata_test.dart
19/19 passed

dart test
316/316 passed

git diff --check
PASS

git status
clean
```

## Dependency

Added:

```yaml
toml: ^0.16.0
```

This version preserves the package's current Dart SDK floor of `>=3.3.0`.

## Deliberately out of scope

This checkpoint does not add:

- legacy Forge `mcmod.info`
- bytecode `@Mod` scanning
- older Forge/LaunchWrapper discovery fallbacks
- NeoForge provider
- Quilt provider
- Modrinth API integration
- CurseForge API integration
- dependency compatibility evaluation
- source URL inference

## Next likely checkpoint

The next local metadata provider can be NeoForge using the same generic target model.

Legacy Forge support should remain a separate checkpoint because real 1.8.9-era mods may require `mcmod.info`, manifest inspection and/or bytecode annotation discovery rather than modern `mods.toml`.
