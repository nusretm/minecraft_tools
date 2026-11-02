# PRIVATE-1 — Minecraft Content Service .mtn layout migration

Date: 2026-11-02
Repository: nusretm/minecraft_tools
Branch: feature/content-private-layout-migration
Related launcher: nusretm/mtn_launcher_app PR #65, stacked on Draft PR #64
Status: architecture and migration contract only; runtime migration/code NOT implemented yet.

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
