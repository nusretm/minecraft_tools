# Minecraft Tools — Planned Minecraft Content Batch Download Foundation

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Planning baseline main HEAD:
53ff05a8147f3f747ecdff650571ad8d3553fe2c

Planning status:
DESIGN LOCKED
IMPLEMENTATION COMPLETE
VALIDATED
CONTINUITY CLOSED
FEATURE BRANCH: feature/minecraft-content-download-plan
PRODUCTION/TEST HEAD: 245315c3dd980adc5f4e6750204e0b018222d01f
VALIDATED FEATURE HEAD: 4c1113af904999c15e7f23328030a80b575c9958
MERGE APPROVED

Implementation baseline main:
8e227cf7e33ac968e9189ad4babbc1483cfc53f3
```

This document records the agreed architecture direction after completion of the content file-selection foundation.

Implementation was explicitly approved on 2026-10-08. Authoritative local Dart validation completed successfully at feature HEAD `4c1113af904999c15e7f23328030a80b575c9958`. Subsequent changes before merge are continuity-only.

## Completed prerequisite chain

```text
Dependency Graph
      ↓
Install Policy
      ↓
Desired State
      ↓
Installed-State Reconciliation
      ↓
File Selection
```

Latest completed package version:

```text
minecraft_content_service 1.0.0-dev.14
```

Latest completed checkpoint:

```text
feature/minecraft-content-file-selection
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #42
merge commit: b39f9ef5ed7dda2c4e6ab182aead2668f6263230
post-merge main continuity HEAD:
53ff05a8147f3f747ecdff650571ad8d3553fe2c
```

## Core architecture decision

Minecraft content downloads are batch-oriented.

Generic content code must not orchestrate one independent download-manager submission for every selected mod/file.

Wrong architecture:

```text
selected A -> downloadManager.add(A)
selected B -> downloadManager.add(B)
selected C -> downloadManager.add(C)
selected D -> downloadManager.add(D)
```

Required architecture:

```text
all selected install/replace files
        ↓
resolve all required download sources
        ↓
one complete content download plan
        ↓
launcher adapter
        ↓
one DownloadList
        ↓
one downloadManager.add(downloadList)
```

The download manager remains responsible for executing the batch.

## Existing launcher integration context

The launcher already has a download-manager architecture with batch/list semantics.

The important integration contract is conceptually:

```text
DownloadList
  ├─ item
  ├─ item
  ├─ item
  └─ item
        ↓
downloadManager.add(downloadList)
        ↓
manager handles completion/error
```

The exact launcher types remain launcher-owned.

`minecraft_tools` must not import or depend directly on `mtn_launcher`.

Dependency direction must stay:

```text
minecraft_content_service
        ↓ produces neutral plan

launcher
        ↓ adapts neutral plan

launcher DownloadList / Download Manager
```

Never:

```text
minecraft_content_service
        ↓ imports
mtn_launcher
```

## Responsibility split

### minecraft_content_service owns

```text
WHAT should be downloaded?
WHERE can each selected file be downloaded from?
WHAT expected metadata belongs to each selected file?
IS the complete download batch resolvable?
```

This includes:

- selected install/replace targets
- resolved source URL or equivalent neutral download source
- file name
- size metadata when known
- hash metadata when known
- original file selection / desired version provenance
- aggregate source-resolution issues
- deterministic batch item ordering

### Download executor / launcher owns

```text
HOW should bytes be downloaded?
```

This includes:

- concurrency
- parallel item count
- retry policy
- progress
- cancellation
- pause/resume if supported
- network scheduling
- transfer lifecycle
- download-manager handlers/events
- batch completion/error lifecycle

These responsibilities must not leak back into generic content planning.

## Next checkpoint direction

The natural next checkpoint should combine source resolution with a batch download plan rather than exposing a narrow per-file download API.

Proposed checkpoint:

```text
dev.15 — Batch Download Plan / Source Resolution Foundation
```

Possible branch:

```text
feature/minecraft-content-download-plan
```

Possible package bump:

```text
minecraft_content_service 1.0.0-dev.15
```

Names remain subject to final scope audit before implementation.

## Proposed dev.15 pipeline

```text
MtnMinecraftContentFileSelectionPlan
        ↓
resolve source for every selected file
        ↓
MtnMinecraftContentDownloadPlan
        ├─ items
        └─ issues
```

The plan is a complete batch description.

It does not perform byte transfer.

## Batch-first invariant

A reconciliation may produce:

```text
A install
B replace
C retain
D install
E replace
F remove
```

File selection may produce:

```text
A.jar
B-v2.jar
D.jar
E-v4.jar
```

Source resolution should produce one plan:

```text
DownloadPlan
├─ A.jar
├─ B-v2.jar
├─ D.jar
└─ E-v4.jar
```

The launcher should then be able to adapt that plan to:

```text
one DownloadList
four DownloadItems
one downloadManager.add(downloadList)
```

Retains and removals do not become download items.

## Source-resolution policy direction

A selected file may already contain a directly usable source:

```text
file.downloadUrl != null
-> reuse the normalized direct URL
```

A selected file may not contain a direct URL:

```text
file.downloadUrl == null
-> source resolution may require its provider
```

This is particularly relevant to providers where file metadata can be valid without embedding the final download URL.

Generic core must not hardcode provider endpoint behavior.

Provider-specific download-source lookup stays provider-specific.

The generic service may orchestrate source resolution through the registered provider abstraction, but provider wire details remain inside provider implementations.

## Important completeness rule

Source resolution should evaluate the whole selected batch before download execution begins.

Preferred behavior:

```text
47 selected files
        ↓
resolve sources for all 47
        ↓
47/47 resolved
        ↓
downloadable plan
        ↓
executor / launcher DownloadList
```

If one or more items cannot be resolved:

```text
47 selected files
        ↓
44 resolved
3 issues
        ↓
downloadable == false
        ↓
do not start the batch
```

Do not knowingly hand an incomplete install/replace batch to the download executor and discover source-resolution blockers after partial downloading has already started.

Issues should be aggregated so callers/UI can inspect all blockers at once.

## Proposed neutral result shape

Exact names remain subject to implementation audit, but the intended shape is:

```dart
class MtnMinecraftContentDownloadPlan {
  final List<MtnMinecraftContentDownloadItem> items;
  final List<MtnMinecraftContentDownloadIssue> issues;

  bool get downloadable;
}
```

A download item should preserve enough provenance to connect back to the file-selection decision.

Conceptually:

```dart
class MtnMinecraftContentDownloadItem {
  final MtnMinecraftContentFileSelection selection;
  final Uri url;

  // normalized expected metadata remains reachable
  // through selection.file and/or explicit plan fields
}
```

Likely useful expected metadata:

- file name
- size when known
- hashes when known
- selected file identity/provenance

Do not duplicate model data without a concrete reason.

## No per-file public execution loop

Avoid a content-service API whose intended orchestration is:

```dart
await download(fileA);
await download(fileB);
await download(fileC);
```

or:

```dart
downloadManager.add(itemA);
downloadManager.add(itemB);
downloadManager.add(itemC);
```

The batch plan is the unit handed to an executor/adapter.

A later execution contract, if needed, should conceptually resemble:

```dart
execute(MtnMinecraftContentDownloadPlan plan)
```

not:

```dart
download(MtnMinecraftContentDownloadItem item)
```

for top-level orchestration.

Internal download-manager implementations may naturally process individual items concurrently; the restriction is about the architectural submission/orchestration unit.

## Launcher adapter boundary

The launcher may later contain an adapter similar in responsibility to:

```text
MtnMinecraftContentDownloadPlan
        ↓
Launcher-specific adapter
        ↓
DownloadList
        ↓
DownloadManager.add(...)
```

The adapter may map:

- resolved URL
- file name
- destination information once materialization planning exists
- expected size
- hashes / verification metadata as supported

This adapter belongs on the launcher/integration side, not inside generic `minecraft_content_service` core if doing so would introduce a launcher dependency.

## Actual download implementation

Actual byte transfer is intended to be supported eventually, but it is not automatically part of dev.15.

The architecture should remain compatible with:

```text
A) launcher
   -> existing Download Manager / DownloadList implementation

B) standalone minecraft_tools consumer
   -> future generic batch-capable executor/downloader
```

Do not duplicate the launcher's mature download-manager responsibilities inside the content-planning layer.

Whether `minecraft_content_service` later ships a default Pure Dart batch downloader is a separate design decision.

If it does, it must implement a neutral batch execution contract rather than changing the planning layer to launcher-specific types.

## File-selection boundary carried forward

The completed dev.14 rules remain authoritative:

- only install and replacement desired targets require new-file download planning
- retain does not require a new download
- remove does not require a download
- removal physical-file lookup is still unresolved and must not be guessed from version metadata
- `available == false` blocks file selection before download planning
- `available == null` is not automatically unavailable
- `downloadUrl == null` is not a file-selection failure
- file selection does not interpret hashes/size as availability

Download planning starts only from successful file selections.

## Integrity boundary

Hashes and sizes can travel with the plan as expected metadata.

However, dev.15 source resolution should not automatically become:

- hash verification
- downloaded-size verification
- safe publication
- filesystem materialization

Those are later execution/materialization concerns unless explicitly rescoped.

## Installed artifact / removal boundary

Current installed-state reconciliation knows installed versions, not authoritative installed paths/artifacts.

File selection knows desired new files, not which historical file/path must be removed.

Therefore download planning must not invent removal paths.

A later managed installation/artifact manifest should record enough information to support safe replace/remove/materialization.

## Explicitly out of scope for the planned dev.15 unless separately approved

- actual byte transfer
- direct dependency on launcher Download Manager types
- direct dependency on launcher DownloadList types
- one manager submission per mod
- concurrency implementation
- retry implementation
- progress aggregation
- cancellation implementation
- pause/resume
- filesystem target paths
- file publication
- replacement/removal execution
- installed physical-file discovery
- managed installation manifest
- hash verification
- size verification
- backup/rollback
- transactions
- unknown/manual file cleanup
- provider-specific endpoint logic in generic core
- deferred item client-definition/model/texture rendering

## Suggested design questions for the next chat

Before implementation, audit and lock:

1. What neutral download-source model is needed beyond a single `Uri`, if any?
2. Should direct `file.downloadUrl` resolution be synchronous while provider lookup remains async under one async batch API?
3. What provider method should resolve a selected file with no direct URL?
4. How should provider identity for a selected file be determined without guessing?
5. Should source-resolution issues form a subclass family similar to file-selection issues?
6. Should one unresolved source make `DownloadPlan.downloadable == false`? Current design direction: yes.
7. How should deterministic item order map from file-selection results?
8. Which expected metadata should be copied versus referenced from `selection.file`?
9. Should dev.15 stop strictly at plan/source resolution? Current design direction: yes.
10. What exact launcher adapter boundary will later map one content download plan to one launcher `DownloadList`?

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- no merge without separate explicit approval
- Pure Dart: do not run `dart format`
- use user-supplied local `dart analyze` / tests as authoritative
- provider-specific behavior stays provider-specific
- generic core must not import launcher-specific implementations
- keep checkpoints small
- do not start execution/materialization automatically

## Validation

Authoritative user-supplied local validation on 2026-10-08:

```text
dart analyze
No issues found!

content_download_plan_test.dart
9/9 passed

content_file_selection_test.dart
12/12 passed

content_dependency_reconciliation_test.dart
11/11 passed

content_dependency_desired_state_test.dart
10/10 passed

content_dependency_install_policy_test.dart
11/11 passed

content_provider_service_test.dart
22/22 passed

full dart test
101/101 passed

git diff --check main...HEAD
PASS

working tree
clean

validated feature HEAD
4c1113af904999c15e7f23328030a80b575c9958
```

No `dart format` was run.

## Next action

The checkpoint is implementation-complete, validated, and continuity-closed. Merge has been separately approved by the user.

Deferred resource rendering remains separate:

```text
docs/continuity/PLANNED_2026-10-07_MINECRAFT_RESOURCE_ITEM_RENDERING_FOUNDATION.md
```
