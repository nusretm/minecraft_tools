# Handoff — Minecraft Info Provider Item Nested Stacks

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

Nested Item Stacks Foundation.

Feature branch:

```text
feature/minecraft-item-nested-stacks-foundation
```

Base:

```text
main
b5b85b61bcbba0513515008bfba03ac775aff12e
Add item custom model data foundation
```

Package version:

```text
1.0.0-dev.21
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

No merge approval has been given.

## Public API

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
Map<int, MtnMinecraftInfoItemStack>? containerContents
List<MtnMinecraftInfoItemStack>? bundleContents
List<MtnMinecraftInfoItemStack>? chargedProjectiles
MtnMinecraftInfoItemStack? useRemainder
```

No secondary nested-item public model was introduced. Nested persisted items recursively reuse `MtnMinecraftInfoItemStack`.

## Semantics

```text
property absent
  -> null

explicit empty collection
  -> immutable empty collection

persisted nested item
  -> recursive MtnMinecraftInfoItemStack
```

`containerContents` is sparse and keyed by persisted slot number. Registry-derived fixed container sizes are not synthesized.

## Legacy storage

Recognized legacy forms:

```text
tag.BlockEntityTag.Items
tag.Items
tag.ChargedProjectiles
```

`BlockEntityTag.Items` entries use legacy `Slot` byte plus the normal legacy item-stack shape.

Bundle `Items` and Crossbow `ChargedProjectiles` are normalized to ordered immutable item lists.

The legacy `Charged` boolean is not exposed separately; this checkpoint models persisted nested contents, not Crossbow runtime state.

## Modern storage

Recognized components:

```text
minecraft:container
minecraft:bundle_contents
minecraft:charged_projectiles
minecraft:use_remainder
```

`minecraft:container` entries require:

```text
slot: int 0..255
item: item stack
```

Duplicate slots are invalid.

`minecraft:bundle_contents` and `minecraft:charged_projectiles` are item-stack lists.

`minecraft:use_remainder` is one nested item stack.

## Recursion architecture

New internal parser:

```text
MtnMinecraftInfoItemNestedStackNbtParser
```

Recursion authority remains:

```text
MtnMinecraftInfoItemStackNbtParser
```

Flow:

```text
MtnMinecraftInfoItemStackNbtParser
        |
        +-- MtnMinecraftInfoItemStackComponentsNbtParser
                    |
                    +-- MtnMinecraftInfoItemNestedStackNbtParser
                                |
                                +-- parseItem callback
                                      -> same item-stack parser
```

This avoids parser duplication and supports recursive structures such as container -> Bundle -> item components.

## Authority and removals

Existing rule remains:

```text
components present
  -> modern components authoritative
  -> legacy tag ignored
```

Removal conflict handling now includes:

```text
minecraft:container
minecraft:bundle_contents
minecraft:charged_projectiles
minecraft:use_remainder
```

A recognized component and matching `!component` cannot coexist.

Removal-only patches remain in `removedComponentIds`; effective defaults are not inferred.

## Strictness

Recognized malformed nested structures propagate to the existing player `invalidData` path.

Strict cases include malformed list/item shapes, missing modern slot/item fields, slot outside 0..255, duplicate slots, and invalid required nested item stacks.

Unknown extra metadata on recognized modern container entries is tolerated.

## Query tool

Bounded item-property previews now include:

```text
containerContents=[0:minecraft:diamond_pickaxe*1,...]
bundleContents=[minecraft:stone*32,...]
chargedProjectiles=[minecraft:arrow*1]
useRemainder=minecraft:bowl*1
```

Previews are capped and do not recursively print child properties.

## Deterministic tests

Focused test:

```text
test/minecraft_item_nested_stacks_test.dart
```

Coverage includes:

- legacy `BlockEntityTag.Items`
- modern `minecraft:container`
- sparse slots
- slot 0 and 255
- duplicate/out-of-range rejection
- absent vs explicit empty
- legacy Bundle `Items`
- legacy `ChargedProjectiles`
- modern Bundle contents
- modern charged projectiles
- modern use remainder
- recursive container -> Bundle -> custom-model-data parsing
- immutable nested collections
- modern-over-legacy authority
- removal-only behavior
- removal conflicts
- unknown nested-entry metadata tolerance
- malformed nested item invalidation

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_nested_stacks_test.dart
00:01 +13: All tests passed!

dart test test/minecraft_item_custom_model_data_test.dart
00:00 +11: All tests passed!

dart test
00:03 +239: All tests passed!

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
    Select-String 'containerContents=\[|bundleContents=\[|chargedProjectiles=\['
```

Result:

```text
(no matching output)
```

The command completed without parser/runtime failure, but no discovered real inventory/equipment item persisted explicit nested container, Bundle, or charged-projectile contents.

Therefore this checkpoint does not claim real-file validation of an actual nested-item payload. Deterministic tests remain authoritative for these schemas.

## Explicitly deferred

- `minecraft:container_loot`
- registry-derived container sizes/capacities
- Bundle weight/capacity calculations
- Bundle UI selection/rendering behavior
- Crossbow charged/firing runtime mechanics
- use-remainder runtime behavior
- block-entity inventory discovery
- nested item writing
- general item writing

## Remaining item-read checkpoint

```text
Custom Data Foundation
```

After that, the planned core item-read foundation is complete.

## Next action

Do not begin another feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge against `main`.
