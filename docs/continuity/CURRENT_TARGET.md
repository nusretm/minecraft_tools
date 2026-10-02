# Minecraft Tools — Current Target

Last updated: 2026-10-03

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
35de8cf2b84bcd72a6e0b2e79c9a0d5eb66966aa
```

This baseline includes the COMPLETE / VALIDATED / MERGED foundations for:

- Java NBT codec
- `servers.dat` read/append with unknown-tag preservation
- modern Java Server List Ping
- server-owned online/offline/unavailable lifecycle
- Forge/FML advertised metadata
- Minecraft SRV discovery
- server address normalization and known-server matching
- legacy pre-1.7 server-list ping fallback
- Java Edition world discovery / `level.dat`

The world foundation merged as:

```text
35de8cf2b84bcd72a6e0b2e79c9a0d5eb66966aa
Add Minecraft world discovery foundation
```

## Active checkpoint

Java Edition player discovery foundation.

Current branch:

```text
feature/minecraft-player-discovery-foundation
```

Remote implementation HEAD before this continuity pass:

```text
b3cbde5b290a7fcc91bf9e90f7f21d65a6880aa7
```

Package version for this checkpoint:

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

Public player types:

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

## Player discovery semantics

Supported layouts:

```text
pre-26.1:
<world>/playerdata/<uuid>.dat

26.1+:
<world>/players/data/<uuid>.dat
```

Rules:

- the supplied world must be a direct child of this provider's `saves`
  directory
- the world directory must still exist and be a directory
- missing player-data directories -> immutable empty list
- only UUID-shaped `<uuid>.dat` filenames are candidates
- public UUID identity is canonical lowercase
- the exact discovered filename/path remains available through `dataFile`
- results are deterministically ordered by canonical UUID
- non-file entries and symlink entries are not treated as player-data files
- one invalid/corrupt player does not fail sibling discovery
- if the same UUID exists in both layouts, modern `players/data` wins
- a corrupt modern duplicate does not silently fall back to legacy

## Player .dat / NBT boundary

Each candidate is decoded as:

```text
file bytes
  -> gzip decode
  -> MtnMinecraftNbtCodec.decode()
  -> Compound root
  -> MtnMinecraftInfoPlayer
```

The raw NBT codec remains compression-agnostic. No new runtime dependency was
introduced.

Core metadata:

- root `DataVersion`
- root `Dimension`
- root `Pos` as exactly three doubles

All core metadata is nullable when absent. A present field with an incompatible
NBT type is treated as invalid player data.

Player-local invalid reasons:

```text
readFailed
invalidCompression
invalidNbt
invalidData
```

Storage layout:

```text
legacy
modern
```

## Explicitly deferred player fields

The foundation deliberately does not model/normalize:

- inventory / selected item
- ender chest
- health
- food / hunger
- XP
- game mode
- abilities
- effects
- spawn state
- stats
- advancements
- `singleplayer_uuid` relationship

These remain separate checkpoints because their storage and cross-version
semantics are broader than player discovery identity and core location data.

## Validation status

Validated locally on Windows on 2026-10-03:

```text
dart analyze
No issues found!

dart test
00:02 +62: All tests passed!

git diff --check
PASS
```

The local validation sequence ran `dart format` before analyzer/tests. It left
only a formatter diff in `test/minecraft_player_discovery_test.dart`; no
behavior changed. That local formatter diff is intentionally not overwritten by
this remote metadata pass.

Current checkpoint state:

```text
IMPLEMENTED / LOCALLY VALIDATED
```

The remote feature branch currently contains implementation commits and this
metadata/continuity pass. Branch history may be squashed before merging to
`main`.

## Locked foundations

The merged server and world foundations remain locked. Player discovery does
not redesign:

- server lifecycle/status/SRV/address matching/legacy ping
- raw NBT codec
- world discovery semantics
- `level.dat` schema handling

## Development rules

- Do not start a new checkpoint without explicit user approval.
- Keep checkpoints small and independently reviewable.
- Do not commit/push/merge/tag unless the current task explicitly calls for it.
- Prefer deterministic automated tests before live smoke tests.
- Do not introduce Flutter or MtnLauncher dependencies.
- Preserve Pure Dart operation.
- Do not add backward-compatibility layers unless explicitly requested.

## Next action

1. Pull this metadata/continuity pass into the local feature branch.
2. Preserve/apply the local formatter-only player-test change.
3. Run final `git diff --check`, `dart analyze` and `dart test`.
4. Inspect the final checkpoint diff.
5. Squash the feature branch to one clean commit if desired.
6. Merge only after explicit approval.

Likely later domains include:

- player stats
- player advancements
- richer player gameplay state
- `singleplayer_uuid` relation
- richer world metadata / version history
- installed content discovery
