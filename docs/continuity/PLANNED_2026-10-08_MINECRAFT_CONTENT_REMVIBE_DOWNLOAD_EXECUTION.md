# Minecraft Tools — RemVibe Batch Execution Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.21 — RemVibe Batch Execution Foundation
Branch: feature/minecraft-content-remvibe-download-execution
Baseline main: 026693122556626934c5d1ee35795bebb0b3fddd
Implementation HEAD: 338841ec2b6445dc45022d33ec53160fcf331a0e
Production/test HEAD: 866b910b5ad4fc32f1d804333f148af21c1ebf96
Package version: 1.0.0-dev.21
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: PENDING
Merge: NOT REQUESTED
```

No `dart format` was run.

## Goal

Execute one already-built integrity-aware RemVibe content batch without taking ownership of global download-service lifecycle or final managed-file publication.

```text
MtnMinecraftContentDownloadAdapterRemVibeBatch
        ↓
MtnMinecraftContentDownloadExecutionRemVibe
        ↓
exact RemVibeDownloadJob
        ↓
completed staging files
```

## Public surface

New types:

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

## Fresh-batch contract

Execution requires:

- job status `idle`
- no active items
- every item status `idle`
- every item downloaded size `0`
- every item error count `0`

A previously completed, failed, cancelled, partially-run, or otherwise reused batch is rejected.

New execution requires a new batch.

## Exact-job and duplicate-key contract

RemVibe `addJob()` merges jobs that share the same key.

That merge behavior is intentionally not accepted here because the dev.19 association binds exact content targets to exact batch items.

Before starting/submitting:

```text
service.jobs contains same key
  -> fail fast
```

The preflight is repeated after a possible asynchronous `start()` and immediately before synchronous `addJob()`.

After submission:

```text
identical(service.addJob(batch.job), batch.job)
```

must be true.

## Global service ownership

Execution may ensure the singleton is running:

```text
inactive -> await start()
active   -> reuse
```

Execution does not:

- stop the service
- change `clearPolicy`
- clear completed jobs
- cancel unrelated jobs
- restart after an external owner intentionally stops the service

An external `stop()` therefore pauses the exact job and leaves execution pending. External `start()` resumes normal RemVibe processing.

## Completion observation

Execution uses a private `RemVibeDownloadHandler`.

It processes only:

```text
identical(eventJob, batch.job)
```

The dev.19 `RemVibeDownloadJob.onStatus` callback remains untouched.

Success requires:

```text
job.status == completed
```

The handler is disposed when execution settles.

## Error semantics

When RemVibe exhausts its retry budget and the exact job becomes `error`, execution completes with:

```text
MtnMinecraftContentDownloadExecutionRemVibeException
status: RemVibeDownloadStatus.error
```

The batch remains the diagnostic authority for:

- item status
- item error message
- item error count
- target/item association

## Cancellation semantics

`cancel()` is idempotent.

Before submission:

```text
cancel requested
-> no addJob()
-> typed cancelled execution result
```

After submission:

```text
cancel()
-> RemVibeDownloadService.cancelJob(batch.job)
-> cancelled update
-> active HTTP futures cancelled/awaited
-> temporary .download cleanup
-> job remove event
-> execution settles as cancelled
```

The execution intentionally does not settle on the first `cancelled` update because RemVibe cleanup may still be running.

## Existing integrity boundary

Dev.20 validation remains unchanged.

A job can reach completed only after each RemVibe item has passed its configured validator, when one exists, and its temporary download has been promoted to the staging destination.

Files without verifiable size/supported checksum metadata still have no integrity validator; they represent successful transfer completion rather than cryptographically verified bytes.

## Validation coverage

Focused execution tests cover:

- inactive service start
- exact single submission / idempotent `execute()`
- staging-file completion
- existing `onStatus` preservation
- global `clearPolicy` preservation
- duplicate-key rejection before service start/mutation
- integrity failure through RemVibe retry exhaustion
- typed execution error
- in-flight cancellation cleanup/removal
- idempotent repeated `cancel()`
- cancel-before-submit
- non-fresh batch rejection
- external service stop/pause and external restart/resume

## Explicitly out of scope

- final target publication
- replace/remove execution
- target-OS path collision/canonicalization policy
- staging cleanup policy after terminal execution
- backup/rollback
- installation-manifest filesystem persistence
- RemVibeTaskService workflow
- unmanaged/manual cleanup
- resource rendering

## Validation required

Run from `minecraft_content_service/`:

```text
dart pub get
dart analyze
dart test test/content_download_execution_remvibe_test.dart
dart test test/content_download_integrity_remvibe_test.dart
dart test test/content_download_adapter_remvibe_test.dart
dart test test/content_materialization_plan_test.dart
dart test test/content_installation_manifest_test.dart
dart test
```

Then from repository root:

```text
git diff --check main...HEAD
git status
git rev-parse HEAD
```

Expected feature HEAD before continuity-only follow-up commits:

```text
866b910b5ad4fc32f1d804333f148af21c1ebf96
```

Do not merge without separate explicit user approval.
