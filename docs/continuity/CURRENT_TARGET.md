# Minecraft Tools — Current Target

Last updated: 2026-10-04

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.
- `docs/WORKING_RULES.md` is the authoritative development and architecture
  standard.

## Authoritative merged baseline

Feature branch base:

```text
main
7bb833bc73ebac023f5919d46781c8f79df6849d
Ignore Dart package generated files
```

This baseline includes the COMPLETE / VALIDATED / MERGED foundations for:

- Java NBT codec
- `servers.dat` read/append with unknown-tag preservation
- modern and legacy Java Server List Ping
- server-owned online/offline/unavailable lifecycle
- Forge/FML advertised metadata
- Minecraft SRV discovery
- server address normalization and known-server matching
- Java Edition world discovery / `level.dat`
- Java Edition player discovery
- world-owned player snapshots
- world icon read/write

The immediately preceding merged feature checkpoint is:

```text
f315fda3842a33816c53ae6203d36e58b2bccb32
Add Minecraft world aggregate and icon IO
```

## Active checkpoint

Java Edition player statistics foundation.

Current branch:

```text
feature/minecraft-player-stats-foundation
```

Implementation/tool HEAD before this metadata pass:

```text
2607cb4a4019da3cf92433147641f64412c91965
```

Package version for this checkpoint:

```text
1.0.0-dev.10
```

## Public API

Provider addition:

```dart
Future<MtnMinecraftInfoPlayerStats?> readPlayerStats(
  MtnMinecraftInfoWorld world,
  MtnMinecraftInfoPlayer player,
);
```

Public stats types:

```text
MtnMinecraftInfoPlayerStats
MtnMinecraftInfoPlayerStatsStorageLayout
MtnMinecraftInfoPlayerStatsState
MtnMinecraftInfoPlayerStatsError
```

Stats remain player-owned information and do not create a second player-list
authority. `world.players` remains the player identity source.

## Storage layouts

Explicitly supported:

```text
legacy / pre-26.1:
<world>/stats/<uuid>.json

modern / 26.1+:
<world>/players/stats/<uuid>.json
```

The user explicitly approved legacy stats support for this checkpoint.

Stats layout is independent from `MtnMinecraftInfoPlayer.storageLayout`.

When the same canonical UUID exists in both stats locations:

- modern `players/stats` wins
- modern is resolved first
- corrupt modern does not silently fall back to legacy
- a malformed unrelated legacy storage path does not block valid modern data

A stats file never creates a new player. The caller supplies a world-owned
`MtnMinecraftInfoPlayer`, and the provider validates its UUID, data-file
layout and data-file path against that world.

## Stats JSON boundary

Missing stats:

```text
null
```

Present stats:

```text
JSON object
  -> optional integer DataVersion
  -> required object stats
  -> category key
  -> statistic/resource key
  -> integer counter
```

Public values:

```dart
Map<String, Map<String, int>>
```

Both map levels are immutable.

Unknown vanilla, future and modded category/statistic keys are preserved as
external wire/domain keys rather than converted to a closed enum.

State/error semantics:

```text
available
invalid

readFailed
invalidJson
invalidData
```

Raw counters are exposed as stored. No tick/time, distance, damage or other
unit conversion is performed.

## Loading policy

Stats are deliberately on demand.

`readWorlds()` continues to load world/player identity snapshots without
parsing every stats JSON file. Callers request one player's stats explicitly
through `readPlayerStats(world, player)`.

This keeps the core world/player discovery path bounded and avoids unnecessary
I/O for UI surfaces that do not need statistics.

## Tool smoke validation

`tool/query_minecraft_worlds.dart` now reports for every discovered player:

- stats missing/present
- stats state/error
- legacy/modern stats layout
- stats DataVersion
- exact file path
- category count
- total counter count
- per-category counter count

The tool does not dump every individual counter, keeping the smoke output
readable while still validating the full JSON parser.

## Validation status

Automated Windows validation:

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

No `dart format` was run.

Real Java Edition 1.20.1 validation:

- 3 worlds discovered
- 8 player snapshots total
- all 8 corresponding legacy stats files read as `available`
- all reported `layout=legacy`
- all reported `DataVersion=3465`
- real category sets ranged from 1 to 9 categories
- real counter sets ranged from 5 to 668 counters
- categories observed include `minecraft:broken`, `minecraft:crafted`,
  `minecraft:custom`, `minecraft:dropped`, `minecraft:killed`,
  `minecraft:killed_by`, `minecraft:mined`, `minecraft:picked_up` and
  `minecraft:used`

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD LEGACY VALIDATED
```

Modern 26.1+ storage behavior is deterministic-test validated; a real 26.1+
save was not used in this checkpoint.

## Explicitly deferred

- statistics writing
- statistics aggregation / leaderboard APIs
- semantic/unit conversion helpers
- advancements
- richer player gameplay state
- singleplayer UUID relationship

## Locked foundations

This checkpoint does not redesign:

- world/player discovery ownership
- player UUID identity
- player NBT parsing
- world icon I/O
- server/status/SRV/address behavior
- raw NBT codec

## Development rules

Always read and follow:

```text
docs/WORKING_RULES.md
```

Notably:

- no implementation without explicit user approval
- small, independently reviewable steps
- no `dart format` for Pure Dart unless explicitly requested
- `.dart_tool/` and `pubspec.lock` are ignored for this Dart library package
- GitHub repository changes are preferred over patch files
- architecture/naming/dependency boundaries are part of the acceptance bar
- backward/legacy support is only added when explicitly requested

## Next action

1. Pull this metadata/continuity pass into the local feature branch.
2. Run final `dart analyze`, `dart test`, `git diff --check` and
   `git status`.
3. Squash the feature branch to one clean commit against
   `7bb833bc73ebac023f5919d46781c8f79df6849d`.
4. Force-push only with `--force-with-lease`.
5. Merge to `main` only after the squashed tree is locally verified.

Likely next domain after this checkpoint:

- Java Edition player advancements
