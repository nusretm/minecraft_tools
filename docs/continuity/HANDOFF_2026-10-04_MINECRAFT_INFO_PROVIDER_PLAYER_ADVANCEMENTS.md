# Handoff — Minecraft Info Provider Player Advancements Foundation

Date: 2026-10-04

## Purpose

This note captures the Java Edition player advancements foundation after
automated validation and a real Java Edition 1.20.1 legacy advancement smoke
test.

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
371668da6565b9fb41d9a12dd1e4b51a57fc6eb9
Add Minecraft player stats foundation
```

Active branch:

```text
feature/minecraft-player-advancements-foundation
```

Implementation/tool HEAD before metadata finalization:

```text
d367f7e652223bd451666c3c8322e4330755aaad
```

Package version:

```text
1.0.0-dev.11
```

## Public API

```dart
Future<MtnMinecraftInfoPlayerAdvancements?> readPlayerAdvancements(
  MtnMinecraftInfoWorld world,
  MtnMinecraftInfoPlayer player,
);
```

Public types:

```text
MtnMinecraftInfoPlayerAdvancements
MtnMinecraftInfoPlayerAdvancement
MtnMinecraftInfoPlayerAdvancementsStorageLayout
MtnMinecraftInfoPlayerAdvancementsState
MtnMinecraftInfoPlayerAdvancementsError
```

## Architecture

Advancement progress is player-owned supplemental information. It does not
create player identities and is not eagerly loaded by `readWorlds()`.

Stats and advancements now share one internal player-owned JSON resource reader
for filesystem ownership validation, UUID matching, modern-first storage
resolution and JSON I/O. Their public models and schema parsers remain
independent.

## Storage generations

Supported:

```text
legacy:
<world>/advancements/<uuid>.json

modern:
<world>/players/advancements/<uuid>.json
```

Resolution policy:

- advancement layout is independent from player-data layout
- modern is checked first
- modern wins when both exist
- corrupt modern does not fall back to legacy
- valid modern data does not depend on legacy storage being well-formed

## Ownership validation

The provider validates that:

- the world belongs directly to this provider's `saves` directory
- the player data-file parent matches the declared player storage layout
- the player-data filename contains the canonical UUID
- filename UUID matches `player.uuid`

The advancement JSON file itself never creates or re-identifies a player.

## JSON/schema rules

Missing file:

```text
null
```

Valid present file:

```text
state=available
error=null
```

Invalid present file:

```text
state=invalid
error=readFailed | invalidJson | invalidData
```

Schema rules:

- root must be a JSON object
- `DataVersion` is optional; when present it must be an integer
- every non-`DataVersion` root key is preserved as an advancement resource ID
- every advancement value must be an object
- `done` must be boolean
- `criteria` must be an object
- every criterion value must be a vanilla timestamp string
- criterion timestamps are exposed as UTC `DateTime`

The provider does not infer completion from criteria. The stored `done`
boolean remains authoritative.

Both the advancement map and each criterion map are immutable.

## Deterministic coverage

Twenty focused advancement tests cover:

- missing file -> null
- legacy layout
- modern layout
- player-layout/advancement-layout independence
- modern precedence
- corrupt modern no fallback
- valid modern independent of malformed legacy storage
- invalid JSON
- invalid root/schema
- invalid DataVersion
- invalid progress object
- invalid `done`
- invalid `criteria`
- non-string criterion timestamp
- malformed criterion timestamp
- positive/negative timezone offsets and UTC conversion
- deep map immutability
- uppercase filename UUID normalization
- foreign player rejection
- foreign world rejection
- invalid storage directory shape

Full package validation:

```text
dart analyze
No issues found!

dart test
00:04 +104: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

## Real Java Edition 1.20.1 smoke validation

Three worlds and eight player snapshots were read from a real game directory.

Observed advancement summaries:

```text
Deneme 1
261 advancements / 241 completed / 284 criteria

Mtnler
1363 / 1333 / 1430
892  / 871  / 926
1091 / 1065 / 1155
942  / 919  / 982
715  / 695  / 745
889  / 864  / 950

New World
2 / 1 / 2
```

All eight snapshots reported:

```text
state=available
error=null
layout=legacy
DataVersion=3465
```

Real advancement IDs included vanilla and modded namespaces such as:

```text
minecraft
additionaladditions
alekiships
alexscaves
alexsmobs
aquaculture
```

The `New World` sample exposed both an incomplete advancement
(`done=false`) and a completed advancement (`done=true`), validating that
the public model preserves stored completion state rather than deriving it.

The successful parse of all real files also exercises the criterion timestamp
parser against real 1.20.1 data.

Modern 26.1+ storage is deterministic-test validated but was not exercised with
a real 26.1+ save.

## Tool behavior

`minecraft_info_provider/tool/query_minecraft_worlds.dart` reports:

- one `ADVANCEMENTS` summary per player
- up to 10 sorted `ADVANCEMENT` preview lines
- one `ADVANCEMENT_MORE` line when entries remain

This keeps large modded saves readable while retaining useful smoke-test
coverage.

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/minecraft_info_provider.dart
minecraft_info_provider/lib/src/info/info_player_advancements.dart
minecraft_info_provider/lib/src/info/info_provider.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_player_advancements_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-04_MINECRAFT_INFO_PROVIDER_PLAYER_ADVANCEMENTS.md
```

## Explicitly deferred

- advancement definitions
- display/title/description/icon/reward extraction
- requirement evaluation
- progress percentages / remaining criteria
- advancement writing
- richer player gameplay state
- singleplayer UUID relationship
- installed-content discovery

## Working rules

`docs/WORKING_RULES.md` remains authoritative.

No `dart format` was run. The library package's `.dart_tool/` and
`pubspec.lock` remain ignored.

## Next action

Pull the metadata pass, run final analyzer/tests/diff/status checks, then squash
the entire feature branch to one clean commit against
`371668da6565b9fb41d9a12dd1e4b51a57fc6eb9`.

Do not merge until the squashed tree is locally verified.
