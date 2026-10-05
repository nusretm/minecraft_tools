# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Authoritative merged baseline

Feature branch base:

```text
main
32091e15224b91f78a92668e92b53439fc1c2578
Add Minecraft player advancements foundation
```

This baseline includes COMPLETE / VALIDATED / MERGED foundations for:

- Java NBT codec
- `servers.dat` read/append
- modern and legacy Java Server List Ping
- server lifecycle / Forge-FML metadata / SRV
- server address normalization and known-server matching
- Java Edition world discovery
- Java Edition player discovery
- world-owned player snapshots and world icon I/O
- Java Edition player statistics
- Java Edition player advancements

## Active checkpoint

Java Edition Player Gameplay Core.

Current branch:

```text
feature/minecraft-player-gameplay-core
```

Implementation/tool HEAD before this metadata pass:

```text
029411e8eca2c697391f2c1f96ef49271fd57bd6
Show player gameplay state in world query tool
```

Package version for this checkpoint:

```text
1.0.0-dev.12
```

## Public player additions

`MtnMinecraftInfoPlayer` now exposes nullable gameplay-core state:

```text
rotation
gameMode
previousGameMode
health
absorptionAmount
food
experience
abilities
selectedItemSlot
respawn
lastDeath
```

New semantic types:

```text
MtnMinecraftInfoPlayerRotation
MtnMinecraftInfoPlayerGameMode
MtnMinecraftInfoPlayerBlockPosition
MtnMinecraftInfoPlayerFood
MtnMinecraftInfoPlayerExperience
MtnMinecraftInfoPlayerAbilities
MtnMinecraftInfoPlayerRespawn
MtnMinecraftInfoPlayerLastDeath
```

## Parsing architecture

Player NBT schema parsing is now physically separated from provider I/O:

```text
MtnMinecraftInfoProvider
  -> player file discovery
  -> gzip decode
  -> raw MtnMinecraftNbtCodec decode
  -> MtnMinecraftInfoPlayerNbtParser
  -> semantic MtnMinecraftInfoPlayer
```

The parser owns player NBT tag names/types and semantic normalization.
The provider continues to own filesystem, storage-layout precedence,
compression and player-local error classification.

## Gameplay rules

Missing persisted gameplay values remain null. No vanilla default values are
invented.

Game mode mapping:

```text
0 -> survival
1 -> creative
2 -> adventure
3 -> spectator
```

`previousPlayerGameType=-1` means no previous game mode and becomes null.
Other unsupported game-mode integers are invalid player data.

`SelectedItemSlot` is accepted only in the hotbar range 0 through 8.

Abilities parse nullable persisted fields for:

```text
flying
mayfly
instabuild
invulnerable
mayBuild
flySpeed
walkSpeed
```

Public Dart names use `mayFly` and `instantBuild`; raw Minecraft tag names
remain at the parser boundary.

## Respawn normalization

Supported semantic sources:

```text
legacy / 1.20.1:
SpawnX / SpawnY / SpawnZ
SpawnAngle
SpawnDimension
SpawnForced

1.21.5:
respawn.pos
respawn.angle
respawn.dimension
respawn.forced

1.21.9+:
respawn.pos
respawn.yaw
respawn.pitch
respawn.dimension
respawn.forced
```

All become one `MtnMinecraftInfoPlayerRespawn`.

When modern `respawn` exists, it is authoritative. A malformed modern
compound does not fall back to legacy fields.

`LastDeathLocation` is normalized to a dimension plus
`MtnMinecraftInfoPlayerBlockPosition`.

## Deterministic validation

Sixteen focused gameplay tests cover:

- complete gameplay-core parsing
- legacy respawn fields
- 1.21.5 respawn `angle`
- 1.21.9+ respawn `yaw` / `pitch`
- modern respawn precedence
- null semantics for missing gameplay fields
- previous game mode `-1`
- partial food / XP groups
- partial abilities
- invalid game mode
- selected-slot range validation
- ability boolean validation
- rotation schema validation
- incomplete legacy respawn
- malformed modern respawn with no legacy fallback
- invalid last-death position
- invalid scalar gameplay type

Full package test result before metadata finalization:

```text
dart test
00:02 +120: All tests passed!
```

Analyzer after the smoke-tool extension:

```text
dart analyze
No issues found!
```

Earlier checkpoint diff validation:

```text
git diff --check origin/main...HEAD
PASS
```

Final analyzer/test/diff/status validation must be rerun after this metadata
pass.

No `dart format` was run.

## Real Java Edition 1.20.1 smoke validation

Three worlds and eight player snapshots were read from a real game directory.
All player snapshots remained `state=available` with `DataVersion=3465`.

Observed gameplay behavior included:

- rotation values for all eight players
- both creative and survival game modes
- health values including 3.5 and 20.0
- absorption values
- food level/saturation/exhaustion/tick timer
- XP level/progress/total/seed, including zero-XP and high-XP players
- creative and survival ability combinations
- selected hotbar slots
- real `LastDeathLocation` values for multiple players
- one real legacy respawn:
  - position `1060,135,-243`
  - dimension `minecraft:overworld`
  - yaw `105.85567474365234`
  - pitch null
  - forced false

The legacy respawn observation validates normalization from the real 1.20.1
`Spawn*` representation.

Modern respawn generations remain deterministic-test validated; a real
1.21.5+ or 26.1 player file was not used in this checkpoint.

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD 1.20.1 VALIDATED
```

## Explicitly deferred

- player inventory
- ender chest
- equipment
- item components / richer item information
- active effects
- singleplayer player identity / UUID relationship
- installed-content discovery

## Locked foundations

This checkpoint does not redesign:

- player identity / UUID discovery
- legacy vs modern player-data precedence
- stats / advancements APIs
- world ownership / player aggregate semantics
- world icon I/O
- server/status/SRV/address behavior
- raw NBT codec

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- keep checkpoints small and reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- keep `.dart_tool/` and `pubspec.lock` ignored for this library package
- architecture/naming/dependency boundaries are acceptance criteria
- backward/legacy support is added only with explicit approval

## Next action

1. Pull the metadata/finalization commit into the local feature branch.
2. Run final `dart analyze`, `dart test`, `git diff --check` and
   `git status`.
3. Squash the feature branch to one clean commit against
   `32091e15224b91f78a92668e92b53439fc1c2578`.
4. Force-push only with `--force-with-lease`.
5. Fast-forward merge to `main` only after the squashed tree is locally
   verified.

Likely next checkpoint:

- Player Inventory / Equipment Foundation
