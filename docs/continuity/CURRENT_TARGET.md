# Minecraft Tools — Current Target

Last updated: 2026-10-06

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\\development\\cross-platform\\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Repository state

Merged server-management milestone:

```text
main
ea853076eaab34ac2b55906f4740028cb4770ea0
Add servers.dat management and server health checks
```

Merge path:

```text
PR #16
feature/servers-dat-example -> main
squash merge
```

Package version:

```text
1.0.0-dev.28
```

Working milestone state:

```text
SERVER LIST CRUD + AUTO CHECK / HEALTH CHECK
COMPLETE / VALIDATED / MERGED
```

Working mod-loader discovery checkpoint:

```text
Branch: feature/mod-loader-discovery-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoModLoaderType`
- `MtnMinecraftInfoModLoader`
- `MtnMinecraftInfoProvider.readModLoader()`

Locked scope:

- reads only `<gameDirectory>/versions/version.json`
- interprets only `id` and `inheritsFrom`
- reports recognized loader type, loader version and Minecraft version
- missing profile or unknown loader returns null
- does not parse libraries, launcher arguments, assets, downloads or runtime metadata
- does not inspect loader JARs or the `mods/` directory

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused mod-loader discovery
9/9 passed

full package test suite
265/265 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed active profile signal:

```text
Mod loader: fabric
Loader version: 0.19.5
Minecraft version: 26.1.2
```


## Installed mod-file discovery checkpoint

```text
Branch: feature/installed-mod-file-discovery
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoMod`
- `MtnMinecraftInfoProvider.readMods()`

Locked behavior:

- scans only direct files under `<gameDirectory>/mods/`
- accepts `.jar` extension case-insensitively
- missing `mods/` returns an empty immutable list
- nested directories are not traversed
- non-JAR files are ignored
- results are sorted deterministically by file name
- At this historical checkpoint, the discovered file was the only modeled source.
- This file-only model was superseded by the dev.25 provider/graph checkpoint below; `MtnMinecraftInfoMod` now represents normalized logical mods with installed and embedded provenance.
- JAR contents and metadata were not read during the dev.24 checkpoint

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused installed mod-file discovery
7/7 passed

full package test suite
272/272 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
54 direct mod JAR files discovered
```

The real profile includes mixed naming conventions, reinforcing that file names
are discovery labels only and must not be treated as authoritative mod metadata
or loader compatibility.


## Fabric mod metadata and dependency graph checkpoint

```text
Branch: feature/fabric-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftModInfoProvider`
- `MtnMinecraftModInfoProviderFabric`
- `MtnMinecraftModList`
- `MtnMinecraftInfoMod`
- `MtnListEvent`
- `MtnMinecraftInfoProvider.readMods(modList)`

Locked behavior:

- `MtnMinecraftModList.providers` is the single parser registry authority.
- Every direct `mods/*.jar` file is offered to every registered provider.
- Provider recognition is represented by `MtnMinecraftInfoMod.modTypes`, using each provider's stable `name`.
- Logical mod identity is currently normalized by `id + version`.
- The same logical mod can be directly installed and embedded at the same time.
- Different versions remain distinct and can expose dependency/version conflicts.
- Fabric `fabric.mod.json` is parsed by the Fabric provider, not the generic info provider.
- Fabric `jars[].file` entries are verified inside the parent archive and recursively parsed in memory.
- Embedded JARs are not extracted to disk.
- Shared embedded dependencies are merged into one logical mod with multiple `parentMods`.
- `getDependencyList(mod, recursive: true)` traverses embedded dependency relationships.
- `remove(mod)` rejects embedded-only mods; installed roots can be removed while dependencies still referenced by another parent remain in the graph.
- `onItem(list, mod, event)` emits `MtnListEvent.add/update/remove` only for normalized visible-state changes.
- Core registry/list code does not hardcode Fabric/Forge/NeoForge/Quilt cases.

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused installed mod-file discovery
7/7 passed

focused mod-list registry / graph
8/8 passed

focused Fabric provider
10/10 passed

full package test suite
290/290 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
54 physical JAR files
188 normalized logical Fabric mods
```

Examples confirmed:

- direct mods with no parent
- embedded-only mods
- mods that are both directly installed and embedded
- one embedded dependency shared by several parent mods
- multiple versions of the same mod ID remaining distinct
- parent output disambiguated as `id@version`

Next launcher-facing extension after this checkpoint is mod presentation data such as icon lookup, followed later by richer metadata/dependency interpretation and additional loader providers.


## Mod icon lookup checkpoint

```text
Branch: feature/mod-icon-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoMod.hasIcon`
- `MtnMinecraftInfoMod.getIcon({int size = 128})`

Locked behavior:

- icon bytes are loaded lazily only when requested
- generic mod/core code does not interpret provider-specific icon metadata
- Fabric provider supports both a single icon path and size-to-path icon maps
- multi-size lookup selects the smallest icon width >= requested size, or the largest available icon when none are large enough
- installed mod icons reopen the root JAR lazily
- embedded mod icons reopen the root JAR and follow the embedded archive chain in memory
- embedded JARs and icons are never extracted to temporary files
- normalized `MtnMinecraftModList` entries retain working provider-backed icon resolvers
- missing icon files do not invalidate otherwise valid mods; icon lookup becomes unavailable instead
- non-positive requested sizes are rejected

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Fabric provider
15/15 passed

focused mod-list
9/9 passed

full package test suite
296/296 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
116 mods declared usable icons
116 icons loaded successfully
```

The successful reads included directly installed mods, embedded-only mods and mods that were both installed and embedded.

Example:

```text
minecraft_info_provider/example/mod_icons.dart
```


## Generic mod metadata checkpoint

```text
Branch: feature/generic-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public surface added to the provider-independent mod model:

- `MtnMinecraftInfoMod.contributors`
- `MtnMinecraftInfoMod.licenses`
- `MtnMinecraftInfoMod.urls`
- `MtnMinecraftInfoMod.clientSide`
- `MtnMinecraftInfoMod.serverSide`
- `MtnMinecraftInfoMod.dependencies`
- `MtnMinecraftInfoMod.providedIds`
- `MtnMinecraftInfoModUrls`
- `MtnMinecraftInfoModDependency`
- `MtnMinecraftInfoModDependencyType`

Locked generic metadata rules:

- `MtnMinecraftInfoMod` stays loader/provider independent.
- Provider-specific metadata tokens are normalized inside their provider implementation.
- URL metadata exposes first-class `homepage`, `source` and `issues` fields.
- Local metadata providers do not guess missing source URLs from issue-tracker or homepage URLs.
- Future Modrinth/CurseForge integration may enrich missing remote/project metadata only after a real remote match.
- `clientSide` and `serverSide` are independent booleans so client-only, server-only and both-side mods are representable.
- Fabric `environment` maps to those booleans; default/missing Fabric environment supports both sides.
- Dependency types are generic: required, recommended, suggested, conflict and incompatible.
- Provider version syntax remains raw in `versionConstraints`; multiple entries represent OR alternatives.
- `providedIds` stores provider-declared aliases without turning them into separate logical mods.
- The normalized mod list unions list metadata and side capabilities across providers and fills only missing URL fields.
- Forge/NeoForge-specific metadata parsing remains outside this checkpoint.

Fabric fields normalized in this checkpoint:

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

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Fabric metadata
19/19 passed

focused mod-list
10/10 passed

full package test suite
301/301 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-fabric-3.5.0+26.3.jar
```

Observed normalized metadata:

```text
id: armor_hud
version: 3.5.0
license: MIT
homepage: https://modrinth.com/mod/armor-hud
source: https://github.com/SaolGhra/Armor-Hud
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: false
required: fabricloader >=0.15.0
required: minecraft ~26.3
required: fabric-api *
```

Example:

```text
minecraft_info_provider/example/mod_metadata.dart
```


## Forge mod metadata checkpoint

```text
Branch: feature/forge-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public/provider surface:

- `MtnMinecraftModInfoProviderForge`
- `MtnMinecraftInfoModDependencyType.optional`
- `MtnMinecraftInfoModDependencyOrdering.none`
- `MtnMinecraftInfoModDependencyOrdering.before`
- `MtnMinecraftInfoModDependencyOrdering.after`

Locked Forge scope:

- modern Forge metadata is read from root `META-INF/mods.toml`
- one JAR may declare multiple `[[mods]]` entries
- generic fields include ID, version, display name, description, authors, license, homepage and issue tracker
- Forge metadata does not provide a source repository URL in the validated Armor HUD JAR; `urls.source` therefore remains null
- `logoFile` uses the existing lazy provider-backed icon API
- missing logo files do not invalidate otherwise valid mod metadata
- dependency `mandatory=true` maps to generic required
- dependency `mandatory=false` maps to generic optional
- dependency `ordering=NONE/BEFORE/AFTER` maps to generic dependency ordering
- dependency `side=CLIENT/SERVER/BOTH` applies only to that dependency relationship
- dependency side is never promoted into mod-level `clientSide/serverSide`
- Forge `displayTest` is not treated as a physical-side declaration
- explicit file-level `clientSideOnly=true` maps to client-only; otherwise mod-level side remains conservatively both
- Forge `versionRange` syntax is preserved as raw generic `versionConstraints`
- `${file.jarVersion}` resolves from manifest `Implementation-Version`
- `${file.<property>}` resolves from Forge file-level `properties`
- declared JarJar entries are read from `META-INF/jarjar/metadata.json`
- embedded Forge mods are recursively parsed in memory
- JarJar libraries without Forge mod metadata do not become logical mods
- legacy `mcmod.info`, bytecode `@Mod` discovery and older Forge fallbacks remain outside this checkpoint

Shared archive infrastructure:

- Fabric and Forge now reuse the same internal ZIP signature validation, archive entry lookup and lazy root/embedded archive-chain reading implementation
- embedded JARs and icons remain in-memory/lazy and are not extracted to disk

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Forge provider
15/15 passed

focused Fabric provider regression
19/19 passed

full package test suite
316/316 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-forge-3.5.0+1.20.1.jar
```

Observed logical mods:

```text
armor_hud@3.5.0
mixinextras@0.4.1
```

Observed Armor HUD normalization:

```text
homepage: https://modrinth.com/mod/armor-hud
source: null
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: true
required: forge [47,) client=true server=false
required: minecraft [1.20.1] client=true server=false
```

The Forge dependency `CLIENT` scopes intentionally do not imply that the whole mod is client-only.

Example:

```text
minecraft_info_provider/example/mod_metadata.dart
```


## Completed server-list management

`MtnMinecraftInfoProvider` now owns the complete saved-server mutation surface needed by the launcher/UI:

- `readServers()`
- `addServer(server, first: true|false)`
- `updateServer(server)`
- `removeServer(address)`

Locked behavior:

- default add remains append
- `first: true` inserts at index 0
- update preserves the matching entry's list position
- remove preserves remaining order
- update/remove target canonical server identity through `MtnMinecraftInfoServerAddress.sameIdentity()`
- bare default-port and explicit `:25565` addresses therefore match
- existing unrelated/unknown NBT tags are preserved
- writes remain serialized per target and atomically published
- caller policy decides whether a server should be added/updated/removed; there is no hidden provider-side dedup policy

Real Java Edition 1.8.9/launcher-profile smoke tests confirmed:

- existing saved servers are read correctly
- resource-pack prompt/disabled/enabled states round-trip as expected
- hidden server state is read correctly
- Provanas can be inserted first
- duplicate add is prevented by the example's canonical identity check
- update changes the chosen title/resource-pack policy in place
- remove deletes the matching entry and a second remove reports not found

## Server automatic status lifecycle

`MtnMinecraftInfoServer` now owns its own optional status refresh lifecycle.

Public/runtime behavior:

```dart
server.autoCheck       // default false
server.autoCheckSec    // default 15, minimum 15
server.dispose()
```

Locked semantics:

- values below 15 seconds clamp to 15
- enabling automatic checks never allows overlapping queries
- the first status query can be started immediately by the health-check coordinator
- after a query finishes, the next delay begins from completion time
- therefore cadence is: query -> wait interval -> query
- changing `autoCheckSec` while waiting reschedules the next check
- `dispose()` cancels waiting timers, disables auto-check and releases `onChange`
- an in-flight transport operation may finish, but after disposal it cannot publish a new status callback or schedule another automatic check
- querying or re-enabling auto-check on a disposed server is rejected

`MtnMinecraftInfoServer.clone()` preserves `autoCheckSec` but does not automatically start polling.

## Server health-check orchestration

Public coordinator:

```text
MtnMinecraftInfoServerHealthCheck
```

It owns collection/lifecycle orchestration while each server owns its timer and query logic.

Public surface includes:

- `servers` as an immutable view
- `intervalSec` with the same 15-second minimum
- `active`
- `add(server)`
- `remove(server)`
- `start()`
- `stop()`
- `dispose()`

Callbacks:

```dart
onAdd(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onChange(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onRemove(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
```

Lifecycle rules:

- add rejects duplicate object membership
- add wires the server's existing `onChange` into the checker callback chain instead of discarding it
- add starts one immediate `queryStatus()`
- if `start()` happens while that initial query is running, no second overlapping query is launched
- once the initial query completes, active auto-check scheduling begins
- changing checker `intervalSec` propagates to all managed servers
- `stop()` disables managed auto-check timers without disposing server snapshots
- `remove()` removes membership, disposes that server, then emits `onRemove`
- checker `dispose()` disposes every remaining managed server and emits `onRemove` for each

## Examples

### servers.dat CRUD

```text
minecraft_info_provider/example/servers_dat.dart
```

Actions:

```text
--add
--update
--remove
```

The example targets `oyna.provanas.com`, inserts it first when missing, updates the title/resource-pack policy, and removes it by canonical identity.

### Live server checker

```text
minecraft_info_provider/example/server_checker.dart
```

The example:

1. accepts a concrete `servers.dat` file path
2. reads every saved server
3. adds them to `MtnMinecraftInfoServerHealthCheck`
4. begins immediate status queries
5. prints add/change/remove callbacks until Ctrl+C
6. omits icon/favicon data from output
7. renders MOTD through the existing `MtnMinecraftText.plainText` representation

## Validation

Authoritative local validation on 2026-10-06:

```text
dart analyze
No issues found!

dart test
00:03 +256: All tests passed!

git diff --check
PASS

git status
clean
```

Live smoke validation used:

```text
C:\Provanas\profiles\919ffebe-f609-4019-afed-fe31537e3e5f\servers.dat
```

Observed real servers included:

- `oyna.provanas.com`
- `mc.hypixel.net`
- `play.zenitmc.com`

The live checker confirmed immediate first callbacks, repeated non-overlapping checks, online status, version/player/latency/MOTD updates, and clean remove callbacks during Ctrl+C shutdown.

## Completed item-read foundation

The core `MtnMinecraftInfoItemStack` read foundation remains complete.

Covered persisted information includes:

- item ID and count
- damage / repair cost / unbreakable
- active and stored enchantments
- custom name / item name / lore
- potion contents / duration scale
- attribute modifiers
- custom model data
- nested container contents / Bundle contents / charged projectiles / use remainder
- modern `minecraft:custom_data`
- exact legacy raw `tag`
- explicit removed component IDs

The authoritative completion note remains:

```text
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_READ_FOUNDATION_COMPLETE.md
```

## Locked item-read semantics

These remain unchanged:

- models represent persisted values, not synthesized registry defaults
- modern `components` are authoritative when present
- removed modern components remain explicit
- unknown future/modded IDs are tolerated where their schema is not recognized
- recognized malformed data remains strict
- legacy raw `tag` and modern `minecraft:custom_data` are distinct
- no Minecraft DataFixer behavior is guessed
- Pure Dart code is not auto-formatted unless explicitly requested

## Current backlog

Completed server-list CRUD and health-check work is no longer an open backlog item.

Remaining major areas include:

### Installed content / launcher presentation

- mod namespace -> owning mod mapping
- localization/resource lookup
- item model/texture resolution needed for launcher inventory rendering

### World/player expansion

- richer world metadata / cross-version normalization
- dimension/map presentation
- pre-26.1 embedded `Data.Player` singleplayer identity handling
- additional persisted player/world data only when needed by launcher/UI

### Item write/effective architecture

- item writing foundation
- effective item/registry defaults
- registry-derived capacities/defaults
- safe mutation/persistence policy

### Player progress semantics

- statistics units/aggregation/writing
- advancement definitions/display metadata/requirements/rewards
- semantic completion progress
- advancement writing

### Runtime/gameplay semantics

- attribute registry/runtime calculations
- potion/effect registry/runtime calculations
- resource-pack/item-model resolution
- nested runtime/block-entity inventory discovery
- richer Minecraft text runtime resolvers

### Advanced custom-data tooling

- legacy-to-modern migration/DataFixer integration
- NBT path query/mutation
- custom-data matching/mutation
- SNBT tooling
- mod-specific custom-data interpretation

### Separate integration work

Exact live server/sub-game/activity discovery remains future client-mod communication work. It must not be guessed from server address/logs alone.

## Authoritative handoffs

Server work:

```text
docs/continuity/HANDOFF_2026-10-02_MINECRAFT_INFO_PROVIDER_SERVER_FOUNDATION.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_SERVER_MANAGEMENT_HEALTH_CHECK.md
```

Item read work:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CORE_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_TEXT_ITEM_DISPLAY.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_POTION_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_ATTRIBUTE_MODIFIERS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_MODEL_DATA.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_NESTED_STACKS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_DATA.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_READ_FOUNDATION_COMPLETE.md
```

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- no merge without separate explicit approval
- keep checkpoints small and independently reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- use `dart analyze`, focused tests, `dart test`, `git diff --check`, `git status`
- architecture/naming/dependency boundaries are acceptance criteria
- do not modify `hypixel_api/`
- do not add backward compatibility unless explicitly approved

## Next action

There is no automatically selected next implementation checkpoint.

There is no automatically selected next implementation checkpoint after mod icon lookup. Likely launcher-facing follow-ups include richer Fabric metadata, namespace ownership/localization/resource lookup, or additional loader providers.
