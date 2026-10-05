# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Authoritative merged baseline

Feature branch base:

```text
main
a4e1f76ee8004e9909cbe1319af123515921ec1d
Add Minecraft player gameplay core
```

This baseline includes COMPLETE / VALIDATED / MERGED foundations for:

- Java NBT codec
- `servers.dat` read/append
- modern and legacy Java Server List Ping
- server lifecycle / Forge-FML metadata / SRV
- server address normalization and known-server matching
- Java Edition world discovery
- Java Edition player discovery
- world-owned player snapshots and world icon I/O
- Java Edition player statistics
- Java Edition player advancements
- Java Edition player gameplay core

## Active checkpoint

Java Edition Player Inventory / Equipment Foundation.

Current branch:

```text
feature/minecraft-player-inventory-equipment-foundation
```

Implementation/tool HEAD before this metadata pass:

```text
a25956fae7dbeaf351aa1fed35ee455a25055b4b
Show player inventory and equipment in world query tool
```

Package version for this checkpoint:

```text
1.0.0-dev.13
```

## Public API additions

New public item model:

```text
MtnMinecraftInfoItemStack
  id
  count
```

New equipment model:

```text
MtnMinecraftInfoPlayerEquipment
  head
  chest
  legs
  feet
  offHand
```

`MtnMinecraftInfoPlayer` now additionally exposes:

```text
inventory
enderChest
equipment
selectedItem
```

Semantic storage shapes:

```text
inventory  -> nullable immutable List<MtnMinecraftInfoItemStack?> length 36
enderChest -> nullable immutable List<MtnMinecraftInfoItemStack?> length 27
```

`selectedItem` is derived from the existing `selectedItemSlot` and semantic
inventory.

## Parsing architecture

Inventory/equipment parsing is split into dedicated internal parsers:

```text
MtnMinecraftInfoPlayerNbtParser
  -> MtnMinecraftInfoPlayerInventoryNbtParser
       -> slot routing / storage normalization
       -> MtnMinecraftInfoItemStackNbtParser
            -> serialized item-stack normalization
```

The main player parser remains responsible for composing the semantic
`MtnMinecraftInfoPlayer` snapshot. Filesystem/gzip/raw-NBT responsibilities
remain in `MtnMinecraftInfoProvider`.

## Inventory and ender chest rules

Legacy player `Inventory` slot mapping:

```text
0..35  -> semantic inventory
100    -> feet
101    -> legs
102    -> chest
103    -> head
-106   -> offHand
```

`EnderItems` recognizes slots 0..26.

Missing tag semantics:

```text
Inventory absent  -> inventory == null
Inventory empty   -> 36 null semantic slots

EnderItems absent -> enderChest == null
EnderItems empty  -> 27 null semantic slots
```

Unknown/future/modded slot numbers are ignored. Duplicate recognized semantic
slots are invalid player data.

## Item stack normalization

Minimal semantic item:

```text
id    -> namespaced external resource ID
count -> semantic integer stack count
```

Supported serialized count forms:

```text
legacy / pre-1.20.5:
Count: Byte

modern / 1.20.5+:
count: Int

missing count:
semantic count = 1
```

Modern `count` is authoritative when both modern and legacy count fields are
present.

Non-positive counts and `minecraft:air` normalize to an empty slot.

Legacy `tag` and modern `components` payloads are intentionally ignored by
this foundation. They are not schema-validated here.

Namespaced item IDs are preserved unchanged, so modded items require no
provider-specific registry or switch.

## Equipment normalization

Legacy equipment is derived from the special `Inventory` slot numbers listed
above.

Modern player `equipment` is resolved per semantic slot:

```text
modern slot has item
  -> modern item wins

modern slot explicitly present but empty
  -> semantic slot is empty
  -> no legacy fallback

modern slot absent
  -> matching legacy equipment slot may be used
```

This keeps modern representation authoritative without discarding still-valid
legacy fallback data for unrelated slots.

## Deterministic validation

Fifteen focused inventory/equipment tests cover:

- legacy inventory routing
- legacy armor/off-hand routing
- ender-chest routing
- selected-item derivation
- modern count parsing
- missing-count default
- legacy metadata ignored
- modern equipment per-slot precedence
- explicit empty modern slot
- missing-vs-empty storage semantics
- unknown slot tolerance
- duplicate recognized inventory/equipment/ender slots
- malformed recognized item fields
- legacy signed-byte count normalization
- air / zero-count empty normalization
- immutable public slot lists
- invalid storage/equipment container shapes

Full package validation before smoke-tool finalization:

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

Smoke-tool extension was then pulled locally and re-analyzed:

```text
dart analyze
No issues found!
```

Final test/diff/status validation must be rerun after this metadata pass.

No `dart format` was run.

## Real Java Edition 1.20.1 modded smoke validation

Three worlds and eight player snapshots were read from the real game directory.
All observed files used legacy player-data storage with `DataVersion=3465`.

Real inventory/equipment behavior included:

- populated and empty 36-slot inventories
- selected-item derivation from the selected hotbar slot
- legacy stack counts including stacks of 64, 55, 28, 21 and other values
- legacy armor slots normalized into head/chest/legs/feet
- legacy off-hand normalized independently
- vanilla and modded namespaced IDs in the same semantic item model
- bounded smoke output for inventories containing up to 35 occupied slots

Observed mod namespaces included examples such as:

```text
aquamirae
alexsmobs
caverns_and_chasms
born_in_chaos_v1
butchersdelight
deeperdarker
simplyswords
cataclysm
eeeabsmobs
sophisticatedbackpacks
farmersdelight
artifacts
```

Representative real equipment observations included:

```text
head=aquamirae:abyssal_heaume
offHand=minecraft:totem_of_undying

chest=caverns_and_chasms:sanguine_chestplate
legs=caverns_and_chasms:sanguine_leggings
feet=caverns_and_chasms:sanguine_boots

head/chest/legs/feet=cataclysm:cursium_*
```

All observed `EnderItems` snapshots were empty, so non-empty ender-chest
behavior remains deterministic-test validated.

Modern 1.20.5+ `count` and 1.21.5+ player `equipment` formats also remain
deterministic-test validated because no real modern-format player file was used
for this checkpoint.

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD 1.20.1 MODDED VALIDATED
```

## Explicitly deferred

- legacy item `tag` semantics
- modern item `components` semantics
- enchantments / durability / custom names / lore
- nested item containers
- player active effects
- singleplayer player identity / UUID relationship
- inventory/equipment writing
- installed-content discovery

## Locked foundations

This checkpoint does not redesign:

- player identity / UUID discovery
- legacy vs modern player-data storage precedence
- gameplay-core fields
- stats / advancements APIs
- world ownership / player aggregate semantics
- world icon I/O
- server/status/SRV/address behavior
- raw NBT codec

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- keep checkpoints small and reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- keep `.dart_tool/` and `pubspec.lock` ignored for this library package
- architecture/naming/dependency boundaries are acceptance criteria
- backward/legacy support is added only with explicit approval

## Next action

1. Pull the metadata/finalization commit into the local feature branch.
2. Run final `dart analyze`, `dart test`, `git diff --check` and
   `git status`.
3. Squash the feature branch to one clean commit against
   `a4e1f76ee8004e9909cbe1319af123515921ec1d`.
4. Force-push only with `--force-with-lease`.
5. Fast-forward merge to `main` only after the squashed tree is locally
   verified.

Likely next player-data checkpoint:

- Player Active Effects Foundation

Item components remain a separate cross-domain item-model checkpoint.
