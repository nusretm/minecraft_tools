# Minecraft Tools — dev.28 In-Process Recovery and Cancellation Validation

Date: 2026-10-08

## Status and authority

- Repository: `nusretm/minecraft_tools`
- Package: `minecraft_content_service 1.0.0-dev.28` on feature branch; latest merged release `1.0.0-dev.27`
- Active checkpoint: **dev.28 — Installation Recovery and Cancellation Boundary Hardening**
- Main baseline at design creation: `89f93a1b4727465c6c95ee0854418a73ddef607a`
- PR #55 was squash merged at `d6adb12233dd9fc9395345f7d7bf56a6bf9cf44d`; dev.27 full Windows suite 244/244, `dart analyze` clean
- Status: **IMPLEMENTED / WINDOWS VALIDATED (257/257 TESTS) / ACTUAL-DIFF + RECOVERY AUDIT COMPLETED / NOT MERGED**
- Branch: `feature/minecraft-content-installation-recovery-hardening`
- Implementation explicitly approved by user after verified clean `main` at the baseline
- Dev.27 merged feature branch cleanup: deletion commands supplied; user confirmation pending
- Authoritative rules: `docs/WORKING_RULES.md`; no pure Dart `dart format`, no merge without separate approval

## Why this checkpoint is next

The dev.27 end-to-end install execution covers one-RemVibe-job batch download, zero-download plans, staging security, checksum checks, cancellation during transfer, and coordinated filesystem + manifest commit. The 244 passing tests do **not** directly force:

1. A dev.26 `commitIncomplete` outcome **after** irreversible file cleanup begins, followed by a successful same-authority forward-only retry.
2. A `rollbackIncomplete` outcome during partial manifest or file restoration, followed by successful same-authority rollback retry.
3. Cooperative cancellation **while awaiting coordinated begin**, after a reversible pending handle is returned, or at the exact transition into irreversible commit.
4. A failed coordinated `begin()` with retained manual recovery candidates and a root lease, including whether the caller has a usable recovery authority rather than a stranded lock.

Test count alone cannot establish those guarantees. Resolve the observable in-process lifecycle and recovery contracts before a launcher-facing API relies on them.

## Scope: four narrow work items

### A. Deterministic fault and lifecycle probes

- Inventory existing commit/rollback publication primitives, failure states and root-lease ownership first.
- Use controlled, deterministic failure points for selected **existing** IO boundaries (managed-file backup cleanup; manifest backup cleanup; manifest restore; managed-file restore). Prefer a minimal internal test seam only if black-box fixture manipulation cannot target the boundary reliably.
- Never expose `skipLock`, public failpoints, synthetic success statuses or production-mode bypasses.
- Preserve the single dev.26 root-lease authority and the existing public IO entrypoint. Avoid introducing another transaction implementation.

### B. Forward-only commit recovery

- Validate two-phase recovery *before* the first destructive cleanup and preserve this guarantee.
- Force first cleanup to succeed and later cleanup to fail; the executor must report `recoveryRequired`, keep the same authority/transaction, and **not** report installation success.
- `retryCommit()` must finish only forward cleanup, without redownloading or rolling back already finalized files; release lease exactly once on completion.
- Reject `retryRollback()` after irreversible cleanup starts; fail closed if backups/owned state are unexpectedly altered.
- Verify follow-up installation can acquire the root lease only after terminal completion.

### C. Rollback and begin-error recovery

- Force manifest-first rollback failure and managed-file rollback failure independently; retain and expose the actual recovery candidates and original failure cause.
- Verify `retryRollback()` restores the original file bytes and manifest, leaves caller-owned staging untouched, and does not claim a successful installation.
- Review `coordinator.begin()` errors **before** a combined handle is fully returned. If it can retain a root lease without a retriable handle, document and correct the authority contract within scope after a repro.
- Unowned manual recovery candidates must be surfaced explicitly; never silently discard backup evidence or release the root lease when recovery cannot be confirmed.
- Preserve operation idempotence and reject wrong-owner or simultaneous finalization.

### D. Cancellation at publication boundary

- Inject deterministic control points immediately before coordinated begin, while awaiting it, after a pending transaction is obtained, during reversible rollback and when commit cleanup has started.
- Cancellation before irreversible cleanup must prevent false success, triggering rollback where a pending handle exists; incomplete rollback must yield `recoveryRequired`.
- Cancellation after cleanup starts is non-reversing; the operation must continue commit recovery or report `commitIncomplete` rather than falsely return `cancelled`.
- Repeated `execute()`, `cancel()`, `retryCommit()` and `retryRollback()` calls must not race into double finalization or steal another RemVibe job.
- Distinguish terminal result status from the cancellation request flag.

## Acceptance and evidence

- Test pure Dart fixtures in a dedicated new test file or narrowly extend the existing coordinated IO/executor test files; do not duplicate plan builders unnecessarily.
- Run focused dev.26 transaction and manifest IO tests, dev.27 installation tests, and full package `dart test`.
- Run `dart analyze`, `git diff --check`, and confirm clean branch/worktree.
- Maintain invariant: no installation success until managed files **and** manifest are committed; no rollback once irreversible cleanup begins; manual recovery evidence persists if restoration cannot finish.
- Document exactly which injected faults were demonstrated, along with any paths that remain observational or cannot be simulated.
- Do not assume new tests alone prove process-crash atomicity or filesystem power-loss durability.
- Add package changelog/version only if dev.28 implementation is separately approved.

## Explicit exclusions

- Persistent write-ahead journal and recovery after process termination or power loss
- Cross-process lock coordination and ACID claims
- New HTTP/download manager, per-mod downloads, RemVibe package modification, TaskService changes
- Staging garbage collection and automatic deletion of caller-owned files
- Provider search/planning modifications, MtnLauncher UI or game-process integration

## Implementation gate

The user explicitly approved dev.28 implementation. A dedicated feature branch was created from verified main; no PR or merge has occurred. Run Windows Dart validation, inspect actual diff, and obtain separate merge approval before merging. Do not run `dart format`.

## Implementation progress and exact demonstrated scenarios

The feature branch now reuses existing public IO authorities rather than adding a failpoint or replacing the transaction implementation. Two **optional collaborator-injection parameters** were introduced:

- `MtnMinecraftContentMaterializationFileSystemCoordinator(manifestFileSystem: ...)` accepts a policy-matched existing manifest IO authority; policy mismatches are rejected.
- `MtnMinecraftContentInstallationExecutionRemVibe(coordinator: ...)` accepts a policy-matched coordinated transaction authority, preserving the exact owner through `retryCommit()` / `retryRollback()`. Existing callers retain the same default behavior.

Dedicated `test/support/content_recovery_test_authorities.dart` defines test-only subclasses of the normal IO/collaboration classes. The tests drive real transaction state and filesystem bytes using one-shot manifest commit/rollback errors; no production failpoints or global IO override are introduced.

Focused assertions newly added:

1. Managed files finalize, then injected manifest commit fails -> `commitIncomplete`; rollback rejected, root lease retained, forward-only retry completes and releases the lease.
2. Manifest-first rollback deliberately fails -> `rollbackIncomplete`; managed files restored, later manifest retry restores original snapshot.
3. Real manifest backup tampering -> rollback failure, recoverable lease retained; restoration of backup allows retry.
4. Real managed backup tampering -> rollback failure, recovery after restoring backup preserves prior files and manifest.
5. Precommit tamper -> `commitFailure` while still pending; correcting bytes permits safe retry before any cleanup.
6. Partial source application fails -> automatic rollback confirms no leaked exclusive lease; follow-up transaction allowed.
7. Executor cancellation while waiting for an already-held root lease -> cancellation, not success, followed by lease release.
8. Executor cancellation with a *real pending* transaction withheld from its `begin()` future -> rollback and cancelled result.
9. Executor cancellation after entering the committing phase -> no reverse or false cancelled result.
10. Executor `retryCommit()` after actual partial cleanup -> successful terminal state, no download job for removal-only plan.
11. Executor `retryRollback()` after pending precommit failure plus one injected manifest rollback interruption -> restores original managed bytes and manifest, never claims installation success.
12. Injected coordinator/manifest policy mismatch is rejected before execution/mutation.

Existing tests are preserved and shared test support avoids copying fault-injection helpers across suites.

**Still outside test proof:** a failure originating inside the *real* manifest backup `File.delete()` itself (rather than through its composable authority method), a crash/power loss, cross-process lock conflicts, and a manual recovery candidate with no combined handle. The static coordinator begin path was inspected: manifest publication happens only after a materialization transaction exists, while earlier pretransaction failures have no owned manifest candidates. If Windows validation or fault reproduction reveals a handleless retained lease, treat it as a blocker before merge.

**First Windows validation (user-provided output, feature HEAD `8fbbc7fcbed6cc01fed1889867f4dd7bf4ad8a0e`):** `dart pub get` succeeded. `dart analyze` reported one compile error at `test/content_installation_execution_remvibe_test.dart:203`: `Future<void>.doWhile` is not a valid Dart static invocation. Focused coordination tests passed **23/23**, materialization transaction **15/15**, and installation manifest IO **17/17**. The new executor test file could not load due to the same compile error; the full `dart test` could not pass either (232 tests passed before final summary; not a green run).

**Targeted correction committed:** replace `await Future<void>.doWhile(...)` with `await Future.doWhile(...)`, commit `34c46b8dd0dce4aeac062a5c0108625c9430ab69`. This is a test-source change only, not a production transaction change. **Successful Windows revalidation (user-provided) at feature HEAD `1ff74dfd78c0482f9c3559765c5a0bc7046af371`:** `dart analyze` found no issues, executor suite passed **25/25**, coordination suite **23/23**, and the full package suite **257/257**. `git diff --check main...HEAD` was clean, `git status` reported a clean feature branch synchronized with `origin`, and HEAD matched exactly. The previously observed invalid static call was fixed without production changes.

## Final pre-merge actual-diff and recovery audit (2026-10-08)

- GitHub comparison of `feature/minecraft-content-installation-recovery-hardening` against `main` at the validated HEAD: **20 commits ahead, 0 behind**; 9 changed files confined to `minecraft_content_service/` and `docs/continuity/`.
- Production modifications remain restricted to optional, policy-checked collaborator injection on the existing coordinator and installation executor. Default construction, RemVibe download ownership, filesystem transaction algorithms, and general provider/planning models are unchanged.
- Test-only authorities extend the regular collaborators. Commit interruption occurs after the coordinator's real managed-file commit has completed but **before** the injected manifest `commit()` method delegates to the actual manifest implementation. It proves the coordinator/executor forward-only retry protocol, **not** an OS-level interrupted `File.delete()` inside the manifest method.
- The injected manifest rollback interruption proves the coordinator and executor can retry reversible rollback and restore both sides; separate backup tampering tests exercise real filesystem integrity checks and recovery retry behavior.
- Cancellation tests cover lease waiting, returning a real pending transaction, and pausing just before actual `commit()` execution. They validate lifecycle behavior at these deterministic cooperation boundaries, **not** arbitrary interruption inside a running OS filesystem operation.
- Existing wrong-authority, already-finalizing and precommit guardrails remain covered by the established coordinator suite; mismatched injected policies are directly rejected.
- Incomplete or manual recovery from a publication failure that leaves **unowned filesystem candidates without a combined handle** is not injected in this checkpoint. A process crash, power failure, cross-process isolation and successful recovery after non-atomic disk faults are **not** guaranteed.
- The reviewed production paths reveal **no new critical merge blocker**. The remaining limitations above are explicit and should not be described as verified crash durability. Any observed handleless retained lease in a future real-world fault remains a blocker for that scenario.
- No PR/merge created. Separate explicit merge approval is required. Pure Dart `dart format` is prohibited by working rules.
