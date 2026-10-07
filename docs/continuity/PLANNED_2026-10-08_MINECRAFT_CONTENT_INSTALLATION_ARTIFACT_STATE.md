# Minecraft Tools — Managed Installation Artifact State Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.16 — Managed Installation Artifact State Foundation
Branch: feature/minecraft-content-installation-artifact-state
Baseline main: 17bddddc6449302eb6984ceb9ef665abee5b156e
Production/test HEAD: 135d5a41113c7859d819bf2f598a9cd5a72c115a
Package version: 1.0.0-dev.16
Implementation: COMPLETE
Validation: PENDING
Merge: NOT REQUESTED
```

No `dart format` was run.

## Why this checkpoint exists

The completed download-plan layer can resolve the new selected artifact source, but reconciliation still represents current installed content only as versions.

For replacement/removal, generic code must not guess an old physical filename/path from provider version metadata.

```text
current version
        ≠
authoritative installed physical artifact path
```

This checkpoint introduces that ownership boundary without starting filesystem execution.

## Public surface

```dart
MtnMinecraftContentInstallationArtifact
MtnMinecraftContentInstallationState
```

An installation artifact owns:

```text
installed version
exact canonical selected file
installation-root-relative path
```

Installation state owns an immutable collection of those artifacts and exposes:

```dart
state.dependencyInstalledState
```

as the existing reconciliation-compatible version view.

## Canonical file rule

The artifact's `file` must be the exact object instance contained by `version.files`.

Equivalent-but-separately-created metadata is not accepted.

This preserves the same canonical-reference discipline used by desired state, reconciliation, and file selection.

## Relative path boundary

The state stores only a neutral path relative to a caller-owned installation root.

Examples of valid shapes:

```text
mods/example.jar
resourcepacks/example.zip
managed/content/example.jar
```

These examples are caller decisions. The generic service does not select a destination directory.

Rejected paths include:

- empty paths
- leading-slash absolute paths
- Windows drive-prefixed paths
- backslash-separated paths
- `.` / `..` traversal segments
- empty path segments
- null characters

No filesystem normalization or existence access occurs.

## Ownership invariants

A managed installation state rejects:

- duplicate `version.key`
- more than one installed version for the same logical `content.key`
- duplicate exact relative artifact paths

Artifact order is preserved.

An empty managed installation is valid.

## OS boundary

Relative path identity is exact and case-sensitive at this generic layer.

Therefore:

```text
mods/A.jar
mods/a.jar
```

are distinct here.

A Windows-target materialization layer must later reject case-insensitive collisions before filesystem mutation. Linux/macOS policy remains target-specific rather than being guessed by this neutral state model.

## Reconciliation boundary

The existing:

```dart
MtnMinecraftContentDependencyInstalledState
```

and reconciliation algorithm remain unchanged.

The installation state creates that existing installed-version view from its managed artifact ordering.

This avoids duplicating install/retain/replace/remove classification logic.

## Explicitly out of scope

- `MtnMinecraftContentList` schema changes
- installation manifest persistence
- filesystem discovery
- file existence checks
- absolute paths
- target directory selection
- download manager integration
- byte transfer
- staging
- hash verification
- size verification
- file publication
- replace/remove filesystem execution
- rollback/transactions
- unmanaged/manual artifact cleanup
- target-OS case/canonical path rules
- resource/item rendering

## Intended next architecture

After this checkpoint is validated, a later materialization-plan checkpoint can combine:

```text
ReconciliationPlan
        +
DownloadPlan
        +
InstallationState
        ↓
MaterializationPlan
```

That later plan may describe downloads, retained artifacts, replacements, and removals without guessing historical paths.

Actual byte execution remains separate.

## Validation required

Run from `minecraft_content_service/`:

```text
dart analyze
dart test test/content_installation_state_test.dart
dart test test/content_dependency_reconciliation_test.dart
dart test test/content_file_selection_test.dart
dart test test/content_download_plan_test.dart
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
135d5a41113c7859d819bf2f598a9cd5a72c115a
```

Do not merge without separate explicit user approval.
