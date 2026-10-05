# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

Potion Item Properties Foundation.

Feature branch:

```text
feature/minecraft-item-potion-properties-foundation
```

Base:

```text
main
9b7464e71aa2acdb993943795354ec0916a052f4
Add player active effects foundation
```

Package version:

```text
1.0.0-dev.18
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_potion_properties_test.dart
+12: All tests passed!

dart test test/minecraft_player_active_effects_test.dart
+10: All tests passed!

dart test
+201: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

No merge approval has been given for this checkpoint.

## Public potion model

New public API:

```text
MtnMinecraftInfoPotionContents
```

The model is deliberately shared rather than item-specific because Minecraft
also reuses the potion-contents structure outside item stacks.

Fields:

```text
potion
customColor
customEffects
customName
```

`customEffects` is always an immutable list.

Within an existing potion-contents value, absence of the persisted custom-effect
list normalizes to an empty list.

## Item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
MtnMinecraftInfoPotionContents? potionContents
double? potionDurationScale
```

The item-component model continues to represent explicitly persisted overrides,
not effective Minecraft item-registry defaults.

Therefore:

```text
potion component absent
  -> potionContents == null

explicit minecraft:potion_contents={}
  -> potionContents != null
  -> customEffects == []

potion_duration_scale absent
  -> potionDurationScale == null
```

The provider does not synthesize the implicit potion-content or duration-scale
defaults of potion item types.

## Legacy potion storage

Pre-1.20.2 item tags are normalized from:

```text
Potion
CustomPotionColor
CustomPotionEffects
```

Legacy `CustomPotionEffects` entries use the shared legacy mob-effect parser
with numeric effect identity.

Minecraft 1.20.2 through 1.20.4 changed custom effects to:

```text
custom_potion_effects
```

with modern mob-effect-instance field names and resource-location effect IDs.

When both custom-effect names exist in the same legacy item tag:

```text
custom_potion_effects
  -> authoritative

CustomPotionEffects
  -> ignored
```

Malformed authoritative snake-case data does not fall back to the older list.

## Modern potion contents

1.20.5+ item components are normalized from:

```text
minecraft:potion_contents
```

Supported full fields:

```text
potion
custom_color
custom_effects
custom_name
```

The modern component may also be read from the supported single-string potion
ID shorthand.

Potion and effect IDs remain arbitrary external strings; vanilla/future/modded
IDs do not require a closed registry inside the provider.

`custom_name` remains a plain string because Minecraft uses it as a potion
name/translation suffix. It is not a Minecraft text component.

`custom_color` remains the persisted integer value; the provider does not
introduce rendering/color abstractions in this checkpoint.

## Potion duration scale

1.21.5+:

```text
minecraft:potion_duration_scale
```

is exposed as nullable persisted `double`.

Recognized storage is a non-negative NBT float.

The provider does not synthesize Minecraft's implicit default of 1.0 and does
not apply the scale to stored custom-effect durations.

## Shared mob-effect amplifier correction

The previous shared mob-effect checkpoint supported the older NBT byte
amplifier representation.

Minecraft later corrected mob-effect amplifier NBT storage to integer and
restricted the integer value to 0..127.

The shared parser now accepts:

```text
TAG_Byte
  -> older persisted representation
  -> normalized as unsigned byte

TAG_Int
  -> corrected/current representation
  -> required range 0..127
```

This correction applies equally to:

- player active effects
- potion custom effects
- future domains reusing the shared mob-effect parser

Existing player active-effect coverage retains the older byte form and now also
includes an integer-amplifier regression.

## Authority rules

Existing item metadata authority is unchanged:

```text
components present
  -> modern components are authoritative
  -> legacy tag is not consulted
```

Therefore a legacy `Potion` tag does not fill a missing
`minecraft:potion_contents` field when a modern `components` container is
present.

Modern component removal conflicts are schema-strict for:

```text
minecraft:potion_contents
minecraft:potion_duration_scale
```

A component and its `!component` removal marker cannot both be persisted.

Removal-only patches remain represented through the existing
`removedComponentIds` authority.

## Parser boundary

New internal parser:

```text
MtnMinecraftInfoPotionContentsNbtParser
```

Dependency direction:

```text
MtnMinecraftInfoItemStackComponentsNbtParser
        |
        +-- MtnMinecraftInfoPotionContentsNbtParser
                    |
                    +-- MtnMinecraftInfoMobEffectNbtParser
```

Potion parsing contains nested mob-effect parse failures and exposes only its
own parser exception to the item-component parser.

The shared potion model/parser can therefore be reused by another persisted
domain later without making that domain depend on item-stack parsing.

## Query tool

Existing item-property smoke output now also reports:

```text
potion=<id|null>
potionColor=<int|null>
potionCustomEffects=<count|null>
potionCustomName=<string|null>
potionDurationScale=<double|null>
```

This applies to inventory, ender-chest and equipment item previews through the
existing shared item-property formatter.

## Deterministic coverage added

New focused file:

```text
test/minecraft_item_potion_properties_test.dart
```

Coverage includes:

- pre-1.20.2 `Potion`, `CustomPotionColor`, `CustomPotionEffects`
- 1.20.2 through 1.20.4 `custom_potion_effects`
- modern potion-contents compound
- modern string shorthand
- modern `custom_name`
- arbitrary modded potion/effect IDs
- modern integer mob-effect amplifier
- explicit empty potion contents
- immutable custom-effect list
- modern item-component authority
- snake-case custom-effect authority
- malformed authoritative data without fallback
- component removals and removal conflicts
- non-negative potion duration scale
- malformed recognized legacy/modern potion properties

Existing player active-effect tests gain a regression for the corrected integer
amplifier representation and reject integer amplifier values above 127.

## Validation

Authoritative local validation completed from
`D:\development\cross-platform\minecraft_tools\minecraft_info_provider`:

```text
dart analyze
No issues found!

dart test test/minecraft_item_potion_properties_test.dart
00:01 +12: All tests passed!

dart test test/minecraft_player_active_effects_test.dart
00:00 +10: All tests passed!

dart test
00:03 +201: All tests passed!
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

Player Active Effects / Shared Mob Effect Foundation was validated, squash
merged through PR #9, and cleaned up.

Merged main HEAD:

```text
9b7464e71aa2acdb993943795354ec0916a052f4
```

Package version at that checkpoint:

```text
1.0.0-dev.17
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_PLAYER_ACTIVE_EFFECTS.md
```

Locked decisions retained:

- `MtnMinecraftInfoMobEffect` is shared rather than player-specific
- modern resource-location and legacy numeric identities are preserved
- no registry guessing for legacy IDs
- recursive hidden effects share the same model
- unknown effect metadata is tolerated
- recognized malformed effect data remains strict
- player active-effects modern storage remains authoritative

The amplifier storage correction in this active checkpoint supersedes only the
previous parser's byte-only amplifier assumption; the public model and other
locked decisions remain unchanged.

## Explicitly deferred

Potion/effect semantics:

- potion ID -> effective vanilla/modded effect resolution
- potion/effect registries
- brewing recipes
- effective potion color calculation
- generated/localized potion display names
- applying duration scale to effective durations
- tipped-arrow or lingering-potion runtime duration behavior
- runtime attribute/effect calculations
- effect/potion writing

Other item properties:

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
