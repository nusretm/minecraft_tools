# Minecraft Tools — Content Materialization Plan Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.17 — Content Materialization Plan Foundation
Branch: feature/minecraft-content-materialization-plan
Baseline main: 42445d7847af62963afec43b9f18da16337e0b8c
Production/test HEAD: e4c241d83d252ba9ea0ab24184198d63b7faf5a5
Validated feature HEAD: e4c241d83d252ba9ea0ab24184198d63b7faf5a5
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: APPROVED
Package version: 1.0.0-dev.17
```

No `dart format` was run.

## Goal

Combine reconciliation, resolved download sources, managed installed-artifact ownership, and caller-selected final relative targets into one neutral materialization plan without performing filesystem execution.

```text
ReconciliationPlan
        +
DownloadPlan
        +
InstallationState
        +
caller final relative paths
        ↓
MtnMinecraftContentMaterializationPlan
```

## Public surface

```dart
MtnMinecraftContentMaterializationTarget

MtnMinecraftContentMaterializationAction
MtnMinecraftContentMaterializationActionInstall
MtnMinecraftContentMaterializationActionRetain
MtnMinecraftContentMaterializationActionReplace
MtnMinecraftContentMaterializationActionRemove

MtnMinecraftContentMaterializationPlan

MtnMinecraftContentService.planContentMaterialization(...)
```

## Locked behavior

- Planning is synchronous, provider-independent, network-free and filesystem-free.
- A fully downloadable dev.15 download plan is required.
- The exact dev.16 installation state whose `dependencyInstalledState` produced reconciliation is required.
- Every canonical download item must have exactly one canonical materialization target.
- The caller chooses final installation-root-relative paths.
- Target construction reuses dev.16 installation artifact/path validation.
- Generic core does not infer destination directories.
- Install actions own new targets.
- Retain actions preserve the authoritative current artifact.
- Replace actions preserve both the authoritative current artifact and the new target.
- Remove actions preserve the authoritative current artifact to be removed later.
- Action lists are classifications, not filesystem execution order.
- `resultingInstallationState` is derived automatically in complete desired-state order.
- Replace targets may reuse their current path.
- New targets may reuse paths released by remove/replace.
- Exact collisions among resulting managed artifacts are rejected by dev.16 state invariants.
- Path identity remains OS-neutral and case-sensitive at this layer.

## Deliberately not implemented

- `dart:io`
- filesystem discovery/existence checks
- byte transfer
- launcher DownloadJob / DownloadManager adaptation
- staging
- hash/size verification
- target-OS path collision policy
- file copy/rename/delete
- atomic publication
- execution sequencing
- rollback/transactions
- installation manifest persistence
- unmanaged/manual file cleanup
- deferred resource rendering

## Validation

Initial validation found only six `prefer_interpolation_to_compose_strings` lint infos in diagnostic strings. They were corrected without behavioral changes.

Authoritative user-supplied local validation on 2026-10-08:

```text
dart analyze
No issues found!

dart test test/content_materialization_plan_test.dart
9/9 passed

dart test
118/118 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
e4c241d83d252ba9ea0ab24184198d63b7faf5a5
```

Earlier focused validation also passed:

```text
content_installation_state_test.dart
8/8

content_download_plan_test.dart
9/9

content_file_selection_test.dart
12/12

content_dependency_reconciliation_test.dart
11/11
```

## Next boundary

A later execution/materialization checkpoint can consume:

```text
MtnMinecraftContentMaterializationPlan
        ↓
stage/download bytes
verify expected metadata
preflight target-platform collisions
publish new artifacts
remove obsolete managed artifacts
persist resultingInstallationState
```

Execution ordering, safe publication and rollback remain separate design decisions.
