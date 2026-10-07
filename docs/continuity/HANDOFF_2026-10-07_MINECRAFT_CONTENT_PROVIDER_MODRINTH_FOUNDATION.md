# Minecraft Tools — Minecraft Content Provider Modrinth Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-provider-modrinth-foundation
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Validated production HEAD:
f5003897401a6692b0fd67c1c6edace4d3fec254
```

Baseline:

```text
main
2a6c671cf15740880b581b37f2585ea951ab71a0
Merge pull request #29 from nusretm/feature/minecraft-content-provider-service-foundation
```

Package version: `1.0.0-dev.3`.

## Goal

Implement the first concrete remote content provider on top of the generic provider/service foundation without leaking Modrinth-specific API behavior into core.

## Public surface

- `MtnMinecraftContentProviderModrinth`
- `MtnMinecraftContentProviderModrinthException`

Provider identity:

```text
modrinth
```

The identity remains a string and is registered through the existing explicit provider list mechanism.

## HTTP boundary

The provider uses `package:http`.

Constructor inputs:

- required application `userAgent`
- optional injected `http.Client`
- optional base URI

Default base URI:

```text
https://api.modrinth.com/v2/
```

A blank/whitespace-only User-Agent is rejected.

Every request sends:

```text
Accept: application/json
User-Agent: <caller supplied value>
```

An injected client remains caller-owned. A provider-created client is owned by the provider and is closed by `close()`.

HTTP non-success responses throw `MtnMinecraftContentProviderModrinthException` with URI, status code, message and response body.

## Search

Generic operation:

```text
search(MtnMinecraftContentSearchRequest)
```

Mapped request fields:

- query
- content types
- Minecraft game versions
- mod loaders
- offset
- limit

Search facet mapping stays inside the Modrinth mapper.

Content type mapping:

```text
mod          -> project_type:mod
modPack      -> project_type:modpack
resourcePack -> project_type:resourcepack
shaderPack   -> project_type:shader
dataPack     -> all_project_types:datapack
```

Game versions map to `versions:<version>` facets.

Loaders map to Modrinth category facets.

The generic provider contract remains capped at 50 items per page; it was not widened specifically for Modrinth.

Search results produce partial generic content objects while preserving the complete search hit in provider metadata.

## Project/content mapping

`getContent(id)` accepts a Modrinth project ID or slug and reads the full project object.

Canonical graph identity:

```text
content.key = modrinth:<projectId>
```

Canonical provider metadata:

```text
provider = modrinth
id       = <projectId>
metadata = <raw project map>
```

Normalized fields include:

- title/name
- slug
- summary/description
- project type
- primary/additional categories
- icon
- gallery
- license
- source/issues/wiki/Discord URLs
- donations
- published/updated/approved timestamps

The generic content model has one primary content type. Provider metadata remains the lossless home for additional Modrinth type/status/counter/environment fields that are not first-class generic fields.

## Version mapping

`getVersions(content, request)` resolves the canonical Modrinth project ID from the supplied logical content's provider metadata.

Provider-side query filtering is used for:

- loaders
- game versions

`include_changelog=true` is requested.

Generic release-type filtering is applied after mapping because it is part of the generic request surface.

Mapped version identity:

```text
version.key = modrinth:<versionId>
provider id = <versionId>
```

Returned versions use the exact caller-supplied `MtnMinecraftContent` object.

The version response `project_id` must equal that content's canonical Modrinth project ID. A mismatch is rejected rather than creating or attaching to another logical graph node.

Mapped version fields include:

- name / version number
- release / beta / alpha
- game versions
- loaders
- environment
- publication date
- changelog
- featured flag
- files
- dependencies

Version lists are sorted deterministically by publication date ascending. This preserves the existing content-model convention that latest is the last registered version.

Generic offset/limit pagination is then applied to the mapped/filter result.

## Files

Modrinth files map to `MtnMinecraftContentFile`.

Rules:

- filename is required from provider data
- URL/size/primary/file-type are normalized
- all returned hashes are preserved as generic hash algorithm/value pairs
- no provider file ID is invented because Modrinth version files do not expose an independent file ID
- raw file metadata is preserved
- if no returned file is marked primary, the first file becomes primary

## Dependencies

Supported Modrinth dependency types map as:

```text
required     -> required
optional     -> optional
incompatible -> incompatible
embedded     -> embedded
```

Dependency project ID, version ID and filename are preserved.

No version constraint is synthesized when Modrinth did not provide one.

Raw dependency metadata is preserved.

## Loader mapping

Known mappings include:

```text
minecraft  -> vanilla
fabric     -> fabric
quilt      -> quilt
forge      -> forge
neoforge   -> neoForge
cauldron   -> cauldron
liteloader -> liteLoader
other      -> unknown
```

For non-mod content, the generic model invariant remains `[vanilla]`.

For mod content, unknown future provider loaders remain representable as `unknown` while the raw provider loader list remains available in metadata.

## Tests

Focused Modrinth tests use `MockClient`; they do not depend on live network availability.

Coverage includes:

- User-Agent header
- search URL/query/facet generation
- search hit mapping
- raw search metadata preservation
- full project mapping
- categories/links/gallery/license mapping
- version query filters
- release-type filtering
- chronological version ordering
- logical content object identity
- version project-ID validation path in production code
- files and hashes
- primary-file inference
- dependency mapping
- absent Modrinth file ID behavior
- provider-specific HTTP error
- required User-Agent validation

## Validation

Authoritative local validation supplied by the user:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +17: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
f5003897401a6692b0fd67c1c6edace4d3fec254
```

No separate live Modrinth network smoke test was required or recorded for this checkpoint.

## Deliberately not implemented

- Modrinth authentication/token flows
- write/update operations
- rate-limit orchestration
- automatic retries/backoff
- caching
- bulk project/version endpoints
- team/member hydration into full author lists
- organization hydration
- multi-provider aggregation/fallback
- cross-provider association
- dependency constraint solving
- automatic dependency installation
- artifact download/materialization
- CurseForge provider
- `minecraft_info_provider` integration

## Natural next checkpoint

```text
MtnMinecraftContentProviderCurseForge
→ API-key HTTP/read foundation
→ search mapping
→ project/mod mapping
→ file/version/dependency mapping
```

CurseForge-specific wire enums, IDs, authentication and response mapping must stay in its concrete provider subtree.

No cross-provider match may be inferred from name/slug alone.

A new implementation checkpoint requires explicit approval. Merge of this branch also requires separate explicit approval.
