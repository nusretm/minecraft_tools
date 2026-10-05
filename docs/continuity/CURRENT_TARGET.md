# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

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

No merge approval has been given for this checkpoint.

## Public item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
Map<int, MtnMinecraftInfoItemStack>? containerContents
List<MtnMinecraftInfoItemStack>? bundleContents
List<MtnMinecraftInfoItemStack>? chargedProjectiles
MtnMinecraftInfoItemStack? useRemainder
```

No second nested-item public model was introduced. Nested values recursively
reuse `MtnMinecraftInfoItemStack` and therefore automatically reuse the same
item/component parsing semantics at every depth.

## Semantics

Persisted-data policy remains unchanged:

```text
property absent
  -> null

explicit empty container/list
  -> immutable empty collection

persisted nested item
  -> recursive MtnMinecraftInfoItemStack
```

Registry-derived/default content is not synthesized.

`containerContents` is a sparse immutable map keyed by persisted slot number.
The provider does not create a fixed-size list because effective container
capacity depends on item/block registry semantics outside this foundation.

## Legacy storage

Recognized legacy container storage:

```text
tag.BlockEntityTag.Items = [
  {
    Slot: <byte>,
    id: ...,
    Count: ...,
    tag: ...
  }
]
```

Legacy slot bytes normalize to integer map keys.

Recognized legacy Bundle storage:

```text
tag.Items = [<item stack>, ...]
```

Recognized legacy Crossbow storage:

```text
tag.ChargedProjectiles = [<item stack>, ...]
```

The legacy `Charged` boolean is not exposed as a separate public property.
This checkpoint preserves persisted projectile contents and does not compute
Crossbow runtime state.

## Modern storage

Recognized components:

```text
minecraft:container
minecraft:bundle_contents
minecraft:charged_projectiles
minecraft:use_remainder
```

`minecraft:container` format:

```text
[
  {
    slot: <int 0..255>,
    item: <item stack>
  }
]
```

Duplicate recognized container slots are invalid.

`minecraft:bundle_contents` and `minecraft:charged_projectiles` are direct
lists of item stacks.

`minecraft:use_remainder` is one item stack.

Empty/air/count-zero nested stacks are not accepted as persisted nested
contents for these recognized modern components.

## Recursion architecture

New internal parser:

```text
MtnMinecraftInfoItemNestedStackNbtParser
```

Recursion authority remains:

```text
MtnMinecraftInfoItemStackNbtParser
```

Dependency/callback flow:

```text
MtnMinecraftInfoItemStackNbtParser
        |
        +-- MtnMinecraftInfoItemStackComponentsNbtParser
                    |
                    +-- MtnMinecraftInfoItemNestedStackNbtParser
                                |
                                +-- parseItem callback
                                      -> same ItemStack parser
```

This avoids a source/class dependency cycle and prevents a second copy of
item-stack parsing logic.

Recursive examples such as container -> bundle -> item components use the
same parser path all the way down.

## Authority and removal semantics

Existing item authority remains:

```text
components present
  -> modern components authoritative
  -> legacy tag not consulted
```

Recognized removal IDs now include:

```text
minecraft:container
minecraft:bundle_contents
minecraft:charged_projectiles
minecraft:use_remainder
```

A component and its `!component` removal marker cannot coexist.

Removal-only patches remain represented by `removedComponentIds`; no effective
default content is synthesized.

## Strictness

Recognized malformed nested data maps to the existing player `invalidData`
path.

Strict recognized conditions include:

- malformed list/item shapes
- missing required modern `slot` or `item`
- modern container slot outside 0..255
- duplicate container slot
- malformed nested item stack
- empty/air/count-zero required nested item

Unknown extra metadata on recognized modern container entries remains
tolerated.

Legacy `BlockEntityTag` data outside recognized `Items` content remains
outside this foundation.

## Query tool

Shared item-property output now includes bounded nested previews:

```text
containerContents=[0:minecraft:diamond_pickaxe*1,5:minecraft:apple*3]
bundleContents=[minecraft:stone*32,minecraft:apple*2]
chargedProjectiles=[minecraft:arrow*1]
useRemainder=minecraft:bowl*1
```

Nested previews are capped at three entries and do not recursively dump child
component properties.

## Deterministic coverage added

Focused test:

```text
test/minecraft_item_nested_stacks_test.dart
```

Coverage includes:

- legacy `BlockEntityTag.Items`
- modern `minecraft:container`
- sparse container slots
- modern slot 0 and 255
- duplicate and out-of-range slot rejection
- explicit empty versus absent container
- legacy Bundle `Items`
- legacy `ChargedProjectiles`
- modern `bundle_contents`
- modern `charged_projectiles`
- modern `use_remainder`
- recursive container -> bundle -> custom-model-data parsing
- immutable nested maps/lists
- modern component authority over legacy nested tags
- removal-only behavior
- removal conflicts for all four modern components
- unknown nested-entry metadata tolerance
- malformed nested item handling

## Validation

Authoritative local validation completed from:

```text
D:\development\cross-platform\minecraft_tools\minecraft_info_provider
```

```text
dart analyze
No issues found!

dart test test/minecraft_item_nested_stacks_test.dart
00:01 +13: All tests passed!

dart test test/minecraft_item_custom_model_data_test.dart
00:00 +11: All tests passed!

dart test
00:03 +239: All tests passed!
```

Repository-root validation:

```text
git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

Real-file smoke inspection against the local Java Edition game directory completed without parser/runtime failure, but no persisted nested container, Bundle, or charged-projectile contents were found in the discovered inventory/equipment data.

Smoke command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'containerContents=\[|bundleContents=\[|chargedProjectiles=\['
```

Result:

```text
(no matching output)
```

Therefore this checkpoint does not claim real-file validation of an actual nested-item payload; deterministic tests remain authoritative for the supported schemas.

## Previous completed checkpoint

Custom Model Data Foundation was validated, squash merged through PR #12,
and cleaned up.

Merged main HEAD:

```text
b5b85b61bcbba0513515008bfba03ac775aff12e
```

Package version at that checkpoint:

```text
1.0.0-dev.20
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_MODEL_DATA.md
```

Locked decisions retained:

- item components represent explicitly persisted overrides
- modern `components` remains authoritative over legacy `tag`
- component removals remain explicit
- unknown external IDs/metadata are tolerated where not schema-recognized
- recognized malformed component data remains strict
- no item-registry default synthesis
- recursive nested items reuse the same item model/parser

## Explicitly deferred

Nested/runtime semantics:

- `minecraft:container_loot`
- registry-derived container sizes/capacities
- Bundle weight/capacity calculations
- Bundle UI selection/rendering behavior
- Crossbow charged/firing runtime mechanics
- use-remainder runtime behavior
- block-entity inventory discovery
- nested item writing

Remaining item-read checkpoint:

- Custom Data Foundation

General item work:

- item writing

Attribute/potion/effect semantics:

- effective item-registry attribute defaults and calculations
- attribute/potion/effect registry lookup
- brewing/runtime effect calculations
- general `minecraft:tooltip_display` support

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

Checkpoint implementation, automated validation, and available real-file smoke inspection are complete.

Finalize the checkpoint handoff, then prepare squash/PR/merge only after explicit user approval. Do not begin the next feature before this checkpoint is closed.
