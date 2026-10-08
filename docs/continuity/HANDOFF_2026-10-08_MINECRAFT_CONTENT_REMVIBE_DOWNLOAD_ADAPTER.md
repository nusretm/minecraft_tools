# Minecraft Tools — RemVibe Batch Download Adapter Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.19 — RemVibe Batch Download Adapter Foundation
Branch: feature/minecraft-content-remvibe-download-adapter
Baseline main: 4e6004fa8fc2830dff707df6747748a8c1473eaa
Production/test HEAD: 40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
Validated feature HEAD: 40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
PR: #47
Merge commit: ceab133f18546ce0215da04c36339957bf2dfb31
Package version: 1.0.0-dev.19
```

No `dart format` was run.

## Goal

Adapt one complete Minecraft content materialization plan into one reusable RemVibe download batch without starting transfer execution.

```text
MtnMinecraftContentMaterializationPlan
        ↓
MtnMinecraftContentDownloadAdapterRemVibe
        ↓
MtnMinecraftContentDownloadAdapterRemVibeBatch
        ├─ exact target ↔ RemVibeDownloadItem associations
        └─ ONE RemVibeDownloadJob
```

## Public integration boundary

Generic consumers keep importing:

```dart
package:minecraft_content_service/minecraft_content_service.dart
```

RemVibe-aware consumers explicitly import:

```dart
package:minecraft_content_service/minecraft_content_service_remvibe.dart
```

The generic core library does not export RemVibe types.

Public integration types:

```text
MtnMinecraftContentDownloadAdapterRemVibe
MtnMinecraftContentDownloadAdapterRemVibeBatch
MtnMinecraftContentDownloadAdapterRemVibeItem
```

## Batch-first invariant

One materialization plan produces one RemVibe download job.

Install and replacement targets contribute download items.

Retain and remove actions contribute no download items.

The adapter iterates canonical `plan.download.items` order after building exact target associations from canonical install/replacement actions.

Therefore:

- download-plan order is preserved
- each RemVibe item keeps exact materialization provenance
- no independent per-mod job submission is introduced

## Mapping

For each canonical download target:

```text
download.url
  -> RemVibeDownloadItem.url

stagingRoot + relativePath parent
  -> RemVibeDownloadItem.directory

relativePath basename
  -> RemVibeDownloadItem.filename

normalized selected file size
  -> RemVibeDownloadItem.size

validator
  -> null in dev.19
```

The caller-owned final target basename is authoritative even when the provider/source filename differs.

No directories are created during adaptation.

## Empty plan

A valid no-change materialization plan may have zero download items.

The adapter rejects creation of a zero-item RemVibe job. The caller should skip the download stage in that case.

## Execution boundary

Dev.19 does not:

- start `RemVibeDownloadService`
- call `addJob()`
- await completion
- orchestrate cancellation
- perform integrity verification
- publish staged files
- execute replacements/removals
- write the installation manifest

Transfer lifecycle remains owned by RemVibe/caller execution code.

## Filesystem boundary

The explicit integration layer uses `dart:io Directory` because the reusable RemVibe item contract requires a destination directory.

The generic planning and persistence layers remain filesystem-free.

The package now directly depends on `path` for host filesystem staging path composition.

## SDK/dependency boundary

The reusable download package requires Dart >=3.5.

Therefore dev.19 raises `minecraft_content_service` minimum SDK from Dart 3.3 to Dart 3.5.

Configured dependency:

```yaml
remvibe_download_service:
  git:
    url: https://github.com/nusretm/remvibe_download_service
    ref: main
```

Observed dependency resolution during authoritative validation:

```text
remvibe_dart_models 1.0.0 @ 2db0ec
remvibe_download_service 1.0.0 @ 59422d
```

## Validation

Initial local validation found one `directives_ordering` info in the integration library. Export ordering was corrected without behavioral changes.

Authoritative user-supplied final validation on 2026-10-08:

```text
dart analyze
No issues found!

content_download_adapter_remvibe_test.dart
7/7 passed

dart test
134/134 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
40f3484230c9f0f4cc8cf1aead8a924659e7e0fd
```

Earlier focused validation also passed:

```text
content_materialization_plan_test.dart
9/9

content_download_plan_test.dart
9/9

content_installation_manifest_test.dart
9/9
```

## Next boundary

The next natural checkpoint is download integrity validation.

Conceptually:

```text
normalized content file hashes / expected size
        ↓
RemVibeDownloadItem.validator
        ↓
staged file integrity decision
```

This should remain separate from final publication, replacement/removal execution, rollback and installation-manifest filesystem persistence.
