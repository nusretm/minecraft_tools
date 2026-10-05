# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

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

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_world_discovery_test.dart
+20: All tests passed!

dart test
+179: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

No merge approval has been given for this checkpoint.

## Scope

Minecraft Java Edition 26.1 replaced the embedded singleplayer `Player` tag
in `level.dat` with:

```text
Data.singleplayer_uuid
```

This checkpoint handles only that modern relationship.

It does not add pre-26.1 embedded `Data.Player` parsing or any compatibility
shim.

## World singleplayer identity

`MtnMinecraftInfoWorld` now exposes:

```dart
String? singleplayerUuid
MtnMinecraftInfoPlayer? get singleplayerPlayer
```

Authority rule:

```text
singleplayerUuid
  -> canonical persisted authority from level.dat

singleplayerPlayer
  -> derived lookup over world.players
```

The player object is deliberately not stored as a second authority.

## UUID normalization

The recognized modern storage shape is:

```text
Data.singleplayer_uuid
  -> TAG_Int_Array
  -> exactly four signed 32-bit integers
```

The four integers are interpreted as the standard 128-bit Minecraft UUID
representation and normalized to canonical lowercase hyphenated text:

```text
00112233-4455-6677-8899-aabbccddeeff
```

A present recognized tag with the wrong NBT type or wrong array length is
world-local invalid data.

## Relationship semantics

When `singleplayerUuid` is absent:

```text
singleplayerUuid   == null
singleplayerPlayer == null
```

When the UUID is present and its player snapshot is discovered:

```text
singleplayerUuid
  -> retained canonical UUID

singleplayerPlayer
  -> the same MtnMinecraftInfoPlayer instance contained by world.players
```

When the UUID is present but the referenced player snapshot is unavailable:

```text
singleplayerUuid
  -> still retained

singleplayerPlayer
  -> null
```

The provider does not fabricate a player and does not invalidate an otherwise
valid world merely because the referenced player file is missing.

Existing player-discovery authority remains unchanged:

```text
pre-26.1  playerdata/<uuid>.dat
26.1+     players/data/<uuid>.dat
modern duplicate UUID candidate wins
```

The derived relationship is UUID-based and therefore reuses the existing player
snapshot/discovery model rather than adding another player reader.

## Parser boundary

World parsing remains in the existing world schema path inside
`info_provider.dart`.

The checkpoint adds only the UUID field normalization required by the existing
world model. It does not introduce a new provider, registry or parallel world
parser.

## Query tool

`tool/query_minecraft_worlds.dart` now reports:

```text
singleplayerUuid=<uuid|null>
singleplayerPlayer=<resolved uuid|null>
```

This allows real 26.1+ saves to verify both the persisted reference and player
snapshot resolution.

## Deterministic coverage added

`minecraft_world_discovery_test.dart` now covers:

- absent singleplayer UUID
- valid four-int UUID normalization
- resolution to the exact discovered player snapshot
- persisted UUID with missing player snapshot
- wrong NBT type
- wrong UUID array length
- world-local `invalidData` behavior for malformed recognized values

## Validation

Authoritative local validation completed from
`D:\development\cross-platform\minecraft_tools\minecraft_info_provider`:

```text
dart analyze
No issues found!

dart test test/minecraft_world_discovery_test.dart
00:00 +20: All tests passed!

dart test
00:02 +179: All tests passed!
```

Repository-root validation:

```text
git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Previous completed checkpoint

Minecraft Text / Item Display Properties Foundation was completed and squash
merged through PR #7.

Merged main HEAD:

```text
4887a13138ecb7dfa87c44061e968d513e731a65
```

Package version at that checkpoint:

```text
1.0.0-dev.15
```

Its authoritative handoff remains:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_TEXT_ITEM_DISPLAY.md
```

Locked text decisions remain unchanged:

- `MtnMinecraftText.text` is the canonical mutable authority.
- `plainText` is the static visible projection.
- `items` is immutable render-ready semantic span data.
- JSON/NBT conversion does not retain a second original-document authority.
- `translate/fallback/with` semantics are preserved.
- runtime `keybind`, selector, NBT-path and unresolved-score evaluation are
  still outside the provider foundation.
- item custom-name/item-name/lore reuse the global text model.

## Explicitly deferred

Text/runtime:

- runtime localization/language resolver
- keybind resolver
- selector evaluation
- scoreboard lookup
- NBT component path evaluation
- font
- insertion
- clickEvent
- hoverEvent
- richer interactive text semantics

Item/player/provider:

- custom model data
- attribute modifiers
- potion-specific properties
- nested containers / bundle-like contents
- custom data
- item writing
- player active effects
- pre-26.1 embedded `Data.Player` singleplayer identity handling
- installed-content discovery

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- keep checkpoints small and independently reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- use `dart analyze`, `dart test`, `git diff --check`, `git status`
- architecture/naming/dependency boundaries are acceptance criteria
- do not modify `hypixel_api/`
- do not add backward compatibility unless explicitly approved

## Next action

Checkpoint implementation and automated validation are complete.

Create/finalize the checkpoint handoff, then prepare the feature branch for
review/squash/PR/merge only after explicit user approval. Do not begin another
feature before this checkpoint is closed.
