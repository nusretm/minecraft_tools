# Handoff — Minecraft Info Provider Item Attribute Modifiers

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

Item Attribute Modifiers Foundation.

Feature branch:

```text
feature/minecraft-item-attribute-modifiers-foundation
```

Base:

```text
main
bcef38d20670e4265f26b1295bcadd1148ad28c9
Add item potion properties foundation
```

Package version:

```text
1.0.0-dev.19
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

No merge approval has been given.

## Public API

New public model:

```text
MtnMinecraftInfoItemAttributeModifier
```

Operation enum:

```text
MtnMinecraftInfoAttributeModifierOperation
  addValue
  addMultipliedBase
  addMultipliedTotal
```

Slot enum:

```text
MtnMinecraftInfoItemAttributeModifierSlot
  any
  hand
  armor
  mainHand
  offHand
  head
  chest
  legs
  feet
  body
  saddle
```

Display model:

```text
MtnMinecraftInfoItemAttributeModifierDisplay
MtnMinecraftInfoItemAttributeModifierDisplayType
  defaultDisplay
  hidden
  override
```

Override display requires `MtnMinecraftText`. Default and hidden display
values do not carry replacement text.

## Item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
List<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers
```

Semantics:

```text
property absent
  -> null

explicit empty property
  -> immutable []
```

Only explicitly persisted stack data is represented. Effective item-registry
defaults are not synthesized.

## Modifier identity

Modern and legacy modifier identities are deliberately preserved separately.

Current identity:

```text
id
```

Legacy identity:

```text
UUID / uuid
Name / name
```

Public fields:

```text
id
legacyUuid
legacyName
```

Exactly one identity form is valid for a semantic modifier.

Legacy four-int UUIDs normalize to canonical lowercase hyphenated UUID text.
The provider does not emulate Minecraft data-fixer conversion from legacy UUID
to namespaced modifier ID.

Legacy human-readable names remain persisted strings and may be empty.

## Attribute identity

`attributeId` is an external non-empty string.

No closed vanilla registry is introduced, so historical, current, future and
modded attribute IDs are retained without provider-side guessing.

## Legacy storage

Legacy item field:

```text
AttributeModifiers
```

Entry fields:

```text
AttributeName
Name
UUID
Amount
Operation
Slot
```

Legacy operation normalization:

```text
0 -> addValue
1 -> addMultipliedBase
2 -> addMultipliedTotal
```

Byte and integer numeric operation tags are accepted.

Missing slot normalizes to `any`.

Amount is schema-strict NBT double.

## Modern storage

Recognized component:

```text
minecraft:attribute_modifiers
```

Supported 1.20.5-era forms:

```text
{modifiers:[...]}
[...]
```

Pre-1.21 modern entries retain:

```text
type
uuid
name
amount
operation
slot
```

1.21+ entries use:

```text
type
id
amount
operation
slot
```

A present current `id` is authoritative; legacy identity fields are ignored.

Modern operation normalization:

```text
add_value            -> addValue
add_multiplied_base  -> addMultipliedBase
add_multiplied_total -> addMultipliedTotal
```

Supported slots include individual equipment slots plus `any`, `hand`,
`armor`, `body` and `saddle`.

Historical `show_in_tooltip` wrapper metadata is tolerated but not exposed as
a dedicated public API. General tooltip policy is deferred to a future
`minecraft:tooltip_display` foundation.

## 1.21.6+ display metadata

Supported entry display compounds:

```text
{type:"default"}
{type:"hidden"}
{type:"override", value:<Minecraft text component>}
```

Override text reuses `MtnMinecraftText.fromNbt`.

Absent display metadata remains null instead of synthesizing an effective
display mode.

## UUID parser reuse

New internal parser:

```text
MtnMinecraftInfoNbtUuidParser
```

It is shared by:

- world `Data.singleplayer_uuid`
- legacy item attribute modifier UUIDs

This removes duplicate four-int UUID canonicalization logic.

## Authority and strictness

Existing item authority remains:

```text
components present
  -> modern components authoritative
  -> legacy tag ignored
```

Removal conflicts are strict:

```text
minecraft:attribute_modifiers
!minecraft:attribute_modifiers
```

Both cannot exist simultaneously.

Removal-only patches remain represented through `removedComponentIds`.

Recognized malformed modifier data invalidates the containing item/player
snapshot through the existing invalid-data path.

Unknown wrapper and entry metadata remains tolerant.

## Query tool

Item property output now includes a bounded modifier preview:

```text
attributeModifiers=[
  attributeId:identity:amount:operation:slot:displayType,
  ...
]
```

At most three entries are printed, with a remaining-count marker when needed.

The same formatter is reused for inventory, ender-chest and equipment items.

## Deterministic tests

Focused test:

```text
test/minecraft_item_attribute_modifiers_test.dart
```

Coverage includes:

- legacy UUID/name identity
- signed four-int UUID normalization
- legacy attribute IDs
- byte/int operation storage
- missing slot normalization
- 1.20.5 full wrapper
- 1.20.5 direct-list form
- legacy identity in modern component storage
- current namespaced modifier IDs
- arbitrary modded attribute/modifier IDs
- grouped/body/saddle slots
- current-ID authority
- 1.21.6 default/hidden/override display
- Minecraft text override value
- absent versus explicit empty semantics
- immutable modifier lists
- modern-over-legacy item authority
- removal-only patches and conflicts
- unknown metadata tolerance
- malformed recognized legacy and modern modifier data

World discovery regression validates that the shared UUID parser continues to
preserve existing singleplayer UUID behavior.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_attribute_modifiers_test.dart
00:01 +14: All tests passed!

dart test test/minecraft_world_discovery_test.dart
00:01 +20: All tests passed!

dart test
00:03 +215: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Real-file smoke inspection

Command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'attributeModifiers=\['
```

Result:

```text
(no matching output)
```

The command completed without parser/runtime failure, but the discovered real
inventory/equipment data did not contain any explicitly persisted
`AttributeModifiers` values.

Therefore this checkpoint does not claim real-file validation of an actual
legacy modifier payload. Attribute-modifier schema behavior remains validated
by deterministic tests.

## Explicitly deferred

Attribute semantics:

- effective item-registry default modifiers
- effective/final attribute calculations
- attribute registry/catalog lookup
- legacy-to-modern modifier-ID data-fixer emulation
- generated modifier tooltip text
- general `minecraft:tooltip_display` support
- attribute-modifier writing

Other item properties:

- custom model data
- nested containers / bundle-like contents
- custom data
- item writing

Potion/effect semantics:

- potion/effect registries
- effective potion effects
- brewing recipes
- calculated potion color/name/duration
- runtime effect calculations
- potion/effect writing

Provider/player:

- pre-26.1 embedded `Data.Player` singleplayer handling
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
