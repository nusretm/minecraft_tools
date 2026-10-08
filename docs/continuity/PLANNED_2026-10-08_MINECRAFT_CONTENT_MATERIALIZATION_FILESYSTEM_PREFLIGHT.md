# Minecraft Tools — Materialization Filesystem Preflight Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.22 — Materialization Filesystem Preflight Foundation
Branch: feature/minecraft-content-materialization-filesystem-preflight
Baseline main: eb4e4ba70c681ea1ba32ea5caef675229132d128
Initial production/test HEAD: 0bd3ff1f08aed852d2b9475778b6169cd952db26
Corrected production/test HEAD: 244b1150a3e9d633a0bf38a661c6169cd952db26
Validated feature HEAD: 13a6986ec6ea5ba1c646b6e4b0210b68938fe089
Package version: 1.0.0-dev.22
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
```

No `dart format` was run.

## Goal

Inspect whether one already-built materialization plan is physically safe for a concrete local installation root before any filesystem mutation.

```text
pure materialization plan
        ↓
existing installation root
        ↓
read-only filesystem preflight
        ↓
safe / typed issues
```

Dev.22 does not publish files.

## Explicit IO surface

Filesystem behavior is intentionally exported through:

```dart
package:minecraft_content_service/minecraft_content_service_io.dart
```

The generic:

```dart
package:minecraft_content_service/minecraft_content_service.dart
```

remains free of `dart:io`.

The RemVibe surface also remains independent.

## Public types

```text
MtnMinecraftContentMaterializationFileSystem
MtnMinecraftContentMaterializationFileSystemPolicy
MtnMinecraftContentMaterializationFileSystemPlatform
MtnMinecraftContentMaterializationFileSystemPreflight
MtnMinecraftContentMaterializationFileSystemArtifactState
MtnMinecraftContentMaterializationFileSystemEntityType
MtnMinecraftContentMaterializationFileSystemStateScope
MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason
MtnMinecraftContentMaterializationFileSystemManagedArtifactReason
MtnMinecraftContentMaterializationFileSystemPreflightIssue
MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision
MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision
MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath
MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact
MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy
MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink
```

Policy/preflight declarations are physically separated into `part` files while remaining one Dart library so internal construction stays private.

## Installation-root contract

`preflight()` requires:

- an absolute path
- an existing directory

A caller-owned root symbolic link is resolved through `resolveSymbolicLinks()` and the resolved directory becomes the path authority for inspection and future target representation.

The root itself is not rejected merely because the caller selected it through a symlink.

## Platform policy

```text
Windows host
  -> windows
  -> caseSensitive: false

macOS host
  -> posix
  -> caseSensitive: false (conservative default)

other hosts
  -> posix
  -> caseSensitive: true
```

Callers may supply an explicit policy.

This allows tests and known case-sensitive/case-insensitive volumes to avoid hard-coding host assumptions.

## Logical versus physical path identity

Dev.16/dev.17 intentionally keep managed relative-path identity OS-neutral and case-sensitive.

Dev.22 does not change that model.

Instead:

```text
logical plan
        ↓
selected filesystem policy
        ↓
physical identity preflight
```

Case-insensitive policy lower-cases path segments for identity comparison.

The implementation also enumerates physical directory children and compares their names using the selected policy. Therefore a Windows-policy preflight can detect a differently-cased on-disk file even when tests run on a case-sensitive host.

## Managed-state collision checks

Both:

```text
plan.installation
plan.resultingInstallationState
```

are checked.

Two file paths with the same policy identity produce:

```text
MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision
```

A file path that is the ancestor of another managed file path produces:

```text
MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision
```

Example:

```text
mods/a.jar
mods/a.jar/config.json
```

is unsafe.

## Windows path legality

When the Windows policy is selected, each relative-path segment is rejected for:

- trailing dot
- trailing space
- ASCII control characters
- `< > : " / \ | ? *`
- reserved base names such as `CON`, `PRN`, `AUX`, `NUL`, `CONIN$`, `CONOUT$`, `COM1..COM9`, `LPT1..LPT9`

No guessed `MAX_PATH` limit is introduced.

## Physical artifact-state model

Each inspected artifact reports:

```text
artifact
target
physicalPath
entityType
```

Entity states:

```text
missing
file
directory
link
blocked
other
```

`blocked` means inspection could not safely reach the requested final artifact because an ancestor was inaccessible, ambiguous, a symbolic link, or not a directory.

## Current managed artifacts

Current artifacts are inspected before resulting occupancy policy.

Rules:

```text
retain + regular file
  -> OK

retain + missing
  -> managed-artifact issue

replace/remove + missing
  -> allowed

managed path + directory/other
  -> managed-artifact issue

managed path/ancestor + symbolic link
  -> symbolic-link issue

non-directory ancestor
  -> invalid-target-path issue
```

No hash re-verification is introduced here.

## Unmanaged occupancy

For every resulting target:

```text
physical entity exists
AND no current managed artifact owns that target identity
  -> unmanaged occupancy issue
```

The service never adopts or overwrites an unmanaged/manual file merely because it happens to occupy the intended target.

If the target identity is owned by the current managed installation, occupancy is permitted. This includes:

- replacement at the same path
- new install reusing a path released by a managed removal
- case-only reuse under a case-insensitive policy

Wrong-type diagnostics for an owned current path are emitted from current-state inspection rather than duplicated.

## Symbolic links and physical ambiguity

Preflight does not follow symbolic links below the resolved installation root.

Any link encountered in the target chain is a blocker.

The portable authority is what Dart exposes as `FileSystemEntityType.link`; platform-specific reparse implementations not surfaced as links remain outside the generic Dart contract.

When a selected case-insensitive policy observes multiple physical children that map to the same requested segment identity, the path is marked blocked with:

```text
ambiguousPhysicalIdentity
```

## Read-only guarantee

Production code in this checkpoint contains no:

```text
create
delete
rename
write
copy
```

operations.

It uses only read/inspection primitives such as:

```text
resolveSymbolicLinks
Directory.list
FileSystemEntity.type
```

The focused tests also verify fixture content is unchanged by preflight.

## TOCTOU boundary

A preflight result describes the filesystem state observed during inspection.

It cannot guarantee the filesystem remains unchanged afterward.

A future publication/mutation checkpoint must repeat safety-critical ownership/entity checks immediately before mutation.

## Focused test coverage

The new test file contains 12 tests covering:

- absolute/existing root requirement
- resulting-state Windows case collision
- current-state Windows case collision
- POSIX case-sensitive distinction
- resulting file/descendant hierarchy collision
- unmanaged occupancy
- differently-cased unmanaged occupancy under Windows policy
- managed removal-path reuse
- retained-missing versus missing replace/remove behavior
- non-directory ancestor blocker
- Windows-illegal segments
- symbolic-link indirection (where host permits portable link creation)

## Explicitly out of scope

- directory creation
- staging publication
- cross-volume copy
- same-directory promotion
- backup/restore
- removal execution
- multi-artifact transaction ordering
- rollback
- staging cleanup
- manifest filesystem persistence
- TaskService orchestration
- unmanaged/manual cleanup
- resource rendering

## Validation history

First authoritative local validation attempt on feature HEAD `c31d406a564112880e52e4ef6720c1084efecad1` found a compile-time literal bug in the new Windows reserved-device checks:

```text
dart analyze
2 errors

CONIN$ / CONOUT$ were parsed as Dart interpolation
```

Existing focused suites that did not load the new IO file remained green:

```text
content_materialization_plan_test.dart
9/9 passed

content_installation_state_test.dart
8/8 passed

content_installation_manifest_test.dart
9/9 passed

content_download_execution_remvibe_test.dart
7/7 passed

git diff --check main...HEAD
PASS

working tree
clean
```

Correction:

```text
CONIN$  -> r'CONIN$'
CONOUT$ -> r'CONOUT$'
```

Regression coverage also includes:

```text
CONIN$.jar
CONOUT$.jar
```

The corrected production/test tree differs from the validation-attempt tree only by:

```text
minecraft_content_materialization_file_system.dart
2 lines changed (+2/-2)

content_materialization_file_system_preflight_test.dart
1 line changed (+1/-1)
```

Corrected production/test HEAD:

```text
244b1150a3e9d633a0bf38a661c6160ddcd07ac9
```

A connector-side replacement mistake while documenting the $-suffixed names temporarily duplicated the source tail and later triple-duplicated `CURRENT_TARGET.md`. Both were rebuilt from the clean pre-error tree. The final source was compared against the pre-fix source and confirmed to contain only the two raw-string changes above; the regression test contains only the one intended values-list change.

## Final authoritative validation

User-supplied local validation completed successfully on feature HEAD:

```text
13a6986ec6ea5ba1c646b6e4b0210b68938fe089
```

Results:

```text
dart analyze
No issues found!

content_materialization_file_system_preflight_test.dart
12/12 passed

dart test
162/162 passed

git diff --check main...HEAD
PASS

git status
working tree clean
```

No `dart format` was run.

The checkpoint is implementation-complete, actual-diff reviewed, validated and continuity-closed. Merge still requires separate explicit user approval.
