# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

Player Active Effects / Shared Mob Effect Foundation.

Feature branch:

```text
feature/minecraft-player-active-effects-foundation
```

Base:

```text
main
d6ba63614a10eb9a8266e8ed0d93895b1944f175
Add Minecraft singleplayer UUID relationship foundation
```

Package version:

```text
1.0.0-dev.17
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_player_active_effects_test.dart
+9: All tests passed!

dart test
+188: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

No merge approval has been given for this checkpoint.

## Shared mob-effect model

Public API:

```text
MtnMinecraftInfoMobEffect
MtnMinecraftInfoMobEffectId
```

The model is deliberately shared rather than player-specific because the same
persisted mob-effect-instance structure is also used by Minecraft item potion
data.

`MtnMinecraftInfoMobEffect` contains:

```text
id
amplifier
duration
ambient
showParticles
showIcon
hiddenEffect
```

`hiddenEffect` is recursive and uses the same semantic model.

## Mob-effect identity

`MtnMinecraftInfoMobEffectId` preserves the actual persisted identity source:

```text
1.20.2+ resource-location ID
  -> resourceLocation

pre-1.20.2 numeric registry ID
  -> legacyNumeric
```

The provider does not guess a resource-location string for numeric legacy IDs.
This avoids falsely mapping modded legacy registry values without registry
context.

Legacy byte IDs are normalized as unsigned byte values. Legacy integer IDs are
preserved as non-negative integers.

## Shared NBT parser

Internal parser:

```text
MtnMinecraftInfoMobEffectNbtParser
```

The parser is independent from the player model so later item potion parsing
can reuse the same mob-effect-instance normalization.

Supported legacy fields:

```text
Id
Amplifier
Duration
Ambient
ShowParticles
ShowIcon
HiddenEffect
```

Supported modern fields:

```text
id
amplifier
duration
ambient
show_particles
show_icon
hidden_effect
```

Modern resource IDs remain arbitrary non-empty external strings so vanilla,
future and modded namespaces do not require a closed registry in the provider.

## Default normalization

Minecraft 1.20.5 stopped encoding several default mob-effect values. Missing
effect fields therefore normalize semantically rather than becoming nullable:

```text
amplifier     -> 0
duration      -> 0
ambient       -> false
showParticles -> true
showIcon      -> true
```

Duration remains the persisted tick value and may be negative where Minecraft
uses a special persisted meaning.

The provider does not add convenience interpretation such as seconds,
localized names or computed effect levels in this foundation.

## Player integration

`MtnMinecraftInfoPlayer` now exposes:

```dart
List<MtnMinecraftInfoMobEffect>? activeEffects
```

Semantics:

```text
effect-list field absent
  -> activeEffects == null

effect-list field explicitly empty
  -> immutable empty list
```

Storage normalization:

```text
legacy:
  ActiveEffects

modern:
  active_effects
```

When both forms exist, modern `active_effects` is authoritative.

A malformed modern field does not silently fall back to otherwise valid legacy
data.

## Strictness and tolerance

Recognized effect schema remains strict:

- effect ID is required
- modern ID must be a non-empty string
- legacy ID must be a byte or integer numeric ID
- amplifier must use the expected byte representation
- duration must be an integer
- booleans must be byte 0 or 1
- hidden effect must be a compound
- effect list must be a compound list

Unknown effect metadata remains tolerated.

Deprecated/removed metadata such as `factor_calculation_data` is not modeled
but does not invalidate an otherwise valid effect instance.

Malformed recognized active-effect data is normalized to the existing
player-local:

```text
MtnMinecraftInfoPlayerError.invalidData
```

## Query tool

`tool/query_minecraft_worlds.dart` now reports:

```text
PLAYER_EFFECTS ... missing=true
```

or:

```text
PLAYER_EFFECTS ... count=<n>
PLAYER_EFFECT ... id=<id> amplifier=<n> duration=<ticks> ...
```

Effect detail output is bounded to ten entries, consistent with existing query
tool preview behavior.

## Deterministic coverage added

New focused test file:

```text
test/minecraft_player_active_effects_test.dart
```

Coverage includes:

- absent active-effect list
- modern resource IDs
- modded resource IDs
- recursive hidden effects
- modern omitted-default normalization
- explicit empty-list semantics and immutability
- legacy integer IDs
- older legacy byte IDs
- modern-over-legacy authority
- malformed-modern no-fallback behavior
- malformed recognized effect fields
- unknown/future effect metadata tolerance

## Validation

Authoritative local validation completed from
`D:\development\cross-platform\minecraft_tools\minecraft_info_provider`:

```text
dart analyze
No issues found!

dart test test/minecraft_player_active_effects_test.dart
00:00 +9: All tests passed!

dart test
00:03 +188: All tests passed!
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

Java Edition 26.1+ Singleplayer UUID Relationship Foundation was validated,
squash merged through PR #8, and cleaned up.

Merged main HEAD:

```text
d6ba63614a10eb9a8266e8ed0d93895b1944f175
```

Package version at that checkpoint:

```text
1.0.0-dev.16
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_SINGLEPLAYER_UUID.md
```

Its locked decisions remain:

- `singleplayerUuid` is the persisted authority
- `singleplayerPlayer` is derived from `world.players`
- 26.1+ four-int UUID data normalizes to canonical lowercase UUID text
- missing referenced player snapshots do not fabricate a player
- pre-26.1 embedded `Data.Player` handling remains separate

## Existing locked foundations

- Minecraft text uses `MtnMinecraftText.text` as canonical mutable authority.
- Server MOTD and item display text share the global text model.
- Item components preserve modern-over-legacy authority.
- Player inventory/equipment use the shared item-stack parser.
- Player storage uses modern-over-legacy UUID precedence.
- Stats and advancements remain on-demand player-owned resources.
- World snapshots own immutable discovered player lists.

## Explicitly deferred

Mob effects / items:

- potion base-effect resolution
- `minecraft:potion_contents` parsing
- custom potion color
- effect registry/catalog lookup
- numeric legacy effect ID to resource-location lookup
- effect display names/localization
- effect icon/color lookup
- duration formatting
- runtime attribute/effect calculation
- effect writing
- custom model data
- attribute modifiers
- nested containers / bundle-like contents
- custom data
- item writing

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

Provider/player:

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
