# Minecraft Tools — Single-target Safe Publication Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.23 — Single-target Safe Publication Foundation
Branch: feature/minecraft-content-single-target-publication
Baseline main: 58f598e2d43ecd1c75a49c83c88de4f8091e3feb
Production/test HEAD: eba5888e36847ca504cac59ea26a28ab49e0bed0
Package version: 1.0.0-dev.23
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
```

No `dart format` was run.

## Goal

Safely publish one already-downloaded content artifact into one canonical materialization target without yet orchestrating the complete materialization plan.

```text
safe filesystem preflight
        ↓
single canonical target
        ↓
caller-owned source
        ↓
reversible publication
```

## Public IO surface

The feature remains available through:

```dart
package:minecraft_content_service/minecraft_content_service_io.dart
```

Public additions are provided by the same filesystem library:

```text
MtnMinecraftContentMaterializationFileSystemPublication
MtnMinecraftContentMaterializationFileSystemPublicationState
MtnMinecraftContentMaterializationFileSystemPublicationFailure
MtnMinecraftContentMaterializationFileSystemPublicationException
MtnMinecraftContentMaterializationFileSystemPublicationOperations
```

Main calls:

```dart
final publication = await fileSystem.publish(
  preflight: preflight,
  target: target,
  source: source,
);

await fileSystem.commit(publication);
// or:
await fileSystem.rollback(publication);
```

## Physical separation

The existing dev.22 filesystem implementation body remains unchanged.

New wiring in the main filesystem library is limited to:

- `dart:async`
- internal shared integrity import
- publication model part
- publication operations part

Publication declarations are split into:

```text
minecraft_content_materialization_file_system_publication.dart
minecraft_content_materialization_file_system_publication_operations.dart
```

Provider-neutral integrity is physically separate at:

```text
lib/src/integration/minecraft_content_file_integrity.dart
```

It is not exported as a new generic public package surface.

## Source ownership

Publication takes a caller-owned `File source`.

Rules:

- source must be a regular file
- symbolic-link sources are rejected by publication before copy
- source must not alias the managed target
- source is opened only for reading
- publication never deletes, renames or writes source
- source cleanup remains orchestration/downloader responsibility

## Cross-volume publication

The source is never directly renamed into the installation.

Instead:

```text
source
  ↓ stream copy
target-parent/.mtn-content-staging-...
  ↓ verification
same-parent rename
target
```

This removes any requirement for source staging and the installation root to be on the same filesystem volume.

## Integrity

The dev.20 RemVibe integrity implementation was factored into a provider-neutral internal authority.

RemVibe keeps its existing public adapter:

```text
MtnMinecraftContentDownloadIntegrityRemVibe
MtnMinecraftContentDownloadIntegrityException
```

and still exposes:

```text
expectedSize
checksums
validate(File)
```

Supported canonical metadata remains:

- MD5
- SHA-1
- SHA-256
- SHA-512
- optional hyphen aliases for SHA algorithms
- expected size

Unknown provider-specific algorithms remain ignored.

Conflicting aliases and malformed supported hashes remain blocking format errors.

Publication revalidates canonical metadata against its own same-parent staging copy immediately before target mutation.

When canonical size/hash metadata is completely absent, publication calculates a transient SHA-256 snapshot solely to ensure:

```text
source snapshot == sibling staging
published target == published staging before commit/rollback
```

This transient digest is not written back to content metadata or manifests.

## Stale-preflight enforcement

Publication requires:

- `preflight.safe == true`
- the exact canonical install/replacement target represented by the preflight plan
- the same filesystem policy as the filesystem authority

Before mutation it rechecks:

- installation root still resolves to the preflight root
- target still has the preflight-observed missing/file state
- an existing managed target still has the same policy-normalized physical identity

The target state is checked once before parent creation and again after source copy immediately before target mutation.

## Parent creation

Missing target parents are processed segment-by-segment.

For each segment:

```text
existing directory
  -> continue

missing
  -> create one directory
  -> re-resolve and require one regular directory

link / file / ambiguous / inaccessible
  -> fail
```

Only directories definitely created by this publication are recorded.

On failed publication they are removed best-effort in reverse order using non-recursive deletion, so externally populated directories are not recursively removed.

## Same-target serialization

Publication uses a library-wide target queue keyed from:

```text
resolved installation root
+
selected filesystem platform/case policy
+
policy-normalized relative target path
```

A successful publication retains its target lock while its handle remains pending.

The lock is released only by:

- commit
- rollback
- publication failure before a handle is returned

Therefore two cooperating publication authorities cannot mutate the same logical target while the first transaction still owns recovery state.

Different targets are not globally serialized.

## Existing target publication

If preflight observed a managed regular file at the target:

```text
current target
  ↓ rename
target-parent/.mtn-content-backup-...

verified sibling staging
  ↓ rename
target
```

The backup is retained by the returned publication handle.

It is not deleted by `publish()`.

## Missing target publication

If preflight observed a missing target:

```text
verified sibling staging
  ↓ rename
target
```

No backup is created.

Publication-created parent directories are retained while the publication is pending.

## Commit

Commit:

1. requires the creating filesystem authority
2. requires pending or already-committed state
3. revalidates the published target
4. refuses to delete a backup path that has become an unexpected entity type
5. deletes the owned backup when present
6. marks the handle committed
7. releases the same-target lock

Repeated commit after success is idempotent.

Rollback after commit is rejected.

## Rollback

Rollback:

1. requires the creating filesystem authority
2. revalidates the published target
3. requires a replacement backup to still be a regular file
4. moves the published target to a temporary rollback sibling
5. restores the previous managed backup when present
6. preserves recovery candidates if restoration fails
7. removes the displaced new file after successful replacement restoration
8. for originally missing targets, removes the displaced published file and publication-created empty parents
9. marks the handle rolled back
10. releases the same-target lock

Repeated rollback after success is idempotent.

Commit after rollback is rejected.

## Finalization tamper protection

Before commit or rollback:

- canonical metadata is revalidated when available
- metadata-less publication uses its transient SHA-256 plus length snapshot

If the published target changed externally, finalization refuses to destroy backup/recovery state.

## Failure recovery

Before final promotion:

- source/copy/integrity/preflight failures leave the public target untouched
- owned sibling staging is cleaned best-effort
- owned newly-created empty parent directories are cleaned best-effort

For an existing managed target:

- backup-rename failure leaves the original target in place
- promotion failure attempts immediate backup restore
- if restore also fails, backup and staging recovery candidates are preserved and exposed through `MtnMinecraftContentMaterializationFileSystemPublicationException`

Owned empty placeholder files used to reserve backup/rollback names are best-effort cleaned when placeholder preparation itself fails.

## Portable external-race limitation

The implementation repeats target state inspection immediately before mutation and serializes all cooperating same-target publication calls.

However, portable Dart `File.rename` does not expose an atomic no-replace option.

Therefore a non-cooperating external process can theoretically create/replace the target in the narrow interval between the final check and rename on a platform where rename replaces an existing destination.

This is an explicitly documented residual boundary, not treated as solved by preflight.

A native filesystem backend can tighten this later if required.

## Focused test coverage

The publication test currently contains 14 tests covering:

- missing-target publish + commit
- missing-target rollback + created-parent cleanup
- replacement backup + rollback restore
- replacement commit + backup cleanup
- canonical integrity failure cleanup
- stale missing target becoming occupied
- stale non-directory parent
- missing/symbolic-link source rejection
- source/target alias rejection
- canonical target identity requirement
- same-target lock retained until finalization
- external target tamper blocks commit/rollback and preserves recovery
- finalization authority ownership
- metadata-less transient integrity and finalization tamper detection

Existing dev.20 RemVibe integrity tests remain required regression coverage for the internal integrity extraction.

## Explicitly out of scope

- whole-plan publication loops
- remove execution
- multi-artifact transaction ordering
- multi-artifact rollback
- installation-manifest filesystem persistence
- RemVibe batch-to-publication orchestration
- staging-root cleanup
- TaskService orchestration
- unmanaged/manual cleanup
- resource rendering

## Authoritative validation

User-supplied local validation completed successfully on feature HEAD:

```text
494fc3769267d5a0366eefc7d249aec2ab853174
```

Results:

```text
dart pub get
PASS

dart analyze
No issues found!

content_materialization_file_system_publication_test.dart
14/14 passed

content_materialization_file_system_preflight_test.dart
12/12 passed

content_download_integrity_remvibe_test.dart
9/9 passed

content_download_execution_remvibe_test.dart
7/7 passed

content_materialization_plan_test.dart
9/9 passed

content_installation_manifest_test.dart
9/9 passed

dart test
176/176 passed

git diff --check main...HEAD
PASS

git status
working tree clean
```

No `dart format` was run.

The checkpoint is implementation-complete, actual-diff reviewed, validated and continuity-closed. Merge still requires separate explicit user approval.

## Historical validation command set

Run from `minecraft_content_service/`:

```text
dart pub get
dart analyze

dart test test/content_materialization_file_system_publication_test.dart
dart test test/content_materialization_file_system_preflight_test.dart
dart test test/content_download_integrity_remvibe_test.dart
dart test test/content_download_execution_remvibe_test.dart
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

Expected production/test HEAD before the continuity-only commit:

```text
eba5888e36847ca504cac59ea26a28ab49e0bed0
```

Do not merge without separate explicit user approval.
