# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

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

Real-file smoke inspection against the local modded Java Edition game directory
completed without parser/runtime failure, but no persisted item with explicit
`AttributeModifiers` was found in the discovered inventory/equipment data.
Therefore real legacy attribute-modifier payloads remain deterministic-test
validated rather than real-file validated.

No merge approval has been given for this checkpoint.

## Public API

New public item modifier model:

```text
MtnMinecraftInfoItemAttributeModifier
```

Shared operation enum:

```text
MtnMinecraftInfoAttributeModifierOperation
  addValue
  addMultipliedBase
  addMultipliedTotal
```

Item-specific slot enum:

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

Display API:

```text
MtnMinecraftInfoItemAttributeModifierDisplay
MtnMinecraftInfoItemAttributeModifierDisplayType
  defaultDisplay
  hidden
  override
```

`override` requires an `MtnMinecraftText` value. Default/hidden displays do
not carry replacement text.

## Item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
List<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers
```

Semantics:

```text
attribute modifier property absent
  -> attributeModifiers == null

explicit empty AttributeModifiers / minecraft:attribute_modifiers
  -> immutable []
```

The provider still models explicitly persisted item overrides only. It does not
synthesize implicit item-registry attribute defaults such as weapon attack
damage/speed.

## Modifier identity

Modern and legacy identity remain distinct.

1.21+:

```text
id
  -> MtnMinecraftInfoItemAttributeModifier.id
```

Pre-1.21:

```text
UUID / uuid
  -> legacyUuid

Name / name
  -> legacyName
```

Legacy UUIDs are normalized to canonical lowercase hyphenated text.

The provider deliberately does not convert a legacy UUID into a modern
namespaced modifier ID. Minecraft's data-fixer upgrade rules are not reproduced
as provider-side guesses.

A semantic modifier instance must carry exactly one identity form:

```text
modern:
  id != null
  legacyUuid == null
  legacyName == null

legacy:
  id == null
  legacyUuid != null
  legacyName != null
```

Legacy human-readable names are preserved as strings, including an explicitly
empty string.

## Attribute identity

`attributeId` remains a raw non-empty external string.

No closed vanilla attribute enum or registry lookup is introduced. This
preserves vanilla, historical, future and modded attribute IDs without guessing
renames or data-fixer behavior.

## Legacy storage

Legacy item tag:

```text
AttributeModifiers
```

Recognized entry fields:

```text
AttributeName
Name
UUID
Amount
Operation
Slot
```

`UUID` uses Minecraft's four-int UUID representation.

`Amount` is persisted as NBT double.

Legacy operation values normalize as:

```text
0 -> addValue
1 -> addMultipliedBase
2 -> addMultipliedTotal
```

Both byte and integer numeric operation representations are accepted.

Missing legacy `Slot` normalizes to `any`.

## Modern 1.20.5 component storage

Recognized component:

```text
minecraft:attribute_modifiers
```

The parser accepts both 1.20.5 representations:

```text
full:
  {modifiers:[...]}

direct:
  [...]
```

Pre-1.21 modern entries use:

```text
type
uuid
name
amount
operation
slot
```

The historical `show_in_tooltip` wrapper field is intentionally not exposed
as a public attribute-modifier API. Tooltip policy later belongs to the general
`minecraft:tooltip_display` foundation.

Unknown wrapper/entry metadata remains tolerated.

## Current modifier storage

1.21+ entries replace `uuid + name` with:

```text
id
```

If a current `id` is present it is authoritative for modifier identity;
legacy `uuid` / `name` fields are not used as fallback.

Modern operation tokens normalize as:

```text
add_value
add_multiplied_base
add_multiplied_total
```

Supported slots include single equipment slots and modern slot groups,
including `body` and `saddle`.

## 1.21.6+ display

Optional entry field:

```text
display
```

Supported display compounds:

```text
{type:"default"}
{type:"hidden"}
{type:"override", value:<Minecraft text component>}
```

Override text uses the existing shared `MtnMinecraftText.fromNbt` path.

Missing display metadata remains null rather than synthesizing the effective
default display behavior.

## UUID parser reuse

New internal shared parser:

```text
MtnMinecraftInfoNbtUuidParser
```

It normalizes Minecraft's four-int UUID representation once for:

- world `Data.singleplayer_uuid`
- legacy item attribute modifier `UUID` / `uuid`

The previous world-local four-int UUID conversion was replaced with this
shared parser so UUID normalization has one implementation authority.

## Item metadata authority

Existing authority remains unchanged:

```text
components present
  -> modern components authoritative
  -> legacy tag not consulted
```

Recognized removal conflict:

```text
minecraft:attribute_modifiers
!minecraft:attribute_modifiers
```

Both cannot be present simultaneously.

Removal-only patches remain represented by the existing
`removedComponentIds` set.

## Parser boundary

New internal parser:

```text
MtnMinecraftInfoItemAttributeModifierNbtParser
```

Dependency direction:

```text
MtnMinecraftInfoItemStackComponentsNbtParser
        |
        +-- MtnMinecraftInfoItemAttributeModifierNbtParser
                    |
                    +-- MtnMinecraftInfoNbtUuidParser
                    +-- MtnMinecraftText
```

Recognized malformed modifier data is translated through the existing
item/player invalid-data path.

Unknown modifier metadata remains tolerated.

## Query tool

Existing item-property output now includes bounded modifier previews:

```text
attributeModifiers=[
  attributeId:modifierIdentity:amount:operation:slot:displayType,
  ...
]
```

The preview is capped at three modifier entries and is shared by inventory,
ender-chest and equipment item output.

## Deterministic coverage added

New focused file:

```text
test/minecraft_item_attribute_modifiers_test.dart
```

Coverage includes:

- legacy attribute ID/name/UUID/amount/operation/slot
- canonical UUID normalization including signed int-array words
- byte and integer legacy operation storage
- missing slot -> `any`
- 1.20.5 full wrapper form
- 1.20.5 direct-list form
- legacy identity inside modern component storage
- 1.21+ namespaced modifier IDs
- arbitrary modded attribute/modifier IDs
- group/body/saddle slots
- current-ID authority over legacy identity fields
- 1.21.6 default/hidden/override display metadata
- shared Minecraft text for display override
- absent-versus-explicitly-empty semantics
- immutable modifier lists
- modern item-component authority
- component removals and removal conflicts
- unknown metadata tolerance
- malformed recognized legacy data
- malformed recognized modern data

Existing singleplayer UUID tests also exercise the shared UUID parser after the
internal refactor.

## Validation

Authoritative local validation completed from
`D:\development\cross-platform\minecraft_tools\minecraft_info_provider`:

```text
dart analyze
No issues found!

dart test test/minecraft_item_attribute_modifiers_test.dart
00:01 +14: All tests passed!

dart test test/minecraft_world_discovery_test.dart
00:01 +20: All tests passed!

dart test
00:03 +215: All tests passed!
```

Repository-root validation:

```text
git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

Real-file smoke command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'attributeModifiers=\['
```

The command completed with no matching output. The discovered real items did not
persist explicit attribute modifiers, so no real legacy modifier payload was
available to inspect. This is not a parser failure; automated deterministic
coverage remains the authority for the attribute-modifier formats in this
checkpoint.

## Previous completed checkpoint

Potion Item Properties Foundation was validated, squash merged through PR #10,
and cleaned up.

Merged main HEAD:

```text
bcef38d20670e4265f26b1295bcadd1148ad28c9
```

Package version at that checkpoint:

```text
1.0.0-dev.18
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_POTION_PROPERTIES.md
```

Locked decisions retained:

- `MtnMinecraftInfoPotionContents` is reusable rather than item-specific
- item components represent persisted overrides rather than registry defaults
- modern components remain authoritative over legacy item tags
- shared mob-effect parsing is reused for potion custom effects
- current integer and older byte amplifier storage remain supported
- registry/effective potion semantics remain outside the provider foundation

## Explicitly deferred

Attribute semantics:

- effective item-registry default attribute modifiers
- final/effective attribute-value calculations
- attribute registry/catalog lookup
- modifier-ID data-fixer emulation
- tooltip formatting/calculated modifier text
- general `minecraft:tooltip_display` parsing
- attribute modifier writing

Other item properties:

- custom model data
- nested containers / bundle-like contents
- custom data
- item writing

Potion/effect semantics:

- potion/effect registries
- effective base-effect resolution
- brewing recipes
- effective potion color/name/duration calculation
- runtime potion/effect behavior
- potion/effect writing

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

Checkpoint implementation, automated validation and available real-file smoke
inspection are complete.

Create/finalize the checkpoint handoff, then prepare the feature branch for
review/squash/PR/merge only after explicit user approval. Do not begin another
feature before this checkpoint is closed.
