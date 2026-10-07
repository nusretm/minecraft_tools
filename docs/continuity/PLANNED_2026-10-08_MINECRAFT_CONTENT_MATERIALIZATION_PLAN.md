# Minecraft Tools — Content Materialization Plan Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.17 — Content Materialization Plan Foundation
Branch: feature/minecraft-content-materialization-plan
Baseline main: 42445d7847af62963afec43b9f18da16337e0b8c
Production/test HEAD: 66a6876d963a55d744dfab64a000d1c665cd2539
Package version: 1.0.0-dev.17
Implementation: COMPLETE
Validation: PENDING
Merge: NOT REQUESTED
```

No `dart format` was run.

## Goal

Combine the completed reconciliation, download-source planning, and managed installation-artifact state into one neutral physical-change plan without performing filesystem execution.

```text
ReconciliationPlan
        +
DownloadPlan
        +
InstallationState
        +
caller-owned final relative targets
        ↓
MaterializationPlan
```

The checkpoint answers:

- which new managed artifacts are installs
- which existing managed artifacts are retained
- which existing artifacts are replaced by which new targets
- which existing artifacts are removed
- what the managed installation state should be after successful execution

It does not perform those actions.

## Public surface

```dart
MtnMinecraftContentMaterializationTarget

MtnMinecraftContentMaterializationAction
├─ MtnMinecraftContentMaterializationActionInstall
├─ MtnMinecraftContentMaterializationActionRetain
├─ MtnMinecraftContentMaterializationActionReplace
└─ MtnMinecraftContentMaterializationActionRemove

MtnMinecraftContentMaterializationPlan

MtnMinecraftContentService.planContentMaterialization(...)
```

## Materialization target

A target is created from:

```text
canonical MtnMinecraftContentDownloadItem
        +
caller-provided final relativePath
        ↓
canonical desired version
canonical selected file
        +
dev.16 path validation
        ↓
MtnMinecraftContentInstallationArtifact
```

The caller chooses the final relative path.

The generic content service does not infer destination directories from content type, provider, file extension, loader, or filename.

## Canonical chain

Planning requires:

```text
download.selection.reconciliation.current
        ===
installation.dependencyInstalledState
```

by object identity.

Every materialization target must reference the exact canonical download item contained in the supplied download plan.

This prevents independently reconstructed lookalike plans/states from being mixed.

## Action semantics

### Install

Contains the new materialization target for a canonical reconciliation install entry.

### Retain

Contains:

- the canonical desired retain entry
- the authoritative current installation artifact

No new target/download is created.

### Replace

Contains:

- the canonical reconciliation replacement
- the authoritative current installation artifact
- the new materialization target

The plan deliberately does not prescribe whether execution deletes, renames, stages or publishes first.

### Remove

Contains the authoritative current installation artifact selected by reconciliation.

## Resulting installation state

`MtnMinecraftContentMaterializationPlan.resultingInstallationState` is derived automatically.

Ordering follows the complete desired-state order, not grouped action-list order.

For every desired version:

- install -> new target artifact
- retain -> current installed artifact
- replace -> new target artifact

Removal artifacts do not appear in the resulting state.

This resulting state is the state that a later executor may persist only after successful materialization.

## Path reuse and collision policy

Because the resulting state is built after reconciliation semantics are applied:

- a replacement may reuse its old exact path
- a new install may reuse a path released by a removal
- a new target may not collide with a retained/resulting artifact
- duplicate exact resulting relative paths are rejected through dev.16 installation-state invariants

Path identity remains exact and case-sensitive in this neutral layer.

Therefore:

```text
mods/A.jar
mods/a.jar
```

remain distinct here.

Target-platform policy, including Windows case-insensitive collision handling, belongs to a later filesystem/materialization execution layer.

## Ordering boundary

The four action lists preserve their source reconciliation category order.

They are classifications, not an execution sequence.

Dev.17 does not decide ordering such as:

```text
download -> verify -> delete old -> publish new
```

or:

```text
stage all -> preflight -> publish replacements -> remove stale
```

That is a later execution design.

## Explicitly out of scope

- `dart:io`
- filesystem discovery
- filesystem existence checks
- actual byte transfer
- launcher DownloadJob / DownloadManager integration
- staging paths/directories
- hash verification
- size verification
- target-OS path canonicalization/collision policy
- file copy
- file rename
- file deletion
- atomic/safe publication
- execution ordering
- rollback
- transactions
- installation-manifest serialization/persistence
- unmanaged/manual file cleanup
- resource/item rendering

## Validation required

Run from `minecraft_content_service/`:

```text
dart analyze
dart test test/content_materialization_plan_test.dart
dart test test/content_installation_state_test.dart
dart test test/content_download_plan_test.dart
dart test test/content_file_selection_test.dart
dart test test/content_dependency_reconciliation_test.dart
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
66a6876d963a55d744dfab64a000d1c665cd2539
```

Do not merge without separate explicit user approval.
