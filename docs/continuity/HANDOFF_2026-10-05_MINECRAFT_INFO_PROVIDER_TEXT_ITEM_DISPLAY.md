# Handoff — Minecraft Info Provider Text / Item Display Foundation

Date: 2026-10-05

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` is authoritative. Do not modify `hypixel_api/`.

## Checkpoint

Minecraft Text / Item Display Properties Foundation.

Feature branch:

```text
feature/minecraft-text-item-display-foundation
```

Base:

```text
main
0e6ae8b9250f4207dbeed431c356380709204506
Add Minecraft item core properties
```

Package version finalized as:

```text
1.0.0-dev.15
```

## What was added

A global Minecraft text model shared by server status and persisted item text:

```text
MtnMinecraftText
MtnMinecraftTextItem
MtnMinecraftTextStyle
MtnMinecraftTextColor
MtnMinecraftTextColorType
MtnMinecraftTextFormat
```

The package exports the text API from
`minecraft_info_provider.dart`.

## Authoritative text state

`MtnMinecraftText.text` is the canonical mutable authority.

It is backed by a getter/setter. A real text change invalidates semantic
metadata imported from JSON/NBT. Assigning the same canonical text does not
invalidate metadata.

Derived surfaces:

```text
plainText
items
toJson()
toNbt()
toString()
```

No original JSON/NBT document is retained as a parallel source of truth.

## Color and formatting

Classic named colors and arbitrary RGB colors are supported.

Named and arbitrary RGB colors remain semantically distinct even if their
rendered RGB value matches.

Formatting supports:

```text
obfuscated
bold
strikethrough
underlined
italic
reset
```

The legacy text parser preserves malformed RGB/unknown section sequences
literally instead of partially consuming them.

`items` is immutable and segmented only when effective style or semantic
component identity changes.

## JSON and NBT conversion

Supported APIs:

```dart
MtnMinecraftText.fromJson(...)
MtnMinecraftText.fromNbt(...)
text.toJson()
text.toNbt()
```

Supported persisted representations include JSON Text Components,
1.20.5-era NBT strings containing JSON, and direct inline NBT Text Component
values.

Serialization uses the current semantic/text state.

## Translate component

Translate metadata is preserved on `MtnMinecraftTextItem`:

```text
translate
translateFallback
translateWith
isTranslated
```

`translateWith` is an immutable snapshot of nested
`MtnMinecraftText` values.

Fallback display policy:

```text
fallback present -> fallback is the visible unresolved text
fallback absent  -> translation key is the safe unresolved text
```

This is not locale resolution.

Explicit style overrides inside `with` arguments survive serialization even
when their value disables an inherited parent style.

## Other dynamic components

No runtime resolver was added for:

```text
keybind
selector
nbt
unresolved score
```

They are context-dependent and must not be exposed as if they had already been
resolved.

Current policy:

```text
keybind/selector/nbt -> no fabricated plainText
score.name           -> never used as score output
score.value          -> accepted only when explicitly stored as a string
extra children       -> still parsed normally
```

Future support should be added only if an actual information-provider feature
needs the required runtime context.

## Server integration

`MtnMinecraftInfoServerStatus.motd` changed from raw string semantics to:

```dart
MtnMinecraftText?
```

Modern JSON status descriptions and legacy section-sign MOTDs now share the
same text model.

`toMap()` intentionally exposes `motd.plainText`.

## Item display integration

`MtnMinecraftInfoItemStackComponents` now contains:

```dart
MtnMinecraftText? customName
MtnMinecraftText? itemName
List<MtnMinecraftText>? lore
```

Legacy:

```text
tag.display.Name -> customName
tag.display.Lore -> lore
```

Modern:

```text
minecraft:custom_name -> customName
minecraft:item_name   -> itemName
minecraft:lore        -> lore
```

Modern `components` remains authoritative over legacy `tag`.

Lore keeps absent vs explicitly empty semantics and is immutable.

Malformed recognized display data remains strict. Unknown components remain
tolerated. Recognized component/removal conflicts remain invalid.

## Validation

Authoritative local validation immediately before finalization metadata:

```text
dart analyze
No issues found!

dart test test/minecraft_text_test.dart
+19: All tests passed!

dart test
+176: All tests passed!

git diff --check origin/main...HEAD
PASS

git status
clean
```

No `dart format` was run.

The subsequent finalization changes are documentation/changelog/package-version
metadata only.

## Deferred text semantics

Not implemented:

```text
runtime language resolver
keybind resolver
selector evaluation
scoreboard lookup
NBT path evaluation
font
insertion
clickEvent
hoverEvent
full interactive component semantics
```

Do not expand these without a concrete information-provider requirement and
explicit user approval.

## Remaining broader provider work

Still deferred from prior checkpoints:

```text
custom model data
attribute modifiers
potion-specific properties
nested containers / bundle-like contents
custom data
item writing
player active effects
singleplayer player identity / UUID relationship
installed-content discovery
```

## Next conversation

Start from merged `main`.

Before implementation:

1. Read `docs/WORKING_RULES.md`.
2. Read `docs/continuity/CURRENT_TARGET.md`.
3. Read this handoff.
4. Verify local `main` is clean and matches `origin/main`.
5. Audit the remaining provider gaps.
6. Propose one small next checkpoint.
7. Do not implement it until the user explicitly approves.
