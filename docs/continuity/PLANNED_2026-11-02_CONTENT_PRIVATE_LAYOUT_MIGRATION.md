# PRIVATE-1 — Minecraft Content Service .mtn layout migration

Date: 2026-11-02
Repository: nusretm/minecraft_tools
Branch: feature/content-private-layout-migration
Related launcher: nusretm/mtn_launcher_app PR #65, stacked on Draft PR #64
Status: PRIVATE-1A read-only dual-layout inspection verified on Windows; PRIVATE-1B planner defined below, implementation requires explicit approval. Physical migration/write switch NOT implemented.

## Goal and boundary

Consolidate legacy Game Package folders into one .mtn namespace. Content Service exclusively owns content/disabled; Launcher exclusively owns chat. The migration must not touch logs/, saves/, screenshots/, mods/ other than already-manifest-managed enabled/disabled content.

Game Package:
  .mtn/
    content/installation.json             # Content Service
    disabled/mods/..., resourcepacks/..., shaderpacks/...
    chat/                                 # Launcher: NOT Content Service's responsibility

Legacy Content Service:
  .mtn-content/installation.json
  .mtn-disabled/mods/..., resourcepacks/..., shaderpacks/...

## Source investigation

- MtnMinecraftContentInstallationManifestFileSystem (minecraft_content_service/lib/src/integration/io/minecraft_content_installation_manifest_file_system.dart) uses manifestDirectoryName='.mtn-content'; its _inspectLocation checks directory and manifest target type and uses coordinated shared/exclusive root lease.
- MtnMinecraftContentInstallationActivationFileSystem (minecraft_content_service/lib/src/integration/io/minecraft_content_installation_activation_file_system.dart) uses inactiveDirectoryName='.mtn-disabled'; synchronize() converts artifact.relativePath and physically moves managed files, then publishes a new manifest under the root lease.
- MtnMinecraftContentMaterializationFileSystem (minecraft_content_service/lib/src/integration/io/minecraft_content_materialization_file_system.dart) reserves `.mtn-content` in _validateStatePaths. The new policy must reserve `.mtn/content` for the manifest; allow `.mtn/disabled` ONLY for Content Service managed inactive files; reject other `.mtn` artifact targets including `.mtn/chat`.
- MtnMinecraftContentInstallationManifest.toMap encodes each artifact.relativePath. A physical directory rename with no manifest transformation leaves broken managed paths. Runtime migration is NOT possible from the Launcher alone.
- Coordination and publication already exist and must be reused. Do not duplicate low-level path-validation, file-integrity, lock or transaction mechanisms. Existing tests: content_installation_manifest_file_system_test.dart, content_installation_activation_file_system_test.dart and content_materialization_file_system_*_test.dart.

## Proposed migration API and lifecycle

1. Add a Content Service private-layout authority (names and safe resolved paths). A separate migration operation, not a property getter, handles existing installations. There must be ONE place to choose legacy/new location; never silently prefer one if both contain manifest data.
2. Read policy: modern manifest takes precedence only if no legacy conflict exists; old manifest can be read in legacy mode before migration. Missing both returns null with NO directory creation. Both populated or malformed paths are explicit errors, not silently picked.
3. Migration is invoked by the Launcher only when no game process for that package is running and with content installation/reconciliation idle. The Content Service independently acquires its coordinated exclusive root lease; callers must not mistake that lock for an OS game-running detector.
4. Preflight: resolve physical root; reject links/junctions or case-insensitive aliases in .mtn, .mtn-content and .mtn-disabled; verify manifest schema, inventory, every disabled artifact file and integrity hashes; require target absence or verified same-operation recovery marker. Any unknown or colliding contents stop migration WITHOUT deletion.
5. Plan exact relativePath rewrite of each legacy `.mtn-disabled/<kind>/<file>` to `.mtn/disabled/<kind>/<file>`; enabled artifact paths such as mods/<file> are unchanged. Reject paths not in supported manifest-owned families. Use versioned migration journal/recovery record under `.mtn` with identity of old/new manifest plus transfer progress; journal is NOT content manifest or chat data.
6. Publication: stage or move the managed disabled files on the same package filesystem, checksum each destination, publish the transformed manifest to `.mtn/content/installation.json` using coordinated/recoverable manifest operations, verify it, then finalize the journal. Preserve the only known good old manifest and disabled artifact bytes until committed and recoverable. Cleanup empty legacy directories only after verified commit; unknown files keep their directory and must not be deleted.
7. Recovery: crash/cancellation between each stage must either restore the original working installation or resume forward from a verified journal. No automatic rollback once a verified new manifest becomes the authoritative state unless reverse file moves can be fully validated. Repeated migration should be idempotent. No cross-process OS atomicity claims without proof.
8. After upgrade, new installations/publishes target .mtn/content and new disable operations target .mtn/disabled. Reject unauthorized materialization into .mtn/content, .mtn/chat, or arbitrary .mtn descendants. The private Chat cache is never traversed by Content Service cleanup.

## PRIVATE-1A implementation checkpoint (2026-11-02, Windows verified)

- Added public `MtnMinecraftContentInstallationManifestFileSystem.inspectLayout(installationRoot: ...)` returning immutable `MtnMinecraftContentInstallationManifestFileSystemLayoutInspection` with kind absent/legacy/modern, optional decoded manifest, discovered physical manifest File, byte length, and SHA256. Read-only, no directory creation, move, write, or cleanup.
- Inspects both `.mtn-content/installation.json` and `.mtn/content/installation.json` under the existing materialization shared root coordinator, validates requested root remains stable, and reuses the same case-policy-aware physical-child inspection as the existing manifest filesystem. Refuses duplicate live manifests and malformed JSON without falling back.
- A single generic ancestor resolver now backs legacy and modern physical-path inspection; rejects inaccessible/ambiguous directory segments, link/file ancestors, and nonregular manifest targets. Reserved `.mtn/chat` can exist without being treated as a manifest or altered.
- The existing production `read()`, `publish()`, commit, rollback and activation paths deliberately still use `.mtn-content` / `.mtn-disabled` until PRIVATE-1B/1C are separately approved and safely implemented. Thus this is NOT a migration or a declaration that new paths are ready for production writes.
- Added 10 test scenarios in `content_installation_manifest_file_system_test.dart`: missing, legacy, modern, both conflict, malformed modern, chat-only namespace, linked parent, ambiguous Windows-case paths, linked target and blocked non-directory segments/targets. User Windows evidence: `dart analyze`: no issues, manifest test suite 27 passed, activation/preflight regression 14 passed, `git diff --check origin/main...HEAD` clean, tracked working tree clean.

## PRIVATE-1B — proposed read-only migration preflight and plan

**Gate:** production implementation has not been authorized; this section is a design for review. Preserve PRIVATE-1A's current legacy-only `read()`/`publish()` and activation behavior.

- API: `MtnMinecraftContentInstallationManifestFileSystem.planPrivateLayoutMigration(installationRoot: ...)` (name to be finalized while implementing) produces an immutable plan value with validated resolved package root, original manifest SHA256/byte count, expected target manifest data, and an ordered list of disabled-file source → destination transformations. No directory creation, moves, writes, cache changes or manifest publication.
- Precondition: inspect under Content Service's existing coordinated shared root lease; only a valid `legacy` layout with no modern manifest can produce a nonempty plan. `absent` yields a no-op classification; modern installations are already-current but any unsupported/mixed files still require explicit safety policy. Both locations occupied and invalid paths fail closed.
- Per artifact: accept only enabled `mods/<file>`, `resourcepacks/<file>` and `shaderpacks/<file>` or disabled `.mtn-disabled/<kind>/<file>` entries. Reject unknown relative paths, traversal, duplicate/case-colliding targets, unexpected .mtn roots and unsupported depths. Enabled paths are unchanged. Disabled paths rewrite to `.mtn/disabled/<kind>/<file>` in the derived manifest. Keep original version/file ownership and stored metadata.
- Validate each managed disabled source using the already-existing materialization `_inspectArtifact` and file-integrity routines. Reject links, inaccessible parents, nonregular files, missing sources, destination occupancy or case aliases, and untracked files inside legacy private directories that cannot be safely accounted for. Do not touch `.mtn/chat`. If upstream artifact checksum is unavailable, compute and record a physical SHA256 for later revalidation rather than asserting unverifiable integrity.
- The plan is a **snapshot, not an execution permit**. It carries source identities/digests and expected manifest SHA; PRIVATE-1C must acquire an exclusive root lease and repeat all relevant source/destination/manifest checks immediately before mutating anything, including no-running-game precondition enforced by the Launcher.
- Test matrix: no-op missing/current layouts, legacy manifest with zero/one/multiple disabled artifacts, exact rewrite and byte identity, missing/modified source, digest mismatch, symlink/junctions, occupied or case-alias targets, malicious manifest paths, duplicate target paths, unknown legacy occupants and concurrent manifest publication. Explicitly assert no filesystem mutation for success OR failure.

### PRIVATE-1A Windows acceptance (user evidence)

- `dart pub get` completed; `dart analyze` reported no issues.
- `dart test test/content_installation_manifest_file_system_test.dart`: 27 passed.
- `dart test test/content_installation_activation_file_system_test.dart test/content_materialization_file_system_preflight_test.dart`: 14 passed.
- `git diff --check origin/main...HEAD`: clean, `git status -sb`: feature branch up to date with origin and no local modifications.
- PRIVATE-1B remains design-only pending explicit user approval. No merge/cleanup of Draft PR #90 and no Launcher package pin update.
## Narrow implementation checkpoints (approval gates)

- PRIVATE-1A: central layout policy and **read-only** legacy/new manifest location inspection; no migration or writes. Regression tests for missing/legacy/new/both/link/case conflicts and reserved paths.
- PRIVATE-1B: coordinated migration planner/preflight with manifest path rewriting and injectable failure stages; still no physical mutation until independently tested.
- PRIVATE-1C: journaled migration execution and deterministic recovery; real on-disk tests + fault injection. Only then activate new path writes and old layout migration.
- PRIVATE-2: Launcher updates library dependency; Windows smoke against an actual existing Game Package. Draft PR #65 remains isolated from this library PR.

## Required tests

- Fresh install manifest publication, read/replace/rollback and concurrent transactions at new path.
- Existing legacy manifest and disabled mod preserved byte-for-byte, correct rewritten relativePath, reversible disable/re-enable without duplicates.
- Unexpected files/dirs in old/new roots, both manifests populated, fake case variants, unreadable folder, linked/junction parent, wrong or corrupt checksums: fail closed.
- Cancel/interrupt immediately after every source move, after target write, before and after manifest publication; recover without data loss.
- Install/reconcile while migration in progress uses the same root lock, not two independent mutation paths.
- No mutation of .mtn/chat and no non-content Game Package data changes.

## Workflow

Follow AGENTS.md and docs/WORKING_RULES.md: architecture first, narrow approved checkpoints, pure Dart no auto-format, validate with `cd D:\development\cross-platform\minecraft_tools`; `cd minecraft_content_service`; `dart pub get`; `dart analyze`; focused `dart test`; review git diff --check. Preserve user-local generated changes. Do not merge or modify Launcher dependency until user explicitly authorizes each stage.
