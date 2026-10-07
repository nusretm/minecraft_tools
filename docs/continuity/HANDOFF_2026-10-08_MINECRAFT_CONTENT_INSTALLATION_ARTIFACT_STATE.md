# Minecraft Tools — Managed Installation Artifact State Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.16 — Managed Installation Artifact State Foundation
Branch: feature/minecraft-content-installation-artifact-state
Baseline main: 17bddddc6449302eb6984ceb9ef665abee5b156e
Production/test HEAD: 135d5a41113c7859d819bf2f598a9cd5a72c115a
Validated feature HEAD: 0701ee126b37f3f9c2a30f0fbc52f122650f6b4d
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
PR: #44
Merge commit: 4a5457180f87abd805588fa0f8afa5fe1fe595df
Package version: 1.0.0-dev.16
```

No `dart format` was run.

## Goal

Introduce authoritative managed physical-artifact ownership without starting filesystem execution.

The completed download-plan layer can resolve a desired artifact source, but replace/remove operations must not guess historical installed paths from provider/version metadata.

```text
installed version
        +
exact canonical normalized file
        +
installation-root-relative path
        ↓
MtnMinecraftContentInstallationArtifact
        ↓
MtnMinecraftContentInstallationState
```

## Public surface

```dart
MtnMinecraftContentInstallationArtifact
MtnMinecraftContentInstallationState
```

`MtnMinecraftContentInstallationState.dependencyInstalledState` exposes the existing reconciliation-compatible installed-version view so reconciliation remains unchanged.

## Locked behavior

- Each managed artifact references one installed `MtnMinecraftContentVersion`.
- The artifact file must be the exact canonical object instance contained by that version's `files`.
- The artifact path is relative to a caller-owned installation root.
- Absolute paths are never persisted here.
- Generic code does not hardcode `mods/`, `resourcepacks/`, or any other content directory.
- Empty paths, leading-slash paths, Windows drive prefixes, backslashes, null characters, empty segments, `.`, and `..` segments are rejected.
- Managed installation state rejects duplicate version keys.
- Managed installation state rejects more than one installed version for the same logical content.
- Managed installation state rejects duplicate exact relative artifact paths.
- Artifact ordering is preserved.
- Empty managed installation state is valid.
- Path identity is intentionally exact/case-sensitive at this neutral layer.
- Target-OS case-insensitive/canonical path collision rules remain a later materialization concern.
- Existing dependency installed-state and reconciliation models are reused rather than duplicated or rewritten.

## Deliberately not implemented

- `MtnMinecraftContentList` schema changes
- installation manifest serialization/persistence
- filesystem discovery
- path existence checks
- absolute paths
- target-directory policy
- byte transfer
- launcher DownloadManager/DownloadJob integration
- staging
- hash/size verification
- target-OS collision handling
- safe publication
- replacement/removal execution
- rollback/transactions
- unmanaged/manual artifact cleanup
- deferred resource rendering

## Validation

Authoritative user-supplied local validation on 2026-10-08:

```text
dart analyze
No issues found!

dart test test/content_installation_state_test.dart
8/8 passed

dart test test/content_dependency_reconciliation_test.dart
11/11 passed

dart test test/content_file_selection_test.dart
12/12 passed

dart test test/content_download_plan_test.dart
9/9 passed

dart test
109/109 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
0701ee126b37f3f9c2a30f0fbc52f122650f6b4d
```

The commits after the validated feature HEAD are continuity-only and do not change production or test implementation.

## Next boundary

A later materialization-plan checkpoint can combine:

```text
ReconciliationPlan
        +
DownloadPlan
        +
InstallationState
        ↓
MaterializationPlan
```

That layer may describe target/staging paths, replacement/removal actions, and target-OS collision policy without guessing existing artifact ownership.

Filesystem execution remains separate.
