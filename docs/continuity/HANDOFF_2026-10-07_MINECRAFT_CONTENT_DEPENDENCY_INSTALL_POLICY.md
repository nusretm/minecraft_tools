# Minecraft Tools — Minecraft Content Dependency Install / Conflict Policy Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-install-policy
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
Baseline main:
8c67afc0e4726276fb4ac11b4622591f27208a2a
Validated feature HEAD:
dca0bae51a6ababcb312705c0795149addb6dfb2
Production/test HEAD:
4e41c35de65d9770388d5f2c955551ac6a505690
```

Package version: `1.0.0-dev.11`.

No `dart format` was run.

## Goal

Add a pure install/conflict policy layer on top of the resolved recursive dependency graph.

The dependency graph remains the authority for resolved dependency relationships.

The install plan answers a separate question:

```text
Dependency graph
    = what dependency relationships exist and what did they resolve to?

Install plan
    = which resolved graph branches are actually install-reachable under policy?
```

This checkpoint is synchronous, provider-independent, network-free, filesystem-free, and does not perform artifact selection or materialization.

## Public surface

New request:

```dart
MtnMinecraftContentDependencyInstallRequest
```

Current policy input:

```dart
selectedOptionalVersionKeys
```

New plan:

```dart
MtnMinecraftContentDependencyInstallPlan
```

Plan surface:

```text
root
installVersions
installEdges
optionalEdges
selectedOptionalEdges
bundledEdges
toolEdges
incompatibleEdges
unresolvedInstallEdges
conflicts
installable
```

New conflict family:

```dart
abstract class MtnMinecraftContentDependencyInstallConflict

MtnMinecraftContentDependencyInstallConflictMultipleVersions
MtnMinecraftContentDependencyInstallConflictIncompatible
```

New service operation:

```dart
MtnMinecraftContentDependencyInstallPlan planDependencyInstall(
  MtnMinecraftContentDependencyGraph graph,
  MtnMinecraftContentDependencyInstallRequest request,
)
```

## Install traversal policy

The root is always the first install version and preserves the exact root instance from the graph.

Traversal is deterministic and follows graph edge order from each active source.

Dependency behavior:

```text
required
  -> install target
  -> continue target branch

embeddedLibrary
  -> install target
  -> continue target branch

optional
  -> do not install by default
  -> when target version.key is explicitly selected, install target and continue target branch

bundled
  -> do not install separately
  -> do not continue target branch

tool
  -> do not install
  -> do not continue target branch

incompatible
  -> do not install through the incompatible edge
  -> classify as an active-source conflict rule
  -> do not continue target branch
```

The planner does not filter `graph.versions`.

It performs a fresh install-reachability traversal from `graph.root`.

Therefore a version resolved by the graph can remain outside the install plan when it is reachable only through optional, bundled, tool, or incompatible policy branches.

## Active-source classification

Only edges whose source version is install-reachable are policy-active.

Example:

```text
A optional B
B incompatible C
```

If B is not selected:

```text
A is install-reachable
B is not install-reachable
B -> incompatible C is not an active incompatibility rule
```

The same active-source boundary applies to nested optional, bundled, and tool classifications.

## Optional selection

Optional selection uses resolved canonical version identity:

```text
MtnMinecraftContentVersion.key
```

A selected optional key must identify at least one resolved optional target somewhere in the supplied graph.

Unknown keys or keys that occur only on non-optional edges are rejected with `ArgumentError`.

Selection does not bypass source reachability.

Example:

```text
A optional B
B optional C
```

Selecting only C produces:

```text
installVersions:
A
```

Selecting B and C produces:

```text
installVersions:
A
B
C
```

Because the request intentionally selects by resolved version key, an unresolved optional declaration has no selectable version key in this foundation. Such an edge remains non-blocking and cannot be selected until it resolves.

## Unresolved dependency policy

```text
required unresolved
  -> unresolvedInstallEdges
  -> blocking

embeddedLibrary unresolved
  -> unresolvedInstallEdges
  -> blocking

optional unresolved
  -> optionalEdges
  -> non-blocking

bundled unresolved
  -> bundledEdges
  -> non-blocking

tool unresolved
  -> toolEdges
  -> non-blocking

incompatible unresolved
  -> incompatibleEdges
  -> non-blocking
```

`installable` is false when:

```text
unresolvedInstallEdges is not empty
OR
conflicts is not empty
```

## Version identity and cycles

Install versions are deduplicated by:

```text
MtnMinecraftContentVersion.key
```

Graph cycles are not install conflicts.

Example:

```text
A required B
B required A
```

produces:

```text
installVersions:
A
B
```

The cyclic install edge is preserved while recursion terminates through the planner's expanded-version set.

No graph state is mutated.

## Multiple-version conflict

If install-reachable traversal contains multiple distinct versions of the same logical content:

```text
version.content.key == same logical content
version.key         == different versions
```

the plan contains:

```dart
MtnMinecraftContentDependencyInstallConflictMultipleVersions
```

and `installable == false`.

The conflict preserves the content key and every conflicting install-reachable version in deterministic install order.

No automatic winner is selected.

The planner does not use:

- newest version
- direct dependency preference
- root distance
- provider priority
- release-type priority

as conflict heuristics.

## Incompatible conflict

Only incompatible edges emitted by active install-reachable sources are evaluated.

Unresolved incompatible edges are retained but do not block.

### Exact-version incompatibility

A declaration is exact when it already carries a resolved dependency version or an explicit provider version id.

The planner compares against the exact resolved graph target/version key.

If that exact version is install-reachable:

```dart
MtnMinecraftContentDependencyInstallConflictIncompatible
```

is emitted.

If another version of the same content is installed, the exact rule does not match it.

### Content-level incompatibility

When the declaration is not exact, incompatibility is evaluated at logical content identity.

The graph-selected version is used only to resolve the target content identity and does not narrow the conflict to that selected version.

Example:

```text
installed:
B-v2

incompatible declaration:
B (content-level)

graph happened to resolve declaration target:
B-v1

result:
B-v2 still conflicts
```

This prevents graph version selection from accidentally changing provider-declared content-level incompatibility semantics.

`versionConstraint` remains uninterpreted in this checkpoint.

## Immutability and mutation boundary

The request copies and exposes an immutable optional-key list.

The plan copies and exposes immutable lists for versions, edges, classifications, blockers, and conflicts.

Planning does not mutate:

- the dependency graph
- content models
- version models
- dependency models
- `MtnMinecraftContentVersion.direct`

The existing mutable `direct` field is not used as install-policy authority.

## Tests added

Dedicated pure policy tests cover:

- required / embedded-library install traversal
- optional default exclusion
- selected optional traversal
- nested optional reachability
- invalid optional selection rejection
- bundled/tool branch cut-off
- unresolved blocking vs non-blocking semantics
- cycle preservation without conflict
- install-version deduplication
- multiple-version conflict
- content-level incompatibility independent of graph-selected version
- exact-version incompatibility no-match and blocking-match behavior
- inactive-source incompatibility suppression
- request/plan collection immutability
- no mutation of version `direct` state

Provider fakes are not used by the new policy tests.

## Deliberately not implemented

- provider/API calls from install planning
- installed/current instance state
- uninstall/disable actions
- installed-state reconciliation
- `versionConstraint` parsing/evaluation
- automatic conflict winner selection
- optional UI/prompt implementation
- artifact/file selection
- download/materialization
- filesystem operations
- cross-provider association
- graph mutation
- content/version/dependency mutation
- deferred item client-definition/model/texture rendering

## Validation

Authoritative user-supplied local validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_dependency_install_policy_test.dart
00:00 +11: All tests passed!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +59: All tests passed!

git diff --check main...HEAD
PASS

git status
On branch feature/minecraft-content-dependency-install-policy
Your branch is up to date with 'origin/feature/minecraft-content-dependency-install-policy'.
nothing to commit, working tree clean

git rev-parse HEAD
dca0bae51a6ababcb312705c0795149addb6dfb2
```

No `dart format` was run.

## Next action

This checkpoint is implementation-complete, validated, and continuity-closed.

Merge is not yet requested and still requires separate explicit user approval.

Installed-state reconciliation and artifact/file selection remain later separate checkpoints and are not automatically approved.
