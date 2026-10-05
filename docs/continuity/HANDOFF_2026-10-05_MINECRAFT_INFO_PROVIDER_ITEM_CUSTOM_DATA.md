# Handoff — Minecraft Info Provider Item Custom Data

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

Custom Data Foundation.

Feature branch:

```text
feature/minecraft-item-custom-data-foundation
```

Base:

```text
main
dd592be8b44711936c52128a7a13461a79e6005c
Add item nested stacks foundation
```

Package version:

```text
1.0.0-dev.22
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

No merge approval has been given.

## Public API

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
Map<String, MtnMinecraftNbtValue>? customData
Map<String, MtnMinecraftNbtValue>? legacyTag
```

Both are immutable snapshots.

## Core semantic decision

Legacy item `tag` and modern `minecraft:custom_data` remain separate concepts.

```text
pre-1.20.5 tag
  -> legacyTag
  -> customData == null

1.20.5+ minecraft:custom_data
  -> customData
  -> legacyTag == null
```

The provider does not emulate or guess Minecraft data-fixer migration rules.

Known legacy fields continue to be normalized semantically while the full raw legacy tag is retained in parallel.

## Modern custom data

Recognized component:

```text
minecraft:custom_data
```

Persisted storage must be `TAG_Compound`.

The public map preserves all normal NBT value types through `MtnMinecraftNbtValue`, including primitive numerics, strings, arrays, lists and nested compounds.

Malformed recognized non-compound storage follows the existing player `invalidData` path.

## Legacy tag preservation

A present pre-1.20.5 `tag` compound is preserved exactly through `legacyTag`, including:

- Minecraft-owned known fields
- not-yet-modeled vanilla fields
- mod-specific fields
- nested compounds/lists/arrays

Raw preservation does not change existing semantic normalization.

Example:

```text
legacy tag:
{
  Damage: 7,
  examplemod:value: 42
}

result:
damage == 7
legacyTag['Damage'] == 7
legacyTag['examplemod:value'] == 42
customData == null
```

## Absent / empty semantics

```text
custom_data absent -> customData == null
custom_data {}     -> customData is non-null and empty

tag absent         -> legacyTag == null
tag {}             -> legacyTag is non-null and empty
```

A present empty legacy tag therefore causes `MtnMinecraftInfoItemStackComponents` to remain non-null.

## Authority and removals

Existing authority remains:

```text
components present
  -> modern authoritative
  -> legacy tag ignored
```

`minecraft:custom_data` participates in recognized removal conflicts.

A matching component and `!minecraft:custom_data` cannot coexist.

Removal-only state is retained in `removedComponentIds` while `customData` remains null.

## Parser architecture

No dedicated custom-data parser class was introduced.

`MtnMinecraftInfoItemStackComponentsNbtParser` directly validates modern custom data as a compound and snapshots it.

Legacy tag is already available at the same parser boundary and is preserved directly.

This keeps the implementation simple and avoids a schema abstraction for intentionally schema-free data.

## Query tool

Bounded previews were added:

```text
customData={3:[examplemod:id,examplemod:level,owner]}
legacyTag={8:[AttributeModifiers,Damage,RepairCost,...]}
```

Keys are sorted and previews are capped at five. Raw NBT values are not recursively dumped.

## Deterministic tests

Focused test:

```text
test/minecraft_item_custom_data_test.dart
```

Coverage includes:

- arbitrary modern custom data
- NBT numeric type fidelity
- strings, arrays, lists and nested compounds
- absent versus explicit empty modern custom data
- raw legacy tag preservation
- no legacy-to-modern custom-data guessing
- explicit empty legacy tag versus absent tag
- semantic known-field parsing alongside raw legacy preservation
- modern authority over legacy tag
- immutable top-level and nested data
- constructor snapshot behavior
- custom-data removal-only state
- removal conflict
- malformed modern custom-data type
- unknown modern component tolerance

Existing core-property regression coverage was updated so unknown legacy metadata is now expected to survive in `legacyTag`, while unknown modern component tolerance remains unchanged.

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_custom_data_test.dart
00:00 +11: All tests passed!

dart test test/minecraft_item_core_properties_test.dart
00:00 +14: All tests passed!

dart test test/minecraft_item_nested_stacks_test.dart
00:00 +13: All tests passed!

dart test
00:03 +250: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Real-file smoke validation

Real Java Edition 1.20.1 modded inventory/equipment data produced many persisted legacy tags.

Command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'legacyTag=\{[1-9]|customData=\{[1-9]'
```

Representative observed examples:

```text
minecraft:diamond_sword
  legacyTag={1:[Damage]}

minecraft:firework_rocket
  legacyTag={1:[Fireworks]}

simplyswords:diamond_greataxe
  legacyTag={3:[Damage,Enchantments,RepairCost]}

cataclysm:cursed_bow
  legacyTag={3:[Enchantments,PrevUseTime,UseTime]}

sophisticatedbackpacks:gold_backpack
  legacyTag={7:[borderColor,clothColor,contentsUuid,inventorySlots,renderInfo,+2]}

simplyswords:magiscythe
  legacyTag={3:[Damage,nether_power,runic_power]}
```

This validates real raw legacy-tag preservation across vanilla-known, vanilla-not-yet-modeled, and mod-specific metadata while semantic fields continue to parse.

No real modern `customData={...}` payload was observed in the available 1.20.1 dataset. Every matching real example had `customData=null`, so modern `minecraft:custom_data` remains deterministic-test validated only.

The smoke result does not claim legacy-tag-to-custom-data equivalence.

## Explicitly deferred

- legacy tag -> modern custom-data migration
- Minecraft data-fixer emulation
- NBT path query API
- custom-data partial/predicate matching
- custom-data mutation
- SNBT parser/writer utilities
- mod-specific custom-data interpretation
- item writing
- registry-derived effective values
- general `minecraft:tooltip_display` support

Existing nested/runtime, provider/player and text/runtime deferrals remain unchanged.

## Item-read foundation status

This is the final planned core item-read checkpoint.

Once this checkpoint is squashed and merged, the planned `MtnMinecraftInfoItemStack` read foundation is considered complete.

## Next action

Do not begin another item feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge against `main`.
