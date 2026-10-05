# Minecraft Tools — Current Target

Last updated: 2026-10-05

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Current package: `minecraft_info_provider/`
- `hypixel_api/` is unrelated and must not be modified for these checkpoints.
- `docs/WORKING_RULES.md` is authoritative.

## Completed checkpoint

Minecraft Text / Item Display Properties Foundation.

Feature branch:

```text
feature/minecraft-text-item-display-foundation
```

Implementation HEAD before finalization:

```text
a6e8e6fa91b2c923eb4d53c6e7d618dcbd5010c1
```

Feature branch base:

```text
main
0e6ae8b9250f4207dbeed431c356380709204506
Add Minecraft item core properties
```

Package version:

```text
1.0.0-dev.15
```

Checkpoint state:

```text
IMPLEMENTED / AUTOMATED VALIDATED / READY FOR SQUASH MERGE
```

## Global Minecraft text core

Public text API:

```text
MtnMinecraftText
MtnMinecraftTextItem
MtnMinecraftTextStyle
MtnMinecraftTextColor
MtnMinecraftTextColorType
MtnMinecraftTextFormat
```

`MtnMinecraftText.text` is the authoritative mutable source. `plainText`,
`items`, `toJson()` and `toNbt()` derive from the current text/semantic
state.

The setter is state-aware:

```text
same text assigned
  -> semantic metadata retained

different text assigned
  -> imported semantic metadata invalidated
  -> subsequent items/serialization derive from the new text
```

## Text rendering model

`items` exposes immutable render-ready spans split only when effective style
or semantic component identity changes.

Supported style state:

```text
named color
RGB color
bold
italic
underlined
strikethrough
obfuscated
reset
```

Classic section-sign parsing supports named colors and Java RGB sequences.
Malformed RGB/unknown formatting is preserved literally instead of being
partially consumed.

Color semantics distinguish named colors from arbitrary RGB even when the
rendered RGB value is identical.

## JSON / NBT Text Components

Supported conversion APIs:

```dart
MtnMinecraftText.fromJson(...)
MtnMinecraftText.fromNbt(...)
text.toJson()
text.toNbt()
```

The provider accepts:

```text
JSON Text Component sources
1.20.5-era NBT TAG_String containing JSON text
direct inline NBT Text Component values
```

Serialization is generated from the current semantic/text state. The original
input document is not retained as a second authority.

## Translate semantics

Translated components preserve:

```text
translate
fallback
with
```

Public item fields:

```text
MtnMinecraftTextItem.translate
MtnMinecraftTextItem.translateFallback
MtnMinecraftTextItem.translateWith
MtnMinecraftTextItem.isTranslated
```

`translateWith` is an immutable snapshot. Nested translation arguments remain
`MtnMinecraftText` values and explicit inherited-style overrides survive
round-trip serialization.

Visible fallback behavior:

```text
translate with fallback
  -> item.text/plainText uses fallback

translate without fallback
  -> item.text/plainText uses translation key as a safe unresolved fallback
```

This does not claim that a locale-specific translation has been resolved.

## Other dynamic component types

The provider deliberately does not implement runtime resolution for:

```text
keybind
selector
nbt
unresolved score
```

These require client/server/world/command context and are not converted into
fake visible values.

Current behavior:

```text
keybind / selector / nbt
  -> no fabricated plainText

score without explicit value
  -> no fabricated plainText

score with explicit string value
  -> value may be exposed as visible text

extra children
  -> still parsed normally
```

Runtime resolver machinery remains outside this foundation.

## Server status integration

`MtnMinecraftInfoServerStatus.motd` is now:

```dart
MtnMinecraftText?
```

Modern status description JSON is parsed through the shared text component
codec. Legacy ping MOTDs use the same text model from their section-sign source.

`MtnMinecraftInfoServerStatus.toMap()` intentionally keeps:

```text
motd -> motd.plainText
```

so the existing plain output surface remains simple.

## Item display text integration

`MtnMinecraftInfoItemStackComponents` now includes:

```dart
MtnMinecraftText? customName
MtnMinecraftText? itemName
List<MtnMinecraftText>? lore
```

Legacy normalization:

```text
tag.display.Name -> customName
tag.display.Lore -> lore
```

Modern normalization:

```text
minecraft:custom_name -> customName
minecraft:item_name   -> itemName
minecraft:lore        -> lore
```

Modern `components` remains authoritative over legacy `tag`.

Lore semantics:

```text
property absent
  -> lore == null

property explicitly empty
  -> immutable empty list
```

Recognized display component conflicts with explicit modern removals remain
invalid data. Unknown modern components remain tolerated.

## Validation

Authoritative local validation after the final behavior changes:

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

## Locked decisions

- `MtnMinecraftText.text` remains the canonical mutable authority.
- Original JSON/NBT source is not cached as a parallel authority.
- Text items remain render-ready spans rather than a full Minecraft runtime
  component evaluator.
- `translate` metadata is preserved because it is useful for persisted text
  and serialization.
- `keybind`, `selector`, `nbt` and unresolved `score` are not resolved by
  this provider.
- Item display properties reuse the global text model; item parsing does not
  own a second text-component implementation.
- Server MOTD and item display text share the same text core.
- Backward-compatibility shims are not added before the first release unless
  explicitly approved.

## Explicitly deferred

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
- custom model data
- attribute modifiers
- potion-specific properties
- nested containers / bundle-like contents
- custom data
- item writing
- player active effects
- singleplayer player identity / UUID relationship
- installed-content discovery

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- keep checkpoints small and independently reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- use `dart analyze`, `dart test`, `git diff --check`, `git status`
- keep `.dart_tool/` and library `pubspec.lock` ignored
- architecture/naming/dependency boundaries are acceptance criteria
- do not modify `hypixel_api/` for this work
- do not add backward compatibility unless explicitly approved

## Next action

After this checkpoint is squash-merged into `main`, continue in a new chat.

The next checkpoint has not been selected yet. Start by auditing the remaining
Minecraft information-provider gaps and choose one small foundation before any
implementation.
