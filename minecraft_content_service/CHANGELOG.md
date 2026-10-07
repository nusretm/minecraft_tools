# Changelog

## 1.0.0-dev.15

- Add immutable batch-oriented `MtnMinecraftContentDownloadPlan` and `MtnMinecraftContentDownloadItem`.
- Add source-resolution issue specializations for invalid URLs, missing/ambiguous provider identity, unregistered/not-ready providers, unavailable sources, and provider resolution failures.
- Add `MtnMinecraftContentService.planSelectedFileDownloads()` over a successful file-selection plan.
- Reuse normalized direct download URLs without provider lookup and resolve missing URLs through the registered provider abstraction.
- Add provider-owned `resolveDownloadSource(version, file)` with a neutral nullable `Uri` result.
- Add CurseForge download-source resolution through its project/file download-URL endpoint while keeping project/file IDs, API headers, and endpoint behavior provider-specific.
- Preserve dev.14 selection ordering in the resulting batch and aggregate all source-resolution blockers before download execution.
- Make any source-resolution issue block the complete plan through `downloadable == false`.
- Keep file name, size, hashes, and provider metadata reachable through the original selection/file instead of duplicating them into download items.
- Keep byte transfer, launcher `DownloadList` / `DownloadManager` types, concurrency, retry, progress, cancellation, target paths, verification, publication, replacement/removal execution, and materialization out of this checkpoint.

## 1.0.0-dev.14

- Add immutable `MtnMinecraftContentFileSelection` and `MtnMinecraftContentFileSelectionPlan`.
- Add the `MtnMinecraftContentFileSelectionIssue` family with no-files, ambiguous, and unavailable specializations.
- Add `MtnMinecraftContentService.selectReconciliationFiles()` as a synchronous, provider-independent, network-free, filesystem-free selection layer over reconciliation output.
- Evaluate only install and replacement desired targets; retained and removed versions do not require new-file selection.
- Preserve complete desired-state ordering when install and replacement targets are interleaved.
- Select the sole file when exactly one candidate exists, regardless of its primary flag.
- For multiple files, require exactly one primary file and report ambiguity when zero or multiple primary files exist.
- Treat only `available == false` as unavailable; null availability remains selectable.
- Do not fall back from an unavailable selected primary file to a non-primary alternative.
- Keep null download URLs, missing hashes, unknown sizes, provider metadata, and raw file type outside generic selection policy.
- Keep provider-specific file normalization in provider mappers rather than adding provider switches to core.
- Keep removal-file lookup, installed artifact persistence, download-source resolution, downloads, filesystem paths, verification, execution ordering, rollback, and materialization out of this checkpoint.

## 1.0.0-dev.13

- Add immutable `MtnMinecraftContentDependencyInstalledState` for service-managed current versions.
- Reject duplicate installed `version.key` identities and multiple installed versions of the same logical `content.key`.
- Add `MtnMinecraftContentDependencyReconciliationReplacement` and immutable `MtnMinecraftContentDependencyReconciliationPlan`.
- Add `MtnMinecraftContentService.reconcileDependencyState()` as a synchronous, provider-independent, network-free, filesystem-free reconciliation layer.
- Classify desired/current differences as install, retain, replace, and remove without performing filesystem actions.
- Match current and desired state by logical `content.key`; retain only exact matching `version.key`, otherwise replace.
- Treat both upgrades and downgrades as neutral replacements without generic version-string ordering.
- Preserve desired ownership/direct metadata on install/retain/replace results while ignoring mutable current `version.direct` as reconciliation authority.
- Reject reconciliation when the desired state is not installable.
- Reject cross-state graph corruption where the same global `version.key` identifies different logical content.
- Preserve deterministic desired order for install/retain/replace classifications and current order for removals.
- Support empty current state and empty desired state, including full managed-content removal.
- Keep `MtnMinecraftContentList` schema adaptation, filesystem discovery, unknown/manual file cleanup, artifact/file selection, downloads, execution ordering, rollback, and materialization out of this checkpoint.

## 1.0.0-dev.12

- Add immutable `MtnMinecraftContentDependencyDesiredVersion` and `MtnMinecraftContentDependencyDesiredState`.
- Add `MtnMinecraftContentService.composeDependencyInstallPlans()` for deterministic instance-wide composition of multiple direct/root install plans.
- Canonicalize desired versions by first-seen `version.key` while preserving install-plan input order.
- Track immutable root ownership for every desired version and derive direct status from root identity without mutating `MtnMinecraftContentVersion.direct`.
- Promote a dependency to direct state when the same canonical version is also supplied as an install-plan root.
- Reject duplicate install plans for the same root version key.
- Preserve invalid/root-local plan blockers in their source plans while keeping desired-state conflicts focused on cross-root interactions.
- Add cross-root multiple-version conflict detection without automatic winner selection.
- Add cross-root exact-version and content-level incompatibility evaluation by reusing the shared install conflict evaluator.
- Refactor install-plan conflict evaluation into one internal evaluator shared by single-root planning and multi-root desired-state composition.
- Support an empty desired state for future full managed-content removal/reconciliation scenarios.
- Keep installed/current instance state, uninstall/disable actions, reconciliation, version-constraint evaluation, artifact/file selection, downloads, and materialization out of this checkpoint.

## 1.0.0-dev.11

- Add immutable `MtnMinecraftContentDependencyInstallRequest` and `MtnMinecraftContentDependencyInstallPlan`.
- Add `MtnMinecraftContentService.planDependencyInstall()` as a synchronous, provider-independent, network-free policy layer over a resolved dependency graph.
- Traverse only install-reachable `required` and `embeddedLibrary` branches, plus explicitly selected optional version keys.
- Keep `bundled`, `tool`, and `incompatible` edges out of install traversal while preserving their active-source classifications.
- Treat unresolved required / embedded-library edges as blocking install-plan failures.
- Reject optional selection keys that are not resolved optional graph targets and prevent nested optional selections from bypassing inactive parents.
- Add blocking multiple-version conflicts when more than one version of the same logical content is install-reachable.
- Add blocking active-source incompatibility conflicts with exact-version and content-level matching semantics.
- Keep unresolved incompatibility non-blocking and do not narrow content-level incompatibility to the graph-selected target version.
- Keep graph cycles non-conflicting, deduplicate install versions by `version.key`, and avoid mutating graph/content/version/direct state.
- Keep version-constraint interpretation, installed-state reconciliation, automatic conflict winner selection, artifact/file selection, downloads, and materialization out of this checkpoint.

## 1.0.0-dev.10

- Replace ambiguous generic dependency types `embedded` / `included` with semantic `embeddedLibrary` / `bundled`.
- Normalize Modrinth `embedded` dependencies to generic `bundled`.
- Normalize CurseForge relation type 1 (`EmbeddedLibrary`) to `embeddedLibrary` and relation type 6 (`Include`) to `bundled`.
- Preserve `required`, `optional`, `incompatible`, and `tool` semantics unchanged.
- Keep persisted `MtnMinecraftContentRelationType.included/embedded` unchanged; runtime dependency semantics and persisted relations remain separate concepts.
- Keep install policy, conflict resolution, version-constraint interpretation, artifact selection, and materialization out of this checkpoint.

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
