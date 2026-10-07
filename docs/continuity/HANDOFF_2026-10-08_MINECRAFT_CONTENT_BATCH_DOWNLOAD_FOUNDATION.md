# Minecraft Tools — Minecraft Content Batch Download Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.15 — Batch Download Plan / Source Resolution Foundation
Branch: feature/minecraft-content-download-plan
Baseline main: 8e227cf7e33ac968e9189ad4babbc1483cfc53f3
Production/test HEAD: 245315c3dd980adc5f4e6750204e0b018222d01f
Validated feature HEAD: 4c1113af904999c15e7f23328030a80b575c9958
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: APPROVED
Package version: 1.0.0-dev.15
```

No `dart format` was run.

## Goal

Turn one successful `MtnMinecraftContentFileSelectionPlan` into one complete neutral batch download plan without performing byte transfer or depending on launcher download types.

```text
FileSelectionPlan
        ↓
resolve every selected source
        ↓
one DownloadPlan
        ↓
later launcher adapter
        ↓
one DownloadList
        ↓
one downloadManager.add(...)
```

## Public surface

```dart
MtnMinecraftContentDownloadItem
MtnMinecraftContentDownloadPlan
MtnMinecraftContentDownloadIssue
MtnMinecraftContentService.planSelectedFileDownloads(...)
```

Provider extension point:

```dart
Future<Uri?> resolveDownloadSource(
  MtnMinecraftContentVersion version,
  MtnMinecraftContentFile file,
)
```

## Locked behavior

- Download planning requires a selectable dev.14 file-selection plan.
- Direct normalized HTTP/HTTPS `file.downloadUrl` is reused without provider lookup.
- If no direct URL exists, provider identity comes only from `selection.file.providers`.
- Generic planning contains no Modrinth/CurseForge switch.
- Missing, ambiguous, unregistered, or not-ready provider state becomes a download-plan issue.
- Provider exceptions are aggregated as source-resolution issues instead of aborting the whole scan.
- Provider-resolved URLs must also be absolute HTTP/HTTPS URLs.
- Every canonical file selection is represented exactly once by either one download item or one issue.
- Item ordering preserves dev.14 file-selection ordering.
- All issues are aggregated across the batch.
- Any issue makes `DownloadPlan.downloadable == false`.
- Successful items may remain visible for diagnostics, but an incomplete plan must not be submitted to a download executor.
- Empty selectable input produces an empty downloadable plan.
- Download items keep only the selection provenance plus resolved URI; file name, size, hashes, and provider metadata remain authoritative through `selection.file`.

## Issue family

```text
MtnMinecraftContentDownloadIssue
├─ MtnMinecraftContentDownloadIssueInvalidUrl
├─ MtnMinecraftContentDownloadIssueProviderMissing
├─ MtnMinecraftContentDownloadIssueProviderAmbiguous
├─ MtnMinecraftContentDownloadIssueProviderNotRegistered
├─ MtnMinecraftContentDownloadIssueProviderNotReady
├─ MtnMinecraftContentDownloadIssueSourceUnavailable
└─ MtnMinecraftContentDownloadIssueSourceResolutionFailed
```

## CurseForge boundary

CurseForge owns all provider-specific source lookup details.

The normalized model provides:

```text
version.content.providers -> CurseForge project/mod id
file.providers            -> CurseForge file id
```

The provider resolves:

```text
GET /v1/mods/{modId}/files/{fileId}/download-url
```

API-key headers, integer ID interpretation, endpoint paths, and response-envelope handling remain inside the CurseForge provider.

## Deliberately not implemented

- byte transfer
- launcher `DownloadList` / `DownloadManager` dependency
- one manager submission per content item
- concurrency
- retry
- progress
- cancellation
- pause/resume
- target directories/paths
- filesystem materialization
- hash verification
- size verification
- safe publication
- replacement/removal execution
- managed installation manifest
- rollback/transactions
- unknown/manual file cleanup
- deferred resource/item rendering

## Validation

Authoritative user-supplied local validation on 2026-10-08:

```text
dart analyze
No issues found!

dart test test/content_download_plan_test.dart
9/9 passed

dart test test/content_file_selection_test.dart
12/12 passed

dart test test/content_dependency_reconciliation_test.dart
11/11 passed

dart test test/content_dependency_desired_state_test.dart
10/10 passed

dart test test/content_dependency_install_policy_test.dart
11/11 passed

dart test test/content_provider_service_test.dart
22/22 passed

dart test
101/101 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
4c1113af904999c15e7f23328030a80b575c9958
```

The commits after the validated feature HEAD are continuity-only and do not change production or test implementation.

## Next boundary

A later checkpoint may introduce target/materialization planning and then a launcher-side adapter that maps exactly one neutral content download plan into exactly one launcher `DownloadList`.

Do not move byte-transfer lifecycle responsibilities into `minecraft_content_service` planning.
