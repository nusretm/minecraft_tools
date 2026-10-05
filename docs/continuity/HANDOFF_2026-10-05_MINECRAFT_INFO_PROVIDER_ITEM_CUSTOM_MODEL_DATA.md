# Handoff — Minecraft Info Provider Item Custom Model Data

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

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

No merge approval has been given.

## Public API

New public model:

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

`floats`, `flags`, `strings` and `colors` are immutable.

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
  -> floats == []
  -> flags == []
  -> strings == []
  -> colors == []
```

The provider models persisted stack data only and does not resolve resource-pack
models or synthesize the effective rendered model.

## Storage generations

Pre-1.20.5 legacy item storage:

```text
CustomModelData: TAG_Int
```

1.20.5 through 1.21.3 component storage:

```text
minecraft:custom_model_data: TAG_Int
```

Both numeric forms are preserved as:

```text
legacyValue
```

The provider deliberately does not rewrite a persisted numeric value into the
later `floats[0]` representation.

1.21.4+ expanded component storage:

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
flags   -> TAG_List<TAG_Byte>, each value 0 or 1
strings -> TAG_List<TAG_String>
colors  -> TAG_List<TAG_Int>
```

Missing fields inside a present expanded component normalize to immutable
empty lists.

Packed color values remain raw signed NBT integers. They are not coupled to
`MtnMinecraftTextColor` or another rendering abstraction.

Unknown fields inside the current compound are tolerated while recognized
field types remain schema-strict.

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

Recognized malformed data is translated through the existing item/player
`invalidData` path.

## Authority and removal semantics

Existing item authority remains:

```text
components present
  -> modern components authoritative
  -> legacy tag ignored
```

Recognized removal conflict:

```text
minecraft:custom_model_data
!minecraft:custom_model_data
```

Both cannot be present simultaneously.

Removal-only patches remain represented through `removedComponentIds`.

## Query tool

Bounded item-property output now includes custom-model data.

Numeric form:

```text
customModelData={legacy:42}
```

Expanded form:

```text
customModelData={floats:[...] flags:[...] strings:[...] colors:[...]}
```

Each list preview is capped at three values.

## Deterministic tests

Focused file:

```text
test/minecraft_item_custom_model_data_test.dart
```

Coverage includes:

- legacy `CustomModelData` integer
- 1.20.5-1.21.3 integer component
- numeric zero
- current float/flag/string/color lists
- arbitrary and empty string values
- negative packed color integers
- present empty compound versus absent component
- explicit empty lists
- immutability
- modern-over-legacy authority
- removal-only behavior and removal conflict
- unknown current metadata tolerance
- malformed legacy storage
- malformed current component/list types
- invalid boolean byte values

## Validation

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

## Real-file smoke inspection

Command:

```powershell
dart run tool/query_minecraft_worlds.dart --game-directory "$env:APPDATA\.minecraft" |
    Select-String 'customModelData=\{'
```

Result:

```text
(no matching output)
```

The command completed without parser/runtime failure, but no discovered real
inventory/equipment item persisted explicit custom-model data.

Therefore this checkpoint does not claim real-file validation of an actual
`CustomModelData` payload. The supported schemas remain deterministic-test
validated.

## Explicitly deferred

Custom model/rendering semantics:

- resource-pack model discovery/parsing
- `minecraft:item_model`
- effective rendered-model selection
- model-property evaluation
- custom-model-data writing

Other item properties:

- nested containers / bundle-like contents
- custom data
- item writing

Attribute/potion/effect semantics:

- effective item-registry defaults/calculations
- registry lookup
- brewing/runtime effect calculations
- general `minecraft:tooltip_display` support

Provider/player:

- pre-26.1 embedded `Data.Player` singleplayer handling
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

## Next action

Do not begin another feature yet.

After explicit user approval, prepare this feature branch for squash/PR/merge
against `main`.
