# Handoff — Minecraft Info Provider World Foundation

Date: 2026-10-02

## Purpose

This note captures the Java Edition world discovery / `level.dat` foundation
after implementation and deterministic validation.

## Repository state

Repository:

```text
nusretm/minecraft_tools
```

Local path:

```text
D:\development\cross-platform\minecraft_tools
```

Baseline:

```text
main
9aaa72a528a64497e2729652725063acfef205ad
```

Active branch:

```text
feature/minecraft-world-discovery-foundation
```

The checkpoint is currently uncommitted.

## Public API

Provider additions:

```dart
Directory get savesDirectory;

Future<List<MtnMinecraftInfoWorld>> readWorlds();
```

New public types:

```text
MtnMinecraftInfoWorld
MtnMinecraftInfoWorldVersion
MtnMinecraftInfoWorldState
MtnMinecraftInfoWorldError
```

Public naming remains:

```text
MtnMinecraftInfo<Subject>
```

## Discovery semantics

World candidates are direct child directories of:

```text
<gameDirectory>/saves
```

A candidate is included when it contains a regular:

```text
level.dat
```

Locked foundation behavior:

- missing `saves` -> immutable empty list
- deterministic directory-name ordering
- symlink entries are not followed
- directory name and Minecraft `LevelName` remain distinct
- corrupt/invalid worlds are represented individually
- one corrupt world does not abort discovery of siblings
- no implicit `level.dat_old` recovery

## level.dat pipeline

```text
level.dat bytes
  -> dart:io gzip decoder
  -> existing MtnMinecraftNbtCodec
  -> Compound root
  -> Data Compound
  -> immutable MtnMinecraftInfoWorld snapshot
```

Compression remains outside the raw NBT codec. The NBT API was not changed and
no new runtime dependency was added.

## Foundation metadata

The first checkpoint models:

- `LevelName`
- `DataVersion`
- `Version.Id`
- `Version.Name`
- `Version.Snapshot`
- `Version.Series`
- `LastPlayed`

Also exposed:

- world directory
- `directoryName`
- `levelFile`
- `iconFile`

`LastPlayed` is represented as UTC `DateTime`.

Metadata fields are nullable when absent. Present values with incompatible NBT
types make that world `invalidData`.

## World-local invalid status

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

Provider-level filesystem failures such as an invalid game directory or an
invalid `saves` path remain provider exceptions.

## Explicitly deferred

Not part of this checkpoint:

- game mode
- hardcore
- difficulty
- spawn
- world border
- world generation
- player data
- stats
- advancements
- automatic `level.dat_old` fallback
- filesystem watching / callbacks

The first world API is snapshot discovery only; there is no lifecycle callback.

## Validation

Windows validation on 2026-10-02:

```text
dart analyze
No issues found!

dart test
00:02 +47: All tests passed!
```

The result is:

```text
IMPLEMENTED / VALIDATED
```

No commit, push, merge or tag has been performed for this checkpoint yet.

## Continuation protocol

Before continuing:

1. Read `docs/continuity/CURRENT_TARGET.md`.
2. Read this handoff.
3. Confirm branch, HEAD and working tree.
4. Preserve the merged server foundation.
5. Do not widen world metadata or begin player/stats work without explicit user
   approval.
