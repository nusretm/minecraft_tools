# Minecraft Tools — Current Target

Last updated: 2026-10-03

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.
- `docs/WORKING_RULES.md` is the authoritative development and architecture
  standard for this repository work.

## Authoritative merged baseline

Merged `main` baseline before the active checkpoint:

```text
main
1a488007474b5aee5257f3a2d7fe84176bd190f3
Add working and architecture rules
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
- Java Edition player discovery

Player discovery merged as:

```text
41acef78626b97d27d38e98c7f3d9484ae0b670d
Add Minecraft player discovery foundation
```

The working-rules commit followed it on `main` and is the current branch base.

## Active checkpoint

Java Edition world aggregate player snapshots and world icon I/O.

Current branch:

```text
feature/minecraft-world-player-icon
```

Implementation/tool HEAD before this metadata pass:

```text
2944632898b90ca51bc4710ca7b44b6cad156358
```

Package version for this checkpoint:

```text
1.0.0-dev.9
```

## Public world aggregate API

`MtnMinecraftInfoWorld` now owns the immutable player snapshots discovered
with the world:

```dart
final List<MtnMinecraftInfoPlayer> players;
final MtnMinecraftInfoWorldPlayersState playersState;
final MtnMinecraftInfoWorldPlayersError? playersError;
```

`world.state` / `world.error` continue to describe `level.dat` world
metadata only.

`world.playersState` / `world.playersError` independently describe aggregate
player-list discovery. A malformed player-storage directory therefore does not
invalidate a valid world and does not abort sibling world discovery.

Individual corrupt `<uuid>.dat` files remain represented by
`MtnMinecraftInfoPlayer.state == invalid`; they do not invalidate the
aggregate player list.

`MtnMinecraftInfoProvider.readPlayers(world)` remains the explicit re-read API
for callers that want a fresh player snapshot independently of `readWorlds()`.

## World icon API

`MtnMinecraftInfoWorld` exposes:

```dart
File get iconFile;
Uint8List? get icon;
```

`icon` is a defensive copy of the raw `<world>/icon.png` bytes.

Read semantics:

- regular readable `icon.png` -> raw bytes
- missing icon -> `null`
- non-file icon path -> `null`
- icon read failure -> `null`
- no PNG decoding, validation or resizing

Write API:

```dart
Future<void> writeWorldIcon(
  MtnMinecraftInfoWorld world,
  Uint8List icon,
);
```

The supplied world must belong directly under the provider's `saves`
directory. Writes use the existing serialized same-target lane and shared
atomic replace/rollback machinery. Supplied bytes are persisted as-is.

Image processing remains outside the provider.

## Tool smoke validation

Added:

```text
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Default mode is read-only and prints:

- world directory/display name
- world state/error
- DataVersion/version/lastPlayed
- player aggregate state/error/count
- raw icon byte count
- each player's UUID/state/layout/DataVersion/dimension/position

Optional:

```text
--world <directoryName>
--set-icon <png>
```

`--set-icon` requires `--world`, writes the icon, re-runs world discovery and
verifies the persisted bytes.

## Validation status

Automated validation on Windows:

```text
dart analyze
No issues found!

dart test
00:02 +68: All tests passed!

git diff --check origin/main...HEAD
PASS
```

No `dart format` was run for this Pure Dart checkpoint.

Real Java Edition smoke validation against the user's actual game directory:

- 3 worlds discovered successfully
- player counts observed: 1, 6 and 1
- player UUID/DataVersion/dimension/position parsed successfully
- all 3 world icons read successfully
- selected world icon initially read as 9918 bytes
- replacement PNG written as 8929 bytes
- post-write re-read verified byte-for-byte
- tool reported `ICON_WRITE_RESULT PASS`

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD VALIDATED
```

## Locked foundations

This checkpoint does not redesign:

- server lifecycle/status/SRV/address matching/legacy ping
- raw NBT codec
- world `level.dat` schema semantics
- player UUID identity or NBT field semantics
- legacy/modern player-data precedence

## Development rules

Always read and follow:

```text
docs/WORKING_RULES.md
```

In particular:

- no implementation without explicit user approval
- small, independently reviewable steps
- GitHub repository changes preferred over patch files
- no `dart format` for Pure Dart unless explicitly requested
- default Pure Dart validation is `dart analyze` + `dart test`
- architecture/naming/core boundaries matter in addition to passing tests
- no backward-compatibility additions unless explicitly requested

## Next action

1. Pull this metadata/continuity pass into the local feature branch.
2. Run final `dart analyze`, `dart test` and `git diff --check`.
3. Confirm working tree is clean.
4. Squash the feature branch to one clean commit against
   `1a488007474b5aee5257f3a2d7fe84176bd190f3`.
5. Force-push only with `--force-with-lease`.
6. Merge to `main` only after final local verification.

Likely next domain after this checkpoint:

- player statistics as world/player-owned information
- then player advancements
