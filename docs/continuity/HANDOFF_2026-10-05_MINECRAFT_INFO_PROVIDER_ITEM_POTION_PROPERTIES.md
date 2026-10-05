# Handoff — Minecraft Info Provider Item Potion Properties

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

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

No merge approval has been given.

## Public potion API

New public shared model:

```text
MtnMinecraftInfoPotionContents
```

Fields:

```text
potion
customColor
customEffects
customName
```

`customEffects` is immutable and uses the shared
`MtnMinecraftInfoMobEffect` model.

The model is intentionally not item-specific so another persisted Minecraft
domain can reuse the same potion-contents representation later.

## Item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
MtnMinecraftInfoPotionContents? potionContents
double? potionDurationScale
```

The item component model continues to represent explicitly persisted values
rather than synthesizing Minecraft item-registry defaults.

Semantics:

```text
potion component absent
  -> potionContents == null

explicit minecraft:potion_contents={}
  -> potionContents != null
  -> customEffects == []

potion_duration_scale absent
  -> potionDurationScale == null
```

## Legacy potion storage

Supported pre-1.20.2 item tags:

```text
Potion
CustomPotionColor
CustomPotionEffects
```

Supported 1.20.2 through 1.20.4 custom-effect field:

```text
custom_potion_effects
```

When both custom-effect names are present:

```text
custom_potion_effects
  -> authoritative

CustomPotionEffects
  -> ignored
```

Malformed authoritative snake-case data does not fall back.

Legacy numeric effect identity and modern resource-location effect identity are
preserved through the existing shared mob-effect model.

## Modern potion contents

Supported modern item component:

```text
minecraft:potion_contents
```

Supported compound fields:

```text
potion
custom_color
custom_effects
custom_name
```

The modern single-string potion-ID shorthand is also supported.

Potion/effect IDs remain arbitrary external strings so vanilla, future and
modded IDs do not require a closed provider-side registry.

`custom_name` is preserved as a plain string, not as `MtnMinecraftText`.

`custom_color` is preserved as the persisted integer without introducing a
rendering/color abstraction.

## Potion duration scale

Supported modern component:

```text
minecraft:potion_duration_scale
```

The persisted representation is a non-negative NBT float.

The provider preserves the explicit value as nullable `double` and does not
synthesize the implicit default or apply the scale to persisted effect
durations.

## Shared mob-effect amplifier correction

The shared mob-effect parser now supports both amplifier storage eras:

```text
TAG_Byte
  -> older representation
  -> normalized as unsigned byte

TAG_Int
  -> corrected/current representation
  -> required range 0..127
```

This correction applies to player active effects, potion custom effects and
future shared-parser consumers.

The existing player active-effects tests now include an integer-amplifier
regression while retaining invalid-type strictness.

## Authority and strictness

Existing item authority is unchanged:

```text
components present
  -> modern components authoritative
  -> legacy tag not consulted
```

Recognized removal conflicts are strict for:

```text
minecraft:potion_contents
minecraft:potion_duration_scale
```

A component and its `!component` removal marker cannot both exist.

Removal-only patches remain represented by `removedComponentIds`.

Recognized malformed potion properties invalidate the containing player item
snapshot through the existing `invalidData` path.

Unknown item metadata remains tolerant.

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

Potion parsing contains nested mob-effect parser failures behind its own parser
exception, so item parsing does not depend directly on mob-effect parser
exceptions.

## Query tool

The existing shared item-property smoke output now includes:

```text
potion
potionColor
potionCustomEffects
potionCustomName
potionDurationScale
```

This covers inventory, ender-chest and equipment previews through the existing
formatter.

## Deterministic tests

New focused test:

```text
test/minecraft_item_potion_properties_test.dart
```

Coverage includes:

- pre-1.20.2 potion tags
- 1.20.2 through 1.20.4 custom effects
- modern potion-contents compound
- modern potion-ID string shorthand
- modern custom name
- arbitrary modded potion/effect IDs
- integer mob-effect amplifiers
- explicit empty potion contents
- immutable custom effects
- modern-over-legacy item authority
- snake-case custom-effect authority
- malformed-authoritative no-fallback behavior
- potion component removals/conflicts
- non-negative duration scale
- malformed recognized legacy/modern potion metadata

Existing active-effects coverage now also validates the current integer
amplifier representation.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_potion_properties_test.dart
00:01 +12: All tests passed!

dart test test/minecraft_player_active_effects_test.dart
00:00 +10: All tests passed!

dart test
00:03 +201: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Validation correction note

The first local validation attempt failed at compile/load time because one
stale `MtnMinecraftInfoMobEffectNbtParserException` catch remained in the item
component parser after exception encapsulation was introduced.

That single compile error caused all test files to fail loading. It was not
seventeen independent test regressions.

The correction pass also resolved the analyzer's export-order and
`prefer_final_locals` findings.

The final validation above is authoritative.

## Explicitly deferred

Potion/effect semantics:

- potion ID to effective effect resolution
- potion/effect registries
- brewing recipes
- effective potion color calculation
- generated/localized potion display names
- duration-scale application
- tipped-arrow/lingering-potion runtime behavior
- runtime effect/attribute calculations
- potion/effect writing

Other item properties:

- custom model data
- attribute modifiers
- nested containers / bundle-like contents
- custom data
- item writing

Provider/player:

- pre-26.1 embedded `Data.Player` singleplayer identity handling
- installed-content discovery

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

## Next action

Do not begin another feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge
against `main`.
