# Changelog

## 1.0.0-dev.9

- Add `MtnMinecraftContentDependencyGraph` and `MtnMinecraftContentDependencyGraphEdge` as immutable runtime resolution results.
- Add `MtnMinecraftContentService.resolveDependencyGraph()` for recursive dependency traversal from a caller-selected root version.
- Reuse existing `resolveDependencyVersion()` semantics for every graph edge instead of duplicating identity/version-selection logic.
- Traverse dependencies deterministically in depth-first declaration order.
- Collapse shared dependency nodes by canonical `version.key` while preserving every declaring edge.
- Preserve unresolved dependencies as graph edges with no target version.
- Detect direct and deep cycles, retain the cyclic edge, and stop expansion without treating cycles as errors.
- Preserve all dependency relation types as metadata only; do not introduce install/conflict policy.
- Keep `versionConstraint` interpretation, artifact selection, downloads/materialization, and cross-provider association out of this checkpoint.

## 1.0.0-dev.8

- Add immutable `MtnMinecraftContentVersionSelectionRequest` without exposing pagination as selection policy.
- Add `MtnMinecraftContentService.resolveDependencyVersion()` on top of the existing identity resolver.
- Preserve already-resolved and exact provider version identities without version-list dispatch.
- Resolve content identity first, then select the newest compatible normalized provider version using game-version, loader, and release-type filters.
- Use provider pagination only as an internal selection detail; jump to the final page when a total is known and advance page-by-page otherwise.
- Preserve content-only resolution when no compatible version exists.
- Keep `versionConstraint`, recursive dependency traversal, install/conflict policy, artifact selection, downloads, and cross-provider fallback out of this checkpoint.

## 1.0.0-dev.7

- Add exact provider version lookup through `MtnMinecraftContentProvider.getVersion()` and `MtnMinecraftContentService.getVersion()`.
- Add `MtnMinecraftContentDependencyResolution` and non-recursive `resolveDependency()` orchestration.
- Resolve exact provider version identities before content-only identities while preserving unresolved file-name/version-constraint declarations.
- Validate provider content identity when dependency declarations include a provider content ID.
- Add Modrinth exact version lookup through `/version/{id}` and CurseForge file lookup through `POST /v1/mods/files`.
- Keep recursive graph solving, version selection, artifact selection, downloads, cross-provider lookup and association out of this checkpoint.

## 1.0.0-dev.6

- Add `MtnMinecraftContentService.searchAll()` for multi-provider search across registered ready providers.
- Keep registered-but-not-ready providers out of aggregate search without unregistering them.
- Preserve provider registration order in multi-provider search results.
- Add provider identity directly to `MtnMinecraftContentSearchResult`.
- Keep pagination provider-local instead of inventing a merged total/page.
- Preserve same-name results from different providers as separate content entries; no name/slug deduplication or automatic association is performed.

## 1.0.0-dev.5

- Add provider readiness as a first-class contract independent from registration.
- Add `MtnMinecraftContentProviderNotReadyException`, `readyItems`, and ready-provider service routing.
- Allow CurseForge to stay registered without an API key and become ready when a key is configured later.
- Add provider-owned serialized request execution and observable rate-limit state.
- Track Modrinth `X-Ratelimit-Limit`, `X-Ratelimit-Remaining`, and `X-Ratelimit-Reset` response headers instead of hardcoding the published quota.
- Retry one HTTP 429 when the provider supplies a usable reset / retry duration.
- Keep CurseForge free of guessed fixed rate-limit numbers and use `Retry-After` only when returned.

## 1.0.0-dev.4

- Add authenticated `MtnMinecraftContentProviderCurseForge` foundation.
- Discover Minecraft CurseForge content classes through the categories endpoint instead of hardcoding class IDs.
- Add CurseForge v1 search, project/description and paginated file/version requests.
- Map CurseForge file IDs, hashes, fingerprints, modules and dependency relation types into the generic model.
- Preserve raw provider response maps without exposing API keys.
- Keep unsupported multi-class and multi-version-file filter shapes explicit instead of returning incorrect pagination.

## 1.0.0-dev.3

- Add read-only `MtnMinecraftContentProviderModrinth` foundation.
- Add Modrinth v2 search, project and project-version requests.
- Map Modrinth project/version/file/dependency metadata into the generic content model.
- Preserve full provider response maps alongside normalized fields.
- Require an application-specific Modrinth User-Agent.
- Keep pagination and release-type filtering compatible with the generic provider contract.

## 1.0.0-dev.2

- Add `MtnMinecraftContentProvider` base contract.
- Add explicit `MtnMinecraftContentProviderList` registry authority.
- Add `MtnMinecraftContentService` routing for registered providers.
- Add provider-independent search and version-list request/result contracts.
- Keep concrete provider HTTP/API behavior outside the generic core.

## 1.0.0-dev.1

- Add reusable Minecraft content model foundation.
- Add content specializations for mods, modpacks, resource packs, shader packs and data packs.
- Add version, file, dependency and version-to-version relation models.
- Add provider metadata preservation for multi-provider logical content.
- Add JSON/UTF-8 serialization and content-list graph restoration.
