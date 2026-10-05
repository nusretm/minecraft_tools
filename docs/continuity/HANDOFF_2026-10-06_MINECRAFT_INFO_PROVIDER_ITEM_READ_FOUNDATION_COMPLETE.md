# Handoff — Minecraft Info Provider Item Read Foundation Complete

Date: 2026-10-06

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. `hypixel_api/` is unrelated.

## Milestone state

```text
CORE MtnMinecraftInfoItemStack READ FOUNDATION
COMPLETE / MERGED / VALIDATED
```

Current main:

```text
97cc91ba6cc311d4872f9f9136d1dc6892ff1eb0
Add item custom data foundation
```

Package version:

```text
1.0.0-dev.22
```

There is no active item-read feature branch.

## Milestone commit chain

```text
0e6ae8b9250f4207dbeed431c356380709204506  Add Minecraft item core properties foundation
4887a13138ecb7dfa87c44061e968d513e731a65  Add Minecraft text and item display foundation
bcef38d20670e4265f26b1295bcadd1148ad28c9  Add item potion properties foundation
4bdecaeaaa84eb1f92f07b6568814cbd347bf30a  Add item attribute modifiers foundation
b5b85b61bcbba0513515008bfba03ac775aff12e  Add item custom model data foundation
dd592be8b44711936c52128a7a13461a79e6005c  Add item nested stacks foundation
97cc91ba6cc311d4872f9f9136d1dc6892ff1eb0  Add item custom data foundation
```

Player inventory/equipment foundation on which the item stack work builds:

```text
00467ae4b985b092f79cf929b391a549070fb966
Add Minecraft player inventory and equipment foundation
```

## Public read surface completed

`MtnMinecraftInfoItemStack` now provides:

- namespaced item ID
- semantic stack count
- nullable persisted `MtnMinecraftInfoItemStackComponents`

`MtnMinecraftInfoItemStackComponents` now covers:

- damage
- repair cost
- unbreakable
- enchantments
- stored enchantments
- custom name
- item name
- lore
- potion contents
- potion duration scale
- attribute modifiers
- custom model data
- sparse container contents
- Bundle contents
- charged projectiles
- use remainder
- modern custom data
- exact legacy raw tag
- removed modern component IDs

Nested item stacks recursively reuse the same item-stack model and parser.

## Cross-version storage coverage

Legacy pre-1.20.5 item storage and modern component storage are normalized
into one public item model where a semantic mapping is known.

Important examples:

```text
legacy Count                 <-> modern count
legacy Damage                <-> minecraft:damage
legacy RepairCost            <-> minecraft:repair_cost
legacy Enchantments          <-> minecraft:enchantments
legacy StoredEnchantments    <-> minecraft:stored_enchantments
legacy display.Name/Lore     <-> custom_name / lore
legacy potion tags           <-> potion_contents
legacy AttributeModifiers    <-> attribute_modifiers
legacy CustomModelData       <-> custom_model_data
legacy nested item tags      <-> container / bundle_contents / charged_projectiles
```

Modern-only persisted properties such as `minecraft:use_remainder` and
`minecraft:custom_data` are represented directly.

## Locked architecture decisions

### Persisted snapshot model

The item API represents persisted stack data, not a computed effective item.

Registry-derived defaults are not synthesized.

### Modern authority

```text
components present
  -> modern component storage authoritative
  -> legacy tag ignored
```

Malformed modern recognized data does not silently fall back to legacy data.

### Component removals

`!minecraft:*` removals are retained separately in `removedComponentIds`
because calculating the effective post-removal value requires registry data.

### Unknown external values

Unknown vanilla/future/modded resource IDs and unrecognized metadata remain
available/tolerated where possible.

Recognized schemas remain strict.

### Legacy tag preservation

Pre-1.20.5 raw `tag` is preserved through `legacyTag` in addition to semantic
parsing of recognized fields.

Legacy tag is not reclassified as modern custom data.

### No DataFixer guessing

The provider does not emulate Minecraft DataFixer behavior when migrating
legacy item tags into modern components/custom data.

### Immutability

Public component maps/lists/sets are immutable snapshots.

NBT compound/list values retain immutable nested structure.

### Recursion

`MtnMinecraftInfoItemStackNbtParser` remains the single item recursion
authority. Nested containers do not introduce a parallel public item model.

## Validation baseline

Final validation at the end of the milestone:

```text
dart analyze
No issues found!

focused Custom Data tests
11/11 passed

focused Item Core Properties regression
14/14 passed

focused Nested Item Stacks regression
13/13 passed

full package test suite
250/250 passed

git diff --check
PASS

working tree
clean
```

No `dart format` was run.

## Real-file coverage

Real Java Edition 1.20.1 modded player data has validated multiple legacy
item-read paths during the item milestones, including:

- damage
- repair cost
- vanilla and modded enchantment IDs
- equipment routing
- custom/raw legacy tag preservation
- mod-specific legacy item metadata

Representative legacy raw tags included:

```text
Damage
Fireworks
Damage + Enchantments + RepairCost
Enchantments + PrevUseTime + UseTime
Sophisticated Backpacks metadata
Simply Swords nether_power / runic_power metadata
```

Some modern 1.20.5+ representations remain deterministic-test validated only
because the available real-world smoke dataset is Java Edition 1.20.1.

## What this milestone does not mean

`MtnMinecraftInfoItemStack` read completion does not mean all item/gameplay
behavior is complete.

Still separate are:

- writing item stacks
- item-registry defaults/effective values
- tooltip-display semantics
- attribute runtime calculations
- potion/effect registry/runtime calculations
- resource-pack/item-model resolution
- Bundle/Crossbow/use-remainder runtime behavior
- block-entity inventory discovery
- DataFixer migration tooling

## Remaining backlog

The canonical prioritized backlog is maintained in:

```text
docs/continuity/CURRENT_TARGET.md
```

Major remaining areas:

```text
1. Item Writing Foundation
2. Effective Item / Registry Foundation
3. Richer World Metadata
4. Pre-26.1 Embedded Singleplayer Player
5. Advancement Definitions / Semantic Progress
6. Statistics Semantics / Aggregation / Writing
7. Installed Content Discovery
8. Potion / Effect Runtime Registry
9. Attribute Runtime / Registry
10. Resource-Pack / Item Model Resolution
11. Nested Runtime / Block-Entity Inventories
12. Minecraft Text Runtime Resolution
13. servers.dat write/dedup policy
14. Advanced Custom-Data Tooling
15. Client-Mod Activity Integration
```

## Next action

No feature is currently selected.

Choose one backlog area, define a narrow checkpoint, and obtain explicit user
approval before implementation.

Merge approval remains a separate explicit step.
