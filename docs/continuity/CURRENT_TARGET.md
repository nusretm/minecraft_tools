# Minecraft Tools — Current Target

Last updated: 2026-10-06

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Current main

```text
main
97cc91ba6cc311d4872f9f9136d1dc6892ff1eb0
Add item custom data foundation
```

Package version:

```text
1.0.0-dev.22
```

Working milestone state:

```text
CORE ITEM-READ FOUNDATION COMPLETE
NO ACTIVE FEATURE CHECKPOINT
```

The Custom Data Foundation was squash merged through PR #14 and both the
local and remote feature branches were deleted.

## Completed item-read foundation

The planned core `MtnMinecraftInfoItemStack` read foundation is complete.

Completed checkpoints:

```text
Item Core Properties
Text / Item Display
Potion Properties
Attribute Modifiers
Custom Model Data
Nested Item Stacks
Custom Data
```

The item model now covers the following persisted information across the
supported legacy and modern storage generations:

- item ID and count
- damage
- repair cost
- unbreakable state
- active enchantments
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
- Crossbow charged projectiles
- use remainder
- modern `minecraft:custom_data`
- exact legacy raw `tag` preservation
- explicit modern component removals

Nested persisted item stacks recursively reuse `MtnMinecraftInfoItemStack`.

## Locked item-read semantics

These decisions are authoritative unless explicitly redesigned later.

### Persisted values, not effective registry values

`MtnMinecraftInfoItemStackComponents` represents explicitly persisted
stack data/overrides. It does not synthesize item-registry defaults.

### Modern authority

```text
components present
  -> modern component storage is authoritative
  -> legacy tag is not used as fallback
```

### Removal preservation

Modern `!minecraft:*` removals remain explicit through
`removedComponentIds`. Effective registry values are not guessed.

### Unknown external metadata

- unknown vanilla/future/modded IDs remain tolerant where not schema-recognized
- recognized malformed component data remains strict
- malformed recognized item data maps to the existing player `invalidData` path

### Legacy tag versus modern custom data

```text
pre-1.20.5 tag
  -> legacyTag
  -> customData == null

1.20.5+ minecraft:custom_data
  -> customData
  -> legacyTag == null
```

No Minecraft DataFixer migration behavior is guessed.

### Absent versus explicit empty

Persisted empty collections/compounds remain distinguishable from absent
properties where the storage format makes that distinction.

### No automatic formatting

`dart format` is not used for Pure Dart code unless explicitly requested.

## Final item-read validation

Authoritative validation at the final Custom Data checkpoint:

```text
dart analyze
No issues found!

dart test test/minecraft_item_custom_data_test.dart
11/11 passed

dart test test/minecraft_item_core_properties_test.dart
14/14 passed

dart test test/minecraft_item_nested_stacks_test.dart
13/13 passed

dart test
250/250 passed

git diff --check origin/main...HEAD
PASS

git status
clean
```

Real Java Edition 1.20.1 modded smoke validation confirmed legacy item-tag
preservation across vanilla-known, not-yet-modeled and mod-specific metadata.
Modern `minecraft:custom_data` did not occur in that real 1.20.1 dataset and
therefore remains deterministic-test validated only.

## Authoritative item handoffs

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CORE_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_TEXT_ITEM_DISPLAY.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_POTION_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_ATTRIBUTE_MODIFIERS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_MODEL_DATA.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_NESTED_STACKS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_DATA.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_READ_FOUNDATION_COMPLETE.md
```

## Open backlog

No next feature has been selected yet. The following work remains open.

### Priority group 1 — write/effective item architecture

- Item Writing Foundation
  - serialize `MtnMinecraftInfoItemStack`
  - legacy `tag` versus modern `components` generation policy
  - all currently normalized item properties
  - nested recursive item writing
  - component removals
  - unknown/modded metadata preservation policy
  - safe/atomic persistence boundary
- Effective Item / Registry Foundation
  - item registry lookup
  - registry-derived default components
  - persisted overrides + defaults
  - effective handling of removed components
  - registry-derived capacities/default values

### Priority group 2 — world/player foundations still open

- richer world metadata / cross-version normalization
  - difficulty
  - default/world game mode
  - world spawn
  - world border
  - world-generation settings
  - possible `level.dat_old` recovery policy
- pre-26.1 embedded `Data.Player` singleplayer identity handling
- installed-content discovery

### Priority group 3 — player progress semantics

- statistics semantic unit conversion
- statistics aggregation / leaderboards
- statistics writing
- advancement definition discovery/parsing
- advancement titles/descriptions/icons/display metadata
- advancement requirements and criteria definitions
- advancement rewards
- semantic completion percentage / remaining criteria
- advancement writing

### Priority group 4 — item/gameplay runtime semantics

- attribute registry lookup
- effective item-registry attribute defaults
- attribute calculations
- potion registry lookup
- effective potion base effects
- brewing recipes
- computed potion colors/names/durations
- potion writing
- effect registry lookup
- effect localization/duration formatting/runtime calculations
- effect writing
- general `minecraft:tooltip_display` support

### Priority group 5 — item rendering and nested runtime

- resource-pack discovery / precedence
- item-model definitions
- `minecraft:item_model`
- custom-model-data driven model resolution
- effective rendered-model selection
- `minecraft:container_loot`
- registry-derived container sizes/capacities
- Bundle weight/capacity/runtime UI behavior
- Crossbow charged/firing runtime mechanics
- use-remainder runtime behavior
- block-entity inventory discovery

### Priority group 6 — Minecraft text runtime

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

### Priority group 7 — server-list write policy

- address deduplication policy
- normalized-address write/update behavior
- existing-record update versus append behavior
- possible remove/update APIs

### Priority group 8 — advanced custom-data tooling

- legacy tag -> modern custom-data migration
- Minecraft DataFixer emulation/integration
- NBT path query API
- custom-data partial/predicate matching
- custom-data mutation
- SNBT parser/writer utilities
- mod-specific custom-data interpretation

These are lower priority than preserving the current reader architecture.

### Separate integration work

- client-mod activity discovery / exact runtime server-subsystem discovery

This requires the future Minecraft client-mod communication path and should
not be guessed from logs/server address alone.

## Explicit non-provider responsibility

World-icon PNG decoding, validation, resizing and image conversion remain
application/UI responsibility. The provider intentionally exposes raw icon
bytes and atomic replacement only.

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- no merge without separate explicit approval
- keep checkpoints small and independently reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- use `dart analyze`, focused tests, `dart test`, `git diff --check`, `git status`
- architecture/naming/dependency boundaries are acceptance criteria
- do not modify `hypixel_api/`
- do not add backward compatibility unless explicitly approved

## Next action

Select the next checkpoint from the open backlog before implementation.

No implementation should begin solely because an item appears earlier in the
priority groups; the user must explicitly approve the chosen scope.
