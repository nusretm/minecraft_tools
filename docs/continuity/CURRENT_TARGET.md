# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

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

No merge approval has been given for this checkpoint.

## Public item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
Map<String, MtnMinecraftNbtValue>? customData
Map<String, MtnMinecraftNbtValue>? legacyTag
```

Both maps are immutable snapshots and retain `MtnMinecraftNbtValue` values
so persisted NBT type fidelity is preserved.

## Core design decision

Legacy item `tag` and modern `minecraft:custom_data` are intentionally kept
as separate public concepts.

```text
pre-1.20.5 tag
  -> legacyTag
  -> customData == null

1.20.5+ minecraft:custom_data
  -> customData
  -> legacyTag == null
```

The provider does not guess Minecraft data-fixer migration rules.

Known legacy fields continue to be parsed semantically while the full raw
legacy tag is also preserved. Unknown/modded and not-yet-modeled vanilla
fields therefore remain available without falsely classifying them as modern
custom data.

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

## Modern custom data

Recognized component:

```text
minecraft:custom_data
```

Persisted item NBT must store it as a `TAG_Compound`.

Any field names and any normal nested NBT values are preserved, including:

- byte
- short
- int
- long
- float
- double
- byte array
- string
- list
- compound
- int array
- long array

Recognized non-compound `minecraft:custom_data` storage is invalid.

## Absent / explicit empty semantics

Modern:

```text
minecraft:custom_data absent
  -> customData == null

minecraft:custom_data = {}
  -> customData != null
  -> customData.isEmpty
```

Legacy:

```text
tag absent
  -> components may remain null when no other recognized source exists
  -> legacyTag == null

tag = {}
  -> components != null
  -> legacyTag != null
  -> legacyTag.isEmpty
```

The explicit empty legacy-tag distinction is preserved because raw persisted
storage is now part of the public item snapshot.

## Modern authority

Existing authority rule is unchanged:

```text
components present
  -> modern components authoritative
  -> legacy tag ignored
```

A legacy `tag` beside a modern `components` compound is not surfaced through
`legacyTag` and is not used as fallback.

## Removal semantics

`minecraft:custom_data` is a recognized component ID for conflict checking.

```text
minecraft:custom_data
!minecraft:custom_data
```

cannot coexist.

Removal-only patches preserve the ID in `removedComponentIds` while
`customData` remains null.

## Parser architecture

No dedicated custom-data parser class was added.

`minecraft:custom_data` is deliberately generic compound NBT, so the existing
`MtnMinecraftInfoItemStackComponentsNbtParser` only validates that the
recognized modern component is a compound and retains its NBT tree.

Likewise legacy `tag` is already available at the component parser boundary
and is snapshotted directly.

This avoids unnecessary abstractions and keeps schema-specific parsers only
for properties that actually have their own schema.

## Immutability

`customData` and `legacyTag` use immutable top-level maps.

`MtnMinecraftNbtValue` already preserves immutable compound/list snapshots and
defensive array access, so nested custom/legacy data remains protected from
mutation through the public API.

## Query tool

Item-property output now includes bounded key previews:

```text
customData={3:[examplemod:id,examplemod:level,owner]}
legacyTag={8:[AttributeModifiers,Damage,RepairCost,...]}
```

Keys are sorted, previews are capped at five entries, and raw NBT values are
not recursively dumped.

## Deterministic coverage added

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
- no legacy-tag-to-custom-data guessing
- explicit empty legacy tag versus absent tag
- semantic known-field parsing alongside raw legacy preservation
- modern components authoritative over legacy tag
- immutable custom-data maps and nested NBT collections
- constructor snapshot behavior
- custom-data removal-only behavior
- custom-data/removal conflict
- malformed modern custom-data type invalidation
- unknown modern component tolerance regression

## Validation

Authoritative local validation completed from:

```text
D:\development\cross-platform\minecraft_tools\minecraft_info_provider
```

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
```

Repository-root validation:

```text
git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

## Real-file smoke validation

Real Java Edition 1.20.1 modded player inventory/equipment smoke validation completed successfully.

Command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'legacyTag=\{[1-9]|customData=\{[1-9]'
```

Observed real legacy tags included both vanilla/game-owned and mod-specific fields, for example:

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

This validates exact real-file legacy raw-tag preservation alongside semantic parsing of supported known fields.

No real `customData={...}` payload was observed in this 1.20.1 dataset; every matching real example had `customData=null`. Therefore modern `minecraft:custom_data` remains deterministic-test validated only.

The smoke result deliberately does not classify arbitrary legacy-tag fields as modern custom data and does not claim Minecraft data-fixer migration equivalence.

## Previous completed checkpoint

Nested Item Stacks Foundation was validated, squash merged through PR #13,
and cleaned up.

Merged main HEAD:

```text
dd592be8b44711936c52128a7a13461a79e6005c
```

Package version at that checkpoint:

```text
1.0.0-dev.21
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_NESTED_STACKS.md
```

Locked decisions retained:

- item components represent explicitly persisted values/overrides
- modern `components` remains authoritative over legacy `tag`
- component removals remain explicit
- unknown external IDs/metadata are tolerated where not schema-recognized
- recognized malformed component data remains strict
- no item-registry default synthesis
- recursive nested items reuse the same item model/parser
- no Minecraft data-fixer guessing

## Explicitly deferred

Custom-data tooling:

- legacy tag -> modern custom-data migration
- Minecraft data-fixer emulation
- NBT path query API
- custom-data partial/predicate matching
- custom-data mutation
- SNBT parser/writer utilities
- mod-specific custom-data interpretation

General item work:

- item writing
- registry-derived effective values
- general `minecraft:tooltip_display` support

Nested/runtime semantics:

- `minecraft:container_loot`
- registry-derived container sizes/capacities
- Bundle weight/capacity/runtime UI behavior
- Crossbow charged/firing runtime mechanics
- use-remainder runtime behavior
- block-entity inventory discovery

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

## Item-read foundation status

This is the final planned core item-read checkpoint.

Once implementation is locally validated, smoke inspected, documented,
squashed and merged, the planned `MtnMinecraftInfoItemStack` read foundation
is considered complete.

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

Checkpoint implementation, automated validation, and real-file legacy-tag smoke validation are complete.

Finalize the checkpoint handoff, then prepare squash/PR/merge only after explicit user approval. Do not begin another item feature before this checkpoint is closed.
