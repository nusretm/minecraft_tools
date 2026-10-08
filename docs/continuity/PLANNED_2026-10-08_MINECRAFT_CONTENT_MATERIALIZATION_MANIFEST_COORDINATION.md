# Minecraft Tools — Proposed dev.26 Materialization + Manifest Coordination

Date: 2026-10-08

## Status

- Repository: `nusretm/minecraft_tools`
- Baseline: `main` at `096b328e4cfa8ea0ba4a2b62f1d3f994034803a8`
- Package: `minecraft_content_service 1.0.0-dev.26`
- Scope: **IMPLEMENTED IN FEATURE BRANCH / LOCAL DART VALIDATION PENDING / NOT MERGED**
- Feature branch: `feature/minecraft-content-materialization-manifest-coordination` (implementation explicitly approved)
- New coordinated regression test count: 16
- Last completed checkpoint: dev.25, PR #53, squash commit `76b01cc4a4f465fdd27d4960fe12683e6ee874ec`, Windows `dart analyze` clean and 209/209 tests
- Dev.25 feature branch: removed locally and remotely (user-verified PowerShell output); main clean before dev.26

## Verified current boundaries

1. Dev.24 `MtnMinecraftContentMaterializationFileSystem.beginTransaction()` accepts a safe preflight and canonical target/source mappings. It obtains an **exclusive installation-root lease**, publishes/replaces/removes managed files, then returns a pending reversible handle. `commitTransaction()` and `rollbackTransaction()` finalize and release the lease.
2. Dev.25 `MtnMinecraftContentInstallationManifestFileSystem.read()` takes a **shared root lease**; `publish()` takes an **exclusive root lease** retained by its publication handle until `commit()` or `rollback()`.
3. Manifest schema v1 is already strict; `MtnMinecraftContentInstallationManifest.fromInstallationState(...)` derives a manifest from the resulting canonical installation state.
4. Both filesystem implementations share the policy-normalized in-process `_MaterializationRootGate`. Their current public entrypoints are intentionally **not reentrant**.

## Blocking architecture issue

Calling public `beginTransaction()`, then public manifest `publish()` while the first handle remains pending will wait on an exclusive lock already held by the caller. Reversing the order deadlocks as well. Finalizing the first handle merely to release the lock before publishing the second would create a non-reversible consistency gap.

**Do not work around this by a public `skipLock` boolean or by releasing either handle early.**

## Proposed dev.26 boundary

Add a single IO-specific coordination authority and one **combined pending handle**. The authority owns one exclusive root lease for the entire operation. The existing dev.24 and dev.25 standalone public APIs remain independently valid and behavior-compatible; implementation may add narrowly scoped private, owner-checked entrypoints that accept the coordinator's lease authority, with no public lock bypass.

High-level lifecycle:

```text
caller-owned resolved download sources + canonical plan
        |
        v
exclusive shared root lease (ONE owner)
        |
        v
revalidate preflight and current persisted manifest
        |
        v
apply dev.24 reversible managed-file transaction
        |
        v
publish dev.25 reversible manifest derived from plan.resultingInstallationState
        |
        v
COMBINED PENDING HANDLE
        +-- rollback: restore manifest first, then managed files
        +-- commit: validate BOTH sets of recovery state, then forward-only cleanup
```

The combined authority must not call the public lock-acquiring variants while already holding the exclusive lease. Prefer a minimal private core to duplicated workflows. Preserve individual publication backup integrity checks, path validation, cancellation safety and authority tokens.

## Required invariants

- The current persisted manifest is read under the coordinator's exclusive root lease. `null` means truly absent, not corrupt; corrupt, unsafe, linked or ambiguous manifest entities fail closed.
- Reconcile against the **persisted current installation state**. Reject a supplied plan that does not match the currently persisted manifest; an absent manifest is only compatible with an empty managed installation state. Never silently adopt unmanaged files.
- Persist **only** `MtnMinecraftContentInstallationManifest.fromInstallationState(plan.resultingInstallationState)`; the caller cannot provide an unrelated desired manifest.
- Revalidate the canonical physical filesystem preflight, installation root and current manifest contents after acquiring the lease, before mutation.
- Source files remain caller-owned and are never consumed. The existing `.mtn-content` reserved namespace and policy-normalized path rules remain enforced.
- The coordinator owns both pending recovery handles and root lease, and returns a combined handle only when **both** reversible publications have completed.
- Failure before the commit point attempts rollback in reverse application order, manifest first then files. Never assert successful recovery when either side is incomplete; expose typed errors and recovery paths.
- Before destroying the first backup, prevalidate **both** manifest and managed file recovery state. Once any irreversible cleanup begins, the combined state is **forward-only**: retry commit, never offer rollback.
- Commit order and recoverable partial-cleanup status must be explicit; all operations remain under the same exclusive lease until terminal success. Same-direction finalization idempotent; opposite and concurrent finalization rejected.
- No mutation of the pure model/provider boundary, RemVibe job ownership, or TaskService workflow in this checkpoint.

## Proposed commit policy (requires review before implementation)

1. Prevalidate both handle types while both sets of backups still exist.
2. Cross the explicit forward-only boundary.
3. Finalize managed-file transaction first, then manifest publication, without releasing the root lease in between.
4. If cleanup fails, preserve a `commitIncomplete` state and retry **only** forward completion; do not report atomic rollback. A pending/partially finalized on-disk state may require manual intervention.

Alternative ordering (manifest first) must be evaluated against interruption semantics; the two independent primitives do **not** make two-directory changes durable/atomic across a process crash. The term *coordinated transaction* refers to in-process lock ownership and checked recovery, not database-like ACID guarantees.

## Must-test scenarios

- Success and reload from disk for initial installation, replacement, removal, and empty plan
- Manifest absent vs corrupt vs stale vs symlink; reject installation-plan mismatch
- Managed file publication error after previous mutations => entire rollback
- Manifest publication error after files applied => rollback files
- Manifest rollback failure and content rollback failure => preserve recovery; no false success
- Pre-commit tampering of either backup/retained file/manifest => refuse destructive cleanup
- Commit cleanup failure => forward-only retry, no rollback
- Combined handle authority validation, concurrent commit/rollback, idempotence
- Dev.24 and dev.25 public entrypoints block correctly while combined transaction pending
- Windows case-insensitive paths, metadata namespace, and parent symlink checks
- Full existing package regression tests; `dart analyze` and `git diff --check` clean

## Explicit exclusions

- Durable journal, power-loss recovery, cross-process locking or true multi-file ACID atomicity
- RemVibe batch execution, downloads, source staging-root ownership/cleanup
- TaskService, MtnLauncher orchestration, mod rendering
- Schema migration or backward compatibility shims

## Next action

The combined authority, one-lease ownership and forward-only commit ordering were explicitly approved and implemented on the dev.26 feature branch. Next verify Windows Dart analysis and regression results, review actual diff, and obtain separate merge approval. Respect `docs/WORKING_RULES.md`; pure Dart code must not be run through `dart format`.

## Implementation checkpoint (feature branch)

- Root ownership is represented by a private `_MaterializationCoordinatedRootLease`, which verifies the same resolved installation root and case/path policy.
- Dev.24 and dev.25 share private lease-aware core entrypoints; original public calls continue acquiring their own root lease.
- Coordinator `begin(preflight, sources)` snapshots the manifest, verifies the persisted schema-v1 current installation state, applies a reversible file transaction, rechecks the raw manifest digest and publishes the resulting manifest.
- Combined pending handle holds private sub-handles; only the coordinator can finalize. `commit()` validates both recovery states before forward-only cleanup. `rollback()` restores manifest first, then files.
- Automatic application rollback and typed incomplete-recovery handling keep the root lease held if unsafe recovery remains.
- Focused tests target initial install, replacement, removal, empty state, stale/missing/corrupt manifests, externally changed snapshots, integrity tampering and pending root leases.
- **Validation not yet run on Windows**. Before merge review: `dart analyze`, focused coordinated tests, previous transaction/manifest tests, full `dart test`, `git diff --check` and clean `git status`.
- Separate merge approval is still required. No `dart format` for pure Dart.
