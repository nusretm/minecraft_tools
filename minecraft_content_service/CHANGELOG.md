# Changelog

## 1.0.0-dev.28

- Strengthen in-process coordinated installation recovery and cancellation boundary validation.
- Support composition of existing policy-matched manifest filesystem and coordinated transaction authorities, retaining the same owner through recovery retries without public test-only failpoints.
- Add deterministic commit interruption and rollback interruption regression tests, including real forward-only commit retry, incomplete rollback retry, retained root lease, and restoration of prior manifest/managed-file contents.
- Validate executor retryCommit/retryRollback outcomes, cancellation while awaiting an installation-root lease, cancellation after reversible pending publication, and non-reversing cancellation at the commit boundary.
- Verify failed coordinated begin releases the root lease after successful automatic rollback; reject injected authorities using conflicting filesystem policies.
- Preserve one-job RemVibe download behavior and caller-owned staging without modifying the download service.
- This checkpoint does not add durable on-disk journaling, cross-process locking or crash/power-loss recovery.

## 1.0.0-dev.27

- Add an explicit opt-in RemVibe + IO entrypoint for complete content installation execution.
- Compose existing dev.19 one-job batch creation, dev.20 file integrity, dev.21 batch execution, and dev.26 coordinated managed-file/manifest commit.
- Skip download service entirely for retain, remove and empty plans while still committing the installation manifest.
- Reject unsafe staging roots, symlinks, case-folded path aliases, occupied outputs and staging/managed-root overlaps before transfer; validate exact completed item paths and checksums again after download.
- Refresh the destination preflight after transfer; retain source identity through canonical batch item targets.
- Preserve caller-owned staging files, existing RemVibe singleton ownership and unrelated jobs.
- Coordinate cancellation before submission, during transfer, and at the reversible publication boundary.
- Surface incomplete recovery and permit owner-held retryCommit / retryRollback without redownloading or exposing private coordinator internals.
- Add local HTTP and filesystem regression coverage for one-batch installs, replacements, zero-download transactions, failure, cancellation, staging safety and manifest consistency.
- Defer crash-durable recovery, cross-process isolation, TaskService integration and staging cleanup policy.

## 1.0.0-dev.26

- Add a single-authority coordinator for dev.24 managed-file and dev.25 manifest publication under one exclusive installation-root lease.
- Refactor internal publication entrypoints to accept only an active private root-lease capability; existing standalone public APIs keep their lock semantics.
- Compare persisted current manifest schema-v1 snapshot to the canonical plan installation state before any content mutation.
- Reject missing, corrupt, stale and externally modified current manifests; publish only the canonical resulting installation state.
- Return one combined pending handle; keep individual recoverable publication handles inaccessible to callers.
- On application failure, restore the managed-file transaction; preserve the root lease and recovery candidates if restoration is incomplete.
- Prevalidate both managed-file and manifest recovery before irreversible cleanup; enforce forward-only commit retry once cleanup starts.
- Roll back manifest first and then managed files, preserving incomplete rollback state for same-direction retries.
- Add focused coordinated install, replace, remove, empty plan, rollback, tamper, stale manifest and exclusive-lease regression tests.
- Deliberately exclude crash-durable journals, cross-process locks, RemVibe/TaskService orchestration and ACID multi-file guarantees.

## 1.0.0-dev.25

- Add explicit IO filesystem persistence for schema-v1 installation manifests while leaving the generic manifest serialization unchanged.
- Read missing manifests as null and reject corrupt, linked, ambiguous, inaccessible or non-file manifest targets without adopting unmanaged state.
- Publish manifests from flush-written, SHA-256-verified same-directory sibling staging; retain previous raw bytes in a reversible backup handle.
- Support explicit commit and rollback with backup verification, concurrency-safe finalization state and retryable incomplete states.
- Coordinate manifest read and publication with the dev.24 installation-root lease system; pending materialization transactions block manifest mutation.
- Reserve the policy-normalized .mtn-content namespace against managed artifacts during filesystem preflight.
- Add focused manifest IO, rollback, tampering, link safety, and transaction synchronization tests.
- Keep manifest+materialization cross-resource commit orchestration and process-crash durable recovery out of this checkpoint.

## 1.0.0-dev.24

- Add whole-plan reversible materialization transactions on the explicit IO surface, retaining canonical install/replace source associations independently of RemVibe.
- Publish deterministic install/replacement targets through the dev.23 single-target publication primitive.
- Derive obsolete physical removals from current minus resulting policy-normalized managed path identities, including moved replacements and path reuse.
- Stage managed removals as same-parent reversible backup renames; never delete unmanaged files.
- Add one private transaction recovery ledger with reverse-order rollback, non-destructive finalization validation, and retryable incomplete states.
- Coordinate standalone publications (shared root lease) and whole-plan transactions (exclusive root lease), preserving existing per-target publication locks.
- Capture and verify previous managed publication backups, removal backups, and retained-file integrity snapshots before finalization.
- Reject caller-owned sources aliasing any current/resulting managed artifact path; sources remain read-only and are never consumed.
- Preserve recovery candidates and report unresolved failures instead of claiming a full rollback.
- Keep manifest filesystem persistence, TaskService, RemVibe batch orchestration/cleanup, native crash recovery, and MtnLauncher integration out of scope.
- Reject simultaneous finalizations for one transaction and guard against changed or linked target-parent paths during publication finalization.
- Add focused transaction execution, rollback, tamper, and serialization regression tests.

## 1.0.0-dev.23

- Add a single-target safe publication primitive to the explicit IO integration.
- Copy caller-owned staging sources into target-parent sibling staging so publication does not depend on source and installation roots sharing a volume.
- Extract provider-neutral file integrity verification and keep the existing RemVibe integrity API as a delegating adapter.
- Revalidate canonical size/checksum metadata after the publication copy and before final promotion.
- Recheck installation-root and target snapshot state after preflight to detect stale or externally changed filesystem state.
- Create missing target-parent directories one segment at a time while rejecting changed, ambiguous, linked or non-directory ancestors.
- Serialize operations for the same policy-normalized target across filesystem authority instances.
- Publish through same-parent rename, preserving a managed previous target as a sibling backup.
- Return a reversible publication handle whose lock and recovery state remain owned until explicit commit or rollback.
- Add commit cleanup and rollback restoration without deleting the caller-owned source staging file.
- Keep whole-plan install/replace/remove orchestration, multi-artifact rollback, manifest persistence and TaskService integration out of this checkpoint.

## 1.0.0-dev.22

- Add explicit `minecraft_content_service_io.dart` filesystem integration without introducing `dart:io` into the generic package entrypoint.
- Add read-only `MtnMinecraftContentMaterializationFileSystem.preflight()` over one materialization plan and an existing absolute installation root.
- Add host-default and explicitly testable filesystem path policies with Windows/POSIX identity and configurable case sensitivity.
- Detect case-policy path collisions and file/descendant hierarchy collisions in both current and resulting managed states.
- Reject Windows-illegal target path segments before any publication attempt.
- Inspect current managed artifacts for missing retained files, wrong entity types, inaccessible paths and symbolic-link indirection.
- Reject unmanaged occupancy at resulting target paths instead of silently adopting or overwriting manual files.
- Allow an existing final path when it is owned by the current managed installation, including replacement/removal path reuse.
- Detect non-directory ancestors and ambiguous physical child identities without mutating the filesystem.
- Keep directory creation, staging publication, rename/copy/delete, replacement/removal execution, rollback and manifest filesystem persistence out of this checkpoint.

## 1.0.0-dev.21

- Add `MtnMinecraftContentDownloadExecutionRemVibe` for submitting and awaiting one integrity-aware RemVibe content batch.
- Start the application-wide RemVibe service only when it is inactive, without stopping it or changing its global clear policy.
- Fail fast on duplicate RemVibe job keys instead of allowing `addJob()` to merge an execution into an existing job.
- Require a fresh idle batch before execution and make repeated `execute()` calls share one operation future.
- Observe the exact submitted job through `RemVibeDownloadHandler` without replacing the existing job status callback.
- Complete successfully only when the exact batch job reaches `completed`.
- Convert exhausted RemVibe error state into `MtnMinecraftContentDownloadExecutionRemVibeException` while preserving item-level diagnostics on the batch.
- Add idempotent cancellation, including cancel-before-submit handling and cancellation settlement only after RemVibe removes the cancelled job.
- Keep final managed-target publication, replacement/removal execution, path-collision policy, staging cleanup policy, rollback, installation-manifest filesystem persistence and TaskService orchestration out of this checkpoint.

## 1.0.0-dev.20

- Add `MtnMinecraftContentDownloadIntegrityRemVibe` as the explicit staged-file integrity policy for RemVibe content downloads.
- Capture expected size from the canonical content file instead of relying on mutable `RemVibeDownloadItem.size`, which is updated from the actual transfer.
- Support MD5, SHA-1, SHA-256 and SHA-512 checksum validation with SHA dash aliases and lowercase digest normalization.
- Ignore unknown provider-specific checksum algorithms while failing fast on malformed metadata for supported algorithms.
- Reject conflicting aliases that declare different digests for the same canonical checksum algorithm.
- Calculate every required supported checksum in one streamed file pass.
- Attach the integrity policy to each dev.19 batch association and wire `validate()` into `RemVibeDownloadItem.validator`.
- Keep validator null when neither expected size nor a supported checksum can be verified.
- Keep service submission, transfer orchestration, publication, replacement/removal execution, rollback, manifest filesystem persistence and TaskService orchestration out of this checkpoint.

## 1.0.0-dev.19

- Add an explicit RemVibe integration library without adding RemVibe types to the generic core service API.
- Add `MtnMinecraftContentDownloadAdapterRemVibe` for mapping one complete materialization plan to one `RemVibeDownloadJob`.
- Preserve canonical content download ordering while associating every RemVibe item with its exact materialization target.
- Map resolved URL, caller-owned target basename, staging parent directory, and expected normalized file size into each `RemVibeDownloadItem`.
- Keep retain/remove actions out of the download batch.
- Reject no-download materialization plans instead of manufacturing an empty RemVibe job.
- Leave `validator` unset; integrity verification remains a later checkpoint.
- Do not start `RemVibeDownloadService` or call `addJob()`; transfer lifecycle remains executor-owned.
- Keep publication, replacement/removal execution, target-OS collision policy, manifest filesystem persistence and TaskService orchestration out of this checkpoint.

## 1.0.0-dev.18

- Add `MtnMinecraftContentInstallationManifest` as the portable persistence contract for managed installation state.
- Persist schema version, installation-root-relative path, normalized content snapshot, normalized version snapshot, and selected canonical file index for each managed artifact.
- Reconstruct the selected file by index from the decoded version so dev.16 canonical file identity is restored instead of matching by filename.
- Validate embedded version/content ownership explicitly because the generic version decoder does not consume the persisted content key itself.
- Parse schema, artifact shapes, paths and file indexes strictly rather than silently accepting malformed persisted data through fallback conversion helpers.
- Reuse dev.16 installation artifact/state invariants for path safety and duplicate version/content/path ownership checks.
- Support direct map, JSON and UTF-8 round trips without introducing `dart:io`.
- Keep the installation manifest independent from `MtnMinecraftContentList`; it is managed physical-artifact ownership persistence, not catalog/dependency-graph persistence.
- Keep filesystem read/write location, atomic file publication, discovery, download execution, verification, rollback and launcher integration out of this checkpoint.

## 1.0.0-dev.17

- Add immutable materialization targets and install/retain/replace/remove action models.
- Add `MtnMinecraftContentMaterializationPlan` and `MtnMinecraftContentService.planContentMaterialization()`.
- Require one caller-provided installation-root-relative target for every canonical download item.
- Reuse dev.16 installation-artifact path validation instead of duplicating path policy.
- Require the exact managed installation state whose installed-state view produced reconciliation.
- Preserve reconciliation categories without treating action lists as execution order.
- Derive `resultingInstallationState` in desired-state order, retaining existing artifacts and replacing/installing only the planned targets.
- Allow paths owned only by removed/replaced artifacts to be reused while rejecting collisions in the resulting managed state.
- Keep path identity OS-neutral and case-sensitive at this planning layer.
- Keep filesystem I/O, staging, verification, publication, deletion, rollback, installation-manifest persistence, target-OS collision policy, and launcher download-manager adaptation out of this checkpoint.

## 1.0.0-dev.16

- Add immutable `MtnMinecraftContentInstallationArtifact` and `MtnMinecraftContentInstallationState` as the managed physical-artifact ownership foundation.
- Bind each managed artifact to the exact canonical normalized file instance owned by its installed version.
- Store only a caller-owned installation-root-relative neutral path; do not persist or infer absolute filesystem paths.
- Reject empty, absolute, Windows-drive-prefixed, backslash-separated, traversal, empty-segment, and null-character paths.
- Reject duplicate installed version keys, duplicate logical-content ownership, and duplicate exact relative artifact paths.
- Keep relative-path collision semantics OS-neutral; target-platform case-insensitive collision policy remains a later materialization concern.
- Expose the existing `MtnMinecraftContentDependencyInstalledState` as an immutable version view without rewriting reconciliation.
- Keep filesystem discovery, path existence checks, manifest serialization, downloads, staging, verification, publication, removal execution, rollback, and materialization out of this checkpoint.

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
