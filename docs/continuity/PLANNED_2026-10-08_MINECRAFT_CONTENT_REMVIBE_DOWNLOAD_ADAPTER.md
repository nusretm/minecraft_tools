# Minecraft Tools — RemVibe Batch Download Adapter Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.19 — RemVibe Batch Download Adapter Foundation
Branch: feature/minecraft-content-remvibe-download-adapter
Baseline main: 4e6004fa8fc2830dff707df6747748a8c1473eaa
Production/test HEAD: 40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
Package version: 1.0.0-dev.19
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Validated feature HEAD: 40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
Merge: NOT REQUESTED
```

No `dart format` was run.

## Infrastructure prerequisite

The previous launcher-owned reusable services were extracted before this checkpoint.

Observed main revisions at implementation start:

```text
remvibe_dart_models
2db0ec0f3168a08433dd8cbf687828b899e54745

remvibe_download_service
59422d90d22836ec7ee26904956c987174404c90

remvibe_task_service
46d274cc0a1128119a8253f834e56ed2f774909b
```

This removes the old dependency problem where content execution would otherwise need to import MtnLauncher.

The dev.19 dependency follows the established repository convention:

```yaml
remvibe_download_service:
  git:
    url: https://github.com/nusretm/remvibe_download_service
    ref: main
```

## Goal

Adapt the completed neutral materialization plan into the reusable RemVibe download execution contract without starting execution.

```text
MtnMinecraftContentMaterializationPlan
        ↓
MtnMinecraftContentDownloadAdapterRemVibe
        ↓
MtnMinecraftContentDownloadAdapterRemVibeBatch
        ├─ association
        │    canonical materialization target
        │        ↔
        │    RemVibeDownloadItem
        │
        └─ ONE RemVibeDownloadJob
```

The checkpoint answers how the already-resolved content batch maps into RemVibe download objects.

It does not execute the batch.

## Public API boundary

Generic consumers continue importing:

```dart
package:minecraft_content_service/minecraft_content_service.dart
```

That library does not expose RemVibe types.

RemVibe-aware consumers explicitly import:

```dart
package:minecraft_content_service/minecraft_content_service_remvibe.dart
```

The integration library exports:

- the generic minecraft content public API
- the reusable RemVibe download public API
- the content-to-RemVibe adapter family

Public integration types:

```text
MtnMinecraftContentDownloadAdapterRemVibe
MtnMinecraftContentDownloadAdapterRemVibeBatch
MtnMinecraftContentDownloadAdapterRemVibeItem
```

## Batch-first invariant

One materialization plan becomes one RemVibe download job.

Never:

```text
mod A -> addJob(job A)
mod B -> addJob(job B)
mod C -> addJob(job C)
```

Instead:

```text
materialization plan
   ├─ A install
   ├─ B replace
   ├─ C retain
   └─ D remove
        ↓
download-requiring canonical targets
   ├─ A
   └─ B
        ↓
ONE RemVibeDownloadJob
   ├─ item A
   └─ item B
```

The adapter creates that job but does not submit it.

## Canonical association

Every produced RemVibe item is paired with its exact:

```text
MtnMinecraftContentMaterializationTarget
```

The adapter builds associations from canonical install/replacement actions and then iterates the canonical `plan.download.items` order.

Therefore:

- upstream download-plan order is preserved
- target provenance remains reachable
- later verification/publication layers do not need filename guessing
- duplicate independent per-mod execution is not introduced

## Path mapping

Materialization paths are neutral forward-slash relative paths.

For a target such as:

```text
mods/libraries/example.jar
```

and caller-owned staging root:

```text
<stagingRoot>
```

the adapter maps:

```text
RemVibeDownloadItem.directory
-> <stagingRoot>/mods/libraries

RemVibeDownloadItem.filename
-> example.jar
```

The target basename is authoritative.

A provider/source filename may differ and does not override the materialization target name.

No directories are created by the adapter.

## Metadata mapping

```text
content download URL
  -> RemVibeDownloadItem.url

target artifact normalized file size
  -> RemVibeDownloadItem.size

unknown normalized size
  -> null

integrity validator
  -> null in dev.19
```

Hashes remain reachable from the canonical target file for the next integrity checkpoint.

## Empty-plan behavior

A no-change materialization plan may correctly contain zero downloads.

Because `RemVibeDownloadJob` is an actual transfer execution unit, dev.19 does not create a meaningless zero-item job.

Calling `createBatch(...)` for a zero-download plan fails explicitly.

The caller should skip the download stage when there is no download work.

## Service-lifecycle boundary

Dev.19 does not call:

```dart
RemVibeDownloadService().start();
RemVibeDownloadService().addJob(...);
```

The executor/caller remains responsible for:

- service lifecycle
- actual submission
- completion/error handling
- cancellation
- retry behavior already owned by RemVibe
- progress observation

This keeps mapping separate from execution.

## Filesystem boundary

The generic content core remains network/planning/persistence focused and does not gain filesystem execution behavior.

The explicit RemVibe integration layer uses:

```dart
dart:io
Directory
```

because `RemVibeDownloadItem` requires a staging directory.

This is an integration contract, not final materialization/publication.

The `path` package is a direct dependency for host filesystem staging path composition.

## SDK compatibility boundary

`remvibe_download_service` requires:

```text
Dart >=3.5.0
```

Therefore dev.19 raises the package SDK lower bound:

```text
from >=3.3.0
to   >=3.5.0
```

This is a dependency requirement introduced by the approved integration.

## Explicitly out of scope

- starting RemVibeDownloadService
- submitting the job through `addJob()`
- transfer completion/error orchestration
- cancellation orchestration
- integrity/hash validator
- expected-size enforcement beyond passing normalized metadata
- staging cleanup
- target-platform path canonicalization/collision policy
- final target copy/move/rename
- replacement/removal execution
- safe/atomic publication
- rollback/transactions
- manifest file location/read/write
- installation manifest atomic persistence
- RemVibeTaskService workflow
- unmanaged/manual file cleanup
- resource/item rendering

## Validation

Initial local validation at continuity HEAD `8a1024c9620b21d68950c6cca3abd61abe54979f` found one `directives_ordering` info in the RemVibe integration library. The export order was corrected without changing behavior.

Authoritative user-supplied final local validation on 2026-10-08 at feature HEAD `40f3484230c9f0f4cc8cf1aead8a924659e7e0fd`:

```text
dart analyze
No issues found!

content_download_adapter_remvibe_test.dart
7/7 passed

full dart test
134/134 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
```

Earlier focused validation before the export-order-only correction also passed:

```text
content_materialization_plan_test.dart
9/9

content_download_plan_test.dart
9/9

content_installation_manifest_test.dart
9/9
```

Dependency resolution observed:

```text
remvibe_dart_models 1.0.0 @ 2db0ec
remvibe_download_service 1.0.0 @ 59422d
```

No `dart format` was run.

The checkpoint is implementation-complete, actual-diff reviewed, validated, and continuity-closed. Merge still requires separate explicit user approval.
