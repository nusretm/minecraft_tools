# Minecraft Tools — dev.24 Whole-plan Materialization Transaction Foundation

Date: 2026-10-08

## Status

- Repository: nusretm/minecraft_tools
- Branch: feature/minecraft-content-materialization-transaction
- Baseline main: 6955f67833875b17aeab43bf7579268d3a44834a
- Package: minecraft_content_service 1.0.0-dev.24
- Feature implementation HEAD: b0d6e50d645abec7fa034322fdb20dfbccdb0b2b
- Windows validation (user-provided logs, feature HEAD): `dart analyze` clean; transaction 15/15; publication 15/15; full `dart test` 192/192; `git diff --check` clean; working tree clean.
- Actual-diff hardening: reject simultaneous finalizations and revalidate published target ancestor paths before destructive cleanup; regression tests included in the validated feature HEAD.
- PR: #52 — https://github.com/nusretm/minecraft_tools/pull/52
- Squash merge commit: 596f794801ff1e4f3b20db479fa6be736c6d7db4
- Merge: COMPLETE on 2026-10-08 (user-approved)

## Boundary

The transaction is intentionally on the explicit minecraft_content_service_io.dart surface.
No dart:io dependency is introduced into the generic service entrypoint and no provider,
RemVibe job, TaskService, or MtnLauncher type enters the filesystem transaction.
Caller supplies exact canonical install/replacement target + read-only File source pairs.

## Execution

1. Require safe preflight and complete one-to-one source associations.
2. Acquire exclusive policy-normalized installation-root lock. Existing standalone dev.23 publication calls hold a shared root lock until their publication handle is finalized.
3. Rerun preflight and reject changed physical snapshots before mutation.
4. Refuse source aliases to current/resulting managed targets.
5. Capture retained-file integrity snapshots and validate canonical metadata when present.
6. Publish each install/replacement in deterministic policy-normalized target-path order using the dev.23 primitive, retaining private publication handles.
7. Derive physical removals as current managed path identities minus resulting managed path identities. Path reuse is handled by publication backup, not removal.
8. Rename obsolete managed files into same-parent reversible sibling backups. Missing preflight removals remain no-ops, provided they stay missing.
9. Validate retained files; return the pending transaction with one authoritative private recovery ledger.

## Finalization

- commitTransaction: validate all pending recovery entries + retains before deleting any backup; then cleanup in reverse recovery-ledger order. Once cleanup begins, failures are commitIncomplete and may only retry commit.
- rollbackTransaction: validate all pending recovery entries + retains before restoration; restore in reverse recovery-ledger order. Partial restoration remains rollbackIncomplete and may only retry rollback.
- Committed and rolledBack final states are idempotent for their own finalization method. Opposite finalizations are rejected.
- Transaction finalization belongs only to the creating filesystem authority.
- Concurrent commit/rollback entry on the same transaction handle is rejected until the current finalization completes.
- On application failure, recover already-applied entries. If recovery cannot be confirmed, surface typed transaction failure and preserved candidate paths.
- Transaction public resultingInstallationState is the original plan's candidate state; it is authoritative as applied only after committed.

## Safety and ownership

- Source files remain caller-owned, read-only and never consumed.
- Retained managed files are never intentionally mutated.
- Existing target backup content is captured through transient SHA-256 and size before rename and rechecked before commit/rollback.
- Managed removal backup content is likewise checked before finalization; removed target must remain absent.
- Publication finalization rechecks installation-root resolution and the target's symlink-free parent path chain, not merely target bytes.
- Root lock and target locks are in-process coordination for cooperating callers, not OS-wide locks.
- No arbitrary unmanaged or manually installed files are ever removed.
- External processes can race between portable Dart filesystem inspections and rename; no no-replace native rename primitive is assumed.
- A pending transaction can be visibly partially applied to other processes; it is reversible but not an ACID filesystem transaction.
- Unresolved no-handle publication recovery can keep a root transaction lease held. Manual recovery and process restart may be required; automated durable crash recovery is not promised.
- File-to-directory hierarchy transformations remain blocked by existing dev.22 preflight policy.

## Deliberately out of scope

- Durable process-crash journal and restart recovery
- Installation manifest filesystem persistence or coordinated manifest commit
- RemVibe batch/result association and staging-root cleanup
- TaskService orchestration and cancellation
- Unmanaged file cleanup
- MtnLauncher integration and resource rendering
- minecraft_info_provider and hypixel_api changes

## Validation required before merge review

From minecraft_content_service/:

    dart pub get
    dart analyze
    dart test test/content_materialization_file_system_transaction_test.dart
    dart test test/content_materialization_file_system_publication_test.dart
    dart test test/content_materialization_file_system_preflight_test.dart
    dart test test/content_materialization_plan_test.dart
    dart test test/content_installation_manifest_test.dart
    dart test test/content_download_integrity_remvibe_test.dart
    dart test test/content_download_execution_remvibe_test.dart
    dart test

From repository root:

    git diff --check main...HEAD
    git status
    git rev-parse HEAD

Do not run dart format for Pure Dart.
Merge must not occur without separate explicit user approval.
