# Minecraft Info Provider — Mod Language Translation Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/mod-language-translation-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.31
Status: IMPLEMENTED / VALIDATED / REAL JAR TRANSLATION SMOKE PASSED
```

## Goal

Add a provider-independent exact-locale language/translation layer on top of the mod archive asset-source foundation, without mixing in item identity, model resolution, rendering or implicit resource precedence.

## Public API

New public models:

```dart
MtnMinecraftInfoModLanguage
MtnMinecraftInfoModTranslation
MtnMinecraftInfoModLanguageError
MtnMinecraftInfoModLanguageException
```

New `MtnMinecraftModList` methods:

```dart
readLanguages(namespace, locale: ...)
getTranslations(namespace, key, locale: ...)
```

## Exact-locale semantics

Language resources are read only from:

```text
assets/<namespace>/lang/<locale>.json
```

Locked rules:

- locale lookup is exact
- default locale argument is `en_us`
- requesting `tr_tr` does not implicitly read `en_us`
- Minecraft-style `en_us` fallback may be added later as an explicit higher-level resolver policy
- missing language files return an empty language candidate list
- missing translation keys return an empty translation candidate list
- translation keys are not synthesized in this checkpoint

## Language JSON validation

The JSON document must decode to an object whose values are all strings.

Invalid cases normalize to:

```dart
MtnMinecraftInfoModLanguageException(
  MtnMinecraftInfoModLanguageError.invalidData,
)
```

This includes malformed JSON and non-string translation values.

Language maps are exposed as immutable snapshots.

Locale values are validated as lowercase Minecraft-style locale identifiers before any archive read.

## Candidate preservation

One logical lookup may have multiple results because multiple archive asset sources can contribute to the same namespace.

`MtnMinecraftInfoModTranslation` preserves:

- source
- namespace
- locale
- key
- value

No resource winner is selected.

Candidate order follows normalized asset-source discovery order, but that order is not promoted into an implicit pack-precedence rule.

## Embedded resources

Embedded Fabric/JarJar language resources reuse the existing lazy `MtnMinecraftInfoModAssetSource` archive-chain traversal.

No embedded JAR extraction is performed.

## Example

Added:

```text
minecraft_info_provider/example/mod_translations.dart
```

Usage:

```text
dart run example/mod_translations.dart <mod-jar> <namespace> <locale> [translation-key]
```

The example reports exact-locale language candidates and, when a key is supplied, every matching translation candidate with source provenance.

## Real Armor HUD validation

Input:

```text
D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

Observed language table:

```text
namespace: armor_hud
locale: en_us
language candidates: 1
entries: 11
```

Observed real entries included:

```text
armor_hud.config.title -> Armor HUD Configuration
armor_hud.config.position -> X: %s  Y: %s
armor_hud.config.visible -> HUD Visible
armor_hud.config.exclamation_marks -> Show Warning Marks
armor_hud.config.vertical -> Vertical Layout
armor_hud.config.durability_points -> Show Durability Points
armor_hud.config.reset -> Reset to Defaults
armor_hud.config.interactive.enter -> Interactive Positioning
armor_hud.config.interactive.exit -> Exit Interactive Mode
armor_hud.config.interactive.hint -> Click and drag the armor HUD to position it
armor_hud.config.interactive.dragging -> Dragging...
```

Positive translation smoke:

```text
key: armor_hud.config.title
value: Armor HUD Configuration
source: D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

## Validation

Authoritative local validation:

```text
dart analyze
No issues found!

minecraft_mod_language_translation_test.dart
8/8 passed

minecraft_mod_asset_resource_test.dart
7/7 passed

minecraft_fabric_mod_metadata_test.dart
19/19 passed

minecraft_forge_mod_metadata_test.dart
15/15 passed

minecraft_neoforge_mod_metadata_test.dart
18/18 passed

minecraft_mod_list_test.dart
10/10 passed

dart test
349/349 passed

git diff --check
PASS

git status
clean
```

## Dev.32 compatibility correction

The dev.31 checkpoint above records the behavior validated at that historical boundary. During the subsequent item-name resolution checkpoint, real-profile testing showed that the string-only language-value rule was stricter than Minecraft itself.

Current behavior from dev.32 onward:

- string translation values remain strings
- numeric and boolean JSON primitive values normalize to strings, matching Minecraft's language loader behavior
- unsupported numeric placeholders such as `%d` / `%f` normalize to `%s` while positional indexes are preserved
- object, array and null values remain invalid
- low-level `MtnMinecraftModList.readLanguages()` remains strict for invalid language tables
- high-level item-name candidate resolution may isolate one invalid source and continue with independent sources

This correction does not add locale fallback or resource precedence.

## Deliberately out of scope

- implicit locale fallback
- item ID to translation-key derivation
- block translation-key derivation
- item registry discovery
- `assets/<namespace>/items/*.json` interpretation
- legacy item model JSON parsing
- model parent inheritance
- texture reference resolution
- PNG decoding/rendering
- resource-pack precedence
- conflict winner selection

## Next intended checkpoint

The next checkpoint should connect an item identity such as:

```text
namespace:item_id
```

to an appropriate item translation key/name while preserving the same no-hidden-precedence and explicit-fallback principles.
