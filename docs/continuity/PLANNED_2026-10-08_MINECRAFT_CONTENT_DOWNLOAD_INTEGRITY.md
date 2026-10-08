# Minecraft Tools — Content Download Integrity Validator Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.20 — Content Download Integrity Validator Foundation
Branch: feature/minecraft-content-download-integrity
Baseline main: cf1205d38502fa7cb56c851dd7804a70bc1b9085
Production/test HEAD: c66cbe6716aa6f6a5fffb39c274e6e94e304d5cf
Package version: 1.0.0-dev.20
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Validated feature HEAD: 50d906fbe4f8469ff7caa760e3a76821c03ee326
Merge: COMPLETE
PR: #48
Merge commit: a5c7c2adfc8fd2b38c82034733c34176aba91bca
```

No `dart format` was run.

## Goal

Validate downloaded content bytes against expected canonical file metadata before RemVibe promotes its temporary download into the staging destination.

```text
MtnMinecraftContentMaterializationTarget
        ↓
target.artifact.file
        ├─ size
        └─ hashes
        ↓
MtnMinecraftContentDownloadIntegrityRemVibe
        ↓
RemVibeDownloadItem.validator
        ↓
temporary .download file
```

## RemVibe lifecycle evidence

The reusable RemVibe download service:

1. streams bytes into a temporary `.download` file
2. updates transfer byte count / item size from the actual response
3. calls `RemVibeDownloadItem.validator` with the temporary file
4. only after validator success removes/replaces the staging destination
5. deletes the temporary file and enters normal retry/error behavior when validator throws

Therefore the validator is the correct pre-publication integrity boundary for the staging download.

## Expected-size authority

`RemVibeDownloadItem.size` is not the expected-size authority after transfer because RemVibe updates it from response/received bytes before invoking the validator.

Dev.20 captures expected size from:

```text
target.artifact.file.size
```

inside the integrity policy before transfer starts.

Validation compares:

```text
captured expected size
vs
temporary File.length()
```

## Supported checksums

Supported canonical algorithms:

```text
md5
sha1
sha256
sha512
```

Accepted aliases:

```text
sha-1   -> sha1
sha-256 -> sha256
sha-512 -> sha512
```

Digest rules:

- exact hexadecimal length is required for supported algorithms
- uppercase/lowercase hexadecimal is accepted
- normalized expectation is lowercase
- duplicate aliases with equal normalized digest are accepted
- duplicate aliases with conflicting digests fail fast

Expected lengths:

```text
md5    32 hex
sha1   40 hex
sha256 64 hex
sha512 128 hex
```

## Unknown algorithms

Unknown/provider-specific checksum algorithms are not execution blockers.

Example:

```text
curseforge:99
```

Such metadata remains preserved in the normalized content model but is ignored by dev.20 verification.

This allows future providers to carry opaque integrity metadata without causing generic download failures.

Supported algorithm names with malformed digest values are different: they fail fast because the package claims to understand their semantics.

## Verification matrix

```text
expected size + supported checksum(s)
  -> size AND every supported checksum must pass

expected size only
  -> size must pass

supported checksum(s) only
  -> every supported checksum must pass

unknown hashes only + no size
  -> no executable integrity policy / validator null

no size + no hashes
  -> no executable integrity policy / validator null
```

## Single-pass hashing

When multiple supported checksums are required, the staged file is opened once.

Each streamed byte chunk is forwarded to all active digest sinks:

```text
File.openRead()
   ├─ md5
   ├─ sha1
   ├─ sha256
   └─ sha512
```

This avoids one full file read per algorithm.

## Public RemVibe integration surface

New types:

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

`MtnMinecraftContentDownloadAdapterRemVibeItem` now also exposes its exact nullable `integrity` policy.

The generic public library remains:

```dart
package:minecraft_content_service/minecraft_content_service.dart
```

and does not export this filesystem/RemVibe integration behavior.

RemVibe-aware callers use:

```dart
package:minecraft_content_service/minecraft_content_service_remvibe.dart
```

## Adapter integration

Dev.19 item creation becomes:

```text
canonical target file metadata
        ↓
integrity policy or null
        ↓
RemVibeDownloadItem(
  size: canonical expected size,
  validator: integrity?.validate,
)
```

The `size` field remains useful to RemVibe for initial progress metadata, but integrity uses its separately captured expected size.

## Dependency

Dev.20 adds:

```yaml
crypto: ^3.0.7
```

for MD5/SHA digest implementations and chunked conversion.

## Explicitly out of scope

- `RemVibeDownloadService.start()`
- `RemVibeDownloadService.addJob()`
- waiting for job completion
- cancellation orchestration
- final managed-target publication
- replacement/removal execution
- target-platform case collision policy
- staging cleanup policy
- rollback/transaction behavior
- manifest file location/read/write
- atomic installation-manifest publication
- RemVibeTaskService orchestration
- unmanaged/manual file cleanup
- resource/item rendering

## Validation

Authoritative user-supplied local validation completed successfully on 2026-10-08 at feature HEAD `50d906fbe4f8469ff7caa760e3a76821c03ee326`:

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

full dart test
143/143 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
50d906fbe4f8469ff7caa760e3a76821c03ee326
```

No `dart format` was run.

The checkpoint is implementation-complete, actual-diff reviewed, validated, continuity-closed, and merged through PR #48 at merge commit `a5c7c2adfc8fd2b38c82034733c34176aba91bca`.
