# Handoff — Minecraft Info Provider Player Active Effects Foundation

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

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

No merge approval has been given.

## Public shared mob-effect API

The package now exports:

```text
MtnMinecraftInfoMobEffect
MtnMinecraftInfoMobEffectId
```

The mob-effect model is deliberately shared rather than player-specific so
future item potion parsing can reuse the same persisted effect representation.

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

`hiddenEffect` recursively uses the same semantic model.

## Effect identity

`MtnMinecraftInfoMobEffectId` preserves the persisted identity source:

```text
modern resource location -> resourceLocation
legacy numeric ID        -> legacyNumeric
```

The provider does not guess a resource location for numeric legacy IDs because
legacy/modded registry mappings are outside the available information context.

Legacy byte IDs are normalized as unsigned-byte values. Legacy integer IDs are
preserved as non-negative integers.

## Shared NBT parser

Internal parser:

```text
MtnMinecraftInfoMobEffectNbtParser
```

Supported legacy effect fields:

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

Unknown effect metadata is tolerated. Recognized fields remain schema-strict.

## Default normalization

Missing modern/defaulted values normalize to:

```text
amplifier     -> 0
duration      -> 0
ambient       -> false
showParticles -> true
showIcon      -> true
```

Duration remains the persisted tick value. No seconds conversion, runtime
effect evaluation, display-name resolution or computed level is added.

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

Storage forms:

```text
legacy:
  ActiveEffects

modern:
  active_effects
```

Modern `active_effects` is authoritative when both forms are present.
Malformed modern data does not fall back to legacy data.

Malformed recognized effect data maps to the existing player-local
`MtnMinecraftInfoPlayerError.invalidData`.

## Query tool

`tool/query_minecraft_worlds.dart` now emits bounded active-effect smoke
output:

```text
PLAYER_EFFECTS ... missing=true
```

or:

```text
PLAYER_EFFECTS ... count=<n>
PLAYER_EFFECT ... id=<id> amplifier=<n> duration=<ticks> ...
```

Detail preview is bounded to ten entries.

## Deterministic tests

Focused file:

```text
test/minecraft_player_active_effects_test.dart
```

Coverage verifies:

- absent effect-list semantics
- modern vanilla resource IDs
- arbitrary modded resource IDs
- recursive hidden effects
- omitted-default normalization
- explicit empty-list semantics
- public list immutability
- legacy integer IDs
- legacy byte IDs
- no registry guessing for legacy IDs
- modern-over-legacy authority
- malformed modern no-fallback behavior
- malformed recognized fields
- unknown/future metadata tolerance

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_player_active_effects_test.dart
00:00 +9: All tests passed!

dart test
00:03 +188: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Files changed by the checkpoint

```text
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_PLAYER_ACTIVE_EFFECTS.md
minecraft_info_provider/CHANGELOG.md
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/lib/minecraft_info_provider.dart
minecraft_info_provider/lib/src/info/info_mob_effect.dart
minecraft_info_provider/lib/src/info/info_mob_effect_nbt_parser.dart
minecraft_info_provider/lib/src/info/info_player.dart
minecraft_info_provider/lib/src/info/info_player_nbt_parser.dart
minecraft_info_provider/test/minecraft_player_active_effects_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

## Explicitly deferred

Still outside this checkpoint:

- `minecraft:potion_contents` parsing
- potion base-effect resolution
- custom potion color
- effect registry/catalog lookup
- numeric legacy effect ID to resource-location mapping
- effect display names/localization
- effect icon/color lookup
- duration formatting
- runtime effect/attribute calculations
- effect writing
- custom model data
- attribute modifiers
- nested containers / bundle-like contents
- custom data
- item writing
- pre-26.1 embedded `Data.Player` singleplayer identity handling
- installed-content discovery
- runtime text resolvers and richer interactive text semantics

## Next action

Do not begin another feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge
against `main`.
