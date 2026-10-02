# Minecraft Tools — Current Target

Last updated: 2026-10-02

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.

## Authoritative baseline

Merged `main` baseline before the active checkpoint:

```text
main
9aaa72a528a64497e2729652725063acfef205ad
```

This baseline includes the COMPLETE / VALIDATED / MERGED server foundation:

- Java NBT codec
- `servers.dat` read/append with unknown-tag preservation
- modern Java Server List Ping
- server-owned online/offline/unavailable lifecycle
- Forge/FML advertised metadata
- Minecraft SRV discovery
- server address normalization and known-server matching
- legacy pre-1.7 server-list ping fallback

## Active checkpoint

Java Edition world discovery / `level.dat` foundation.

Current branch:

```text
feature/minecraft-world-discovery-foundation
```

Package version for this checkpoint:

```text
1.0.0-dev.7
```

### Implemented behavior

Public provider additions:

```dart
Directory get savesDirectory;

Future<List<MtnMinecraftInfoWorld>> readWorlds();
```

Public world types:

```text
MtnMinecraftInfoWorld
MtnMinecraftInfoWorldVersion
MtnMinecraftInfoWorldState
MtnMinecraftInfoWorldError
```

Discovery scope:

```text
<gameDirectory>/saves/*/level.dat
```

Rules:

- only direct child directories are considered
- `level.dat` must be a regular file
- symlink entries are not followed
- missing `saves` -> immutable empty list
- output ordering is deterministic by directory name
- one invalid/corrupt world does not fail sibling discovery
- `directoryName` is filesystem identity
- `LevelName` is Minecraft display metadata and does not rewrite the path
- `level.dat_old` is not an implicit fallback

### level.dat / NBT boundary

`level.dat` is decoded as:

```text
file bytes
  -> gzip decode
  -> MtnMinecraftNbtCodec.decode()
  -> Compound root
  -> Data Compound
  -> MtnMinecraftInfoWorld
```

The raw NBT codec remains compression-agnostic. No NBT API changes were needed.

Core metadata:

- `LevelName`
- `DataVersion`
- `Version.Id`
- `Version.Name`
- `Version.Snapshot`
- `Version.Series`
- `LastPlayed`

Optional metadata may be absent. A present field with an incompatible NBT type
is treated as invalid world data.

World-local invalid reasons:

```text
readFailed
invalidCompression
invalidNbt
invalidData
```

### Deferred world fields

The first checkpoint deliberately does not model/normalize:

- game mode
- hardcore
- difficulty
- spawn
- world border
- world generation
- player data
- stats
- advancements

These remain separate checkpoints because their storage and version semantics
are broader than the core world-discovery foundation.

## Validation status

Validated on Windows on 2026-10-02:

```text
dart analyze
No issues found!

dart test
00:02 +47: All tests passed!
```

The checkpoint is therefore:

```text
IMPLEMENTED / VALIDATED
```

It is not yet committed, pushed or merged.

## Locked server architecture

The server foundation merged at
`9aaa72a528a64497e2729652725063acfef205ad` remains locked. World discovery
does not redesign server lifecycle, status, SRV, address normalization, known
server matching or legacy ping behavior.

## Development rules

- Do not start a new checkpoint without explicit user approval.
- Keep checkpoints small and independently reviewable.
- Do not commit/push/merge/tag unless the current task explicitly calls for it.
- Prefer deterministic automated tests before live smoke tests.
- Do not introduce Flutter or MtnLauncher dependencies.
- Preserve Pure Dart operation.
- Do not add backward-compatibility layers unless explicitly requested.

## Next action

Finalize the world-discovery checkpoint metadata/continuity changes, inspect the
working-tree diff, then commit only when the user approves.

Likely later domains include:

- richer world metadata with explicit cross-version normalization
- player data
- statistics / advancements
- installed content discovery
- address deduplication/write policy
