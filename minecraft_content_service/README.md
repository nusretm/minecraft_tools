# minecraft_content_service

Pure Dart Minecraft content domain and provider-service foundation for reusable catalog, version, file, dependency and ownership metadata.

The package models logical Minecraft content independently from any single provider. The same model family can represent mods, modpacks, resource packs, shader packs and data packs while preserving Modrinth, CurseForge and future provider provenance.

Current foundation includes:

- `MtnMinecraftContentModel` serialization and parsing utilities
- `MtnMinecraftContent` base class with concrete content specializations
- version, file, hash, module and dependency metadata
- flat version-to-version `included` / `embedded` relations
- multiple provider metadata records on one logical content/version/file
- JSON / UTF-8 round-trip through `MtnMinecraftContentList`
- duplicate logical provider identity protection
- version selection where `content.version` uses the explicit selection or falls back to `content.versions.last`
- `MtnMinecraftContentProvider` provider contract
- `MtnMinecraftContentProviderList` explicit provider registry authority
- `MtnMinecraftContentService` registered-provider routing
- provider-independent search and version-list request/result contracts
- `MtnMinecraftContentProviderModrinth` read-only Modrinth v2 search/project/version integration
- Modrinth project, version, file and dependency mapping with raw provider metadata preservation
- `MtnMinecraftContentProviderCurseForge` authenticated CurseForge v1 search/project/file integration
- CurseForge class discovery plus project, file/version, hash, fingerprint, module and dependency mapping
- provider readiness independent from registration, with `readyItems` exposed by the provider registry
- provider-owned serialized request gate and observable `MtnMinecraftContentProviderRateLimit` state
- Modrinth rate-limit header tracking and one bounded HTTP 429 retry when a reset duration is supplied
- CurseForge HTTP 429 / `Retry-After` handling without inventing an undocumented fixed request quota
- `MtnMinecraftContentService.searchAll()` across all currently ready registered providers
- provider-tagged per-provider search results with independent pagination
- no cross-provider name/slug deduplication or automatic association
- exact provider version lookup through `getVersion()`
- non-recursive dependency identity resolution through `resolveDependency()`
- dependency-compatible version selection through `resolveDependencyVersion()`
- immutable game-version / loader / release-type selection filters without public pagination policy
- provider/content/version identity validation without cross-provider guessing
- newest compatible normalized provider version selection while preserving content-only resolution when no match exists
- recursive dependency graph resolution through `resolveDependencyGraph()`
- immutable graph/edge results with deterministic depth-first traversal
- shared-version node collapse by `version.key`, unresolved edge preservation, and explicit cycle marking without infinite recursion
- provider-independent dependency semantics: `required`, `optional`, `incompatible`, `embeddedLibrary`, `bundled`, and `tool`
- Modrinth `embedded` dependencies normalize to `bundled`; CurseForge `EmbeddedLibrary` and `Include` remain distinct as `embeddedLibrary` and `bundled`
- pure dependency install planning through `planDependencyInstall()` without provider or filesystem access
- install-reachable traversal for required / embedded-library dependencies plus caller-selected optional versions
- explicit bundled/tool cut-off, unresolved install blockers, multiple-version conflicts, and active-source incompatibility conflicts
- immutable dependency install requests, plans, edge classifications, and conflict result models
- multi-root desired-state composition through `composeDependencyInstallPlans()`
- canonical desired versions by `version.key` with immutable direct-root ownership
- dependency-to-direct promotion without mutating `MtnMinecraftContentVersion.direct`
- cross-root multiple-version and incompatibility conflict detection while preserving root-local blockers in their source plans
- immutable managed installed-state modeling through `MtnMinecraftContentDependencyInstalledState`
- pure installed-state reconciliation through `reconcileDependencyState()`
- deterministic install / retain / replace / remove classification by logical content identity
- replacement semantics that cover both upgrades and downgrades without generic version ordering
- desired-state authority over ownership/direct metadata without mutating persisted version flags
- pure install/replace file selection through `selectReconciliationFiles()`
- deterministic single-file or unique-primary selection without provider-specific switches
- explicit no-files, ambiguous-file, and unavailable-file selection issues
- file selection independent from download URL, hash, size, filesystem path, and materialization concerns
- batch-oriented download-source planning through `planSelectedFileDownloads()`
- immutable download items that preserve the original file selection and add only the resolved source URI
- direct normalized URL reuse before any provider lookup
- provider-owned source resolution for files whose normalized download URL is absent
- CurseForge download-URL lookup without leaking CurseForge IDs, endpoints, or authentication into generic planning
- aggregate source-resolution issues with complete-plan blocking semantics through `downloadable`
- immutable managed installation artifacts that bind an installed version to its exact selected file and caller-owned relative path
- immutable managed installation state with duplicate version/content/path ownership protection
- an installation-state view over the existing dependency installed-state model for reconciliation reuse
- neutral relative-path safety validation without hardcoding `mods/`, resource-pack directories, absolute paths, or target-OS case rules
- pure materialization planning that combines reconciliation, download items, managed installation artifacts, and caller-owned final relative targets
- explicit install / retain / replace / remove materialization action families without imposing filesystem execution order
- deterministic resulting managed installation state derived in desired-state order
- final-state exact-path collision rejection while allowing paths released by replace/remove actions to be reused
- portable managed installation manifest persistence through map, JSON and UTF-8 representations
- schema-versioned artifact snapshots containing content/version metadata plus canonical selected-file index and neutral relative path
- restart-safe reconstruction of dev.16 installation state without filename guessing or filesystem access
- explicit RemVibe integration through `minecraft_content_service_remvibe.dart`
- one materialization plan to one `RemVibeDownloadJob` batch mapping
- canonical download/target association with staging-directory and caller-owned target-filename mapping
- RemVibe staged-file integrity validation for expected size plus supported MD5/SHA-1/SHA-256/SHA-512 metadata
- single-pass multi-checksum calculation before RemVibe promotes its temporary download to the staging destination
- exact-batch RemVibe execution with service-start, duplicate-key protection, terminal wait and idempotent cancellation
- explicit read-only filesystem preflight through `minecraft_content_service_io.dart`
- target-platform path identity, Windows path legality, managed/unmanaged occupancy, ancestor-type and symbolic-link checks before publication
- single-target IO publication through target-parent sibling staging, integrity revalidation, managed backup and explicit commit/rollback

Version-constraint interpretation, manifest file-location/storage policy, whole-plan publication/removal transactions and TaskService orchestration remain separate later checkpoints.


## CLI example

A small live provider search example is available at `example/mc_content.dart`.

```powershell
dart run example/mc_content.dart --provider modrinth --content mod --filter "Skyblocker" --mc-version 26.1.2 --loader fabric
```

The example currently supports the Modrinth provider and maps provider, content type, query, Minecraft version, and loader arguments into the generic content search request.
