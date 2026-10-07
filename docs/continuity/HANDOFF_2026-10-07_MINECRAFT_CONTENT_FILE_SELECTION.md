# Minecraft Tools — Minecraft Content File Selection Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-file-selection
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
Pull request:
#42
Baseline main:
6af90fc33e8d27119efa86d6a746a5ee4b6f49de
Validated feature HEAD:
a952582509eb89cd44fe21f5580e26d7d075cdd5
Merged feature HEAD:
899dc2c26cf6f25828bb064b6c1ee04b723237a9
Production/test HEAD:
f68e773cbfe24c9427558fafb0c4008bc9facd63
Merge commit:
b39f9ef5ed7dda2c4e6ab182aead2668f6263230
```

Package version: `1.0.0-dev.14`.

No `dart format` was run.

## Goal

Select the desired physical `MtnMinecraftContentFile` for reconciliation install and replacement targets without performing provider calls, download-source resolution, filesystem operations, or materialization.

Pipeline:

```text
Desired State
    |
    v
Installed-State Reconciliation     COMPLETE
    |
    v
Install / Replace Targets
    |
    v
File Selection                     THIS CHECKPOINT
    |
    v
Download Source Resolution         LATER
    |
    v
Managed Artifact / Materialization LATER
```

## Provider boundary

Generic file selection uses only normalized `MtnMinecraftContentVersion.files` and `MtnMinecraftContentFile` fields.

It does not switch on provider name.

Provider-specific normalization remains inside provider mappers.

Current provider behavior relevant to this checkpoint:

- Modrinth versions may expose multiple files
- the Modrinth mapper already preserves provider primary information and normalizes the first file to primary when the provider supplies no primary file
- CurseForge normalized versions currently expose one primary file
- CurseForge file `downloadUrl` may be null
- these differences do not create provider branches in generic selection

Raw provider file `type` text is not interpreted by core.

## Public surface

Successful selection:

```dart
MtnMinecraftContentFileSelection
```

Surface:

```text
desired
file
```

Issue family:

```text
MtnMinecraftContentFileSelectionIssue
├─ MtnMinecraftContentFileSelectionIssueNoFiles
├─ MtnMinecraftContentFileSelectionIssueAmbiguous
└─ MtnMinecraftContentFileSelectionIssueUnavailable
```

Selection plan:

```dart
MtnMinecraftContentFileSelectionPlan
```

Surface:

```text
reconciliation
selections
issues
selectable
```

Service operation:

```dart
MtnMinecraftContentFileSelectionPlan selectReconciliationFiles(
  MtnMinecraftContentDependencyReconciliationPlan reconciliation,
)
```

Internal selector:

```dart
MtnMinecraftContentFileSelector
```

The selector is synchronous, provider-independent, network-free, and filesystem-free.

## Target boundary

Only reconciliation actions that need a new desired artifact participate:

```text
install      -> select desired file
replacement  -> select replacement desired file
retain       -> no new file selection
remove       -> no file selection
```

Retained versions already represent no physical version change.

Removed versions do not expose authoritative installed physical file/path information in the current managed installed-state model.

The selector therefore does not guess removal artifacts from current version metadata.

## Deterministic target ordering

Install and replacement groups are not processed independently.

The selector walks the complete desired-state order and emits results only for desired versions that belong to install or replacement actions.

Example:

```text
desired:
A replace
B retain
C install
D replace
```

selection target order:

```text
A
C
D
```

This preserves the desired-state authority even when reconciliation stores action categories separately.

## Selection policy

### No files

```text
version.files is empty
-> MtnMinecraftContentFileSelectionIssueNoFiles
```

Selection continues for other targets.

### Exactly one file

```text
version.files.length == 1
available != false
-> select the sole file
```

The file does not need `primary == true`.

If:

```text
available == false
```

the result is:

```text
MtnMinecraftContentFileSelectionIssueUnavailable
```

### Multiple files

For more than one file:

```text
exactly one primary
-> select that file
```

```text
zero primary
-> MtnMinecraftContentFileSelectionIssueAmbiguous
```

```text
multiple primary
-> MtnMinecraftContentFileSelectionIssueAmbiguous
```

The ambiguous issue preserves the complete candidate list in version-file order.

Generic core does not choose the first file as a fallback.

Provider-specific fallback normalization belongs to provider mappers.

### Unavailable selected file

After deterministic candidate selection:

```text
selected.available == false
-> MtnMinecraftContentFileSelectionIssueUnavailable
```

The selector does not fall back from an unavailable selected primary to a non-primary alternative.

## Availability semantics

```text
available == true
-> selectable

available == false
-> unavailable issue

available == null
-> unknown, but selectable
```

Null is not interpreted as false.

## Download URL / integrity metadata boundary

These fields are not file-selection requirements:

```text
downloadUrl
hashes
size
sizeOnDisk
fingerprint
modules
provider metadata
raw file type
```

Therefore:

```text
downloadUrl == null
```

does not make a file unavailable at this layer.

Download-source resolution is a later checkpoint.

Hash and size verification belong to later download/materialization/integrity policy.

## Selection-plan behavior

The selector evaluates every install/replace target and aggregates all selection issues.

It does not throw merely because one target has no selectable file.

```text
selectable == issues.isEmpty
```

This allows callers/UI to display all file-selection blockers at once.

The public plan constructor requires every install/replace target to be represented exactly once by either:

```text
selection
or
issue
```

Selections/issues cannot reference retain/remove targets.

Successful selections must reference a file object owned by their canonical desired version and cannot select `available == false` files.

## Issue invariants

### NoFiles

Requires:

```text
desired.version.files.isEmpty
```

### Ambiguous

Requires:

- at least two candidates
- candidate list exactly matches desired version files in order/object identity
- primary count is not exactly one

Candidate list is immutable.

### Unavailable

Requires:

- file belongs to desired version
- `file.available == false`

## Mutation / immutability boundary

Selection does not mutate:

- reconciliation
- desired state
- versions
- files
- provider metadata

Selection plan collections are immutable.

Ambiguous candidate collections are immutable.

## Tests added

Dedicated file-selection tests cover:

- interleaved replacement / retain / install desired ordering
- retain and remove exclusion from file selection
- sole-file selection without primary
- null availability selection
- exactly-one-primary selection
- no-files issue
- zero-primary ambiguity
- multiple-primary ambiguity
- unavailable sole file
- unavailable primary without non-primary fallback
- null download URL / no hashes / no size as non-blocking
- retain/removal-only reconciliation with no selection work
- immutable selection/issue collections
- immutable ambiguous candidate list

## Deliberately not implemented

- provider API calls
- CurseForge download-URL lookup
- download-source resolution
- download jobs
- filesystem paths
- target directories
- installed file discovery
- removal file lookup
- managed installation manifest
- hash verification
- size verification
- artifact publication
- execution ordering
- transactions
- backup / rollback
- unknown/manual file cleanup
- supplementary artifact-role inference
- extension-based file heuristics
- raw provider file-type interpretation
- `MtnMinecraftContentList` schema changes
- `versionConstraint` interpretation
- automatic conflict winner selection
- deferred item client-definition/model/texture rendering

## Validation

Authoritative user-supplied local validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_file_selection_test.dart
00:00 +12: All tests passed!

dart test test/content_dependency_reconciliation_test.dart
00:00 +11: All tests passed!

dart test test/content_dependency_desired_state_test.dart
00:00 +10: All tests passed!

dart test test/content_dependency_install_policy_test.dart
00:00 +11: All tests passed!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +92: All tests passed!

git diff --check main...HEAD
PASS

git status
On branch feature/minecraft-content-file-selection
Your branch is up to date with 'origin/feature/minecraft-content-file-selection'.
nothing to commit, working tree clean

git rev-parse HEAD
a952582509eb89cd44fe21f5580e26d7d075cdd5
```

No `dart format` was run.

## Post-merge closure

The validated and continuity-closed feature branch was merged through pull request #42.

```text
PR: #42
feature: feature/minecraft-content-file-selection
validated feature HEAD: a952582509eb89cd44fe21f5580e26d7d075cdd5
merged feature HEAD: 899dc2c26cf6f25828bb064b6c1ee04b723237a9
production/test HEAD: f68e773cbfe24c9427558fafb0c4008bc9facd63
merge commit: b39f9ef5ed7dda2c4e6ab182aead2668f6263230
```

The commits after the validated feature HEAD contain continuity-only closeout changes. No production implementation changed after authoritative validation.

## Next action

This checkpoint is implementation-complete, validated, continuity-closed, and merged.

Download-source resolution becomes the likely next checkpoint, but it remains a separate scope and is not automatically approved.
