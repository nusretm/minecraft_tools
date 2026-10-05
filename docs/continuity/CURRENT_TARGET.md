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
00467ae4b985b092f79cf929b391a549070fb966
Add Minecraft player inventory and equipment foundation
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
- Java Edition player inventory / ender chest / equipment
- minimal semantic item stack `id + count`

## Active checkpoint

Java Edition Item Core Properties Foundation.

Current branch:

```text
feature/minecraft-item-core-properties-foundation
```

Implementation/tool HEAD before this metadata pass:

```text
f824ca985d8ab5802feff7cea0d0ced5d8257e8d
Show item core properties in world query tool
```

Package version for this checkpoint:

```text
1.0.0-dev.14
```

## Public API addition

`MtnMinecraftInfoItemStack` now has:

```text
components -> MtnMinecraftInfoItemStackComponents?
```

Core persisted-property model:

```text
MtnMinecraftInfoItemStackComponents
  damage
  repairCost
  unbreakable
  enchantments
  storedEnchantments
  removedComponentIds
```

The model represents explicitly persisted item overrides. It is not an
effective item definition resolved against the Minecraft item registry.

## Parser architecture

```text
MtnMinecraftInfoPlayerInventoryNbtParser
  -> MtnMinecraftInfoItemStackNbtParser
       -> id / count
       -> MtnMinecraftInfoItemStackComponentsNbtParser
            -> legacy tag
            -> modern components
            -> semantic core properties
```

Item metadata remains an item-domain responsibility rather than a
player-inventory responsibility.

## Legacy item normalization

Pre-1.20.5 `tag` properties handled by this checkpoint:

```text
Damage
RepairCost
Unbreakable
Enchantments
StoredEnchantments
```

Semantic output:

```text
Damage             -> damage
RepairCost         -> repairCost
Unbreakable        -> unbreakable
Enchantments       -> enchantments
StoredEnchantments -> storedEnchantments
```

Legacy enchantments are normalized from compound-list entries containing
namespaced `id` plus short `lvl`.

Unknown legacy metadata remains tolerated. Recognized properties remain
schema-strict.

## Modern item normalization

Recognized 1.20.5+ component IDs:

```text
minecraft:damage
minecraft:repair_cost
minecraft:unbreakable
minecraft:enchantments
minecraft:stored_enchantments
```

A present `components` compound is authoritative over legacy `tag`.

Enchantments accept both:

```text
1.20.5-style:
minecraft:enchantments = {
  levels: {
    minecraft:sharpness: 5
  }
}

later simplified form:
minecraft:enchantments = {
  minecraft:sharpness: 5
}
```

Both normalize to immutable `Map<String, int>`.

Unknown modern components remain tolerated.

## Component removals

Modern item component patches may explicitly remove components:

```text
!minecraft:damage
!minecraft:enchantments
!example:custom_component
```

Their IDs are retained in:

```text
removedComponentIds
```

The provider deliberately does not turn a removal into an effective default
value because item defaults require registry knowledge.

A recognized component cannot simultaneously be supplied and explicitly
removed in the same normalized patch.

## Semantic rules

```text
property absent
  -> nullable semantic property remains null

enchantment property explicitly empty
  -> immutable empty map

modern removal present
  -> component ID retained in removedComponentIds

no recognized property/removal
  -> item.components == null
```

All public enchantment maps and removal sets are immutable.

Namespaced enchantment IDs are preserved as external strings so modded
enchantments require no provider-specific registry.

## Deterministic validation

Fourteen focused item-core-properties tests cover:

- complete legacy damage / repair / unbreakable / enchantment normalization
- complete 1.20.5-style modern core-component normalization
- later simplified enchantment representation
- modern-over-legacy authority
- unknown legacy/modern metadata tolerance
- explicit empty enchantments
- legacy explicit false unbreakable
- immutable enchantment maps
- malformed recognized legacy properties
- duplicate legacy enchantment IDs
- malformed recognized modern properties
- strict `tag` / `components` container shapes
- modern component removals and conflict rejection
- immutable component-removal set

Full package validation before smoke-tool extension:

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

After pulling the smoke-tool extension:

```text
dart analyze
No issues found!
```

Final analyzer/test/diff/status validation must be rerun after this metadata
pass.

No `dart format` was run.

## Real Java Edition 1.20.1 modded smoke validation

Three worlds and eight player snapshots were read from a real modded game
directory. All observed player files used legacy storage with
`DataVersion=3465`.

Real-file validated:

```text
legacy tag parsing
damage
repairCost
active enchantments
vanilla enchantment IDs
modded enchantment IDs
inventory item properties
equipment item properties
large repairCost values
bounded enchantment preview
```

Representative inventory observations:

```text
simplyswords:diamond_greataxe
  damage=365
  repairCost=3
  enchantments=
    celestisynth:pulsation:1
    minecraft:sharpness:4
    minecraft:unbreaking:3

cataclysm:cursed_bow
  enchantments=minecraft:power:5

minecraft:diamond_axe
  damage=147
  enchantments=majruszsenchantments:leech:1
```

Representative equipment observations:

```text
caverns_and_chasms:sanguine_chestplate
  damage=280
  repairCost=1
  enchantments=
    combatroll:acrobat:3
    minecraft:protection:4
    minecraft:unbreaking:3

cataclysm:cursium_helmet/chestplate/leggings/boots
  damage=0
  repairCost up to 131071
  many vanilla and modded enchantments
```

The smoke preview correctly bounded large enchantment collections and reported
the remaining count rather than dumping every entry.

Not encountered in the real 1.20.1 dataset:

```text
explicit unbreakable value
stored enchantments
non-empty EnderItems
```

Deterministic-test only:

```text
unbreakable normalization
storedEnchantments normalization
modern 1.20.5+ components
modern component removals
later simplified enchantment representation
```

Current checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / REAL-WORLD 1.20.1 MODDED VALIDATED
```

## Explicitly deferred

- custom name / lore / text-component normalization
- custom model data
- attribute modifiers
- potion-specific properties
- nested containers / bundle-like contents
- custom data
- other rich item components
- item writing
- player active effects
- singleplayer player identity / UUID relationship
- installed-content discovery

## Locked foundations

This checkpoint does not redesign:

- item identity / count semantics
- inventory / ender-chest slot routing
- equipment normalization
- player identity / storage precedence
- gameplay core
- stats / advancements
- world ownership
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
   `00467ae4b985b092f79cf929b391a549070fb966`.
4. Force-push only with `--force-with-lease`.
5. Fast-forward merge to `main` only after the squashed tree is locally
   verified.

Likely next item-components sub-checkpoint:

- Item Display / Text Properties Foundation

That checkpoint should be designed separately because custom-name/lore text
storage changed materially across Minecraft versions.
