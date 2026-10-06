# Minecraft Info Provider — Item Name Resolution Foundation Handoff

Date: 2026-10-06

## Checkpoint

```text
Branch: feature/item-name-resolution-foundation
Package: minecraft_info_provider
Version: 1.0.0-dev.32
Status: IMPLEMENTED / VALIDATED / REAL PROFILE POSITIVE SMOKE PASSED
```

## Goal

Resolve conventional localized item-name candidates from persisted namespaced item IDs and discovered mod language resources without pretending to emulate the runtime item registry, inventing resource precedence, or guessing mod-specific description IDs.

## Public API

New public types:

```dart
MtnMinecraftInfoItemIdentity
MtnMinecraftInfoItemNameKind
MtnMinecraftInfoItemName
MtnMinecraftInfoItemNameResolver
```

The resolver is intentionally in the item layer and consumes the existing mod asset/language foundation. `MtnMinecraftModList` remains the mod/resource graph authority and does not own item-domain resolution.

## Item identity

`MtnMinecraftInfoItemIdentity.parse()` accepts a Minecraft namespaced item ID:

```text
namespace:path
```

It exposes:

```text
id
namespace
path
translationPath
itemTranslationKey
blockTranslationKey
conventionalTranslationKeys
```

Conventional derivation:

```text
example:tools/iron_hammer
-> item.example.tools.iron_hammer
-> block.example.tools.iron_hammer
```

Slash-separated registry paths become dot-separated translation-key paths.

## Candidate semantics

The resolver checks both conventional forms:

```text
item.<namespace>.<path>
block.<namespace>.<path>
```

Both may be returned.

Locked rules:

- results are candidates, not authoritative runtime registry metadata
- mods may override or dynamically derive description IDs
- item namespace does not imply authoritative language asset ownership
- all discovered language namespaces/sources may contribute a matching key
- duplicate matches from separate sources remain separate candidates
- source, language namespace, locale, key and value provenance are preserved
- locale lookup is exact and defaults to `en_us`
- no implicit locale fallback is applied
- no resource winner or pack precedence is selected
- no custom runtime description ID is guessed
- no runtime item registry is emulated
- persisted item-stack `customName` and `itemName` components remain separate from localization-derived default names

## Invalid language-source isolation

Low-level language APIs remain strict:

```text
MtnMinecraftModList.readLanguages()
invalid language source -> MtnMinecraftInfoModLanguageException
```

The item-name resolver is a multi-source candidate search. One malformed independent language source must not prevent valid candidates from other sources from being considered.

Therefore:

```text
invalid source A -> skip for this high-level resolution
valid source B   -> continue
valid source C   -> continue
```

Focused coverage verifies that `readLanguages()` still throws for the same invalid source while `MtnMinecraftInfoItemNameResolver` can recover a valid candidate from another source.

## Minecraft language compatibility corrections

Real-profile validation exposed language data that the dev.31 string-only parser rejected even though Minecraft accepts it.

From dev.32 onward:

- JSON string values remain strings
- numeric JSON primitive values normalize to strings
- boolean JSON primitive values normalize to strings
- object, array and null values remain invalid
- unsupported numeric format placeholders such as `%d`, `%.2f` and `%2$.2f` normalize to Minecraft-style `%s` / `%2$s`

The low-level language parser remains strict where Minecraft expects a primitive.

## Fabric metadata compatibility corrections

The same real 54-JAR profile exposed valid/tolerated Fabric ecosystem metadata that the local parser had been stricter about.

Observed cases:

```json
"license": ""
```

and an embedded dependency containing:

```json
"contributors": [""]
```

Current normalization:

- empty Fabric license string -> no normalized license entry
- empty Fabric author/contributor string -> ignored in the normalized generic people list
- empty string inside a license list -> ignored
- wrong field types remain invalid
- person objects still require a string `name` field
- provider-specific tolerance remains inside the Fabric provider

This allowed the real profile mod graph to complete without weakening generic core boundaries.

## Example

Added:

```text
minecraft_info_provider/example/item_names.dart
```

Usage:

```text
dart run example/item_names.dart <game-directory> <item-id> [locale]
```

The example prints the derived conventional item/block translation keys and every resolved candidate with provenance.

## Real-profile validation

Profile:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed installed content:

```text
54 direct mod JAR files
Fabric profile
Minecraft 26.1.2
```

### Negative smoke

These persisted/example item IDs were not represented by the active profile's discovered mod graph:

```text
simplyswords:diamond_greataxe
sophisticatedbackpacks:gold_backpack
```

The resolver completed without exception and returned:

```text
No conventional localized name candidate found.
```

This is the expected clean-miss behavior.

### Positive smoke

A real conventional translation entry was discovered in:

```text
verity-4.0.0.jar
```

Input:

```text
verity:flashlight
```

Observed resolution:

```text
Conventional item key: item.verity.flashlight
Conventional block key: block.verity.flashlight
name[0]: Flashlight [item]
key=item.verity.flashlight
langNamespace=verity
source=...\mods\verity-4.0.0.jar
```

This validates the complete real-profile path:

```text
game directory
-> installed mod discovery
-> provider parsing / embedded graph
-> asset-source discovery
-> language resource loading
-> conventional item-key derivation
-> localized item-name candidate
```

## Validation

Authoritative user-run implementation validation before closure metadata changes:

```text
dart analyze
No issues found!

minecraft_fabric_mod_metadata_test.dart
21/21 passed

minecraft_mod_language_translation_test.dart
9/9 passed

minecraft_item_name_resolution_test.dart
9/9 passed

dart test
361/361 passed
```

No `dart format` was run.

Final closure validation should rerun analyzer/tests plus `git diff --check` and `git status` after the dev.32/version/continuity edits.

## Deliberately out of scope

- authoritative runtime item description-ID discovery
- item registry reconstruction
- vanilla registry/default-name synthesis
- implicit locale fallback
- resource-pack precedence
- conflict winner selection
- `assets/<namespace>/items/*.json` client item definitions
- historical `models/item/<item>.json` interpretation
- model inheritance
- texture reference resolution
- PNG decoding or rendering
- mod-specific stack-state-dependent names

## Natural next layer

The natural rendering-oriented continuation is a separate item client-definition/model/texture resolution checkpoint.

It should explicitly consider version differences between modern client item definitions and historical item model layout, and must preserve the existing rule that resource precedence is not silently invented.

No next implementation checkpoint is automatically selected. Explicit user approval is still required before implementation, and merge approval remains a separate step.
