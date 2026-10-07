# Minecraft Tools — Minecraft Content Provider / Service Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-provider-service-foundation
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Validated production HEAD:
55534a1b4979dfcbf46c715716add01c9297bd01
```

Baseline:

```text
main
0ad126e0a568bb3e6414399d87e2df58ddfc26d7
Merge pull request #28 from nusretm/feature/minecraft-content-model-foundation
```

## Purpose

Add the reusable provider/service boundary before any concrete remote provider HTTP implementation.

Public surface:

- `MtnMinecraftContentProvider`
- `MtnMinecraftContentProviderList`
- `MtnMinecraftContentService`
- `MtnMinecraftContentSearchRequest`
- `MtnMinecraftContentSearchResult`
- `MtnMinecraftContentVersionListRequest`
- `MtnMinecraftContentVersionListResult`

Package version: `1.0.0-dev.2`.

## Provider registry

`MtnMinecraftContentProviderList` is the single registry authority.

Rules:

- providers are registered explicitly
- providers do not self-register
- provider names are stable extensible strings
- empty or whitespace-padded names are rejected
- duplicate names are rejected
- registration order is preserved
- lookup contains no provider-specific cases

## Service routing

`MtnMinecraftContentService` owns one provider list and routes:

```text
search(providerName, request)
getContent(providerName, id)
getVersions(providerName, content, request)
```

Unregistered providers fail before dispatch.

Empty remote IDs passed to `getContent` are rejected.

## Version identity rule

`getVersions` receives an existing `MtnMinecraftContent` object instead of only a remote content ID.

Returned `MtnMinecraftContentVersion.content` objects must point to that same logical content instance. A provider must not create a parallel logical content merely to attach versions.

Concrete providers can resolve their native remote ID from the content provider metadata.

## Provider-independent request/result contracts

Search request:

- query
- content types
- Minecraft game versions
- mod loaders
- offset
- limit

Version-list request:

- Minecraft game versions
- mod loaders
- release types
- offset
- limit

All filter lists are immutable copies.

Common pagination contract:

```text
offset >= 0
1 <= limit <= 50
```

Search/version results expose immutable item lists, offset, limit, optional total and `hasMore`.

## Physical structure

```text
minecraft_content_service/lib/src/
├─ model/
├─ provider/
│  ├─ minecraft_content_provider.dart
│  ├─ minecraft_content_provider_list.dart
│  └─ minecraft_content_provider_models.dart
└─ service/
   └─ minecraft_content_service.dart
```

Concrete provider implementations are intentionally not mixed into this core subtree yet.

## Validation

User-supplied authoritative local validation:

```text
dart analyze
No issues found!

dart test
00:00 +12: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
55534a1b4979dfcbf46c715716add01c9297bd01
```

## Deliberately not implemented

- Modrinth provider
- CurseForge provider
- HTTP transport/endpoints
- authentication/API keys
- provider User-Agent handling
- rate-limit handling
- retry/cache/interceptors
- provider wire-model parsing
- multi-provider aggregation/fallback
- cross-provider identity matching
- dependency constraint solving
- orphan cleanup/update reconciliation
- artifact download/materialization
- `minecraft_info_provider` integration

## Natural next checkpoint

```text
MtnMinecraftContentProviderModrinth
→ HTTP/read foundation
→ search mapping
→ content/project mapping
→ version/file/dependency mapping
```

Modrinth-specific behavior must remain in the concrete provider subtree and must not leak into generic service/core.

A new implementation checkpoint requires explicit approval. Merge of this branch also requires separate explicit approval.
