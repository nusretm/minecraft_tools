# Minecraft Info Provider — Generic Mod Metadata Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/generic-mod-metadata-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.27
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

## Goal

Define one loader-independent mod metadata surface that Fabric, Forge, NeoForge and future providers can populate without adding loader-specific fields to `MtnMinecraftInfoMod`.

## Generic model

`MtnMinecraftInfoMod` now carries:

```text
id
name
version
description

authors
contributors
licenses

urls.homepage
urls.source
urls.issues

clientSide
serverSide

dependencies
providedIds

modTypes
parentMods
installedFiles

getIcon()
```

## URL rules

`MtnMinecraftInfoModUrls` contains:

```text
homepage
source
issues
```

Local providers only populate values explicitly supported by their metadata.

A source repository URL must not be guessed by rewriting an issue URL or homepage URL.

This rule is intentional because future Modrinth/CurseForge providers can enrich missing data after an authoritative remote project/file match.

## Side support

Mod side compatibility is represented by two independent booleans:

```text
clientSide=true  serverSide=true   -> both
clientSide=true  serverSide=false  -> client only
clientSide=false serverSide=true   -> server only
```

Fabric mapping:

```text
environment="*"      -> true / true
environment="client" -> true / false
environment="server" -> false / true
missing environment  -> true / true
```

## Generic dependencies

`MtnMinecraftInfoModDependency` contains:

```text
id
versionConstraints
type
clientSide
serverSide
```

Generic types:

```text
required
recommended
suggested
conflict
incompatible
```

Version expressions remain raw provider syntax. The model does not attempt to make Fabric semantic-version expressions and future Forge/NeoForge Maven-style ranges share one parser prematurely.

Multiple `versionConstraints` entries are preserved as OR alternatives.

## Fabric normalization

The Fabric provider now normalizes:

```text
authors
contributors
license
contact.homepage
contact.sources
contact.issues
environment
provides
depends
recommends
suggests
conflicts
breaks
```

Fabric-specific field names remain inside `MtnMinecraftModInfoProviderFabric`.

## Multi-provider merge

`MtnMinecraftModList` continues to use `id + version` as logical identity.

For provider contributions to one logical mod:

- authors, contributors, licenses, dependencies and provided IDs are unioned without duplicates
- provider names are accumulated in `modTypes`
- side support is accumulated
- URL fields retain the first non-null authoritative value and allow later providers to fill missing values
- icon resolvers remain provider-backed and lazy

No Fabric/Forge/NeoForge switch is added to core.

## Real-world cross-loader findings

The supplied Armor HUD releases confirmed why the generic model is necessary:

```text
Fabric:
  fabric.mod.json

Forge:
  META-INF/mods.toml

NeoForge:
  META-INF/neoforge.mods.toml
```

All three describe the same logical project through different metadata vocabulary.

Fabric explicitly exposes its GitHub repository through `contact.sources`.

The inspected Forge/NeoForge Armor HUD metadata exposed Modrinth homepage and GitHub issue tracker URLs but did not expose an explicit source repository URL. The local providers must therefore leave source null rather than infer it.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_fabric_mod_metadata_test.dart
19/19 passed

minecraft_mod_list_test.dart
10/10 passed

dart test
301/301 passed

git diff --check
PASS

git status
clean
```

## Real JAR smoke

```text
armor_hud-fabric-3.5.0+26.3.jar
```

Observed:

```text
armor_hud@3.5.0
homepage: https://modrinth.com/mod/armor-hud
source: https://github.com/SaolGhra/Armor-Hud
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: false

required: fabricloader >=0.15.0
required: minecraft ~26.3
required: fabric-api *
```

## Deliberately out of scope

This checkpoint does not add:

- Forge metadata provider
- NeoForge metadata provider
- Quilt metadata provider
- Modrinth API integration
- CurseForge API integration
- dependency compatibility evaluation
- source URL inference
- remote project matching
- namespace/resource ownership

## Next likely checkpoints

The generic target model is now ready for Forge and NeoForge provider implementations.

After local providers, planned remote provider work can use Modrinth and CurseForge APIs to match local files/projects, enrich missing metadata and locate authoritative source repositories without heuristic URL rewriting.
