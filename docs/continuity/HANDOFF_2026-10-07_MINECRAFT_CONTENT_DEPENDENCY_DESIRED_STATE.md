# Minecraft Tools — Minecraft Content Dependency Desired State Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-desired-state
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: COMPLETE
Pull request:
#40
Baseline main:
28bc28c42feaec81013aebcb738d60fafbaaacfd
Validated feature HEAD:
d97e9bf00a640c812a3a21d0aa3ac450873c057f
Merged feature HEAD:
a35a8a25bec1a9fe0ae7fdd4a1676f489f42f46e
Production/test HEAD:
035df4bf9db4e4b95709e08e515499c3e3565062
Merge commit:
322bdf08325ae8a4c714bd9d84b2c127c27ab24b
```

Package version: `1.0.0-dev.12`.

No `dart format` was run.

## Goal

Compose multiple direct/root dependency install plans into one immutable instance-wide desired state before installed-state reconciliation.

This checkpoint solves ownership and cross-root consistency.

It does not inspect the current filesystem or installed instance.

Pipeline:

```text
Identity Resolution                 COMPLETE
Version Selection                   COMPLETE
Recursive Dependency Graph          COMPLETE
Dependency Semantic Normalization   COMPLETE
Install / Conflict Policy           COMPLETE
        |
        v
Multi-Root Desired State            THIS CHECKPOINT
        |
        v
Installed-State Reconciliation      LATER
        |
        v
Artifact / File Selection           LATER
        |
        v
Download / Materialization          LATER
```

## Why this checkpoint exists

A single-root install plan cannot safely decide removal from an instance containing several direct roots.

Example:

```text
A direct
└─ B dependency

X direct
└─ C dependency
```

Recomputing only A must not make C look orphaned while X still owns it.

Installed-state reconciliation therefore requires one instance-wide desired state that knows every direct root and every dependency ownership relationship.

## Public surface

New desired-version model:

```dart
MtnMinecraftContentDependencyDesiredVersion
```

Surface:

```text
version
roots
direct
```

`direct` is derived from ownership:

```text
true when one of roots has the same version.key as version
```

No `MtnMinecraftContentVersion.direct` mutation is performed.

New desired-state model:

```dart
MtnMinecraftContentDependencyDesiredState
```

Surface:

```text
plans
directVersions
versions
installVersions
conflicts
installable
```

New service operation:

```dart
MtnMinecraftContentDependencyDesiredState composeDependencyInstallPlans(
  Iterable<MtnMinecraftContentDependencyInstallPlan> plans,
)
```

The internal composer is:

```dart
MtnMinecraftContentDependencyDesiredStateComposer
```

## Input plan authority

Every input plan represents one direct/root desired version.

Plans preserve caller input order.

A root `version.key` may appear only once in the input plan list.

Duplicate install plans for the same root version key throw `ArgumentError`.

Different versions of the same logical content are not rejected at input validation. They are represented and evaluated as cross-root multiple-version conflicts.

Invalid/root-local plans are accepted so their blockers remain observable through `state.plans`.

## Canonical desired version identity

Desired versions are canonicalized by:

```text
MtnMinecraftContentVersion.key
```

The first exact version object encountered in plan order / install-version order becomes the canonical desired object for that key.

Later occurrences of the same key extend ownership but do not replace the canonical object.

Example:

```text
Plan A:
A
B
D

Plan X:
X
C
D
```

Desired install order:

```text
A
B
D
X
C
```

D is stored once.

## Root ownership

Every desired version records all direct roots whose install plans contain that version.

Example:

```text
A direct
├─ B
└─ D

X direct
├─ C
└─ D
```

Desired ownership:

```text
A roots=[A]    direct=true
B roots=[A]    direct=false
D roots=[A,X]  direct=false
X roots=[X]    direct=true
C roots=[X]    direct=false
```

If B is also supplied as its own direct/root plan:

```text
B roots=[A,B]
B direct=true
```

When the same `version.key` appears first as a dependency object and later as a root object, the first canonical version object is preserved and becomes the canonical direct version.

The source version objects are not mutated.

## Empty desired state

Zero plans are valid.

The result contains empty immutable collections and:

```text
installable == true
```

This is required for future reconciliation scenarios where all managed content should be removed.

## Desired-state conflicts versus plan-local blockers

The desired state intentionally preserves two levels of failure information.

Root-local failures remain inside the source install plans:

```text
plan.unresolvedInstallEdges
plan.conflicts
plan.installable
```

The desired state's own:

```text
state.conflicts
```

contains composition-level cross-root conflicts.

Therefore:

```text
state.installable ==
  every input plan is installable
  AND
  state.conflicts is empty
```

A root-local conflict is not duplicated into `state.conflicts` when only one root owns the conflicting versions/rule.

## Cross-root multiple-version conflict

After canonical union, distinct versions of the same logical content are evaluated using the existing install conflict model:

```dart
MtnMinecraftContentDependencyInstallConflictMultipleVersions
```

The conflict becomes a desired-state conflict when conflicting versions are owned across more than one direct root.

Example:

```text
Plan A:
A -> B-v1

Plan X:
X -> B-v2
```

Result:

```text
state.conflicts:
multipleVersions
  content = B
  versions = [B-v1, B-v2]

state.installable = false
```

No winner heuristic is introduced.

The composer does not prefer:

- latest version
- direct root version
- root distance
- provider
- release type
- input plan order

as a winner.

Input order only determines deterministic canonical/result ordering.

## Cross-root incompatibility conflict

Each install plan already contains only active-source incompatible edges.

The composer evaluates those rules against desired versions contributed by other plans.

This prevents root-local incompatibility from being duplicated as a desired-state conflict while detecting incompatibility introduced only by composition.

### Content-level example

```text
Plan A:
A
A incompatible X

Plan X:
X
```

Each plan can be individually installable.

After composition:

```text
state.conflicts:
A incompatible X

state.installable = false
```

### Exact-version example

```text
Plan A:
A incompatible B-v1

Plan X:
X -> B-v2
```

No exact conflict.

If another root contributes B-v1, the cross-root exact incompatibility conflicts.

## Shared conflict evaluation authority

Single-root install planning and multi-root desired-state composition reuse one internal conflict evaluator:

```dart
MtnMinecraftContentDependencyInstallConflictEvaluator
```

It owns:

- multiple-version grouping by logical `content.key`
- exact-version incompatible matching
- content-level incompatible matching
- unresolved incompatible non-blocking behavior

The existing install planner delegates its conflict evaluation to this authority.

No provider-specific behavior is introduced.

## Immutability and invariants

Desired-state collections are immutable.

Desired-version root ownership is immutable.

Constructor invariants require:

- unique direct version keys
- unique desired version keys
- unique install-plan root keys
- direct versions to match install-plan roots
- every desired ownership root to reference a direct version
- every direct version to exist as a direct desired version

The composer copies the input plan iterable.

Composition does not mutate:

- input plans
- dependency graphs
- dependencies
- contents
- versions
- `MtnMinecraftContentVersion.direct`

## Tests added

Dedicated pure desired-state tests cover:

- deterministic multi-root composition
- first-seen canonical shared version identity
- shared dependency ownership
- dependency-to-direct promotion
- no version `direct` mutation
- duplicate-root plan rejection
- cross-root multiple-version conflict
- root-local blocker/conflict preservation without desired-conflict duplication
- cross-root content-level incompatibility
- cross-root exact-version incompatibility match/no-match
- root-local incompatibility non-duplication
- empty desired state
- immutable source/result/ownership collections

Existing dependency-install-policy tests continue to protect the shared conflict evaluator refactor.

## Deliberately not implemented

- current installed instance state
- current file discovery
- uninstall/remove decisions
- disable/enable decisions
- orphan cleanup
- replacement/update actions
- installed-state reconciliation
- provider/API calls
- filesystem operations
- `versionConstraint` parsing/evaluation
- automatic conflict winner selection
- artifact/file selection
- downloads
- materialization
- cross-provider association
- deferred item client-definition/model/texture rendering

## Validation

Authoritative user-supplied local validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_dependency_desired_state_test.dart
00:00 +10: All tests passed!

dart test test/content_dependency_install_policy_test.dart
00:00 +11: All tests passed!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +69: All tests passed!

git diff --check main...HEAD
PASS

git status
On branch feature/minecraft-content-dependency-desired-state
Your branch is up to date with 'origin/feature/minecraft-content-dependency-desired-state'.
nothing to commit, working tree clean

git rev-parse HEAD
d97e9bf00a640c812a3a21d0aa3ac450873c057f
```

No `dart format` was run.

## Post-merge closure

The validated and continuity-closed feature branch was merged through pull request #40.

```text
PR: #40
feature: feature/minecraft-content-dependency-desired-state
validated feature HEAD: d97e9bf00a640c812a3a21d0aa3ac450873c057f
merged feature HEAD: a35a8a25bec1a9fe0ae7fdd4a1676f489f42f46e
production/test HEAD: 035df4bf9db4e4b95709e08e515499c3e3565062
merge commit: 322bdf08325ae8a4c714bd9d84b2c127c27ab24b
```

The commits after the validated feature HEAD contain continuity-only closeout changes. No production implementation changed after authoritative validation.

## Next action

This checkpoint is implementation-complete, validated, continuity-closed, and merged.

Installed-state reconciliation becomes the likely next checkpoint, but it remains a separate scope and is not automatically approved.
