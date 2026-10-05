# Handoff — Minecraft Info Provider Item Core Properties Foundation

Date: 2026-10-05

## Purpose

This note captures the Java Edition Item Core Properties Foundation after
deterministic validation and a real modded Java Edition 1.20.1 smoke test.

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
00467ae4b985b092f79cf929b391a549070fb966
Add Minecraft player inventory and equipment foundation
```

Active branch:

```text
feature/minecraft-item-core-properties-foundation
```

Implementation/tool HEAD before metadata finalization:

```text
f824ca985d8ab5802feff7cea0d0ced5d8257e8d
```

Package version:

```text
1.0.0-dev.14
```

## Scope

Included:

```text
legacy item tag core properties
modern item components core properties
damage
repair cost
unbreakable
active enchantments
stored enchantments
modern explicit component removals
modded enchantment resource IDs
```

Explicitly not included:

```text
custom name
lore / text components
custom model data
attribute modifiers
potion data
container contents
custom data
other rich item components
item writing
```

## Public model

`MtnMinecraftInfoItemStack` now exposes:

```text
components -> MtnMinecraftInfoItemStackComponents?
```

The component model:

```text
MtnMinecraftInfoItemStackComponents
  damage
  repairCost
  unbreakable
  enchantments
  storedEnchantments
  removedComponentIds
```

The model contains explicitly persisted stack overrides. It does not claim to
be a registry-resolved effective item definition.

## Parser architecture

New internal parser:

```text
minecraft_info_provider/lib/src/info/info_item_stack_components_nbt_parser.dart
```

Responsibility split:

```text
MtnMinecraftInfoPlayerInventoryNbtParser
  -> player storage / slot routing

MtnMinecraftInfoItemStackNbtParser
  -> item id / count
  -> delegates metadata

MtnMinecraftInfoItemStackComponentsNbtParser
  -> legacy tag format
  -> modern components format
  -> semantic item-core properties
```

This keeps item metadata reusable outside player inventory for future
container/entity/item-bearing sources.

## Legacy normalization

Recognized legacy `tag` fields:

```text
Damage
RepairCost
Unbreakable
Enchantments
StoredEnchantments
```

Enchantments are read as compound-list entries with:

```text
id  -> namespaced string
lvl -> short
```

The result is an immutable namespaced-ID-to-level map.

Unknown legacy fields are ignored by this foundation. Malformed recognized
fields invalidate the containing player snapshot through the existing item
parser error boundary.

## Modern normalization

Recognized component IDs:

```text
minecraft:damage
minecraft:repair_cost
minecraft:unbreakable
minecraft:enchantments
minecraft:stored_enchantments
```

If a `components` compound is present, it is authoritative and legacy
`tag` is not consulted for that item.

Enchantments support both normalized source shapes used across modern
generations:

```text
nested levels compound
direct enchantment-ID map
```

Both become immutable `Map<String, int>` values.

Unknown modern component IDs remain tolerated.

## Modern component removals

Modern patch keys beginning with `!` are retained without registry
interpretation.

Example:

```text
!minecraft:damage
```

becomes:

```text
removedComponentIds contains minecraft:damage
```

The provider does not infer a default damage value after removal because
effective defaults require the Minecraft item registry.

A recognized component supplied and removed simultaneously is treated as
invalid normalized data.

## Missing versus empty semantics

```text
no recognized property/removal
  -> item.components == null

recognized nullable scalar absent
  -> scalar == null

enchantment property explicitly present but empty
  -> immutable empty map

enchantment property absent
  -> null

modern removal set empty on an otherwise recognized component object
  -> immutable empty set
```

## Deterministic tests

Fourteen focused tests were added in:

```text
minecraft_info_provider/test/minecraft_item_core_properties_test.dart
```

They cover:

```text
legacy core properties
1.20.5-style modern components
later simplified enchantment map
modern-over-legacy authority
unknown metadata tolerance
explicit empty enchantments
legacy false unbreakable
map immutability
legacy schema failures
duplicate legacy enchantments
modern schema failures
tag/components container shape
component removals/conflicts
removal-set immutability
```

The earlier inventory/equipment tests were updated only where the previous
foundation deliberately supplied invalid placeholder string values for
`tag` / `components`. Those containers are now valid compounds containing
unknown metadata so tolerance behavior remains tested correctly.

Validation before smoke-tool extension:

```text
dart analyze
No issues found!

dart test
00:02 +149: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

After the smoke-tool extension:

```text
dart analyze
No issues found!
```

Final validation must be repeated after this metadata commit.

No `dart format` was run.

## Real Java Edition 1.20.1 modded smoke validation

The smoke tool read three worlds and eight player snapshots from a real modded
Java Edition 1.20.1 game directory.

All observed player files:

```text
DataVersion=3465
storageLayout=legacy
```

### Real damage and repair cost

Observed examples:

```text
simplyswords:diamond_greataxe
  damage=365
  repairCost=3

minecraft:diamond_axe
  damage=147

butchersdelight:cleaver
  damage=34

simplyswords:magiscythe
  damage=15

simplyswords:emberlash
  damage=2
```

Equipment examples:

```text
caverns_and_chasms:sanguine_chestplate
  damage=280
  repairCost=1

caverns_and_chasms:sanguine_leggings
  damage=274

caverns_and_chasms:sanguine_boots
  damage=280
  repairCost=1
```

Cataclysm Cursium armor provided a useful large persisted repair-cost case:

```text
repairCost=131071
```

The value is preserved as stored rather than capped to an assumed gameplay
range.

### Real enchantments

Mixed vanilla/modded enchantment maps were read successfully.

Examples:

```text
simplyswords:diamond_greataxe
  celestisynth:pulsation:1
  minecraft:sharpness:4
  minecraft:unbreaking:3

minecraft:diamond_axe
  majruszsenchantments:leech:1

caverns_and_chasms:sanguine_chestplate
  combatroll:acrobat:3
  minecraft:protection:4
  minecraft:unbreaking:3
```

Cataclysm Cursium equipment contained many enchantments across vanilla and
modded namespaces. The smoke tool preview stayed bounded and emitted a
remaining-count suffix such as `+9`.

This validates the design choice to preserve enchantment IDs as open
namespaced strings rather than a closed vanilla enum.

### Real validation matrix

```text
legacy tag parsing                REAL VALIDATED
damage                            REAL VALIDATED
repairCost                        REAL VALIDATED
active enchantments               REAL VALIDATED
vanilla enchantment IDs           REAL VALIDATED
modded enchantment IDs            REAL VALIDATED
inventory item properties         REAL VALIDATED
equipment item properties         REAL VALIDATED
large repairCost                  REAL VALIDATED
bounded enchantment preview       REAL VALIDATED

unbreakable                       deterministic-test only
storedEnchantments                deterministic-test only
modern 1.20.5+ components         deterministic-test only
modern component removals         deterministic-test only
later enchantment representation  deterministic-test only
```

The real dataset did not contain explicit persisted unbreakable values or
stored enchantments. All observed ender chests were empty.

## Smoke tool

`tool/query_minecraft_worlds.dart` now appends core item properties to bounded
inventory/ender item preview lines and emits per-equipment-item lines:

```text
PLAYER_INVENTORY_ITEM
PLAYER_ENDER_ITEM
PLAYER_EQUIPMENT_ITEM
```

Per-item properties:

```text
damage
repairCost
unbreakable
enchantments
storedEnchantments
removedComponents
```

Enchantments and removal IDs are previewed with a maximum of five entries plus
a remaining-count suffix.

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/src/info/info_item_stack.dart
minecraft_info_provider/lib/src/info/info_item_stack_nbt_parser.dart
minecraft_info_provider/lib/src/info/info_item_stack_components_nbt_parser.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_item_core_properties_test.dart
minecraft_info_provider/test/minecraft_player_inventory_equipment_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CORE_PROPERTIES.md
```

## Deferred item work

The next item-components work should remain separate rather than expanding this
parser indefinitely.

Likely next sub-checkpoint:

```text
Item Display / Text Properties Foundation
```

Potential scope after dedicated design/research:

```text
custom name
item name
lore
cross-version text-component representation
```

Later item domains remain separate:

```text
attributes
custom model data
potions
containers
custom data
other specialized components
```

## Working rules

`docs/WORKING_RULES.md` remains authoritative.

No `dart format` was run.

## Finalization action

Pull this metadata commit, rerun analyzer/tests/diff/status, squash the feature
branch against
`00467ae4b985b092f79cf929b391a549070fb966`, then merge only after the
squashed tree is locally verified.
