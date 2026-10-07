# Minecraft Tools — Minecraft Content Installed-State Reconciliation Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-installed-state-reconciliation
Implementation: COMPLETE
Validation: PENDING USER-SUPPLIED LOCAL DART VALIDATION
Continuity: OPEN UNTIL VALIDATION
Merge: NOT REQUESTED
Baseline main:
d6d79f3dcdaf2fa92104871fbde554c65682cc98
Production/test HEAD:
e266c2a83fc88fd450892ddc1051ed559a219b00
```

Package version: `1.0.0-dev.13`.

No `dart format` was run.

## Goal

Compare one complete installable dependency desired state with the service-managed current installed state and produce an immutable pure reconciliation plan.

This checkpoint answers:

```text
what should change?
```

It does not answer:

```text
which files should be selected?
how should filesystem operations be ordered?
how should rollback work?
```

Pipeline:

```text
Dependency Install Plans
        |
        v
Desired State                 COMPLETE
        +
Managed Installed State       THIS CHECKPOINT INPUT
        |
        v
Reconciliation Plan           THIS CHECKPOINT OUTPUT
        |
        v
Artifact / File Selection     LATER
        |
        v
Execution / Materialization   LATER
```

## Public surface

Installed state:

```dart
MtnMinecraftContentDependencyInstalledState
```

Surface:

```text
versions
```

The model contains only versions known to be managed by `minecraft_content_service`.

Unknown/manual filesystem content is not represented implicitly.

Replacement result:

```dart
MtnMinecraftContentDependencyReconciliationReplacement
```

Surface:

```text
current
desired
```

Reconciliation result:

```dart
MtnMinecraftContentDependencyReconciliationPlan
```

Surface:

```text
current
desired
installs
retains
replacements
removals
changesRequired
```

Service operation:

```dart
MtnMinecraftContentDependencyReconciliationPlan reconcileDependencyState(
  MtnMinecraftContentDependencyInstalledState current,
  MtnMinecraftContentDependencyDesiredState desired,
)
```

The internal reconciler is:

```dart
MtnMinecraftContentDependencyReconciler
```

## Installed-state invariants

Installed state copies and exposes an immutable version list.

The list requires:

```text
version.key unique
content.key unique
```

Therefore the current state cannot claim two installed versions for the same logical content.

It also cannot contain the same global version key twice.

Current state is intentionally narrower than `MtnMinecraftContentList`.

## Why MtnMinecraftContentList is not the current-state authority

`MtnMinecraftContentList` is generic content/version/relation persistence.

Its `content.version` behavior can fall back to `versions.last` when no explicit version is selected.

That does not prove which artifact is currently installed.

Also:

```text
MtnMinecraftContentRelation.included / embedded
```

represents persisted physical/ownership relations and is not automatically equivalent to dependency-root ownership from the desired-state planner.

This checkpoint therefore does not add:

```dart
installedStateFromContentList(...)
```

and does not change the content-list schema.

A future explicit instance persistence/discovery adapter can construct `MtnMinecraftContentDependencyInstalledState` when that source has authoritative installed-version knowledge.

## Reconciliation identity

Logical matching is performed by:

```text
version.content.key
```

Exact retained-version identity is:

```text
current.version.key == desired.version.key
```

Policy:

```text
desired content absent from current
  -> install

desired content present with same version.key
  -> retain

desired content present with different version.key
  -> replace

current content absent from desired
  -> remove
```

## Replace is intentionally neutral

Generic reconciliation does not parse or order version strings.

Therefore both:

```text
v1 -> v2
v2 -> v1
```

are:

```text
replace
```

The generic layer does not call one update and the other downgrade.

## Desired-state authority

The desired state is the complete instance-wide target assembled from all direct/root plans.

The reconciler does not use current `MtnMinecraftContentVersion.direct` as keep/remove authority.

Example:

```text
current:
A-v1 direct=true

desired:
empty
```

Result:

```text
remove A-v1
```

because current state contains only service-managed content and the complete desired state no longer wants A.

Likewise, ownership-only metadata changes do not force artifact replacement.

Example:

```text
current:
B-v1 dependency

desired:
B-v1 direct
```

Result:

```text
retain B-v1
```

The retained desired entry carries the new desired ownership/direct metadata.

No input version object is mutated.

## Invalid desired state

Reconciliation requires:

```text
desired.installable == true
```

Otherwise:

```text
StateError
```

This prevents destructive partial reconciliation from a target that still contains unresolved required dependencies or install conflicts.

Blocker details remain available through the desired state and its source plans.

## Cross-state identity safety

`version.key` is global graph identity.

If the same version key refers to different logical content across current and desired states:

```text
current:
version.key = shared
content.key = A

desired:
version.key = shared
content.key = B
```

reconciliation throws `StateError`.

It does not reinterpret this as install/remove/replace.

The reconciler also rejects a manually malformed installable desired state that contains more than one desired version for the same logical `content.key`.

## Ordering

Classification ordering is deterministic:

```text
installs       -> desired-state order
retains        -> desired-state order
replacements   -> desired-state order
removals       -> current-state order
```

These lists describe required state differences.

They are not an execution sequence.

Filesystem ordering, temporary coexistence, remove-before-install decisions, transactionality, backup and rollback are later concerns.

## Reconciliation-plan invariants

The public reconciliation-plan constructor requires:

- desired actions do not overlap
- current actions do not overlap
- install/retain/replacement desired actions cover the entire desired state
- retain/replacement/removal current actions cover the entire installed state

Replacement requires:

```text
current.content.key == desired.version.content.key
current.key != desired.version.key
```

All exposed action collections are immutable.

`changesRequired` is true when any install, replacement, or removal exists.

Pure retain-only reconciliation returns:

```text
changesRequired == false
```

## Empty-state behavior

Empty current state is valid.

All desired versions become installs.

Empty desired state is valid.

All managed current versions become removals.

Both empty produces no changes.

## Tests added

Dedicated reconciliation tests cover:

- deterministic install/retain/replace/remove classification
- desired-order and current-order preservation
- neutral downgrade replacement
- ownership/direct metadata change without physical replacement
- current `direct` not overriding complete desired state
- empty current state
- empty desired state and full managed removal
- duplicate installed version-key rejection
- duplicate installed logical-content rejection
- invalid desired-state rejection
- cross-state same-version-key/different-content rejection
- malformed installable desired-state duplicate-content rejection
- installed input copying
- immutable result collections
- replacement constructor invariants

## Deliberately not implemented

- filesystem discovery
- unknown/manual jar cleanup
- unmanaged content deletion
- `MtnMinecraftContentList` installed-state adapter
- content-list schema migration
- artifact/file selection
- file/path planning
- hashes/integrity checks
- downloads
- real install/remove/replace execution
- execution ordering
- transactions
- backup/rollback
- enable/disable state
- provider/API calls
- `versionConstraint` interpretation
- automatic conflict winner selection
- cross-provider association
- deferred item client-definition/model/texture rendering

## Validation

Authoritative local validation is pending.

Required validation:

```text
cd D:\development\cross-platform\minecraft_tools\minecraft_content_service

dart analyze
dart test test/content_dependency_reconciliation_test.dart
dart test test/content_dependency_desired_state_test.dart
dart test test/content_dependency_install_policy_test.dart
dart test test/content_provider_service_test.dart
dart test

cd ..
git diff --check main...HEAD
git status
git rev-parse HEAD
```

Per repository rules, user-supplied local Dart output is authoritative.

Do not mark this checkpoint VALIDATED or continuity-closed until those results are supplied.

## Next action

Run authoritative local validation on the feature branch.

If validation fails, fix only this approved installed-state reconciliation checkpoint.

If validation passes, record the supplied results here and in `docs/continuity/CURRENT_TARGET.md`, close continuity, and wait for separate explicit merge approval.

Artifact/file selection and execution/materialization remain separate later checkpoints and are not automatically approved.
