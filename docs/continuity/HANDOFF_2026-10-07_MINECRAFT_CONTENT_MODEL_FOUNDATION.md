# Minecraft Tools — Minecraft Content Model Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-model-foundation
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Production HEAD before continuity closeout:
ed430670ba5b1ba4c27cb204b8aba5680a0df288
```

This checkpoint creates a new independent Pure Dart sibling package. It does not modify `minecraft_info_provider/` or `hypixel_api/`.

## Goal

Provide a reusable Minecraft content-domain model that can represent Modrinth, CurseForge and future provider metadata without coupling the generic core to one provider.

The model must be reusable for:

```text
mod
modPack
resourcePack
shaderPack
dataPack
```

and must support persistence, version/file metadata, dependencies and version-to-version ownership relations.

## Package

```text
minecraft_content_service/
├─ lib/
│  ├─ minecraft_content_service.dart
│  └─ src/model/
│     ├─ minecraft_content_models.dart
│     ├─ content_model.dart
│     ├─ content_metadata.dart
│     ├─ content.dart
│     ├─ content_version.dart
│     ├─ content_relation.dart
│     └─ content_list.dart
├─ test/content_model_test.dart
├─ pubspec.yaml
├─ analysis_options.yaml
├─ README.md
└─ CHANGELOG.md
```

Package version:

```text
1.0.0-dev.1
```

## Common base model

`MtnMinecraftContentModel` is the common model base.

Locked serialization surface:

```dart
Map<String, dynamic> toMap();

String toJson();
Uint8List encode();
```

There are no client/server serialization variants.

The base also contains the agreed reusable parsing helpers, including integer/string/bool/date/map/list/enum helpers and `enumListFromMap`.

`toString()` derives its representation from `runtimeType` and `toMap()`.

Database/sync record IDs such as `recId` and `remoteRecId` are intentionally absent.

## Content family

```text
MtnMinecraftContent
├─ MtnMinecraftContentMod
├─ MtnMinecraftContentModPack
├─ MtnMinecraftContentResourcePack
├─ MtnMinecraftContentShaderPack
└─ MtnMinecraftContentDataPack
```

Inheritance and `MtnMinecraftContentType` are both retained.

Concrete subclasses fix their own type and callers cannot create a Mod subclass with a conflicting type.

## Logical graph identity

`key` is graph/persistence identity, not a database record ID.

It exists so persisted versions, dependencies and relations can reference logical objects without recursively serializing the runtime graph.

Provider canonical IDs are separate metadata and do not replace graph keys.

## Provider metadata

A logical content/version/file can preserve multiple provider records.

```text
MtnMinecraftContentProviderMetadata
├─ provider
├─ id
└─ metadata
```

Examples:

```text
provider = modrinth
id = P7dR8mSH

provider = curseforge
id = 306612
```

Provider identity is a stable string rather than a closed enum.

Provider IDs are normalized to strings because Modrinth and CurseForge use different ID primitives.

Raw API keys, request headers and transient HTTP/rate-limit state are not model metadata.

## Content metadata

The common content surface includes:

- name / slug
- summary / description
- provider records
- authors
- categories
- links
- icon
- gallery
- license
- created / updated / released timestamps

Provider-only values that do not belong in generic fields remain inside provider metadata.

## Version model

`MtnMinecraftContentVersion` contains:

- graph key
- owning content reference
- provider records
- name
- version string
- release type
- Minecraft game versions
- mod loaders
- environment
- publication date
- changelog
- featured state
- direct state
- files
- dependency declarations

Version text stays a string. Generic SemVer behavior is not assumed.

### Version selection

```text
content.version
→ explicit version when selected
→ otherwise content.versions.last
```

Setting the explicit version back to null restores automatic/latest behavior.

## Mod loaders

`MtnMinecraftContentVersion.modLoaders` is required and non-empty.

Supported foundation enum values include:

```text
vanilla
fabric
quilt
forge
neoForge
cauldron
liteLoader
unknown
```

Locked invariants:

- duplicate loaders are rejected
- `vanilla` cannot coexist with another loader
- non-mod content versions must use exactly `[vanilla]`
- mod versions may support multiple real loaders such as Fabric + Quilt

Persistence stores enum names as strings.

## Release/environment

Release types:

```text
release
beta
alpha
```

The environment model covers the Modrinth-style client/server combinations and permits null when a provider does not expose equivalent information.

## File model

`MtnMinecraftContentFile` models the physical artifact separately from the logical version.

It can preserve:

- provider records
- filename/display name
- download URL
- size and disk size
- primary/available state
- provider file type text
- hashes
- CurseForge fingerprint
- CurseForge file modules

Hash algorithm remains a string instead of a closed enum.

A CurseForge fingerprint is not modeled as a cryptographic hash.

Modrinth files are allowed to have no provider file ID.

## Dependencies

`MtnMinecraftContentDependency` preserves both provider declaration metadata and optional resolved graph targets.

Generic dependency types:

```text
required
optional
incompatible
embedded
included
tool
```

Possible provider declaration values include:

- provider
- provider content/project ID
- provider version ID
- filename
- raw version constraint
- provider metadata

Resolved `content` / `version` references are reconstructed during graph load.

No version constraint is invented when the provider does not supply one.

## Relations

Dependency declaration and physical/ownership relation remain separate concepts.

```text
MtnMinecraftContentRelation
├─ source: MtnMinecraftContentVersion
├─ owner: MtnMinecraftContentVersion
└─ type
```

Relation types:

```text
included
embedded
```

Relations are version-to-version because ownership can change between releases.

The same source version may be related to multiple owners without duplicating the logical content/version.

## Content list authority

`MtnMinecraftContentList` owns:

```text
contents
relations
```

Its flat `versions` surface is derived from the versions owned by registered contents.

This avoids maintaining two independently mutable version registries.

The list rejects:

- duplicate content keys
- duplicate version keys
- duplicate provider canonical content identities
- duplicate provider canonical version identities within a content
- duplicate identical relations
- relations to versions outside the registered graph

## Persistence

Persistence is network-independent.

Top-level shape:

```text
schemaVersion
contents
versions
relations
```

Object references serialize as graph keys rather than recursively embedding objects.

Load order is:

```text
contents
→ versions
→ dependency target resolution
→ relations
→ explicit version selections
```

This reconstructs object identity and prevents circular JSON graphs.

Current schema version:

```text
1
```

## Validation coverage

The focused test file covers:

- common JSON serialization of enum/date/nested metadata
- concrete content type invariants
- latest-vs-explicit version selection
- non-mod vanilla-loader enforcement
- multi-loader mod versions
- one logical source version embedded by multiple owners
- full encode/decode graph round trip
- multi-provider metadata preservation
- dependency reference reconstruction
- relation reference reconstruction
- duplicate provider content identity rejection

Final local validation supplied by the user:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +7: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
ed430670ba5b1ba4c27cb204b8aba5680a0df288
```

## Not implemented yet

This checkpoint deliberately stops before provider/service behavior.

Not included:

- `MtnMinecraftContentService`
- provider registry
- provider base class
- Modrinth HTTP/API adapter
- CurseForge HTTP/API adapter
- provider search pagination
- provider rate-limit/auth behavior
- dependency constraint solver
- conflict resolution
- automatic orphan removal
- update graph reconciliation
- artifact download/materialization
- cross-provider heuristic matching
- integration with `minecraft_info_provider`

## Natural next checkpoint

The natural continuation is a small provider/service foundation:

```text
MtnMinecraftContentService
→ explicit provider registry
→ MtnMinecraftContentProvider contract
→ provider-independent request/result contracts
→ first Modrinth adapter checkpoint
```

CurseForge should follow using the same generic provider contract.

Provider-specific behavior must remain in provider subclasses.

Do not infer that two projects from different providers are the same by comparing name or slug.

A new implementation checkpoint still requires explicit user approval.

Merge also requires separate explicit approval.

## Deferred resource work

The existing Minecraft client item resource/rendering plan remains deferred:

```text
docs/continuity/PLANNED_2026-10-07_MINECRAFT_RESOURCE_ITEM_RENDERING_FOUNDATION.md
```

The new content-service package does not activate that deferred implementation.
