# Minecraft Tools — Minecraft Content Provider CurseForge Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-provider-curseforge-foundation
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Validated production HEAD:
7a504338029f58c0808190d1e43d3b9c79146526
```

Baseline:

```text
main
e1dc811ed85681f766d2711ac546b8ffa4a1b7e3
Merge pull request #31 from nusretm/feature/minecraft-content-cli-example
```

Package version: `1.0.0-dev.4`.

## Goal

Implement the second concrete remote content provider on top of the existing generic provider/service foundation while keeping authentication, endpoints, numeric wire enums and provider-specific mapping isolated from generic core.

## Public surface

- `MtnMinecraftContentProviderCurseForge`
- `MtnMinecraftContentProviderCurseForgeException`

Provider identity:

```text
curseforge
```

Provider registration remains explicit through the existing `MtnMinecraftContentProviderList` authority.

## Authentication / HTTP boundary

The provider uses the package's existing `package:http` dependency.

Constructor inputs:

- required CurseForge API key
- optional injected `http.Client`
- optional base URI

Default base URI:

```text
https://api.curseforge.com/
```

The API key is stored only in a private provider field and sent in the `x-api-key` request header. It is not serialized into models, provider metadata or exception strings.

An injected client remains caller-owned. A provider-created client is owned by the provider and can be released through `close()`.

HTTP non-success responses throw `MtnMinecraftContentProviderCurseForgeException` with URI, status code, message and response body.

## Minecraft content-class discovery

The provider does not expose CurseForge class IDs in generic core.

Before operations that require content-type mapping it reads Minecraft class/category metadata with the provider-specific Minecraft game ID and caches the resolved mapping for the provider instance.

Recognized generic content families:

- mod
- mod pack
- resource pack
- shader pack
- data pack

Unrecognized CurseForge classes remain outside the generic model instead of being guessed.

## Search

Generic operation:

```text
search(MtnMinecraftContentSearchRequest)
```

Search requires exactly one generic content type because CurseForge search is class-oriented and merging multiple provider searches would break the generic page semantics.

Current supported filters:

- query/search text
- one content type
- provider-supported Minecraft game-version request shape
- at most one loader filter
- offset
- limit

The generic 1..50 page size remains unchanged.

Provider-specific access limits are validated rather than silently producing incomplete pages.

For non-mod content, the generic model's loader invariant is authoritative: only `vanilla` is accepted. That value is treated as absence of a CurseForge loader filter, not as provider `Any`.

## Project/content read

`getContent(id)` accepts a positive numeric CurseForge project ID.

It reads both the project object and the separate description endpoint.

Canonical identity:

```text
content.key = curseforge:<projectId>
provider id = <projectId as string>
```

Normalized project metadata includes:

- name
- slug
- summary
- full description
- authors
- categories
- primary category
- website/source/issues/wiki links
- logo
- screenshots
- created/modified/released timestamps

The complete raw project map remains available in provider metadata.

## File/version loading

`getVersions(content, request)` obtains the canonical numeric CurseForge project ID from the supplied logical content object.

The file endpoint is traversed in provider pages. The implementation refuses to claim complete generic filtering if the provider reports more than the supported 10,000-result traversal boundary.

Current provider-side file filters support:

- at most one Minecraft game version
- at most one mod loader

Release-type filtering remains generic and is applied after provider file retrieval.

Canonical version/file identity:

```text
version.key = curseforge:<fileId>
version provider id = <fileId as string>
file provider id = <fileId as string>
```

Each CurseForge file is represented as one generic version containing one physical generic file.

Returned versions retain the exact caller-supplied logical `MtnMinecraftContent` instance.

The response file `modId` must equal the supplied content's canonical CurseForge project ID. A mismatch is rejected.

Versions are sorted by publication date ascending with key tie-breaking, preserving the model convention that the latest version is last.

## File metadata

Mapped metadata includes:

- file ID
- file name
- display name
- download URL when supplied
- file length
- file size on disk
- availability
- file fingerprint
- modules
- hashes

A missing CurseForge download URL remains `null`; no URL is synthesized.

Known hash enum mapping:

```text
1 -> sha1
2 -> md5
```

Unknown positive hash enum values remain open/provider-qualified instead of being misidentified as a known cryptographic algorithm.

CurseForge `fileFingerprint` and module fingerprints are not represented as cryptographic hashes.

## Dependencies

Mapped CurseForge relation types:

```text
1 EmbeddedLibrary     -> embedded
2 OptionalDependency  -> optional
3 RequiredDependency  -> required
4 Tool                -> tool
5 Incompatible        -> incompatible
6 Include             -> included
```

Dependency mod IDs are validated as positive numeric provider identities and normalized to strings.

No version constraint or resolved logical dependency target is invented.

Raw dependency metadata is retained.

## Loader mapping

Supported CurseForge filter mappings:

```text
Forge      -> 1
Cauldron   -> 2
LiteLoader -> 3
Fabric     -> 4
Quilt      -> 5
NeoForge   -> 6
```

`vanilla` is not mapped to CurseForge `Any`; those semantics are intentionally kept distinct.

For mod files returned without an explicit request filter, known loader labels in provider game-version metadata are normalized into the generic loader enum. If none can be established, the mod version uses `unknown`.

For non-mod content, version loaders remain exactly `[vanilla]`.

## Tests

CurseForge tests use `MockClient`; no real API key is required.

Focused coverage includes:

- class/category discovery
- class discovery caching
- `x-api-key` header
- search query/filter mapping
- project/content mapping
- separate description mapping
- author/category/link/logo/screenshot metadata
- file/version query filtering
- release filtering
- chronological ordering
- exact logical content object identity
- file ID preservation
- missing download URL
- SHA1/MD5 hashes
- file fingerprint
- modules
- dependency relations
- non-mod vanilla loader handling
- invalid multi-content/multi-loader/multi-version request shapes
- provider traversal limit
- invalid project IDs
- provider-specific HTTP errors
- API-key secrecy in exception text
- required non-empty API key

## Validation

Authoritative local validation supplied by the user:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +25: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
7a504338029f58c0808190d1e43d3b9c79146526
```

No live CurseForge API smoke test was recorded because an API key is intentionally not stored or introduced into repository sources.

## Deliberately not implemented

- API key persistence/configuration service
- OAuth or account authentication
- write/update operations
- retries/backoff
- rate-limit orchestration
- response caching beyond in-memory class mapping
- cross-provider aggregation/fallback
- cross-provider association/deduplication
- dependency solving
- dependency installation
- artifact download/materialization
- content-service integration with `minecraft_info_provider`

## Natural next checkpoint

A small separate continuation may extend the existing CLI example with CurseForge provider selection and an externally supplied API key, then run a real CurseForge smoke equivalent to the existing Modrinth smoke.

After both provider live paths are proven, multi-provider aggregation/fallback may be designed as a later separate checkpoint.

A new implementation checkpoint requires explicit approval. Merge of this branch also requires separate explicit approval.
