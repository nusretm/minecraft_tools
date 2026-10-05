# Handoff — Minecraft Info Provider Player Gameplay Core

Date: 2026-10-05

## Purpose

This note captures the Java Edition Player Gameplay Core checkpoint after
deterministic validation and a real Java Edition 1.20.1 smoke test.

## Repository state

Repository:

```text
nusretm/minecraft_tools
```

Local path:

```text
D:\development\cross-platform\minecraft_tools
```

Feature branch base:

```text
32091e15224b91f78a92668e92b53439fc1c2578
Add Minecraft player advancements foundation
```

Active branch:

```text
feature/minecraft-player-gameplay-core
```

Implementation/tool HEAD before metadata finalization:

```text
029411e8eca2c697391f2c1f96ef49271fd57bd6
```

Package version:

```text
1.0.0-dev.12
```

## Scope

This checkpoint extends the existing immutable
`MtnMinecraftInfoPlayer` snapshot with gameplay-core fields already persisted
inside the player `.dat` file.

Included:

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

Explicitly not included:

```text
inventory
ender chest
equipment
item components
active effects
singleplayer identity mapping
```

## Public semantic types

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

## Parser architecture

Player semantic parsing was extracted from `info_provider.dart` into:

```text
minecraft_info_provider/lib/src/info/info_player_nbt_parser.dart
```

The boundary is:

```text
provider
  -> discover player file
  -> read bytes
  -> gzip decode
  -> raw NBT decode

MtnMinecraftInfoPlayerNbtParser
  -> validate player NBT schema
  -> normalize cross-version semantic fields
  -> build MtnMinecraftInfoPlayer
```

This keeps filesystem/storage concerns out of the player semantic schema and
provides a stable location for the later inventory/equipment and effect
parsers.

## Nullable/default policy

The provider reports persisted values. It does not manufacture vanilla
defaults for absent tags.

Grouped models such as food, experience and abilities are created when the
corresponding group is present; individual members remain nullable when not
persisted.

## Game mode

Persisted integer mapping:

```text
0 survival
1 creative
2 adventure
3 spectator
```

`previousPlayerGameType=-1` is normalized to null. Unsupported values are
schema-invalid and produce the existing player-local `invalidData` state.

## Selected hotbar slot

`SelectedItemSlot` is accepted only in 0..8.

## Abilities

Supported persisted members:

```text
flying
mayfly
instabuild
invulnerable
mayBuild
flySpeed
walkSpeed
```

Boolean members must be NBT byte 0 or 1.

## Respawn

Legacy representation:

```text
SpawnX
SpawnY
SpawnZ
SpawnAngle
SpawnDimension
SpawnForced
```

1.21.5 representation:

```text
respawn.pos
respawn.angle
respawn.dimension
respawn.forced
```

1.21.9+ representation:

```text
respawn.pos
respawn.yaw
respawn.pitch
respawn.dimension
respawn.forced
```

All map to `MtnMinecraftInfoPlayerRespawn`.

The modern `respawn` compound is authoritative when present. A malformed
modern value does not silently fall back to legacy `Spawn*` tags.

Legacy respawn requires all three block coordinates. Optional dimension,
angle/yaw/pitch and forced values remain nullable when absent.

## Last death

`LastDeathLocation` is represented by:

- required dimension
- required three-int block position

The position shares `MtnMinecraftInfoPlayerBlockPosition` with respawn.

## Deterministic tests

Sixteen new focused tests were added in
`minecraft_player_gameplay_test.dart`.

The full package result before metadata finalization was:

```text
dart test
00:02 +120: All tests passed!
```

After the query-tool extension:

```text
dart analyze
No issues found!
```

The final analyzer/test/diff/status pass must still be rerun after metadata
finalization.

## Real Java Edition 1.20.1 smoke

The query tool read three worlds and eight player snapshots.

All eight remained available and reported `DataVersion=3465`.

Representative observations:

```text
Deneme 1
gameMode=creative
health=3.5
foodLevel=16
xpLevel=1
selectedItemSlot=1

Mtnler player
gameMode=creative
health=20.0
xpLevel=50
lastDeath=-46,66,-3680 minecraft:overworld

Mtnler player
gameMode=creative
xpLevel=64
respawn=1060,135,-243 minecraft:overworld
respawnYaw=105.85567474365234
respawnPitch=null
respawnForced=false
lastDeath=-10,143,-3687 minecraft:overworld

Mtnler survival player
gameMode=survival
mayFly=false
instantBuild=false
invulnerable=false
mayBuild=true
lastDeath=1037,124,-291 minecraft:overworld

New World
gameMode=creative
health=20.0
xpLevel=0
xpTotal=0
```

The real legacy respawn verifies that the old `Spawn*` tags normalize to the
new semantic respawn model without leaking storage-generation details into the
public API.

Float output such as `0.05000000074505806` is expected: persisted NBT
`TAG_Float` values are 32-bit floats represented by Dart `double`.

## Tool output

`tool/query_minecraft_worlds.dart` now emits:

```text
PLAYER_GAMEPLAY
PLAYER_FOOD
PLAYER_XP
PLAYER_ABILITIES
PLAYER_RESPAWN
PLAYER_LAST_DEATH
```

Null values are printed explicitly so smoke validation distinguishes absent
persisted tags from parser failures.

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/src/info/info_player.dart
minecraft_info_provider/lib/src/info/info_player_nbt_parser.dart
minecraft_info_provider/lib/src/info/info_provider.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_player_gameplay_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_PLAYER_GAMEPLAY_CORE.md
```

## Next checkpoint

Player Inventory / Equipment Foundation should build on
`MtnMinecraftInfoPlayerNbtParser` without moving item-format specifics back
into `MtnMinecraftInfoProvider`.

The next design must account for:

- legacy inventory slot encoding
- 1.20.5 item-stack `count` / component changes
- 1.21.5 equipment separation
- semantic inventory/equipment models independent from wire layout

Active effects remain a separate later checkpoint because legacy numeric
effect IDs and modern namespaced effect IDs require their own policy.

## Working rules

`docs/WORKING_RULES.md` remains authoritative.

No `dart format` was run.

## Finalization action

Pull the metadata commit, run final analyzer/tests/diff/status checks, squash
the feature branch against
`32091e15224b91f78a92668e92b53439fc1c2578`, then merge only after the
squashed tree is locally verified.
