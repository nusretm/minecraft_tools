# Minecraft Tools — Planned Item Client Resource / Rendering Foundation

Date: 2026-10-07

## Status

```text
Status: DEFERRED / PLANNED
Repository: nusretm/minecraft_tools
Package: minecraft_info_provider
Implementation approval: NOT YET ACTIVE
Merge approval: NOT REQUESTED
Target execution window after prerequisite: 1-2 focused development days
```

This work is intentionally recorded now and intentionally deferred.

The next prerequisite work happens in the separate launcher project:

```text
MtnLauncher
1. Modrinth API foundation
2. CurseForge API foundation
3. launcher/UI integration that exposes the concrete need for item presentation
4. return to this Minecraft Tools resource foundation
```

The resource work described here must not be started merely because this plan exists.
A new explicit implementation approval is still required under `docs/WORKING_RULES.md`.

The purpose of this document is to preserve the full architecture and implementation plan so the work can be resumed quickly when launcher UI needs item icons/model resources.

---

## Goal

Provide a Pure Dart, version-aware Minecraft client-resource foundation that can resolve the static resource graph needed to present inventory items without turning `minecraft_info_provider` into a renderer.

Primary launcher-facing outcome:

```text
persisted / known item identity
        ↓
Minecraft-version-aware resource helper
        ↓
client item definition / item model
        ↓
normal JSON model
        ↓
parent inheritance
        ↓
texture references
        ↓
resource source stack
        ↓
raw PNG bytes + optional region / render-binding metadata
        ↓
UI decides how to decode, compose and render
```

The resource layer resolves Minecraft resources and preserves the information needed by a UI.
It does not own Flutter, `dart:ui`, GPU rendering or image decoding.

---

## Existing foundations to preserve

The current package already has:

```text
MtnMinecraftInfoModAssetSource
MtnMinecraftInfoMod.assetSources
MtnMinecraftModList.assetSources
MtnMinecraftModList.assetNamespaces
MtnMinecraftModList.getAssetSources(namespace)
MtnMinecraftInfoItemIdentity
MtnMinecraftInfoItemNameResolver
MtnMinecraftInfoItemStack
MtnMinecraftInfoItemCustomModelData
```

Existing rules that remain authoritative:

- a resource namespace is not assumed to equal a logical mod ID
- one archive can expose multiple resource namespaces
- `minecraft` namespace does not imply that the source is Vanilla
- embedded archives stay in memory and are not extracted to disk
- source provenance must be preserved
- runtime registry defaults must not be invented
- persisted item components and registry/default values remain separate concepts
- item-domain behavior must not be pushed into `MtnMinecraftModList`
- provider/loader-specific behavior belongs in its specialized class
- Pure Dart code is not auto-formatted

---

# Locked architecture

## 1. Minecraft version model

The already developed launcher version implementation will be reused under Minecraft Tools naming.

Rename:

```text
MtnLauncherGameVersion
→ MtnMinecraftVersion

MtnLauncherGameVersionType
→ MtnMinecraftVersionType
```

Behavior is preserved rather than redesigned.

Expected surface includes:

```text
parse()
raw
major
minor
build
qualifier
componentCount
type
contains(...)
compareTo(...)
<
<=
>
>=
==
!=
toString()
```

Version types remain:

```text
release
snapshot
preRelease
releaseCandidate
beta
alpha
experimental
unknown
```

Ordering remains deliberately conservative:

- numeric release versions without qualifiers support ordering
- numeric components are compared numerically
- trailing missing numeric components normalize for ordering
- snapshot/pre-release/release-candidate identities are not guessed into a total historical ordering
- unsupported ordering continues to fail explicitly rather than silently guessing

This is sufficient for the first helper ranges:

```text
Legacy:
<= 1.21.1

ItemModelComponent:
1.21.2 .. 1.21.3

Modern:
>= 1.21.4
```

---

## 2. Resource source family

A generic resource-source base is required because item resolution must eventually cross:

```text
mod JAR
Vanilla client resources
resource packs
possibly other resource-backed sources
```

Base concept:

```text
MtnMinecraftResourceSource
```

Its responsibility is storage/provenance, not Minecraft model semantics.

Conceptual surface:

```dart
abstract class MtnMinecraftResourceSource {
  List<String> get namespaces;

  bool containsNamespace(String namespace);

  Future<Uint8List?> read(
    String namespace,
    String path,
  );
}
```

The base layer owns common namespace/path validation where practical.
Storage-specific reading stays in the subclass.

The existing mod source becomes part of this family:

```text
MtnMinecraftResourceSource
└─ MtnMinecraftInfoModAssetSource
```

The existing mod-specific provenance remains on `MtnMinecraftInfoModAssetSource`:

```text
rootFile
embeddedArchivePaths
sameArchive(...)
```

Future sources:

```text
MtnMinecraftResourceSource
├─ MtnMinecraftInfoModAssetSource
├─ MtnMinecraftResourceSourceVanilla      later
└─ MtnMinecraftResourceSourcePack         later
```

Do not add source-type enums, weights, pack-format fields or other speculative metadata until a real requirement exists.

---

## 3. Resource data

Effective/candidate reads must preserve the exact source that provided the bytes.

Planned model:

```text
MtnMinecraftResourceData
    source
    namespace
    path
    bytes: Uint8List
```

Convenience information such as:

```text
assets/<namespace>/<path>
```

may be derivable from the model.

Raw `Uint8List` alone is not sufficient because it loses provenance.

---

## 4. Resource loader

The central authority is:

```text
MtnMinecraftResourceLoader
```

It owns:

```text
Minecraft environment
helper registry
resource-source stack
effective resource lookup
candidate resource lookup
item-resource dispatch
```

It must not own:

```text
mod graph semantics
Fabric metadata parsing
Forge metadata parsing
Flutter rendering
PNG decoding
runtime Minecraft registry emulation
```

The loader is intentionally not coupled directly to `MtnMinecraftModList`.

Integration occurs outside:

```dart
for (final source in modList.assetSources) {
  resourceLoader.registerSource(source);
}
```

This keeps the dependency direction clean:

```text
MtnMinecraftModList
        ↓ exposes
MtnMinecraftInfoModAssetSource
        ↓ registered by caller
MtnMinecraftResourceLoader
```

and avoids:

```text
ResourceLoader → ModList
```

---

## 5. Resource-source precedence

The loader source list is the single effective source-stack authority.

Order is:

```text
LOWEST precedence
        ↓
        ↓
HIGHEST precedence
```

Example:

```text
sources[0] Vanilla
sources[1] Mod A
sources[2] Mod B
sources[3] user resource pack
```

`read(namespace, path)` searches from highest to lowest precedence and returns the first matching resource.

`readAll(namespace, path)` preserves all candidates with provenance, preferably in highest-to-lowest precedence order.

Desired invariant when candidates exist:

```text
read(resource)
==
readAll(resource).first
```

Important rules:

- discovery order is not automatically Minecraft resource precedence
- filesystem ordering is not precedence
- mod-list ordering is not automatically precedence
- the caller constructs the effective source stack intentionally
- malformed data in an effective higher-precedence resource is not silently replaced by a lower-precedence valid resource
- missing resource may continue lookup
- corruption/parser/storage failures remain real failures unless an explicitly higher-level candidate-search API states otherwise

Minimal source-registry operations:

```text
sources
registerSource(...)
unregisterSource(...)
clearSources()
read(...)
readAll(...)
```

Do not add priority numbers or weights unless list order becomes insufficient.

---

## 6. Generic resource identity

Add:

```text
MtnMinecraftResourceLocation
```

It represents generic Minecraft identifiers:

```text
namespace:path
```

Examples:

```text
verity:flashlight
verity:item/flashlight
minecraft:item/generated
minecraft:item/handheld
```

This is not the same domain concept as:

```text
MtnMinecraftInfoItemIdentity
```

Separation:

```text
MtnMinecraftInfoItemIdentity
→ registry item identity

MtnMinecraftResourceLocation
→ generic client resource identity
```

The generic location should own namespace/path parsing, validation and `toString()`.

---

# Resource helper architecture

## 7. Base helper

The central behavior class is:

```text
MtnMinecraftResourceHelper
```

This is not merely an interface.
It must contain the common standard-Minecraft implementation.

Subclass responsibilities are restricted to real behavior differences.

Conceptual properties:

```text
loader
name
title
versionMin?
versionMax?
modLoaderTypes?
```

`modLoaderTypes == null` means loader-independent / standard Minecraft behavior.

If a non-null set is ever used, it constrains applicability to the listed:

```text
MtnMinecraftInfoModLoaderType
```

values.

A non-null empty set should be invalid because it describes a helper that can never run.

Version bounds are inclusive.

Invalid range:

```text
versionMin > versionMax
```

must fail early.

---

## 8. Helper registry

`MtnMinecraftResourceLoader` owns:

```text
List<MtnMinecraftResourceHelper> _helpers
```

Registration is explicit and deterministic.

Built-in helpers pass through the same registry mechanism as extensions.

Duplicate helper names are rejected.

The loader dispatch model is:

```text
for helper in registration order:
    if !helper.supports(environment):
        continue

    result = helper operation

    if result != null:
        return result

return null
```

Do not hardcode:

```text
if Fabric
if Forge
switch loader
switch Minecraft version
```

inside generic loader operations.

---

## 9. Built-in helper family

Initial family:

```text
MtnMinecraftResourceHelper
├─ MtnMinecraftResourceHelperLegacy
├─ MtnMinecraftResourceHelperItemModelComponent
└─ MtnMinecraftResourceHelperModern
```

Ranges:

```text
MtnMinecraftResourceHelperLegacy
versionMin: null
versionMax: 1.21.1
modLoaderTypes: null

MtnMinecraftResourceHelperItemModelComponent
versionMin: 1.21.2
versionMax: 1.21.3
modLoaderTypes: null

MtnMinecraftResourceHelperModern
versionMin: 1.21.4
versionMax: null
modLoaderTypes: null
```

Why three helpers even though the first two both use `models/item`:

```text
<= 1.21.1
render entry starts from item registry identity

1.21.2 - 1.21.3
render entry starts from effective minecraft:item_model
but still maps into models/item

>= 1.21.4
render entry starts from effective minecraft:item_model
and maps into assets/<namespace>/items/<path>.json
```

The semantic start point changed before the physical client-resource path changed.

---

## 10. Loader-specific helpers

Do not pre-create:

```text
LegacyFabric
LegacyForge
LegacyNeoForge
ModernFabric
ModernForge
ModernNeoForge
```

Most resource-pack/model behavior is standard Minecraft behavior.

Only create a specialized subclass when a real loader-specific resource behavior is observed or required.

Example future shape:

```text
MtnMinecraftResourceHelperModern
└─ MtnMinecraftResourceHelperModernNeoForge
```

or:

```text
MtnMinecraftResourceHelperLegacy
└─ MtnMinecraftResourceHelperLegacyForge
```

A subclass must override only the part that differs.

Do not copy the full base pipeline to change a few lines.

---

# Base helper method philosophy

## 11. Common behavior belongs in the base class

The base helper should own the standard Minecraft operations.

Minimal conceptual method surface:

```text
supports()
loadItem(...)
loadItemEntry(...)
loadModel(...)
loadTexture(...)
loadCustomModel(...)
```

Expected responsibilities:

### `supports()`

Common applicability:

```text
Minecraft version range
+
optional mod-loader type set
```

### `loadItem(...)`

Common high-level static item-resource pipeline.

### `loadItemEntry(...)`

Main version-period extension point.

Legacy/intermediate/modern helpers change how an item enters the client-resource graph.

### `loadModel(...)`

Common standard JSON model loading:

```text
models/<path>.json
parent traversal
inheritance
texture-reference resolution
cycle protection
cross-source lookup
```

### `loadTexture(...)`

Common direct texture resource lookup.

### `loadCustomModel(...)`

Loader/mod-specific escape hatch.
Default standard implementation may report unresolved/unsupported rather than invent behavior.

Forge/NeoForge-specific subclasses can override this later if necessary.

---

## 12. Avoid a private-helper explosion

The base class must not become:

```text
_parseModel()
_readJson()
_walkParent()
_resolveTexture()
_resolveTextureVariable()
_checkCycle()
_mergeModel()
_buildResult()
_normalizePath()
_validateFoo()
...
```

Separate a method only when:

1. it is a real domain operation, or
2. it is a real subclass override point.

Small recursion needed only inside `loadModel()` can be implemented as method-local functions rather than growing the class API with private helpers.

The goal is a readable inheritance tree with meaningful operations, not a large procedural utility class.

---

# Item resource pipeline

## 13. Request

Planned input model:

```text
MtnMinecraftResourceItemRequest
```

It should minimally represent:

```text
item identity
effective/explicit item-model identity when known
```

Do not require `MtnMinecraftInfoItemStack` as the only input.

Reason:

- the current persisted item stack does not synthesize registry defaults
- an effective `minecraft:item_model` may come from registry/default state not persisted on the stack
- resource resolution should not be hard-coupled to inventory parsing

A later convenience integration can build a request from an item stack when enough information exists.

---

## 14. Item entry

Planned normalized result of period-specific entry resolution:

```text
MtnMinecraftResourceItemEntry
```

It should preserve:

```text
source/provenance
entry/resource identity
referenced normal model or modern item-model graph
whether an entry was explicit vs conventional when that distinction matters
```

Do not turn every intermediate parsing structure into a public class unless the data is part of the real domain contract.

---

## 15. Base `loadItem()` semantics

Locked semantic statement:

> `MtnMinecraftResourceHelper.loadItem()` resolves the static client-resource graph required by an item. It does not emulate Minecraft runtime state or choose state-dependent render branches.

Conceptual pipeline:

```text
1. determine client item entry identity
2. load version-specific client entry
3. build/preserve the item-model resource graph
4. load referenced normal models
5. follow model parent inheritance
6. resolve inherited texture variables
7. locate texture resources through the loader source stack
8. preserve unresolved references instead of discarding partial success
9. return normalized static resource information
```

`null` should normally mean:

```text
this helper could not find the item's starting client-resource entry
```

A later missing parent or texture should not necessarily erase already resolved information.

Example:

```text
Verity model found
Vanilla parent source not registered
Verity texture found

→ partial resource result
→ unresolved minecraft:item/handheld parent preserved
→ not null
```

---

# Version-specific item entry behavior

## 16. Legacy: <= 1.21.1

Start from registry item ID:

```text
verity:flashlight
→ assets/verity/models/item/flashlight.json
```

No `minecraft:item_model` component is required for the entry step.

---

## 17. Item-model component transition: 1.21.2 - 1.21.3

Start from effective:

```text
minecraft:item_model
```

but the identifier still maps into:

```text
assets/<namespace>/models/item/<path>.json
```

If the effective item-model value is not known, any fallback to registry identity must be explicitly marked conventional rather than authoritative runtime registry metadata.

---

## 18. Modern: >= 1.21.4

Start from effective:

```text
minecraft:item_model
```

and read:

```text
assets/<namespace>/items/<path>.json
```

That file provides a client item-model tree that may reference normal JSON models under:

```text
assets/<namespace>/models/<path>.json
```

Do not force every modern item into one normal model.

---

# Modern item-model graph

## 19. Static graph, not runtime evaluation

The resource loader must distinguish:

```text
what resources can this item reference?
```

from:

```text
which branch should Minecraft render right now?
```

The second question belongs to a later evaluator/renderer context.

Initial modern node support should recognize and preserve at least:

```text
minecraft:model
minecraft:composite
minecraft:condition
minecraft:select
minecraft:range_dispatch
minecraft:special
minecraft:empty
```

Unknown/future valid structures must not be misrepresented as a known type.

### `minecraft:model`

Resolve referenced normal model resources.

### `minecraft:composite`

Preserve child order and resolve all child resource graphs because multiple children may render together.

### `minecraft:condition`

Preserve condition metadata and both branches.
Do not choose true/false without runtime context.

### `minecraft:select`

Preserve cases/fallback and resolve referenced static resources.
Do not choose a case without runtime context.

### `minecraft:range_dispatch`

Preserve thresholds/fallback and resolve referenced static resources.
Do not evaluate the range property inside the resource loader.

### `minecraft:special`

Preserve special renderer metadata.
Resolve any referenced standard/base model that can be resolved statically.
Do not claim to fully render special items.

### `minecraft:empty`

A valid result meaning render nothing.
It is not equivalent to a missing resource.

Modern fields such as transformations that affect later rendering must not be silently discarded merely because the first checkpoint does not render them.

---

# Normal model resolution

## 20. Model paths

Generic model ID:

```text
namespace:path
```

maps to:

```text
assets/<namespace>/models/<path>.json
```

The resolver must not force normal models to `models/item/`.

A modern item definition can reference other model paths, including block-model paths.

---

## 21. Parent inheritance

Parent inheritance belongs in the helper/model-resolution layer, not in `MtnMinecraftResourceSource`.

Conceptual resolution:

```text
child model
    ↓ parent
parent model
    ↓ parent
...
```

Requirements:

- cross-namespace parent IDs
- cross-source parent lookup through `MtnMinecraftResourceLoader`
- cycle detection
- parent properties inherited according to Minecraft semantics
- child declarations override inherited values where applicable
- provenance for actual resources remains available

Example architecture test:

```text
verity:item/flashlight
→ source: verity JAR

parent minecraft:item/handheld
→ source: Vanilla client resources

texture verity:item/flashlight
→ source: verity JAR
```

A single resource resolution must support:

```text
source A → source B → source A
```

without special-casing the `minecraft` namespace.

---

## 22. Texture references

Distinguish:

```text
texture variable name
layer0

variable reference
#layer0

concrete sprite/resource location
verity:item/flashlight
```

Examples:

```text
particle
→ #layer0
→ verity:item/flashlight

#foo
→ #bar
→ namespace:path
```

Requirements:

- inherited texture symbol maps
- child overrides
- variable-chain resolution
- variable-cycle detection
- preserve concrete resource location

Do not make a raw `#foo` reference a public abstraction unless it proves useful outside parsing/resolution.

---

# Images and textures

## 23. UI boundary

The resource layer returns raw binary image data and usage metadata.

It does not:

```text
decode PNG
create Flutter Image
use dart:ui
resize images
upload GPU textures
draw models
```

Binary image data uses:

```text
Uint8List
```

rather than generic `List<int>`.

---

## 24. Image resource vs texture binding

Do not treat every PNG as "a final icon".

Separate:

```text
MtnMinecraftResourceImage
→ the backing image resource

MtnMinecraftResourceTexture
→ how that image participates in the item/model result
```

Planned image information:

```text
MtnMinecraftResourceImage
    location
    png: Uint8List
    region?
```

Planned texture information:

```text
MtnMinecraftResourceTexture
    image
    model/render binding information
    uv? when model UV semantics are actually needed
    tintIndex? when relevant
```

Do not confuse two coordinate concepts:

```text
ImageRegion
→ pixel region inside a backing PNG/sprite sheet

UV
→ model face mapping coordinates
```

They are not the same model.

---

## 25. Multiple PNG / texture contributions

One item may need multiple image contributions.

Examples include:

```text
layer0 + layer1
composite child models
base + tintable overlay
```

The authoritative result should therefore be a texture/image collection, not a single PNG field.

A convenience getter may expose:

```dart
List<Uint8List> get pngList
```

but `pngList` is not authoritative because it loses:

```text
render/order relationship
tint index
image region
UV information
resource identity
provenance
special handling requirements
```

The UI should normally consume the richer texture/image objects.

---

## 26. Tint / mask-like behavior

Do not create a generic "mask PNG" type merely because some textures behave like masks under tinting.

A PNG remains an image resource.

Mask-like behavior is represented by the texture/model binding:

```text
image
+
tintIndex
+
later tint source/evaluation
```

This avoids incorrectly classifying normal PNG files by usage.

Tint-source evaluation itself may require later item/runtime context and is not part of the first static resource foundation.

---

# Single-frame animation policy

## 27. No animation playback in this work

Animation playback is explicitly out of scope.

Do not implement:

```text
animation timer
frametime execution
frame switching
interpolation
animation controller
runtime animation state
GPU animation
```

For an animated Minecraft texture, the resource layer represents one frame only.

---

## 28. First logical frame

When a `.png.mcmeta` animation section exists:

- identify the first logical animation frame
- if `frames` explicitly defines order, use the first logical entry/index
- if normal sequential frames apply, use frame 0
- parse only the metadata needed to identify the frame and its dimensions
- timing does not need to be executed

The static result uses:

```text
original PNG bytes
+
optional MtnMinecraftResourceImageRegion
```

Do not decode, crop and re-encode the PNG in the resource layer.

Example:

```text
16x128 PNG containing eight 16x16 frames
first logical frame = frame 3

image.png
region:
  x = 0
  y = 48
  width = 16
  height = 16
```

The UI decodes the original PNG and draws the specified pixel region.

Static PNG:

```text
region = null
```

means use the complete image.

---

# Advanced resource types deliberately deferred

The first foundation must not expand into a complete Minecraft rendering engine.

Keep the following out of the initial implementation unless required by a real test case:

```text
animation playback
atlas processing as a complete system
atlas unstitch generation
palette permutations
palette-key processing
colormap evaluation
full 3D geometry rendering
display transform evaluation
special renderer implementation
runtime condition/select/range evaluation
registry default emulation
Minecraft DataFixer behavior
Forge/NeoForge custom model loaders not yet observed as required
mod Java code execution
GPU/UI rendering
```

Important distinction:

- a PNG can be a normal sprite
- a texture can be tintable
- a PNG can participate in an atlas or palette pipeline
- a PNG can serve as lookup data
- these usages do not justify flattening all PNG resources into one "icon" concept

When an advanced format is encountered, preserve enough metadata to report/identify unresolved behavior rather than inventing a render result.

---

# Loader-specific resource behavior

## 29. Fabric / Forge / NeoForge

The helper applicability model can include:

```text
modLoaderTypes
```

but standard Minecraft behavior remains the default.

Do not create loader-specific helpers unless the resource semantics differ.

If Forge/NeoForge custom model loaders are required later:

```text
MtnMinecraftResourceHelperModern
└─ MtnMinecraftResourceHelperModernForge
```

or equivalent version-family specialization may override only the relevant extension point such as `loadCustomModel(...)`.

The generic base pipeline remains reused through inheritance.

---

# Expected future source layers

## 30. Vanilla source

A later checkpoint adds:

```text
MtnMinecraftResourceSourceVanilla
```

It can expose Vanilla client resources such as:

```text
assets/minecraft/items/...
assets/minecraft/models/...
assets/minecraft/textures/...
assets/minecraft/atlases/...
```

and any required indexed client assets through an appropriate backing layer.

Adding Vanilla must not require changing standard helper semantics.

---

## 31. Resource-pack source

A later checkpoint adds:

```text
MtnMinecraftResourceSourcePack
```

Backings can later include:

```text
directory
ZIP
```

It participates in the same loader source stack.

Resource-pack precedence belongs to source ordering, not helper logic.

---

# Real-profile acceptance target

Primary real profile:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
Fabric
Minecraft 26.1.2
54 direct mod JARs
```

Known positive item/name smoke:

```text
verity:flashlight
→ item.verity.flashlight
→ Flashlight
→ verity-4.0.0.jar
```

Desired resource smoke:

```text
verity:flashlight
        ↓
assets/verity/items/flashlight.json
        ↓
modern item-model graph
        ↓
normal Verity model
        ↓
possible minecraft:* parent through Vanilla source
        ↓
Verity texture
        ↓
raw PNG bytes
        ↓
optional single-frame image region
```

The architecture is specifically required to permit:

```text
mod source
→ Vanilla source
→ mod source
```

inside one resolution graph.

---

# Planned public concepts

Names may receive small signature-level refinement before implementation, but the architecture currently expects:

```text
MtnMinecraftVersion
MtnMinecraftVersionType

MtnMinecraftResourceSource
MtnMinecraftResourceData
MtnMinecraftResourceLoader
MtnMinecraftResourceLocation

MtnMinecraftResourceHelper
MtnMinecraftResourceHelperLegacy
MtnMinecraftResourceHelperItemModelComponent
MtnMinecraftResourceHelperModern

MtnMinecraftResourceItemRequest
MtnMinecraftResourceItemEntry

MtnMinecraftResourceModel
MtnMinecraftResourceImage
MtnMinecraftResourceImageRegion
MtnMinecraftResourceTexture
MtnMinecraftResource
```

Do not add all classes mechanically.
Before each class is introduced, re-apply `docs/WORKING_RULES.md`:

1. does an existing base already cover it?
2. is this a real domain value?
3. is this a real subclass family?
4. does it prevent actual duplication?
5. is it needed in the current checkpoint?

---

# Implementation plan

Current planning estimate:

```text
14 main steps
~72 concrete substeps
```

This is an implementation planning count, not a requirement to perform the whole job in one checkpoint.

## Step 1 — Version foundation (5)

- add `MtnMinecraftVersion`
- add `MtnMinecraftVersionType`
- preserve existing launcher implementation semantics
- add focused parsing/operator/equality coverage
- keep unsupported historical ordering explicit

## Step 2 — Generic resource source (6)

- add `MtnMinecraftResourceSource`
- centralize common namespace/path contract where appropriate
- fit `MtnMinecraftInfoModAssetSource` into the source family
- preserve root/embedded provenance
- preserve lazy archive reads
- focused source behavior tests

## Step 3 — Resource data + source precedence (7)

- add `MtnMinecraftResourceData`
- add source registry to `MtnMinecraftResourceLoader`
- register/unregister/clear
- low-to-high source ordering
- effective `read()`
- candidate-preserving `readAll()`
- precedence/provenance tests

## Step 4 — Resource helper registry (6)

- add base `MtnMinecraftResourceHelper`
- helper metadata/ranges
- optional mod-loader applicability
- helper registry in loader
- duplicate-name validation
- deterministic dispatch/support tests

## Step 5 — Resource location (4)

- add `MtnMinecraftResourceLocation`
- namespace/path parsing
- validation
- equality/string representation tests

## Step 6 — Item request / entry contracts (5)

- add item request
- distinguish registry identity from effective item-model identity
- add normalized item entry
- preserve explicit/conventional provenance where needed
- focused contract tests

## Step 7 — Version-aware built-in helpers (6)

- Legacy helper
- 1.21.2-1.21.3 item-model-component helper
- Modern helper
- correct inclusive version ranges
- standard loader-independent behavior initially
- helper selection tests

## Step 8 — Base `loadItem()` pipeline (7)

- common static graph orchestration
- period-specific `loadItemEntry()`
- referenced model loading
- parent integration
- texture integration
- partial/unresolved reference preservation
- helper-chain null/error semantics tests

## Step 9 — JSON model + parent inheritance (8)

- parse normal model JSON required for foundation
- generic model path resolution
- parent traversal
- cross-source parent lookup
- child-over-parent inheritance
- texture symbol inheritance
- parent/texture cycle protection
- focused synthetic graph tests

## Step 10 — Modern `items/*.json` model tree (5)

- parse modern client item entry
- support `minecraft:model`
- preserve static graphs for composite/condition/select/range/special/empty
- do not perform runtime branch evaluation
- preserve relevant modern transformation/state metadata

## Step 11 — Image / texture result model (4)

- add raw image model
- add texture binding model
- separate image region from model UV semantics
- expose richer texture collection plus optional `pngList` convenience

## Step 12 — PNG + single-frame `.mcmeta` support (5)

- read direct PNG bytes
- detect relevant animation metadata
- determine first logical frame
- compute optional pixel image region
- no decode/crop/re-encode or animation playback

## Step 13 — Vanilla/mod cross-source resolution (2)

- register sufficient Vanilla source backing for real parent resolution
- verify source A → source B → source A graph behavior

## Step 14 — Real-profile validation + continuity (2)

- run Verity / 26.1.2 real-profile smoke and focused/full validation
- update continuity/changelog/handoff with actual locked behavior and remaining advanced scope

Total planning count:

```text
5 + 6 + 7 + 6 + 4 + 5 + 6 + 7 + 8 + 5 + 4 + 5 + 2 + 2
= 72 substeps
```

---

# Checkpoint strategy

Do not implement all 72 substeps as one giant change.

Suggested checkpoints:

## CP1 — Resource core

```text
Steps 1-4
version
resource source
resource data/source stack
helper registry
```

No item/model/PNG implementation yet.

## CP2 — Item/model core

```text
Steps 5-9
resource location
request/entry
version helpers
base loadItem
normal model/parent/texture-reference resolution
```

## CP3 — Modern image foundation

```text
Steps 10-12
modern items/*.json tree
image/texture results
single-frame PNG metadata
```

## CP4 — Integration

```text
Steps 13-14
Vanilla/mod cross-source resolution
real profile
validation
continuity
```

Each checkpoint should remain independently reviewable.

---

# Validation rules

For implementation checkpoints:

```text
dart analyze
focused tests
dart test               # user runs local authoritative suite
git diff --check
git status
```

Pure Dart:

```text
DO NOT run dart format
```

Architecture/naming/dependency boundaries are acceptance criteria, not optional cleanup.

Do not modify:

```text
hypixel_api/
```

Merge still requires separate explicit approval.

---

# Deferred execution order

This plan is intentionally not the next active implementation task.

Authoritative order as of 2026-10-07:

```text
1. Continue launcher work.
2. Implement launcher Modrinth API foundation.
3. Implement launcher CurseForge API foundation.
4. Reach the launcher UI/presentation point where item resource rendering is needed.
5. Return to minecraft_tools.
6. Re-audit this plan against the then-current repository/Minecraft requirements.
7. Obtain explicit implementation approval.
8. Execute the resource foundation in small checkpoints, targeting a focused 1-2 day implementation window if the assumptions still hold.
```

If Minecraft/resource requirements or repository architecture change before step 5, this document is a design baseline, not permission to preserve obsolete details blindly.
