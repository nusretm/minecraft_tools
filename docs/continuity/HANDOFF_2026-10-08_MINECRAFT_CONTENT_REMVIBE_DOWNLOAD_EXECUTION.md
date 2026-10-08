# Minecraft Tools — RemVibe Batch Execution Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.21 — RemVibe Batch Execution Foundation
Branch: feature/minecraft-content-remvibe-download-execution
Baseline main: 026693122556626934c5d1ee35795bebb0b3fddd
Implementation HEAD: 338841ec2b6445dc45022d33ec53160fcf331a0e
Production/test HEAD before lint-only fix: 866b910b5ad4fc32f1d804333f148af21c1ebf96
Validated feature HEAD: f15750d666d3b22f7ad7302e74fd025db01d14b3
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
PR: #49
Merge commit: 313e21b268157ad6049b5b4e9f578b5e7f17c44a
Package version: 1.0.0-dev.21
```

No `dart format` was run.

## Goal

Execute one already-built integrity-aware RemVibe batch from submission through terminal state without taking ownership of global download-service shutdown or final managed-target publication.

```text
integrity-aware batch
        ↓
MtnMinecraftContentDownloadExecutionRemVibe
        ├─ fresh-batch validation
        ├─ duplicate-key protection
        ├─ ensure service running
        ├─ exact addJob submission
        ├─ exact-job terminal observation
        └─ idempotent cancellation
        ↓
completed staging files
```

## Public surface

```text
MtnMinecraftContentDownloadExecutionRemVibe
MtnMinecraftContentDownloadExecutionRemVibeException
```

Usage:

```dart
final execution = MtnMinecraftContentDownloadExecutionRemVibe(
  batch: batch,
);

await execution.execute();
```

Cancellation:

```dart
await execution.cancel();
```

Repeated `execute()` calls share the same future and never submit the job twice.

Repeated `cancel()` calls share the same cancellation operation.

## Fresh-batch contract

Execution requires:

- job status `idle`
- no active items
- item status `idle`
- downloaded size `0`
- error count `0`

Previously-used batches are rejected.

## Duplicate-key protection

RemVibe merges jobs with the same key.

Dev.21 rejects any already-registered identical key before submission to preserve the exact dev.19 batch association.

The key preflight runs:

1. before a possible service start
2. again after that asynchronous boundary and immediately before `addJob()`

The returned job from `addJob()` must be identical to `batch.job`.

## Service ownership

Execution:

- starts the singleton only when inactive
- reuses it when already active
- never calls `stop()`
- never changes `clearPolicy`
- never clears unrelated jobs
- never cancels unrelated jobs

If an external owner stops the service, the job returns to idle and execution remains pending.

If the external owner starts the service again, the same job resumes and can complete normally.

## Completion observation

A private `RemVibeDownloadHandler` observes only the exact batch job by identity.

The existing dev.19 `job.onStatus` callback is preserved unchanged.

Success requires exact job status `completed`.

The internal handler is disposed after execution settles.

## Error semantics

Retry exhaustion produces:

```text
MtnMinecraftContentDownloadExecutionRemVibeException
status: error
```

Item-level status, error count and error message remain available on the exact batch.

Integrity failures from dev.20 naturally participate in the same RemVibe retry/error lifecycle.

## Cancellation semantics

Before submission:

```text
cancel request
-> no addJob
-> typed cancelled execution
```

After submission:

```text
cancel()
-> RemVibe cancelJob(batch.job)
-> cancelled status update
-> active transfer cancellation / wait
-> temporary .download cleanup
-> remove event
-> execution settles as cancelled
```

Execution does not settle merely on the first cancelled status update.

## Explicitly out of scope

- final managed-target publication
- replacement/removal execution
- target-OS path collision/canonicalization policy
- staging cleanup policy after terminal execution
- backup/rollback transaction semantics
- installation-manifest filesystem persistence
- RemVibeTaskService workflow
- unmanaged/manual cleanup
- resource rendering

## Validation

Authoritative user-supplied local validation:

Behavioral validation before the final lint-only export ordering fix:

```text
dart pub get
PASS

dart analyze
1 info only:
directives_ordering

content_download_execution_remvibe_test.dart
7/7 passed

content_download_integrity_remvibe_test.dart
9/9 passed

content_download_adapter_remvibe_test.dart
7/7 passed

content_materialization_plan_test.dart
9/9 passed

content_installation_manifest_test.dart
9/9 passed

dart test
150/150 passed

git diff --check main...HEAD
PASS

git status
working tree clean

HEAD:
5f2e0c759fbaacc6a871f88f820c936a5e1890c0
```

Final lint-only fix:

```text
commit:
f15750d666d3b22f7ad7302e74fd025db01d14b3

change:
minecraft_content_service_remvibe.dart
export ordering only
+1 / -1
```

Final authoritative validation:

```text
dart analyze
No issues found!

dart test
150/150 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
f15750d666d3b22f7ad7302e74fd025db01d14b3
```

## Next boundary

The next natural checkpoint after merge is filesystem publication/materialization execution:

```text
completed staging files
        ↓
target/platform preflight
        ↓
safe managed-target publication
        ↓
replace/remove transaction boundary
```

That future checkpoint should explicitly define target-platform path identity and publication ordering before mutating the managed installation.
