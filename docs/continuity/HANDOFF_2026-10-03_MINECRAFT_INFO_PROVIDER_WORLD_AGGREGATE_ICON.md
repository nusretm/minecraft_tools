# Handoff — Minecraft Info Provider World Aggregate + Icon I/O

Date: 2026-10-03

## Purpose

This note captures the Java Edition world aggregate player-snapshot and world
icon I/O checkpoint after automated and real-save validation.

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
1a488007474b5aee5257f3a2d7fe84176bd190f3
```

Active branch:

```text
feature/minecraft-world-player-icon
```

Implementation/tool HEAD before this metadata pass:

```text
2944632898b90ca51bc4710ca7b44b6cad156358
```

Package version:

```text
1.0.0-dev.9
```

## World aggregate

`MtnMinecraftInfoWorld` now carries the immutable player list discovered for
that world:

```dart
world.players
world.playersState
world.playersError
```

The error boundaries are intentionally separate:

```text
world.state / world.error
  -> level.dat world metadata

world.playersState / world.playersError
  -> aggregate player-storage discovery

player.state / player.error
  -> one individual player file
```

A malformed `players/data` storage path no longer aborts `readWorlds()` or
invalidates an otherwise healthy `level.dat` world. Sibling worlds continue
to be returned.

Individual corrupt player files remain player-local invalid snapshots.

`readPlayers(world)` remains available as an explicit fresh read of that
world's player storage.

## World icon

World icon path remains:

```text
<world>/icon.png
```

Public snapshot API:

```dart
world.iconFile
world.icon
```

`world.icon` returns defensive raw bytes and is nullable.

No PNG codec or image dependency was added. Missing, non-file or unreadable
icons are represented as `null`.

Write API:

```dart
await provider.writeWorldIcon(world, pngBytes);
```

Writes are serialized per target and use the same generalized atomic
temporary/displaced-file replacement mechanism already used by
`servers.dat`.

The provider does not decode, resize or validate the image payload.

## Tool

Added:

```text
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Read-only example:

```powershell
dart run tool/query_minecraft_worlds.dart `
  --game-directory "$env:APPDATA\.minecraft"
```

Selected world:

```powershell
dart run tool/query_minecraft_worlds.dart `
  --game-directory "$env:APPDATA\.minecraft" `
  --world "New World"
```

Opt-in icon write + re-read verification:

```powershell
dart run tool/query_minecraft_worlds.dart `
  --game-directory "$env:APPDATA\.minecraft" `
  --world "New World" `
  --set-icon "D:\path\to\icon.png"
```

## Automated validation

Windows:

```text
dart analyze
No issues found!

dart test
00:02 +68: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Real-save validation

The tool was run against a real Java Edition game directory.

Observed:

- 3 worlds
- player counts 1 / 6 / 1
- all worlds `available`
- all player aggregates `available`
- UUID, DataVersion, dimension and position parsed for real player files
- icon bytes read for all three worlds
- one selected icon read as 9918 bytes
- replacement icon written as 8929 bytes
- post-write world re-read matched the supplied bytes exactly
- final tool result: `ICON_WRITE_RESULT PASS`

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/src/info/info_world.dart
minecraft_info_provider/lib/src/info/info_provider.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_world_discovery_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-03_MINECRAFT_INFO_PROVIDER_WORLD_AGGREGATE_ICON.md
```

## Working rules

`docs/WORKING_RULES.md` is authoritative.

Notably:

- do not begin a new implementation without explicit approval
- keep checkpoints narrow
- prefer GitHub changes over patch files
- do not run `dart format` for Pure Dart unless explicitly requested
- passing tests alone is not the quality bar
- preserve architecture/naming/dependency boundaries

## Next action

Pull this metadata pass, run final analyzer/tests/diff check, then squash all
feature-branch commits to one clean checkpoint commit against
`1a488007474b5aee5257f3a2d7fe84176bd190f3`.

Do not merge until the final squashed tree is locally verified.
