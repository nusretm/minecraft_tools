# Handoff — Minecraft Info Provider Player Inventory / Equipment Foundation

Date: 2026-10-05

## Purpose

This note captures the Java Edition Player Inventory / Equipment Foundation
after deterministic validation and a real modded Java Edition 1.20.1 smoke
test.

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
a4e1f76ee8004e9909cbe1319af123515921ec1d
Add Minecraft player gameplay core
```

Active branch:

```text
feature/minecraft-player-inventory-equipment-foundation
```

Implementation/tool HEAD before metadata finalization:

```text
a25956fae7dbeaf351aa1fed35ee455a25055b4b
```

Package version:

```text
1.0.0-dev.13
```

## Scope

Included:

```text
36-slot semantic player inventory
27-slot semantic ender chest
minimal semantic item stack: id + count
selectedItem derivation
legacy Count byte
modern count int
legacy armor/off-hand slot normalization
modern equipment compound normalization
per-slot modern equipment precedence
modded namespaced item IDs
```

Explicitly not included:

```text
legacy item tag semantics
modern item components semantics
enchantments
durability
custom names / lore
nested containers
active effects
inventory/equipment writing
singleplayer identity mapping
```

## Public models

```text
MtnMinecraftInfoItemStack
  id
  count

MtnMinecraftInfoPlayerEquipment
  head
  chest
  legs
  feet
  offHand
```

`MtnMinecraftInfoPlayer` additions:

```text
inventory
enderChest
equipment
selectedItem
```

The public slot lists are immutable.

## Parser architecture

Two dedicated internal parsers were added:

```text
info_item_stack_nbt_parser.dart
info_player_inventory_nbt_parser.dart
```

Responsibility split:

```text
MtnMinecraftInfoProvider
  -> filesystem / gzip / raw NBT

MtnMinecraftInfoPlayerNbtParser
  -> complete player semantic snapshot
  -> delegates inventory domain

MtnMinecraftInfoPlayerInventoryNbtParser
  -> Inventory / EnderItems / equipment storage
  -> semantic slot routing
  -> modern-vs-legacy equipment precedence

MtnMinecraftInfoItemStackNbtParser
  -> serialized item-stack id/count normalization
```

This keeps inventory slot rules and item serialization changes out of the main
player parser.

## Inventory slot normalization

Legacy `Inventory`:

```text
0..35  -> inventory[0..35]
100    -> equipment.feet
101    -> equipment.legs
102    -> equipment.chest
103    -> equipment.head
-106   -> equipment.offHand
```

`EnderItems`:

```text
0..26 -> enderChest[0..26]
```

Unknown/future/modded slot numbers are ignored. Their item payloads are not
validated because the foundation does not claim ownership of those slots.

Duplicate recognized slots are invalid player data.

## Missing versus empty storage

```text
Inventory absent
  -> inventory == null

Inventory present empty
  -> immutable 36-entry all-null list

EnderItems absent
  -> enderChest == null

EnderItems present empty
  -> immutable 27-entry all-null list
```

This preserves source-state semantics without exposing raw NBT.

## Item stack normalization

Public item identity remains an external namespaced string.

Supported count sources:

```text
Count: Byte
count: Int
no count -> 1
```

`count` has precedence when both spellings exist.

Legacy byte count is normalized as an unsigned byte value. Non-positive modern
counts and `minecraft:air` normalize to an empty semantic slot.

An empty compound also represents an empty semantic item slot.

Legacy `tag` and modern `components` are ignored by this parser. The
foundation does not validate those payloads.

## Equipment precedence

Modern `equipment` is applied per slot, not as one all-or-nothing source.

```text
modern slot with item
  -> use modern

modern slot explicitly present but empty
  -> semantic empty
  -> suppress legacy fallback

modern slot absent
  -> use matching legacy special slot if present
```

This preserves the modern source's authority without hiding unrelated legacy
equipment.

## selectedItem

`selectedItem` is a derived getter over the already-validated
`selectedItemSlot` and semantic inventory.

```text
inventory missing -> null
selectedItemSlot missing -> null
selected inventory slot empty -> null
otherwise -> inventory[selectedItemSlot]
```

## Deterministic tests

Fifteen focused tests were added in:

```text
minecraft_info_provider/test/minecraft_player_inventory_equipment_test.dart
```

They cover legacy/modern item counts, inventory and ender routing, equipment
precedence, absent/empty semantics, selected-item derivation, immutable lists,
unknown slot tolerance and strict recognized-schema failures.

Full package validation before metadata finalization:

```text
dart analyze
No issues found!

dart test
00:02 +135: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

After pulling the smoke-tool extension:

```text
dart analyze
No issues found!
```

Final analyzer/test/diff/status checks must be repeated after this metadata
commit.

No `dart format` was run.

## Real Java Edition 1.20.1 modded smoke validation

The smoke tool read three worlds and eight player snapshots, all using legacy
player-data layout and `DataVersion=3465`.

### Vanilla + modded inventory

Real inventories included both vanilla and modded IDs through the same
`MtnMinecraftInfoItemStack` model.

Examples observed:

```text
minecraft:diamond_sword
minecraft:firework_rocket
alexsmobs:animal_dictionary
caverns_and_chasms:necromium_hoe
born_in_chaos_v1:pieceofdarkmetal
butchersdelight:deadpig
deeperdarker:warden_carapace
simplyswords:diamond_greataxe
cataclysm:cursed_bow
eeeabsmobs:guardian_core
sophisticatedbackpacks:gold_backpack
farmersdelight:chicken_sandwich
artifacts:eternal_steak
```

One player had 35 occupied semantic inventory slots. Other real snapshots
included 29, 18, 17, 8 and empty inventories.

### selectedItem

Real selected-item derivation succeeded, including examples such as:

```text
selectedSlot=1 -> minecraft:firework_rocket x64
selectedSlot=7 -> minecraft:diamond x64
selectedSlot=0 -> minecraft:coal x64
selectedSlot=6 -> butchersdelight:cleaver x1
```

A selected hotbar slot can legitimately be empty; this produced
`selectedItem=null`.

### Legacy equipment

Real legacy special slots normalized successfully.

Observed examples:

```text
head=aquamirae:abyssal_heaume x1
offHand=minecraft:totem_of_undying x1

offHand=minecraft:diamond_hoe x1

chest=caverns_and_chasms:sanguine_chestplate x1
legs=caverns_and_chasms:sanguine_leggings x1
feet=caverns_and_chasms:sanguine_boots x1

head=cataclysm:cursium_helmet x1
chest=cataclysm:cursium_chestplate x1
legs=cataclysm:cursium_leggings x1
feet=cataclysm:cursium_boots x1
```

This validates the legacy armor/off-hand slot normalization against real modded
1.20.1 player files.

### Ender chest

All real `EnderItems` snapshots in this dataset were present/empty with
`usedSlots=0`.

Therefore non-empty ender-chest parsing remains deterministic-test validated,
not real-file validated.

### Modern formats

No real 1.20.5+ item-stack file or 1.21.5+ player equipment file was used.

The following therefore remain deterministic-test validated:

```text
modern count: Int
missing modern count -> 1
modern equipment compound
per-slot modern precedence
explicit empty modern slot suppresses legacy fallback
```

## Smoke tool

`tool/query_minecraft_worlds.dart` now emits bounded:

```text
PLAYER_INVENTORY
PLAYER_INVENTORY_ITEM
PLAYER_INVENTORY_ITEM_MORE
PLAYER_ENDER_CHEST
PLAYER_ENDER_ITEM
PLAYER_ENDER_ITEM_MORE
PLAYER_EQUIPMENT
```

Only the first 10 occupied slots are printed for inventory/ender previews.

## Files changed in this checkpoint

Production:

```text
minecraft_info_provider/lib/minecraft_info_provider.dart
minecraft_info_provider/lib/src/info/info_item_stack.dart
minecraft_info_provider/lib/src/info/info_item_stack_nbt_parser.dart
minecraft_info_provider/lib/src/info/info_player.dart
minecraft_info_provider/lib/src/info/info_player_inventory_nbt_parser.dart
minecraft_info_provider/lib/src/info/info_player_nbt_parser.dart
```

Tests/tool:

```text
minecraft_info_provider/test/minecraft_player_inventory_equipment_test.dart
minecraft_info_provider/tool/query_minecraft_worlds.dart
```

Metadata/finalization:

```text
minecraft_info_provider/pubspec.yaml
minecraft_info_provider/README.md
minecraft_info_provider/CHANGELOG.md
docs/continuity/CURRENT_TARGET.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_PLAYER_INVENTORY_EQUIPMENT.md
```

## Next checkpoint

The next player-data domain can be Active Effects Foundation.

Item components should remain a separate cross-domain item concern because the
same item-stack metadata model will later be useful outside player inventory,
including containers/entities and other item-bearing data.

## Working rules

`docs/WORKING_RULES.md` remains authoritative.

No `dart format` was run.

## Finalization action

Pull this metadata commit, rerun final analyzer/tests/diff/status checks, squash
the feature branch against
`a4e1f76ee8004e9909cbe1319af123515921ec1d`, then merge only after the
squashed tree is locally verified.
