# Handoff — Minecraft Info Provider Player Foundation

Date: 2026-10-03

## Purpose

This note captures the Java Edition player discovery foundation after
implementation and deterministic local validation.

## Repository state

Repository:

```text
nusretm/minecraft_tools
```

Local path:

```text
D:\development\cross-platform\minecraft_tools
```

Merged baseline:

```text
main
35de8cf2b84bcd72a6e0b2e79c9a0d5eb66966aa
```

Active branch:

```text
feature/minecraft-player-discovery-foundation
```

Implementation HEAD before this metadata pass:

```text
b3cbde5b290a7fcc91bf9e90f7f21d65a6880aa7
```

Package version:

```text
1.0.0-dev.8
```

## Public API

Provider addition:

```dart
Future<List<MtnMinecraftInfoPlayer>> readPlayers(
  MtnMinecraftInfoWorld world,
);
```

New public types:

```text
MtnMinecraftInfoPlayer
MtnMinecraftInfoPlayerPosition
MtnMinecraftInfoPlayerStorageLayout
MtnMinecraftInfoPlayerState
MtnMinecraftInfoPlayerError
```

Public naming remains:

```text
MtnMinecraftInfo<Subject>
```

## Storage generations

The foundation supports both Java Edition player-data layouts:

```text
pre-26.1:
<world>/playerdata/<uuid>.dat

26.1+:
<world>/players/data/<uuid>.dat
```

When the same UUID exists in both locations, the modern `players/data` file
wins. The precedence decision happens before decoding. Therefore a corrupt
modern file remains an invalid modern snapshot and does not cause an implicit
fallback to the legacy file.

This is intentional and deterministic.

## Identity and discovery

Player identity is derived from the filename.

Accepted candidate form:

```text
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.dat
```

where each `x` is hexadecimal.

Rules:

- uppercase/lowercase hex is accepted
- public `uuid` is normalized to lowercase
- `dataFile` preserves the exact discovered filesystem path
- invalid filenames are ignored
- non-file entries are ignored
- symlink entries are not followed
- final result ordering is by canonical UUID
- returned lists are immutable

The supplied `MtnMinecraftInfoWorld` must still point to a direct child
directory under this provider's `saves` directory. Invalid world/storage paths
remain provider-level errors.

## Player .dat pipeline

```text
player .dat bytes
  -> dart:io gzip decoder
  -> existing MtnMinecraftNbtCodec
  -> Compound root
  -> immutable MtnMinecraftInfoPlayer snapshot
```

Compression remains outside the raw NBT codec. No NBT API change and no new
runtime dependency were required.

## Foundation metadata

The first player checkpoint models:

- root `DataVersion`
- root `Dimension`
- root `Pos`

`Pos` must be a list containing exactly three NBT doubles and is exposed as:

```text
MtnMinecraftInfoPlayerPosition
  x
  y
  z
```

All three core fields may be absent. A present value with an incompatible NBT
shape makes that player `invalidData`.

## Player-local invalid status

State:

```text
available
invalid
```

Errors:

```text
readFailed
invalidCompression
invalidNbt
invalidData
```

One corrupt player does not abort sibling discovery.

## Explicitly deferred

Not part of this checkpoint:

- inventory / selected item
- ender chest
- health
- hunger / food
- XP
- game mode
- abilities
- effects
- spawn state
- stats
- advancements
- `singleplayer_uuid` relationship
- filesystem watching / callbacks

The player API is snapshot discovery only.

## Validation

Windows validation on 2026-10-03:

```text
dart analyze
No issues found!

dart test
00:02 +62: All tests passed!

git diff --check
PASS
```

The local validation sequence ran `dart format` before analyzer/tests and left
a formatter-only diff in `test/minecraft_player_discovery_test.dart`. This
metadata pass does not touch that test file, so the local formatter result can
be preserved when pulling the remote documentation commit.

## Branch-history note

The remote feature branch currently contains the initial implementation commit
plus correction commits produced while composing the GitHub-side source update.
The final tree was locally validated. Before merge, the branch may be squashed
to one clean player-foundation commit.

## Locked foundations

Do not redesign the merged server or world foundations while continuing this
checkpoint. The raw NBT codec remains compression-agnostic.

## Continuation protocol

Before continuing:

1. Read `docs/continuity/CURRENT_TARGET.md`.
2. Read this handoff.
3. Confirm branch, HEAD and working tree.
4. Pull the metadata pass without discarding the local formatter-only test diff.
5. Re-run analyzer/tests after final synchronization.
6. Do not begin stats/advancements/richer-player work without explicit user
   approval.
