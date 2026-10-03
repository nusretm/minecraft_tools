# Handoff — Minecraft Info Provider Player Stats Foundation

Date: 2026-10-04

## Purpose

This note captures the Java Edition player statistics foundation after
deterministic automated validation and a real Java Edition 1.20.1 legacy-stats
smoke test.

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
7bb833bc73ebac023f5919d46781c8f79df6849d
Ignore Dart package generated files
```

Active branch:

```text
feature/minecraft-player-stats-foundation
```

Implementation/tool HEAD before metadata finalization:

```text
2607cb4a4019da3cf92433147641f64412c91965
```

Package version:

```text
1.0.0-dev.10
```

## Architecture

Player identity remains owned by:

```text
MtnMinecraftInfoWorld
└─ players: List<MtnMinecraftInfoPlayer>
```

Stats do not create a second player list and do not discover new player
identities.

Stats are a separate persisted resource read on demand:

```dart
await provider.readPlayerStats(world, player);
```

This avoids eagerly parsing all stats JSON during `readWorlds()`.

## Public model

Added:

```text
MtnMinecraftInfoPlayerStats
MtnMinecraftInfoPlayerStatsStorageLayout
MtnMinecraftInfoPlayerStatsState
MtnMinecraftInfoPlayerStatsError
```

The snapshot contains:

```text
uuid
file
storageLayout
state
error
dataVersion
values
```

`values` is:

```dart
Map<String, Map<String, int>>
```

and both levels are immutable.

External statistic/category keys remain strings so unknown vanilla, future and
modded keys are preserved.

## Storage generations

Explicitly supported by user decision:

```text
legacy:
<world>/stats/<uuid>.json

modern:
<world>/players/stats/<uuid>.json
```

Resolution policy:

- stats layout is independent from player-data layout
- modern stats are checked first
- modern wins when both exist
- corrupt modern does not fall back to legacy
- valid modern stats do not depend on legacy storage being well-formed

## Ownership validation

`readPlayerStats(world, player)` validates that:

- world is a direct child of this provider's `saves` directory
- player's data-file parent matches its declared player storage layout
- player data filename contains the canonical UUID
- filename UUID matches `player.uuid`

A stats JSON file alone cannot introduce a player.

## JSON/schema rules

Missing stats file:

```text
null
```

Present valid file:

```text
state=available
error=null
```

Present invalid file:

```text
state=invalid
error=readFailed | invalidJson | invalidData
```

Schema:

- root must be a JSON object
- `DataVersion` is optional; when present it must be an integer
- `stats` is required and must be an object
- each category value must be an object
- every statistic counter must be an integer

No semantic counter conversion is performed.

## Deterministic tests

The stats checkpoint added 16 focused tests covering:

- missing stats -> null
- legacy layout
- modern layout
- player-layout/stats-layout independence
- modern precedence
- corrupt modern no fallback
- valid modern independent of malformed legacy storage
- invalid JSON
- missing/invalid schema
- invalid DataVersion
- non-integer counters
- deep map immutability
- uppercase filename UUID normalization
- foreign player rejection
- foreign world rejection
- invalid stats storage path

Full package validation:

```text
dart analyze
No issues found!

dart test
00:02 +84: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

## Real 1.20.1 smoke validation

`tool/query_minecraft_worlds.dart` was run against a real Java Edition game
directory.

Observed:

- 3 worlds
- 8 player snapshots
- 8/8 legacy stats snapshots available
- all real stats used `<world>/stats/<uuid>.json`
- all real stats reported `DataVersion=3465`
- category counts ranged from 1 to 9
- total counter counts ranged from 5 to 668
- observed categories included:
  - `minecraft:broken`
  - `minecraft:crafted`
  - `minecraft:custom`
  - `minecraft:dropped`
  - `minecraft:killed`
  - `minecraft:killed_by`
  - `minecraft:mined`
  - `minecraft:picked_up`
  - `minecraft:used`

This validates the legacy storage path, UUID correlation, generic JSON parser
and varying real-world category/counter sets.

Modern 26.1+ storage is covered by deterministic tests but was not validated
against a real 26.1+ save in this checkpoint.

## Tool behavior

`minecraft_info_provider/tool/query_minecraft_worlds.dart` now prints one
`STATS` summary per player and one `STATS_CATEGORY` summary per category.

It deliberately reports counts instead of dumping every individual statistic
value.

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/minecraft_info_provider.dart
minecraft_info_provider/lib/src/info/info_player_stats.dart
minecraft_info_provider/lib/src/info/info_provider.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_player_stats_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-04_MINECRAFT_INFO_PROVIDER_PLAYER_STATS.md
```

## Explicitly deferred

- stats writing
- stats aggregation / leaderboards
- unit/semantic conversion
- advancements
- richer player gameplay state
- singleplayer UUID relationship

## Working rules

`docs/WORKING_RULES.md` remains authoritative.

No `dart format` was run. The library package's `.dart_tool/` and
`pubspec.lock` remain ignored.

## Next action

Pull the metadata pass, run final analyzer/tests/diff/status checks, then squash
the entire feature branch to one clean commit against
`7bb833bc73ebac023f5919d46781c8f79df6849d`.

Do not merge until the squashed tree is locally verified.
