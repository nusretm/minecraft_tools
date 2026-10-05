# Handoff — Minecraft Info Provider Singleplayer UUID Foundation

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

Java Edition 26.1+ Singleplayer UUID Relationship Foundation.

Feature branch:

```text
feature/minecraft-singleplayer-uuid-foundation
```

Base:

```text
main
4887a13138ecb7dfa87c44061e968d513e731a65
Add Minecraft text and item display foundation
```

Package version:

```text
1.0.0-dev.16
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

No merge approval has been given.

## Public world API

`MtnMinecraftInfoWorld` now exposes:

```dart
String? singleplayerUuid
MtnMinecraftInfoPlayer? get singleplayerPlayer
```

Authority:

```text
singleplayerUuid
  -> canonical persisted authority from level.dat

singleplayerPlayer
  -> derived lookup over world.players
```

The player relationship is not stored separately.

## Storage normalization

The checkpoint supports the Java Edition 26.1+ world field:

```text
Data.singleplayer_uuid
```

Recognized NBT shape:

```text
TAG_Int_Array
exactly four signed 32-bit integers
```

It is normalized into canonical lowercase UUID text, for example:

```text
00112233-4455-6677-8899-aabbccddeeff
```

Wrong NBT type or wrong array length is recognized malformed world data and
produces the existing world-local `invalidData` state.

## Relationship behavior

When the UUID points to a discovered player, `singleplayerPlayer` returns the
same `MtnMinecraftInfoPlayer` instance already present in `world.players`.

When the UUID exists but its player file is absent or unavailable:

```text
singleplayerUuid   -> retained
singleplayerPlayer -> null
```

The provider does not fabricate a player and does not invalidate an otherwise
valid world solely because the referenced player snapshot is unavailable.

## Scope boundary

This checkpoint deliberately does not implement pre-26.1 embedded
`Data.Player` handling.

Existing player discovery remains authoritative:

```text
pre-26.1  playerdata/<uuid>.dat
26.1+     players/data/<uuid>.dat
```

No second player reader, provider, registry or world parser was introduced.

## Query tool

`tool/query_minecraft_worlds.dart` now includes:

```text
singleplayerUuid=<uuid|null>
singleplayerPlayer=<uuid|null>
```

## Tests

Focused world-discovery coverage now verifies:

- absent singleplayer UUID
- four-int UUID normalization
- resolution to the exact discovered player snapshot
- UUID retention when the player snapshot is missing
- wrong tag type
- wrong int-array length
- world-local `invalidData` classification

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_world_discovery_test.dart
00:00 +20: All tests passed!

dart test
00:02 +179: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Files changed by the checkpoint

```text
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_SINGLEPLAYER_UUID.md
minecraft_info_provider/CHANGELOG.md
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/lib/src/info/info_provider.dart
minecraft_info_provider/lib/src/info/info_world.dart
minecraft_info_provider/test/minecraft_world_discovery_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

## Deferred

Still outside this checkpoint:

- pre-26.1 embedded `Data.Player` singleplayer identity
- player active effects
- custom model data
- attribute modifiers
- potion-specific properties
- nested containers / bundle-like contents
- custom data
- item writing
- installed-content discovery
- runtime text resolvers and richer interactive text semantics

## Next action

Do not begin another feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge
against `main`.
