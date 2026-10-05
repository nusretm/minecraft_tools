# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Active checkpoint

Custom Model Data Foundation.

Feature branch:

```text
feature/minecraft-item-custom-model-data-foundation
```

Base:

```text
main
4bdecaeaaa84eb1f92f07b6568814cbd347bf30a
Add item attribute modifiers foundation
```

Package version:

```text
1.0.0-dev.20
```

Checkpoint state:

```text
COMPLETED / AUTOMATED VALIDATED
```

Authoritative local validation:

```text
dart analyze
No issues found!

dart test test/minecraft_item_custom_model_data_test.dart
00:01 +11: All tests passed!

dart test test/minecraft_item_attribute_modifiers_test.dart
00:00 +14: All tests passed!

dart test
00:03 +226: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

Real-file smoke inspection against the local Java Edition game directory
completed without parser/runtime failure, but no persisted item with explicit
`CustomModelData` was found in the discovered inventory/equipment data.
Therefore real custom-model-data payloads remain deterministic-test validated
rather than real-file validated.

No merge approval has been given for this checkpoint.

## Public model

New public API:

```text
MtnMinecraftInfoItemCustomModelData
```

Fields:

```text
legacyValue
floats
flags
strings
colors
```

`floats`, `flags`, `strings` and `colors` are immutable lists.

`legacyValue` represents the numeric custom-model-data storage used before the
1.21.4 expanded component. It deliberately covers both:

```text
pre-1.20.5 tag.CustomModelData
1.20.5 through 1.21.3 minecraft:custom_model_data integer component
```

The provider does not rewrite that persisted numeric value into `floats[0]`.

## Item integration

`MtnMinecraftInfoItemStackComponents` now exposes:

```dart
MtnMinecraftInfoItemCustomModelData? customModelData
```

Semantics:

```text
property absent
  -> customModelData == null

numeric zero
  -> customModelData != null
  -> legacyValue == 0

current empty compound {}
  -> customModelData != null
  -> legacyValue == null
  -> floats/flags/strings/colors == []
```

As with the other item foundations, this is persisted stack data only. No
resource-pack or effective rendered-model state is synthesized.

## Legacy storage

Pre-1.20.5 item tag:

```text
CustomModelData: TAG_Int
```

The integer is preserved as `legacyValue` without registry/model lookup.

## 1.20.5 through 1.21.3 component storage

Component:

```text
minecraft:custom_model_data: TAG_Int
```

This is also preserved as `legacyValue` instead of being converted to the
later list representation.

## 1.21.4+ expanded component

Current component compound:

```text
minecraft:custom_model_data = {
  floats:  [...],
  flags:   [...],
  strings: [...],
  colors:  [...]
}
```

Normalized public types:

```text
floats  -> List<double>
flags   -> List<bool>
strings -> List<String>
colors  -> List<int>
```

Persisted NBT expectations:

```text
floats  -> TAG_List<TAG_Float>
flags   -> TAG_List<TAG_Byte>, values 0 or 1
strings -> TAG_List<TAG_String>
colors  -> TAG_List<TAG_Int>
```

Missing fields inside a present current compound normalize to immutable empty
lists. Explicit empty lists are also preserved as empty lists.

Unknown fields inside the current compound are tolerated.

Packed color integers are preserved verbatim, including negative signed NBT
integers such as `-1`. They are not routed through `MtnMinecraftTextColor`.

## Parser boundary

New internal parser:

```text
MtnMinecraftInfoItemCustomModelDataNbtParser
```

Dependency:

```text
MtnMinecraftInfoItemStackComponentsNbtParser
        |
        +-- MtnMinecraftInfoItemCustomModelDataNbtParser
```

Recognized malformed custom-model-data storage is translated to the existing
item/player invalid-data path.

## Item authority and removals

Existing item authority remains unchanged:

```text
components present
  -> modern components authoritative
  -> legacy tag not consulted
```

Recognized removal conflict:

```text
minecraft:custom_model_data
!minecraft:custom_model_data
```

Both cannot be present simultaneously.

Removal-only patches remain represented through `removedComponentIds`.

## Query tool

The shared item-property formatter now reports bounded custom-model data.

Numeric form:

```text
customModelData={legacy:42}
```

Current form:

```text
customModelData={floats:[...] flags:[...] strings:[...] colors:[...]}
```

Each current list preview is capped at three values.

## Deterministic coverage added

New focused test:

```text
test/minecraft_item_custom_model_data_test.dart
```

Coverage includes:

- legacy `CustomModelData` integer
- 1.20.5-1.21.3 numeric component
- numeric zero
- current floats/flags/strings/colors together
- arbitrary and empty strings
- negative packed color integer preservation
- present empty compound versus absent component
- explicit empty lists
- immutable current lists
- modern-over-legacy authority
- removal-only behavior
- component/removal conflict
- unknown current metadata tolerance
- malformed legacy type
- malformed modern component/list types
- invalid boolean byte values

## Validation

Authoritative local validation completed from
`D:\development\cross-platform\minecraft_tools\minecraft_info_provider`:

```text
dart analyze
No issues found!

dart test test/minecraft_item_custom_model_data_test.dart
00:01 +11: All tests passed!

dart test test/minecraft_item_attribute_modifiers_test.dart
00:00 +14: All tests passed!

dart test
00:03 +226: All tests passed!
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
    Select-String 'customModelData=\{'
```

The command completed with no matching output. The discovered real
inventory/equipment items did not persist explicit custom-model data, so no
real legacy/current payload was available to inspect. This is not a parser
failure; deterministic coverage remains the validation authority for this
checkpoint.

## Previous completed checkpoint

Item Attribute Modifiers Foundation was validated, squash merged through PR
#11, and cleaned up.

Merged main HEAD:

```text
4bdecaeaaa84eb1f92f07b6568814cbd347bf30a
```

Package version at that checkpoint:

```text
1.0.0-dev.19
```

Authoritative handoff:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_ATTRIBUTE_MODIFIERS.md
```

Locked decisions retained:

- item components represent explicitly persisted overrides
- modern `components` remains authoritative over legacy `tag`
- removal-only component patches remain explicit
- unknown external IDs/metadata are tolerated where not schema-recognized
- recognized malformed component data remains strict
- no item-registry default synthesis

## Explicitly deferred

Custom model/rendering semantics:

- resource-pack model discovery and parsing
- `minecraft:item_model`
- effective rendered-model selection
- model-property evaluation against resource-pack definitions
- custom-model-data writing

Other item properties:

- nested containers / bundle-like contents
- custom data
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

Checkpoint implementation, automated validation and available real-file smoke
inspection are complete.

Create/finalize the checkpoint handoff, then prepare the feature branch for
review/squash/PR/merge only after explicit user approval. Do not begin another
feature before this checkpoint is closed.
