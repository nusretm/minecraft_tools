# Minecraft Tools — Proposed dev.27 RemVibe Batch-to-Installation Execution

Date: 2026-10-08

## Status

- Repository: `nusretm/minecraft_tools`
- Package: `minecraft_content_service 1.0.0-dev.27`
- Proposed checkpoint: **dev.27 — RemVibe Batch-to-Coordinated Installation Execution**
- Baseline main at design creation: `ec509b544dc37e155811d257b5a268a981d92273`
- Status: **IMPLEMENTED ON FEATURE BRANCH / WINDOWS DART VALIDATION PENDING / NOT MERGED**
- Branch: `feature/minecraft-content-remvibe-installation-execution`
- Implementation explicitly approved by user after clean dev.26 branch cleanup
- Focused regression tests added: 17
- Previous checkpoint: dev.26, PR #54, squash `195af95f8523edac35e02a582d2cd1c01fa211d0`, 225/225 tests
- Dev.26 branch cleanup: completed locally and remotely; user verified clean synchronized `main` at design baseline prior to dev.27 documentation commits

## Existing implemented foundations (avoid reimplementation)

1. **dev.19** `MtnMinecraftContentDownloadAdapterRemVibe.createBatch()` maps canonical `MtnMinecraftContentMaterializationPlan` download items to **one** `RemVibeDownloadJob`, retaining identity-linked `batch.items[].target` and `batch.items[].item`. Zero-download plans intentionally cannot create a job.
2. **dev.20** Integrity is enforced on RemVibe downloaded staging files through the existing validator, and is rechecked by filesystem publication as needed.
3. **dev.21** `MtnMinecraftContentDownloadExecutionRemVibe(batch).execute()` handles the actual singleton download-service lifecycle, completed/error/cancelled statuses, exact-job observation, duplicate keys and cancellation. It does not own global service shutdown.
4. **dev.22–24** Preflight, safe target publication and whole-plan file transaction exist on an explicit IO surface.
5. **dev.25–26** Strict installation-manifest persistence and `MtnMinecraftContentMaterializationFileSystemCoordinator.begin()/commit()/rollback()` now coordinate files and manifest under one in-process installation-root lease.

These primitives are already merged and tested. Do **not** add per-mod jobs, a parallel HTTP downloader or a second download manager.

## Missing gap / goal

A narrowly scoped, explicit **RemVibe + IO orchestration** layer should bridge a fully downloadable canonical materialization plan to a completed installed state:

```text
caller-owned canonical MtnMinecraftContentMaterializationPlan
             |
             v
target/installation root safety preflight
             |
             +-- plan.download.items not empty:
             |       dev.19 create ONE RemVibe batch in caller-owned staging root
             |       dev.21 execute and await exact completed job
             |       verify exact completed items + source mappings
             |
             +-- plan.download.items empty:
             |       NO RemVibe job; sources = []
             |
             v
refresh filesystem preflight AFTER any downloads
             |
             v
dev.26 coordinator.begin(preflight, canonical source mappings)
             |
             v
dev.26 coordinator.commit(combined handle)
             |
             v
SUCCESS: managed files AND installation.json finalized
```

If the transaction is still pending, or if commit is incomplete, the overall operation must **not** report success.

## Architecture / public boundary

- RemVibe-specific adapter and execution remain under `lib/src/integration/remvibe/`.
- The dev.26 coordinator remains under `lib/src/integration/io/`; do not add RemVibe imports to the generic materialization model or to the existing coordinator.
- Proposed new **combined opt-in entrypoint**: `lib/minecraft_content_service_remvibe_io.dart`, exporting the RemVibe and IO surfaces plus the new narrow orchestrator. Existing `minecraft_content_service.dart`, `minecraft_content_service_remvibe.dart`, and `minecraft_content_service_io.dart` retain existing contracts.
- Proposed public execution owner: `MtnMinecraftContentInstallationExecutionRemVibe` (name subject to implementation review). It composes the existing adapter, batch execution and IO coordinator rather than creating another generic service/registry.
- Plan, installationRoot, stagingRoot and download job identity are caller-provided or caller-selected. One execution instance runs at most once (repeated `execute()` shares its future). No first-party UI or TaskService dependency.

## Download and source ownership

- For **nonempty** `plan.download.items`, build one batch; do not enqueue individual jobs or call `downloadNow()`.
- The exact `RemVibeDownloadAdapterRemVibeBatch` created for the canonical `plan` is the identity authority. After completion require job `completed`, every exact item `completed`, and a non-null regular `item.file`; preserve exact `item.target` identity for source mapping.
- Construct `MtnMinecraftContentMaterializationFileSystemTransactionSource(target: batchItem.target, source: batchItem.item.file!)` for each canonical install/replacement target; do not reconstruct target objects or map by provider filename/URL.
- Staging root is **caller-owned**. The new checkpoint does not automatically delete/move stage files, stage directories, successful download output or unrelated RemVibe jobs. It also does not change singleton clear policy.
- Validate staging physical paths and target-policy collisions before submission: no symlink/source-path escape outside staging root, duplicate/case-folded physical output paths, or staging root overlapping the managed installation root. Recheck paths after completion. Prefer host-safe/canonical path checks; an in-process check does not guarantee safety against hostile cross-process races.
- Trust neither a status alone nor a stale preflight. The transaction authority revalidates source integrity and safe destination mapping before file mutation.
- For zero-download plans (retain/remove/no-op), skip batch adapter and RemVibe execution **without skipping dev.26 transaction**. Removal-only plans still update managed files and persisted manifest.

## Lifecycle, failures, cancellation

- States/phases should distinguish validating, downloading (optional), publishing/committing, completed, cancelled, and recovery-required without introducing TaskService lifecycle dependencies.
- Download error/cancellation: do not call dev.26 begin; preserve prior managed installation and manifest; leave staging-root cleanup to caller. Return a typed error with the original RemVibe batch/status/cause when applicable.
- Cancellation before submission stops job creation; cancellation during download delegates to existing `MtnMinecraftContentDownloadExecutionRemVibe.cancel()` and waits for it to settle.
- Cancellation after download but **before** transaction begin prevents mutation. If transaction begin has returned a pending handle, cooperative cancellation rolls back using dev.26, subject to its recovery contract.
- Once irreversible commit cleanup begins, cancellation **must not** try to roll back. Forward-only commit retry or explicit typed `commitIncomplete` recovery reporting applies.
- A stale/changed existing manifest or unsafe destination fails closed; do not silently treat a corrupt/absent manifest as an empty managed installation.
- Manifest and file recovery candidates/combined handle from a failed dev.26 transaction must remain observable to the caller. Never swallow an incomplete rollback or claim success.
- The orchestrator must not cancel unrelated RemVibe jobs or stop the global singleton.
- **Locked dev.27 decision:** installation root and (for nonempty download plans) staging root must already exist; the executor never creates the staging root and never deletes caller-owned staging outputs. Zero-download plans may omit staging root.

## Test/acceptance matrix

- Real local HTTP `HttpServer` with two or more download items -> **one** RemVibe job -> file and manifest commit; original staged files retained
- Install and replacement mapping, provider filename differing from final target filename, source size/checksum integrity
- Retain-only, removal-only and truly empty plans -> **zero** RemVibe jobs but correct dev.26 execution and manifest state
- Failed download (including retry exhaustion), cancellation before submission, cancellation during download: no managed file or manifest mutation
- Cancellation after download and before publication; cancellation during pending coordinated transaction -> rollback or explicit recovery-required state
- Existing stale/corrupt/absent manifest mismatch: reject and preserve data
- Unsafe staging root overlap, symlinked source or parent, case-insensitive duplicate paths, source aliasing managed paths: reject before installation mutation
- Missing/tampered completed staging file after transfer but before publication; failed source integrity check
- Preflight becoming stale during download; coordinator revalidates after download and before mutation
- Commit prevalidation failure; interrupted forward-only commit; inability to roll back -> typed error and recovery handle preserved
- Repeated `execute()` and `cancel()` idempotence; avoid swallowing original failure; global RemVibe singleton state and unrelated jobs unchanged
- Existing dev.19–26 focused tests unchanged; `dart analyze`, `dart test`, `git diff --check` clean; **no `dart format`**.

## Explicitly deferred

- New download manager / direct per-mod HTTP downloads
- Download staging-root garbage collection, durable resume across process restart, automatic cleanup of other owners' files
- Persistent commit journal, power-loss recovery, cross-process transaction isolation
- TaskService, MtnLauncher UI and launch lifecycle integration
- Provider resolution, file selection, dependency planner model changes, and mod resource rendering

## Next action

The design and dev.27 production implementation were explicitly approved. Next: run `dart analyze`, `dart test test/content_installation_execution_remvibe_test.dart`, previous RemVibe/IO focused tests and full `dart test` on Windows; inspect actual diff; obtain separate merge approval. No `dart format`.

## Implementation checkpoint (feature branch)

- New explicit entrypoint: `minecraft_content_service/lib/minecraft_content_service_remvibe_io.dart`.
- New owner: `MtnMinecraftContentInstallationExecutionRemVibe`, with one-shot `execute()`, `cancel()`, state, exact `batch`, and typed execution failure.
- State-specific `retryCommit()` and `retryRollback()` retain the private dev.26 coordinator authority so recovery can continue after an unsuccessful initial invocation. A successful rollback does **not** convert a failed execution into an installation success.
- Staging security checks run before download and after completion: absolute existing root, disjoint physical root, stable resolved root, no staging ancestor links, no case-folded aliases, no occupied pre-existing target and no existing temporary `.download` file.
- Uses exact canonical batch item target/source pairs, confirms completed job/item states, verifies supported checksum/size and repeats destination preflight before coordinator mutation.
- Cancellation before download or before commit rejects success; in-flight cancellation uses the existing exact RemVibe job. Cancellation is not honored once forward-only commit cleanup has begun.
- Installation roots, job service lifecycle and caller-owned staging directories remain under their existing owners; executor neither deletes successful staged files nor alters global RemVibe service configuration.
- Unit/integration tests include real local HTTP requests, two-item one-job installation, replacement, zero-download plans, retries, cancellation, symlink/case collision, manifest mismatch, stale destination and tampered output.
- **Windows tests not yet run for this feature branch.** No PR/merge until verified.
