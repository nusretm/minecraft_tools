# Changelog

## 1.0.0-dev.27

Generic mod metadata foundation.

- Expanded `MtnMinecraftInfoMod` with provider-independent contributors, licenses, URLs, client/server-side support, dependency metadata and provided mod IDs.
- Added `MtnMinecraftInfoModUrls` with first-class homepage, source and issue-tracker URLs.
- Added `MtnMinecraftInfoModDependency` and generic dependency types: required, recommended, suggested, conflict and incompatible.
- Preserved raw provider version constraints instead of forcing Fabric and future Forge/NeoForge syntaxes into one parser.
- Multiple dependency constraints are preserved as OR alternatives.
- Fabric `authors`, `contributors`, `license`, `contact`, `environment`, `provides`, `depends`, `recommends`, `suggests`, `conflicts` and `breaks` are normalized into the generic model.
- Fabric `environment` maps to independent `clientSide` and `serverSide` booleans.
- Source URLs are populated only from authoritative metadata; issue URLs are never rewritten or guessed into repository URLs.
- `MtnMinecraftModList` merges generic metadata contributed by multiple providers for the same logical `id + version`.
- Added `example/mod_metadata.dart` with explicit missing-file validation.
- Real Armor HUD Fabric validation confirmed homepage, GitHub source, issue tracker, client-only support and dependency normalization.
- Final validation: analyzer clean, Fabric metadata tests 19/19, mod-list tests 10/10, full suite 301/301, diff-check clean and working tree clean.

## 1.0.0-dev.26

Mod icon lookup foundation.

- Added lazy icon access to `MtnMinecraftInfoMod` through `hasIcon` and `getIcon({int size = 128})`.
- Kept icon bytes out of the normalized model until explicitly requested.
- Preserved provider ownership of icon metadata and archive lookup rules.
- Added Fabric icon parsing for both single string paths and size-to-path maps.
- Multi-size Fabric icons select the smallest available width greater than or equal to the requested size, falling back to the largest available icon.
- Missing declared icon files do not invalidate otherwise valid mod metadata; `hasIcon` remains false and `getIcon()` returns null.
- Added lazy root-JAR reopening for installed mod icons.
- Added lazy embedded archive-chain traversal so icons for embedded mods remain readable after initial parsing without extracting nested JARs to disk.
- Preserved icon loaders through `MtnMinecraftModList` normalization/merge.
- Added `example/mod_icons.dart` for real-profile smoke validation.
- Real Fabric profile validation found 116 mods with declared/readable icons and loaded all 116 successfully.
- Added focused icon coverage; Fabric provider tests reached 15/15, mod-list tests 9/9, and the full suite 296/296.

## 1.0.0-dev.25

Fabric mod metadata/provider and embedded dependency graph foundation.

- Added the extensible `MtnMinecraftModInfoProvider` base contract with stable provider `name` identity.
- Added `MtnMinecraftModInfoProviderFabric` for root-level `fabric.mod.json` parsing.
- Added `MtnMinecraftModList` as the single provider registry and normalized mod graph authority.
- Every discovered root JAR is offered to every registered provider; provider results are merged instead of using first-match-wins behavior.
- Expanded `MtnMinecraftInfoMod` into the normalized output model with ID, name, version, description, authors, provider-derived `modTypes`, parent mods and directly installed source files.
- Canonical merging uses `id + version`, allowing one logical mod to be both directly installed and embedded and allowing different versions to remain distinct.
- Added recursive in-memory Fabric `jars[].file` parsing without extracting embedded JARs to disk.
- Added multi-parent embedded dependency tracking and recursive `getDependencyList()`.
- Added guarded `remove(mod)`: embedded-only mods cannot be removed directly; removing an installed mod rebuilds the graph and preserves dependencies still referenced elsewhere.
- Added `MtnListEvent` and `MtnMinecraftModList.onItem(list, mod, event)` with add/update/remove events based on normalized visible state changes.
- Root JAR parsing uses streaming archive input; embedded JARs are parsed from archive-entry bytes in memory.
- Real Fabric profile validation discovered 188 normalized logical mods from 54 physical JARs, including shared embedded dependencies and simultaneous installed+embedded mods.
- Added focused registry/graph, Fabric metadata, embedded recursion and installed-file discovery coverage; full validation reached 290/290 tests.

## 1.0.0-dev.24

Installed mod-file discovery foundation.

- Added immutable `MtnMinecraftInfoMod` with the discovered JAR file as its single source of truth.
- Added `MtnMinecraftInfoProvider.readMods()`.
- Discovery scans only direct files under `<gameDirectory>/mods/`.
- Matching is case-insensitive for the `.jar` extension.
- Missing `mods/` is treated as an empty immutable list.
- Nested directories and non-JAR files are ignored.
- Results are returned in deterministic file-name order.
- Added `example/mods.dart` for real-profile smoke validation.
- Kept JAR metadata, disabled-mod conventions, nested JARs, loader compatibility, namespace ownership and assets outside this checkpoint.

## 1.0.0-dev.23

Mod-loader discovery foundation.

- Added `MtnMinecraftInfoModLoaderType` for Fabric, Forge, NeoForge and Quilt.
- Added immutable `MtnMinecraftInfoModLoader` with loader type, loader version and inherited Minecraft version.
- Added `MtnMinecraftInfoProvider.readModLoader()`.
- Discovery reads only `versions/version.json` fields needed by this feature: `id` and `inheritsFrom`.
- Kept launcher-version parsing, libraries, arguments, assets, downloads and runtime reconstruction outside this checkpoint.
- Missing `version.json` or an unrecognized loader returns null; recognized malformed loader data remains strict.
- Added a focused `example/mod_loader.dart` smoke-test entry point.
- Added deterministic Fabric, Quilt, Forge and NeoForge discovery coverage.

## 1.0.0-dev.22

Item custom data foundation.

- Added nullable immutable `MtnMinecraftInfoItemStackComponents.customData`
  for explicit 1.20.5+ `minecraft:custom_data` compounds.
- Added nullable immutable `MtnMinecraftInfoItemStackComponents.legacyTag`
  for exact pre-1.20.5 raw item-tag preservation.
- Deliberately kept legacy `tag` distinct from modern `custom_data` instead
  of guessing Minecraft data-fixer migration rules.
- Preserved semantic parsing of known legacy fields while retaining the full
  original legacy tag, including unknown and modded fields.
- Preserved full NBT type fidelity for modern custom data, including numeric
  tag types, arrays, lists, compounds and strings.
- Preserved absent-versus-explicitly-empty semantics for modern custom data
  and legacy tags.
- Kept modern `components` authoritative over legacy `tag`.
- Added `minecraft:custom_data` component-removal conflict handling.
- Kept malformed recognized modern custom-data storage strict while unknown
  modern component IDs remain tolerant.
- Extended world query output with bounded custom-data and legacy-tag key
  previews instead of recursively dumping raw NBT.
- Added focused deterministic custom-data coverage.
- Kept data-fixer emulation, legacy-tag migration, custom-data matching/path
  queries, mutation, SNBT utilities and item writing outside this checkpoint.

## 1.0.0-dev.21

Nested item stacks foundation.

- Added persisted nested item-stack fields to
  `MtnMinecraftInfoItemStackComponents`: sparse `containerContents`,
  ordered `bundleContents`, ordered `chargedProjectiles`, and single
  `useRemainder`.
- Kept nested values recursive by reusing the existing
  `MtnMinecraftInfoItemStack` model instead of adding a second nested-item
  representation.
- Added internal `MtnMinecraftInfoItemNestedStackNbtParser` and kept
  `MtnMinecraftInfoItemStackNbtParser` as the single recursion authority.
- Normalized legacy `BlockEntityTag.Items`, Bundle `Items`, and
  `ChargedProjectiles` storage.
- Added modern `minecraft:container`, `minecraft:bundle_contents`,
  `minecraft:charged_projectiles`, and `minecraft:use_remainder` parsing.
- Preserved sparse container slot numbers rather than synthesizing a
  registry-dependent fixed container capacity.
- Kept nested maps/lists immutable and preserved absent-versus-explicitly-empty
  semantics.
- Added nested component-removal conflict handling while preserving
  modern-component authority over legacy item tags.
- Kept unknown nested-entry metadata tolerant while recognized slot/item
  structure remains strict.
- Extended the world query tool with bounded nested-item previews.
- Added focused deterministic nested-stack coverage including recursive
  container -> bundle -> custom-model-data parsing.
- Kept container loot metadata, bundle capacity/weight, Crossbow runtime
  mechanics, use-remainder runtime behavior, block-entity inventory discovery
  and item writing outside this checkpoint.

## 1.0.0-dev.20

Custom model data item foundation.

- Added public `MtnMinecraftInfoItemCustomModelData` with immutable
  `floats`, `flags`, `strings` and `colors` lists plus nullable
  pre-1.21.4 numeric `legacyValue`.
- Added nullable `MtnMinecraftInfoItemStackComponents.customModelData` with
  absent-versus-explicitly-empty semantics.
- Normalized legacy `CustomModelData` integer item tags.
- Normalized 1.20.5 through 1.21.3 integer
  `minecraft:custom_model_data` components without rewriting them into the
  later float-list representation.
- Added 1.21.4+ expanded custom-model-data parsing for floats, booleans,
  arbitrary strings and packed integer RGB colors.
- Preserved negative packed color integers and raw string values without
  coupling custom-model data to the Minecraft text-color model.
- Kept all current custom-model-data lists immutable and treated absent
  compound fields as empty lists.
- Preserved modern item-component authority and component-removal conflict
  handling for `minecraft:custom_model_data`.
- Kept unknown current custom-model-data fields tolerant while recognized
  fields remain schema-strict.
- Extended the world query tool with bounded custom-model-data output.
- Added focused deterministic custom-model-data coverage.
- Kept resource-pack model resolution, `minecraft:item_model`, effective
  rendered-model selection and item writing outside this checkpoint.

## 1.0.0-dev.19

Item attribute modifiers foundation.

- Added public `MtnMinecraftInfoItemAttributeModifier`,
  `MtnMinecraftInfoAttributeModifierOperation`,
  `MtnMinecraftInfoItemAttributeModifierSlot`,
  `MtnMinecraftInfoItemAttributeModifierDisplay` and display-type APIs.
- Added nullable immutable
  `MtnMinecraftInfoItemStackComponents.attributeModifiers` with
  absent-versus-explicitly-empty semantics.
- Normalized legacy `AttributeModifiers` item-tag entries including
  attribute identity, UUID, human-readable name, amount, operation and slot.
- Preserved legacy modifier UUID/name identity separately instead of guessing
  a modern namespaced modifier ID.
- Added 1.20.5-era `minecraft:attribute_modifiers` full-object and
  direct-list parsing, including legacy UUID/name modifier identity.
- Added 1.21+ namespaced modifier `id` parsing with arbitrary vanilla,
  future and modded attribute/modifier IDs.
- Normalized legacy numeric operations and modern named operations to one
  semantic enum.
- Added slot normalization for `any`, `hand`, `armor`, main/off-hand,
  armor slots, `body` and `saddle`.
- Added 1.21.6+ modifier display metadata with default, hidden and text
  override behavior through the shared `MtnMinecraftText` model.
- Preserved modern item-component authority and component-removal conflict
  handling for `minecraft:attribute_modifiers`.
- Extracted the four-int Minecraft UUID parser so world singleplayer UUIDs and
  legacy item modifier UUIDs share one internal normalization path.
- Extended item query output with a bounded attribute-modifier preview.
- Added focused deterministic attribute-modifier coverage.
- Kept effective item-registry defaults, attribute calculations,
  `tooltip_display`, writing and registry lookup outside this checkpoint.

## 1.0.0-dev.18

Potion item properties foundation.

- Added public `MtnMinecraftInfoPotionContents` as a reusable persisted
  potion-contents model instead of an item-only potion representation.
- Added `MtnMinecraftInfoItemStackComponents.potionContents` and nullable
  persisted `potionDurationScale`.
- Normalized pre-1.20.2 `Potion`, `CustomPotionColor` and
  `CustomPotionEffects` item tags.
- Normalized 1.20.2 through 1.20.4 `custom_potion_effects` with modern
  resource-location mob-effect IDs.
- Added 1.20.5+ `minecraft:potion_contents` compound and string-shorthand
  parsing, including `potion`, `custom_color`, `custom_effects` and the
  later `custom_name` field.
- Added 1.21.5+ `minecraft:potion_duration_scale` as an explicit
  non-negative float override without synthesizing the implicit default.
- Reused the shared mob-effect model/parser for potion custom effects and kept
  custom-effect lists immutable.
- Corrected the shared mob-effect parser to accept both the older byte
  amplifier representation and the newer integer representation, rejecting
  integer amplifiers outside Minecraft's 0..127 range.
- Preserved modern item-component authority and modern snake-case
  `custom_potion_effects` authority without malformed-data fallback.
- Added potion component-removal conflict handling and bounded potion metadata
  output to the world query tool.
- Added focused deterministic potion-property coverage and a player
  active-effect regression for integer amplifiers.
- Kept potion registry lookup, effective base effects, brewing recipes,
  computed colors/names/durations and writing outside this checkpoint.

## 1.0.0-dev.17

Player active effects and shared mob-effect foundation.

- Added public `MtnMinecraftInfoMobEffect` and
  `MtnMinecraftInfoMobEffectId` as a reusable persisted mob-effect model
  rather than a player-only effect representation.
- Preserved modern resource-location IDs and pre-1.20.2 numeric IDs without
  guessing registry mappings for legacy or modded data.
- Added one shared internal mob-effect NBT parser for legacy
  `ActiveEffects` and modern `active_effects` storage.
- Normalized 1.20.2 field renames, recursive hidden effects and 1.20.5 omitted
  defaults into one semantic model.
- Added nullable immutable `MtnMinecraftInfoPlayer.activeEffects` with
  absent-versus-explicitly-empty list semantics.
- Made modern `active_effects` authoritative when both storage forms are
  present; malformed modern data does not fall back to legacy data.
- Kept unknown effect metadata tolerant while recognized effect fields remain
  schema-strict.
- Extended the world query tool with bounded player-effect smoke output.
- Kept potion component parsing, effect registry lookup, localization,
  duration formatting, runtime calculations and effect writing outside this
  checkpoint.

## 1.0.0-dev.16

Java Edition 26.1+ singleplayer player relationship foundation.

- Added nullable `MtnMinecraftInfoWorld.singleplayerUuid` as the canonical
  persisted singleplayer-player reference.
- Added derived `MtnMinecraftInfoWorld.singleplayerPlayer` lookup over the
  world's immutable discovered player snapshots instead of storing a second
  relationship authority.
- Parsed 26.1+ `Data.singleplayer_uuid` from Minecraft's four-int UUID NBT
  representation into canonical lowercase hyphenated UUID text.
- Preserved the UUID when the referenced player file is missing or unavailable;
  the derived player relationship remains null in that case.
- Kept malformed recognized `singleplayer_uuid` values schema-strict so they
  produce world-local `invalidData` instead of a guessed identity.
- Kept pre-26.1 embedded `Data.Player` handling outside this checkpoint.
- Extended the world query tool with singleplayer UUID and resolved-player
  output.
- Added deterministic world-discovery coverage for resolved, unresolved and
  malformed singleplayer UUID relationships.

## 1.0.0-dev.15

Minecraft text and item display properties foundation.

- Added global Pure Dart `MtnMinecraftText`, `MtnMinecraftTextItem`,
  `MtnMinecraftTextStyle`, `MtnMinecraftTextColor` and
  `MtnMinecraftTextFormat` APIs.
- Added classic named colors, arbitrary RGB colors, section-sign parsing,
  render-ready style spans, plain-text projection and canonical text
  serialization.
- Made `MtnMinecraftText.text` the authoritative mutable source through a
  getter/setter contract; changing it invalidates imported semantic component
  metadata.
- Added Minecraft JSON Text Component and NBT Text Component import/export,
  including 1.20.5-era JSON strings and direct inline NBT component values.
- Added semantic `translate`, `fallback` and `with` preservation so
  translated components can round-trip through `toJson()` and `toNbt()`.
- Made translated argument lists immutable snapshots and preserved explicit
  inherited-style overrides during serialization.
- Kept unresolved dynamic `keybind`, `selector`, `nbt` and unresolved
  `score` components from being exposed as fake visible text; an explicit
  stored `score.value` remains usable as visible text.
- Changed server status MOTD from a raw string to `MtnMinecraftText` while
  preserving plain MOTD output in `toMap()`.
- Added item display text normalization:
  `MtnMinecraftInfoItemStackComponents.customName`,
  `itemName` and immutable nullable `lore`.
- Normalized legacy `tag.display.Name` / `tag.display.Lore` and modern
  `minecraft:custom_name`, `minecraft:item_name` and `minecraft:lore`
  through the shared text model.
- Preserved modern-component authority, explicit empty lore semantics and
  component-removal conflict validation.
- Added focused Minecraft text and item-display tests; final validation reached
  176/176 passing tests with clean analyzer and `git diff --check` output.
- No `dart format` was run.

## 1.0.0-dev.14

Java Edition item core properties foundation.

- Added `MtnMinecraftInfoItemStackComponents` and
  `MtnMinecraftInfoItemStack.components`.
- Normalized explicitly persisted damage, repair cost, unbreakable state,
  active enchantments and stored enchantments across legacy item `tag` data
  and modern item `components`.
- Added a dedicated internal
  `MtnMinecraftInfoItemStackComponentsNbtParser` instead of expanding player
  inventory parsing with item-metadata schema rules.
- Made a present modern `components` compound authoritative over legacy
  `tag` for the same stack.
- Preserved arbitrary vanilla, future and modded enchantment resource IDs as
  immutable maps without requiring an enchantment registry.
- Supported both 1.20.5-style enchantment payloads with nested `levels` and
  the later simplified direct enchantment-ID map.
- Preserved explicitly removed modern component IDs separately so registry
  defaults are not guessed by the provider.
- Kept unknown legacy metadata and unknown modern component IDs tolerant while
  recognized properties remain schema-strict.
- Preserved absent-versus-explicitly-empty enchantment semantics.
- Added 14 focused item-core-properties tests; full package validation reached
  149/149 passing tests with clean analyzer output.
- Adjusted prior inventory tests so `tag` / `components` containers now use
  valid compound shapes while unknown contents remain tolerated.
- Extended `tool/query_minecraft_worlds.dart` with bounded item-property
  output for inventory, ender-chest and equipment items.
- Real modded Java Edition 1.20.1 smoke validation read legacy damage,
  repair-cost and enchantment data from real inventory and equipment stacks,
  including vanilla and modded enchantment namespaces.
- Real smoke examples included a Simply Swords greataxe with damage 365,
  repair cost 3 and mixed modded/vanilla enchantments, and Cataclysm armor
  carrying large repair costs and many enchantments.
- Real-file validation did not encounter explicit unbreakable values or stored
  enchantments. Those fields, modern 1.20.5+ components, component removals and
  later enchantment representation remain deterministic-test validated.
- Kept custom name/lore/text, custom model data, attributes, potion/container
  data and other richer item components outside this checkpoint.

## 1.0.0-dev.13

Java Edition player inventory and equipment foundation.

- Added public `MtnMinecraftInfoItemStack` with semantic namespaced item ID
  and stack count.
- Extended `MtnMinecraftInfoPlayer` with immutable nullable 36-slot
  `inventory`, immutable nullable 27-slot `enderChest`, normalized
  `equipment`, and derived `selectedItem`.
- Added `MtnMinecraftInfoPlayerEquipment` for head, chest, legs, feet and
  off-hand slots.
- Added internal `MtnMinecraftInfoItemStackNbtParser` with legacy `Count`
  byte and modern `count` integer support.
- Added internal `MtnMinecraftInfoPlayerInventoryNbtParser` so inventory and
  equipment storage rules remain out of the main player schema parser.
- Normalized legacy player slots 100..103 and -106 into semantic equipment.
- Added per-slot modern `equipment` precedence with legacy fallback only when
  the corresponding modern slot is absent.
- Preserved absent-vs-empty storage semantics for `Inventory` and
  `EnderItems`.
- Ignored unknown/future/modded slot numbers while keeping duplicate recognized
  slots and malformed recognized item data strict.
- Preserved arbitrary vanilla and modded namespaced item IDs without requiring
  an item registry.
- Kept legacy `tag` and modern `components` metadata outside this
  foundation.
- Added 15 focused inventory/equipment tests; full package validation reached
  135/135 passing tests with clean analyzer output.
- Extended `tool/query_minecraft_worlds.dart` with bounded inventory,
  ender-chest and equipment smoke output.
- Real Java Edition 1.20.1 modded smoke validation read legacy inventory and
  equipment from all 8 discovered player snapshots across 3 worlds, including
  vanilla and many mod namespaces.
- Real files validated selected-item resolution, legacy armor/off-hand routing
  and stack counts. Non-empty ender-chest data and modern 1.20.5+/1.21.5+
  storage remain deterministic-test validated.

## 1.0.0-dev.12

Java Edition player gameplay core.

- Added immutable gameplay-core models for rotation, block position, food,
  experience, abilities, respawn and last-death state.
- Added `MtnMinecraftInfoPlayerGameMode` and normalized persisted player game
  mode integers to survival, creative, adventure and spectator.
- Extended `MtnMinecraftInfoPlayer` with nullable rotation, current/previous
  game mode, health, absorption, food, XP, abilities, selected hotbar slot,
  respawn and last-death metadata.
- Kept missing persisted values nullable instead of synthesizing vanilla
  defaults.
- Normalized `previousPlayerGameType=-1` to no previous game mode and rejected
  other unknown game-mode values as invalid player data.
- Added semantic respawn normalization for legacy `Spawn*` fields, 1.21.5
  `respawn.angle`, and 1.21.9+ `respawn.yaw` / `respawn.pitch`.
- Made a present modern `respawn` compound authoritative without silently
  falling back to legacy fields when malformed.
- Added `LastDeathLocation` parsing with dimension and three-int block
  position.
- Extracted player semantic NBT schema parsing into the internal
  `MtnMinecraftInfoPlayerNbtParser`, leaving provider code responsible for
  discovery, gzip and raw NBT decode orchestration.
- Added 16 focused gameplay-core tests; full package validation reached 120/120
  passing tests with clean analyzer output.
- Extended `tool/query_minecraft_worlds.dart` with grouped gameplay-core smoke
  output.
- Real Java Edition 1.20.1 smoke validation read gameplay state for all 8
  player snapshots across 3 worlds and validated legacy respawn plus
  last-death data from real files.
- Kept inventory, ender chest, equipment/item components, active effects and
  singleplayer identity mapping outside this checkpoint.

## 1.0.0-dev.11

Java Edition player advancements foundation.

- Added `MtnMinecraftInfoPlayerAdvancements`,
  `MtnMinecraftInfoPlayerAdvancement`,
  `MtnMinecraftInfoPlayerAdvancementsStorageLayout`,
  `MtnMinecraftInfoPlayerAdvancementsState` and
  `MtnMinecraftInfoPlayerAdvancementsError`.
- Added `MtnMinecraftInfoProvider.readPlayerAdvancements(world, player)` as
  an on-demand player-owned advancement-progress API.
- Added legacy `advancements/<uuid>.json` and 26.1+
  `players/advancements/<uuid>.json` storage with deterministic
  modern-over-legacy precedence and no corrupt-modern fallback.
- Kept advancement storage independent from player-data storage.
- Added nullable missing-file semantics and local `readFailed`,
  `invalidJson` and `invalidData` states for present files.
- Added nullable root `DataVersion`, arbitrary advancement resource IDs,
  authoritative stored `done` state and immutable criterion completion maps.
- Parsed vanilla criterion completion timestamps into UTC `DateTime` values.
- Preserved unknown vanilla, future and modded advancement/criterion IDs.
- Refactored stats and advancements onto one internal player-owned JSON
  resource reader for ownership validation, storage resolution and JSON I/O.
- Kept advancement definitions, requirements, display metadata, rewards,
  semantic progress calculation and writing outside this foundation.
- Extended `tool/query_minecraft_worlds.dart` with bounded advancement smoke
  output.
- Automated validation passes with `dart analyze`, 104/104 tests and
  `git diff --check` on Windows.
- Real Java Edition 1.20.1 smoke validation read all 8 discovered legacy
  advancement snapshots across 3 worlds, including modded namespaces and
  datasets ranging from 2 to 1363 advancement entries.

## 1.0.0-dev.10

Java Edition player statistics foundation.

- Added `MtnMinecraftInfoPlayerStats`,
  `MtnMinecraftInfoPlayerStatsStorageLayout`,
  `MtnMinecraftInfoPlayerStatsState` and
  `MtnMinecraftInfoPlayerStatsError`.
- Added `MtnMinecraftInfoProvider.readPlayerStats(world, player)` as an
  on-demand player-owned statistics read API.
- Added explicit support for legacy `stats/<uuid>.json` and 26.1+
  `players/stats/<uuid>.json` storage.
- Added deterministic modern-over-legacy precedence without silently falling
  back when the authoritative modern file is corrupt.
- Kept stats storage discovery independent from the player's data-file layout.
- Added world/player ownership validation so stats lookup cannot attach a
  foreign player snapshot by UUID alone.
- Added nullable missing-stats semantics and local `readFailed`,
  `invalidJson` and `invalidData` states for present files.
- Added nullable root `DataVersion` and deeply immutable generic
  category/statistic integer maps that preserve unknown external keys.
- Kept unit conversion, closed vanilla-stat enums, aggregation/leaderboards,
  writing and advancements outside this foundation.
- Extended `tool/query_minecraft_worlds.dart` with player-stats smoke output.
- Automated validation passes with `dart analyze`, 84/84 tests and
  `git diff --check` on Windows.
- Real Java Edition 1.20.1 smoke validation read legacy stats for all 8
  discovered player snapshots across 3 worlds, including varying category and
  counter sets.

## 1.0.0-dev.9

Java Edition world aggregate player snapshots and world icon I/O.

- Added immutable `MtnMinecraftInfoWorld.players` snapshots populated during
  `readWorlds()`.
- Added independent `MtnMinecraftInfoWorldPlayersState` and
  `MtnMinecraftInfoWorldPlayersError` so aggregate player-storage failures do
  not invalidate an otherwise valid world or abort sibling world discovery.
- Kept individual corrupt player files represented by the existing
  `MtnMinecraftInfoPlayer.invalid` model.
- Added raw nullable `MtnMinecraftInfoWorld.icon` bytes backed by
  `<world>/icon.png`, with defensive-copy immutability.
- Added `MtnMinecraftInfoProvider.writeWorldIcon(world, bytes)` with serialized
  same-target atomic replacement.
- Generalized the existing atomic file-replacement primitive so server and
  world-icon writes share one implementation.
- Kept PNG decoding, resizing and validation outside the provider.
- Added `tool/query_minecraft_worlds.dart` for real world/player/icon
  inspection and opt-in icon-write verification.
- Automated validation passes with `dart analyze`, 68/68 tests and
  `git diff --check` on Windows.
- Real Java Edition smoke validation discovered 3 worlds with player counts
  1/6/1, read all three icons, and successfully replaced/re-read one icon
  byte-for-byte.

## 1.0.0-dev.8

Java Edition player discovery foundation.

- Added `MtnMinecraftInfoPlayer`, `MtnMinecraftInfoPlayerPosition` and
  `MtnMinecraftInfoPlayerStorageLayout`.
- Added `MtnMinecraftInfoProvider.readPlayers(world)`.
- Added support for pre-26.1 `playerdata/<uuid>.dat` and 26.1+
  `players/data/<uuid>.dat` layouts.
- Added deterministic modern-over-legacy precedence for duplicate UUIDs without
  silently falling back when the modern entry is corrupt.
- Added filename-based canonical lowercase UUID identity while preserving the
  exact discovered `dataFile`.
- Added gzip decoding around the existing raw NBT codec without changing the
  NBT API.
- Added nullable core player metadata for `DataVersion`, `Dimension` and a
  three-double `Pos`.
- Added player-local `available` / `invalid` state and
  read/compression/NBT/data error classification so one corrupt player does not
  fail sibling discovery.
- Added deterministic UUID ordering, provider/world path validation and
  non-following filesystem discovery behavior.
- Kept inventory, health, hunger, XP, game mode, abilities, effects, spawn,
  stats, advancements and singleplayer UUID association out of this foundation.
- Added deterministic player-discovery coverage; full package validation passes
  with `dart analyze` and 62/62 tests on Windows.

## 1.0.0-dev.7

Java Edition world discovery / `level.dat` foundation.

- Added `MtnMinecraftInfoWorld` and `MtnMinecraftInfoWorldVersion`.
- Added `MtnMinecraftInfoProvider.savesDirectory` and `readWorlds()`.
- Added direct `<gameDirectory>/saves/*/level.dat` discovery.
- Added gzip decoding as a file-format wrapper around the existing raw NBT
  codec without changing the NBT API.
- Added core immutable metadata for `LevelName`, `DataVersion`, `Version` and
  `LastPlayed`.
- Kept filesystem directory identity separate from Minecraft `LevelName`.
- Added world-local `available` / `invalid` state and read/compression/NBT/data
  error classification so one corrupt world does not fail sibling discovery.
- Added deterministic directory ordering and non-following symlink behavior.
- Kept `level.dat_old`, player data, difficulty, spawn, world border and
  world-generation normalization out of this foundation checkpoint.
- Added deterministic world-discovery coverage; full package validation passes
  with `dart analyze` and 47/47 tests on Windows.

## 1.0.0-dev.6

Legacy pre-1.7 Java server-list ping fallback.

- Added transparent legacy fallback after modern status timeout or invalid
  modern packet framing.
- Added Minecraft 1.6 extended `FE 01 FA` / `MC|PingHost` support.
- Added Minecraft 1.4/1.5 `FE 01` support.
- Added pre-1.4 `FE` ping support.
- Added `MtnMinecraftInfoServerStatusFormat` to distinguish modern and
  legacy responses.
- Preserved malformed modern JSON/schema as `invalidResponse` without hiding
  it behind legacy fallback.
- Preserved the existing modern stale/grace lifecycle: a previously modern
  server is not downgraded to a legacy snapshot after a transient timeout.
- Added `allowLegacyFallback` to `MtnMinecraftInfoServer.queryStatus()`
  and `--no-legacy` to the query tool.
- Added legacy ping RTT measurement when latency measurement is enabled.
- Added deterministic transport-level tests for all three legacy request
  variants and strict modern-only behavior.


## 1.0.0-dev.5

Server address normalization and known-server matching foundation.

- Added `MtnMinecraftInfoServerAddress` as the shared Java server address
  parser/normalizer.
- Unified status/SRV routing with the public address parser.
- Canonicalized DNS case, trailing dots, default port 25565, and IPv4/IPv6
  textual forms without mutating persisted `servers.dat` addresses.
- Added `MtnMinecraftInfoKnownServer` and explicit match evidence:
  `exact`, `normalized`, `resolvedEndpoint`, and `none`.
- Kept resolved endpoint matching weaker than user-facing address identity.
- Deliberately excluded protocol, MOTD, version, favicon, and player data from
  server identity inference.
- Added deterministic normalization, IPv6, alias, and resolved-endpoint tests.


## 1.0.0-dev.4

Java Edition SRV discovery foundation.

- Added Pure Dart DNS SRV lookup for `_minecraft._tcp.<host>`.
- Bare hostnames now resolve SRV before Server List Ping.
- Explicit ports bypass SRV resolution.
- Added RFC 2782 priority and weighted ordering.
- Added sequential fallback across multiple SRV candidates.
- Kept the original user-facing hostname in the Server List Ping handshake
  while connecting TCP to the resolved SRV target.
- Bounded multi-nameserver SRV resolution to one shared timeout budget.
- Preserved direct `host:25565` fallback when no usable SRV record exists.
- Added explicit handling for SRV target `.` as service unavailable.
- Exposed `MtnMinecraftInfoSrvResolver` for custom/private DNS resolution.
- Added a default UDP resolver using Cloudflare and Google public DNS.
- Added deterministic local UDP DNS parsing tests and server-routing tests.
- Updated the query tool so omitting `--port` exercises SRV discovery.


## 1.0.0-dev.3

Server availability-state correction.

- Added `MtnMinecraftInfoServerState.online/offline/unavailable`.
- DNS failures and never-seen unreachable targets return
  `state=unavailable` instead of throwing.
- Moved reachability history and grace/offline transitions from the raw status
  client into each `MtnMinecraftInfoServer` instance.
- Added `MtnMinecraftInfoServer.queryStatus()`, read-only runtime `status`,
  and `onChange`.
- The stateless raw status client now reports DNS/timeout/connection
  unavailability reasons.
- A previously online server remains online through transient reachability
  failures for a default one-minute grace period.
- Consecutive reachability failures beyond the grace period transition the
  server to `offline`; a successful response resets the window.
- Grace/offline results retain the last known status snapshot with
  `isStale=true`, `lastSuccessfulAt`, and `failureSince`.
- Stale latency is cleared to null so callers can represent measurement as
  pending/unavailable.
- Malformed Minecraft protocol/JSON responses remain exceptions.
- Ping/pong measurement failure remains non-fatal for an otherwise online
  status response.
- Added deterministic unreachable-endpoint and online-to-offline grace
  coverage.

## 1.0.0-dev.2

Java Edition Server Status/Ping foundation.

- Added modern Java Server List Ping over TCP.
- Added version name, protocol, player counts/sample, MOTD, favicon,
  secure-chat flag and optional ping/pong latency.
- Added modern Forge `forgeData` parsing for mods, channels,
  `fmlNetworkVersion` and truncation state.
- Added legacy FML `modinfo.modList` parsing.
- Kept advertised mods distinct from proven client requirements.
- Added explicit required-channel metadata where Forge provides it.
- Preserved the exact raw status JSON for unmodeled loader/proxy fields.
- Added local TCP protocol tests covering handshake, status framing and
  ping/pong.
- Validated with clean analyzer output, 13/13 automated tests, and a live
  `mc.hypixel.net:25565` Server List Ping including successful latency
  measurement.


## 1.0.0-dev.1

Initial extraction from the MtnLauncher prototype into the standalone
`minecraft_tools/minecraft_info_provider` package.

- Added a Pure Dart Java Edition NBT codec covering all standard payload tags,
  big-endian numeric encoding and Java modified UTF-8.
- Added `MtnMinecraftInfoProvider` and `MtnMinecraftInfoServer`.
- Added uncompressed `servers.dat` read and append support.
- Added `hidden`, icon and nullable `acceptTextures` semantics.
- Preserved unknown existing root/server NBT tags while appending.
- Added serialized same-target operations and atomic replacement with rollback.
- Added focused automated tests and a copy-only real-file validator.
- Removed all MtnLauncher compile-time dependencies.
- Validated with clean analyzer output, 10/10 automated tests, and a real
  Java Edition `servers.dat` preserving all pre-existing server compounds.
