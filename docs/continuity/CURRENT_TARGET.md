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
371668da6565b9fb41d9a12dd1e4b51a57fc6eb9
Add Minecraft player stats foundation
```

This baseline includes COMPLETE / VALIDATED / MERGED foundations for:

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
- Java Edition player statistics

## Active checkpoint

Java Edition player advancements foundation.

Current branch:

```text
feature/minecraft-player-advancements-foundation
```

Implementation/tool HEAD before this metadata pass:

```text
d367f7e652223bd451666c3c8322e4330755aaad
```

Package version for this checkpoint:

```text
1.0.0-dev.11
```

## Public API

Provider addition:

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

Advancement progress remains player-owned information. It does not discover
players or create a second player-list authority.

## Storage layouts

Supported:

```text
legacy / pre-26.1:
<world>/advancements/<uuid>.json

modern / 26.1+:
<world>/players/advancements/<uuid>.json
```

Advancement storage layout is independent from
`MtnMinecraftInfoPlayer.storageLayout`.

Resolution semantics:

- modern is checked first
- modern wins when both files exist
- corrupt modern does not fall back to legacy
- malformed unrelated legacy storage does not block valid modern data

## Shared player-owned JSON resource boundary

Stats and advancements now share one internal filesystem/JSON reader for:

- validating world/player ownership
- canonical UUID filename matching
- resolving modern-first legacy/modern paths
- reading UTF-8 JSON
- classifying read vs JSON-decode failures

Stats and advancement schema parsing remain separate. The shared internal
reader does not introduce a public abstraction.

## Advancement JSON boundary

Missing file:

```text
null
```

Present root:

```text
{
  "DataVersion": <optional int>,
  "<advancement resource id>": {
    "criteria": {
      "<criterion name>": "<yyyy-MM-dd HH:mm:ss Z>"
    },
    "done": <bool>
  }
}
```

The public model keeps:

- optional root `DataVersion`
- arbitrary advancement resource IDs
- authoritative `done` boolean
- arbitrary criterion names
- UTC `DateTime` completion timestamps

The provider does not derive `done` from criterion count because advancement
requirements are definition data and are not contained in the player progress
snapshot.

State/error semantics:

```text
available
invalid

readFailed
invalidJson
invalidData
```

Advancement and criterion maps are immutable.

## Loading policy

Advancements are on demand.

`readWorlds()` continues to discover world/player identity without parsing
all stats and advancement JSON files. Callers explicitly use
`readPlayerAdvancements(world, player)`.

## Tool smoke validation

`tool/query_minecraft_worlds.dart` now reports:

- advancement missing/present
- state/error
- legacy/modern layout
- DataVersion
- exact file path
- total advancement count
- completed advancement count
- total completed criterion count
- an alphabetical preview of up to 10 advancement IDs
- remaining preview count through `ADVANCEMENT_MORE`

The bounded preview avoids dumping very large modded advancement files.

## Validation status

Automated Windows validation:

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

No `dart format` was run.

Real Java Edition 1.20.1 legacy validation:

- 3 worlds discovered
- 8 player snapshots total
- 8/8 advancement files parsed as `available`
- all real files used legacy `<world>/advancements/<uuid>.json`
- all reported `DataVersion=3465`
- advancement-entry counts ranged from 2 to 1363
- completed counts ranged from 1 to 1333
- completed-criterion counts ranged from 2 to 1430
- both `done=false` and `done=true` were observed
- vanilla and modded namespaces were preserved, including
  `minecraft`, `alekiships`, `alexscaves`, `alexsmobs`,
  `aquaculture` and `additionaladditions`

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD LEGACY VALIDATED
```

Modern 26.1+ storage behavior is deterministic-test validated; no real 26.1+
save was used in this checkpoint.

## Explicitly deferred

- advancement definitions
- title/description/icon/reward extraction
- requirements evaluation
- percentage / remaining-criteria calculation
- advancement writing
- richer player gameplay state
- singleplayer UUID relationship
- installed-content discovery

## Locked foundations

This checkpoint does not redesign:

- world/player discovery ownership
- player UUID identity
- player NBT parsing
- player statistics public API/schema
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
- `.dart_tool/` and `pubspec.lock` stay ignored for this Dart library package
- GitHub repository changes are preferred over patch files
- architecture/naming/dependency boundaries are part of the acceptance bar
- backward/legacy support is only added when explicitly requested

## Next action

1. Pull this metadata/continuity pass into the local feature branch.
2. Run final `dart analyze`, `dart test`, `git diff --check` and
   `git status`.
3. Squash the feature branch to one clean commit against
   `371668da6565b9fb41d9a12dd1e4b51a57fc6eb9`.
4. Force-push only with `--force-with-lease`.
5. Merge to `main` only after the squashed tree is locally verified.

Likely next domain after this checkpoint:

- richer player gameplay state
