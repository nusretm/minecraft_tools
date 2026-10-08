# Minecraft Tools — Content Download Integrity Validator Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.20 — Content Download Integrity Validator Foundation
Branch: feature/minecraft-content-download-integrity
Baseline main: cf1205d38502fa7cb56c851dd7804a70bc1b9085
Production/test HEAD: c66cbe6716aa6f6a5fffb39c274e6e94e304d5cf
Validated feature HEAD: 50d906fbe4f8469ff7caa760e3a76821c03ee326
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
Package version: 1.0.0-dev.20
```

No `dart format` was run.

## Goal

Provide staged-file integrity validation for RemVibe content downloads before RemVibe promotes its temporary download to the staging destination.

```text
canonical target file metadata
        ├─ expected size
        └─ hashes
        ↓
MtnMinecraftContentDownloadIntegrityRemVibe
        ↓
RemVibeDownloadItem.validator
        ↓
temporary .download file
```

## Public surface

```text
MtnMinecraftContentDownloadIntegrityRemVibe
MtnMinecraftContentDownloadIntegrityException
```

The integrity policy exposes:

```text
expectedSize
checksums
validate(File)
```

The dev.19 association now also exposes the exact nullable integrity policy through:

```text
MtnMinecraftContentDownloadAdapterRemVibeItem.integrity
```

The generic package entrypoint remains free of RemVibe/filesystem execution types.

RemVibe-aware consumers use:

```dart
package:minecraft_content_service/minecraft_content_service_remvibe.dart
```

## Expected-size authority

Expected size is captured from the canonical normalized content file:

```text
target.artifact.file.size
```

It is deliberately not read from `RemVibeDownloadItem.size` during validation because RemVibe updates that field from the actual response/received byte count before calling the validator.

Validation compares captured expected size with temporary `File.length()`.

## Supported checksums

Canonical algorithms:

```text
md5
sha1
sha256
sha512
```

Accepted aliases:

```text
sha-1
sha-256
sha-512
```

Rules:

- supported digests require exact hexadecimal length
- hexadecimal case is normalized to lowercase
- duplicate aliases with the same digest are accepted
- conflicting aliases for the same canonical algorithm fail fast
- malformed digests for supported algorithms fail fast
- unknown/provider-specific algorithms are ignored by this verifier

Expected digest lengths:

```text
md5    32
sha1   40
sha256 64
sha512 128
```

## Verification matrix

```text
size + supported checksum(s)
  -> all must pass

size only
  -> size must pass

supported checksum(s) only
  -> every supported checksum must pass

unknown hashes only + no size
  -> validator null

no verifiable metadata
  -> validator null
```

## Hash execution

Multiple required hashes are calculated in a single streamed file pass.

```text
File.openRead()
   ├─ md5 sink
   ├─ sha1 sink
   ├─ sha256 sink
   └─ sha512 sink
```

## RemVibe lifecycle boundary

The reusable download service executes the validator against the temporary `.download` file after transfer completion and before destination replacement.

A validator exception therefore:

- prevents promotion to the staging destination
- causes temporary-file cleanup
- remains inside the existing RemVibe retry/error lifecycle

Dev.20 does not duplicate retry or transport behavior.

## Dependency

```yaml
crypto: ^3.0.7
```

was added directly for streamed MD5/SHA digest calculation.

## Explicitly out of scope

- starting/submitting RemVibe jobs
- waiting for job completion
- cancellation orchestration
- final managed-target publication
- replacement/removal execution
- target-platform case/canonical collision policy
- staging cleanup policy
- rollback/transaction sequencing
- installation-manifest filesystem persistence
- RemVibeTaskService orchestration
- unmanaged/manual file cleanup
- deferred resource rendering

## Validation

Authoritative user-supplied local validation on 2026-10-08:

```text
dart pub get
PASS
crypto 3.0.7 resolved as direct dependency

dart analyze
No issues found!

content_download_integrity_remvibe_test.dart
9/9 passed

content_download_adapter_remvibe_test.dart
7/7 passed

content_materialization_plan_test.dart
9/9 passed

content_installation_manifest_test.dart
9/9 passed

dart test
143/143 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
50d906fbe4f8469ff7caa760e3a76821c03ee326
```

## Next boundary

The next natural checkpoint is execution orchestration around the already-built batch:

```text
integrity-aware RemVibeDownloadJob
        ↓
submit / wait / cancel
        ↓
verified staging tree
```

That execution layer should still stop before final managed-target publication, replacement/removal, rollback and installation-manifest persistence unless separately approved.
