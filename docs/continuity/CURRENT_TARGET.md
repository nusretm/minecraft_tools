# Minecraft Tools — Current Target

Last updated: 2026-10-08

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\\development\\cross-platform\\minecraft_tools`
- Current package: `minecraft_content_service/`
- `minecraft_info_provider/` and `hypixel_api/` are sibling packages and were not modified by the current content-service checkpoint.
- `docs/WORKING_RULES.md` is authoritative.

## Repository state

Content file selection merge:

```text
PR: #42
main merge commit:
b39f9ef5ed7dda2c4e6ab182aead2668f6263230
Add content file selection foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Installed-state reconciliation merge:

```text
PR: #41
main merge commit:
8b12429e831aba8b71239b13d483bc7061d53a6c
Add installed state reconciliation foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Dependency desired state merge:

```text
PR: #40
main merge commit:
322bdf08325ae8a4c714bd9d84b2c127c27ab24b
Add dependency desired state foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Dependency install / conflict policy merge:

```text
PR: #39
main merge commit:
a6f5e60a9bc48974be611ced297b508bd4a0ccf2
Add dependency install policy foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Dependency semantic normalization merge:

```text
PR: #38
main merge commit:
a6094999cf05c345fe9ffdc0c421e45ccd0e61dc
Normalize dependency semantics
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Recursive dependency graph merge:

```text
PR: #37
main merge commit:
3238bf8d345b58b20c12643e01828bc6db3847d6
Add recursive dependency graph foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Dependency version selection merge:

```text
PR: #36
main merge commit:
519311136091e6ed85c90628ac3ce2393f166997
Add dependency version selection foundation
```

Post-merge continuity closeout commits are docs-only and follow that functional merge commit.

Dependency identity resolution merge:

```text
main
2f9097e1cb1bf29bcede4709ab89d89ec43c6715
Merge dependency identity resolution foundation
```

Authoritative post-merge local state supplied by the user before continuity closeout commits:

```text
Branch: main
origin/main: same
Working tree: clean
HEAD: 2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

Dependency identity resolution checkpoint:

```text
feature/minecraft-content-dependency-identity-resolution
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
validated feature HEAD: 4323cfae7244d18ba3859ae4cdbbb37c2e3c74ed
merge commit: 2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

Post-merge continuity closeout is docs-only and follows the functional merge commit above.

Multi-provider search checkpoint:

```text
feature/minecraft-content-multi-provider-search
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
merge commit: 0655506983ee2300ede96df67d395bda2141a3b9
post-merge continuity sync: 510620a5e22f60a1cb2cf5e90c6bd6e1d47d6d12
```

Previous completed checkpoint:

```text
feature/minecraft-content-dependency-version-selection
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #36
baseline main: 6c2cae386bd0b4a825fd7330d093de01f43c82dd
validated feature HEAD: e64a5596817f4a174b1e5cb952ef619a04eaed15
merged feature HEAD: 549a55bfd2c4f29bd136d3f8a36683ee4c077403
merge commit: 519311136091e6ed85c90628ac3ce2393f166997
```

Previous completed checkpoint:

```text
feature/minecraft-content-recursive-dependency-graph
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #37
baseline main: b6a729cd3cfb78141196b7774726ac4b06224da8
validated feature HEAD: 4bcc8ee5a72129bec5d371366ceb6c94fda04f74
merged feature HEAD: 05600a538a4d046879beeee913bd6cabf171e0a4
production/test HEAD: 4fd032395c081f143a2186519569ac06f8cb54cf
merge commit: 3238bf8d345b58b20c12643e01828bc6db3847d6
```

Previous completed checkpoint:

```text
feature/minecraft-content-dependency-semantic-normalization
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #38
baseline main: 604f0ad6964e6c1147f9969619e5c16b5391a5b6
validated feature HEAD: c395e50d545d776223f978a486db2af8686c3f01
merged feature HEAD: 6e436b08e62a15ad1adb6f4871d796e02d674cdb
implementation HEAD: fd3793b062deccb19490185cff3be3c958272ebe
merge commit: a6094999cf05c345fe9ffdc0c421e45ccd0e61dc
```

Previous completed checkpoint:

```text
feature/minecraft-content-dependency-install-policy
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #39
baseline main: 8c67afc0e4726276fb4ac11b4622591f27208a2a
validated feature HEAD: dca0bae51a6ababcb312705c0795149addb6dfb2
merged feature HEAD: ae1381a8e00e73552c3d5a9d851f50a6a5b98812
production/test HEAD: 4e41c35de65d9770388d5f2c955551ac6a505690
merge commit: a6f5e60a9bc48974be611ced297b508bd4a0ccf2
```

Previous completed checkpoint:

```text
feature/minecraft-content-dependency-desired-state
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #40
baseline main: 28bc28c42feaec81013aebcb738d60fafbaaacfd
validated feature HEAD: d97e9bf00a640c812a3a21d0aa3ac450873c057f
merged feature HEAD: a35a8a25bec1a9fe0ae7fdd4a1676f489f42f46e
production/test HEAD: 035df4bf9db4e4b95709e08e515499c3e3565062
merge commit: 322bdf08325ae8a4c714bd9d84b2c127c27ab24b
```

Previous completed checkpoint:

```text
feature/minecraft-content-installed-state-reconciliation
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #41
baseline main: d6d79f3dcdaf2fa92104871fbde554c65682cc98
validated feature HEAD: de8b978d4c3a56ebb0a9ef01e3e59d12cae4aaeb
merged feature HEAD: 63097e77a5bf9afeefa3951afef079d7245fa3a0
production/test HEAD: 6df0ce3a1f509a18e7b65d43f97547f0859c63bc
merge commit: 8b12429e831aba8b71239b13d483bc7061d53a6c
```

Latest completed checkpoint:

```text
feature/minecraft-content-file-selection
IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
PR: #42
baseline main: 6af90fc33e8d27119efa86d6a746a5ee4b6f49de
validated feature HEAD: a952582509eb89cd44fe21f5580e26d7d075cdd5
merged feature HEAD: 899dc2c26cf6f25828bb064b6c1ee04b723237a9
production/test HEAD: f68e773cbfe24c9427558fafb0c4008bc9facd63
merge commit: b39f9ef5ed7dda2c4e6ab182aead2668f6263230
```

Package version:

```text
minecraft_content_service
1.0.0-dev.14
```

## Minecraft content file selection foundation checkpoint

```text
Branch: feature/minecraft-content-file-selection
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #42
Baseline main: 6af90fc33e8d27119efa86d6a746a5ee4b6f49de
Validated feature HEAD: a952582509eb89cd44fe21f5580e26d7d075cdd5
Merged feature HEAD: 899dc2c26cf6f25828bb064b6c1ee04b723237a9
Production/test HEAD: f68e773cbfe24c9427558fafb0c4008bc9facd63
Merge commit: b39f9ef5ed7dda2c4e6ab182aead2668f6263230
```

Public/service surface:

- `MtnMinecraftContentFileSelection`
- `MtnMinecraftContentFileSelectionIssue`
- `MtnMinecraftContentFileSelectionIssueNoFiles`
- `MtnMinecraftContentFileSelectionIssueAmbiguous`
- `MtnMinecraftContentFileSelectionIssueUnavailable`
- `MtnMinecraftContentFileSelectionPlan`
- `MtnMinecraftContentService.selectReconciliationFiles(reconciliation)`

Locked target boundary:

- file selection evaluates only install and replacement desired targets
- retain targets require no new desired artifact selection
- removal targets do not expose authoritative installed physical file/path information and are not guessed
- install/replace targets are evaluated in complete desired-state order rather than grouped reconciliation order

Locked selection semantics:

```text
0 files
  -> no-files issue

1 file + available != false
  -> select sole file

1 file + available == false
  -> unavailable issue

2+ files + exactly 1 primary + primary available != false
  -> select primary

2+ files + exactly 1 primary + primary available == false
  -> unavailable issue

2+ files + 0 primary
  -> ambiguous issue

2+ files + 2+ primary
  -> ambiguous issue
```

Additional rules:

- single-file selection does not require `primary == true`
- `available == null` is unknown and remains selectable
- no fallback from unavailable selected primary to a non-primary alternative
- null `downloadUrl` is not a selection blocker
- hashes, sizes, fingerprints, modules, provider metadata and raw file type do not participate in generic selection
- generic selector does not switch on provider
- provider-specific file normalization stays in provider mappers
- all install/replace targets are represented exactly once by either a selection or issue
- selection issues are aggregated rather than causing first-error failure
- `selectable == issues.isEmpty`
- results and ambiguous candidate lists are immutable
- source reconciliation/desired/version/file models are not mutated

Still deliberately out of scope:

- provider API calls
- download-source resolution
- CurseForge download-URL lookup
- downloads
- filesystem paths / target directories
- installed file discovery
- removal file lookup
- managed installation manifest
- hashes/integrity verification
- materialization / execution ordering
- transactions / backup / rollback
- unknown/manual file cleanup
- supplementary artifact-role inference
- extension-based heuristics
- raw file-type interpretation
- `MtnMinecraftContentList` schema changes
- `versionConstraint` interpretation
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

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
clean

validated feature HEAD
a952582509eb89cd44fe21f5580e26d7d075cdd5
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_FILE_SELECTION.md
```

## Minecraft content installed-state reconciliation foundation checkpoint

```text
Branch: feature/minecraft-content-installed-state-reconciliation
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #41
Baseline main: d6d79f3dcdaf2fa92104871fbde554c65682cc98
Validated feature HEAD: de8b978d4c3a56ebb0a9ef01e3e59d12cae4aaeb
Merged feature HEAD: 63097e77a5bf9afeefa3951afef079d7245fa3a0
Production/test HEAD: 6df0ce3a1f509a18e7b65d43f97547f0859c63bc
Merge commit: 8b12429e831aba8b71239b13d483bc7061d53a6c
```

Public/service surface:

- `MtnMinecraftContentDependencyInstalledState`
- `MtnMinecraftContentDependencyReconciliationReplacement`
- `MtnMinecraftContentDependencyReconciliationPlan`
- `MtnMinecraftContentService.reconcileDependencyState(current, desired)`

Locked installed-state semantics:

- current state contains only versions known to be managed by `minecraft_content_service`
- installed `version.key` values must be unique
- installed logical `content.key` values must be unique
- current `MtnMinecraftContentVersion.direct` is not keep/remove authority
- unknown/manual filesystem content is outside this model
- `MtnMinecraftContentList` is not automatically interpreted as installed state
- no content-list schema change or installed-state adapter is introduced

Locked reconciliation semantics:

```text
desired content absent from current
  -> install

same logical content + same version.key
  -> retain

same logical content + different version.key
  -> replace

current logical content absent from desired
  -> remove
```

- matching uses logical `content.key`
- exact retained identity uses `version.key`
- replacement is neutral and covers upgrade/downgrade equally
- desired ownership/direct metadata changes alone do not force replacement
- desired state is complete instance-wide authority
- non-installable desired state throws `StateError`
- same global `version.key` pointing to different content across states throws `StateError`
- manually malformed installable desired state with duplicate logical content is rejected
- installs/retains/replacements preserve desired-state order
- removals preserve current-state order
- result lists are decisions, not execution order
- reconciliation does not mutate current or desired models

Reconciliation-plan invariants:

- desired action categories do not overlap
- current action categories do not overlap
- desired actions cover the full desired state
- current actions cover the full managed installed state
- replacement requires same logical content and a different version key
- action collections are immutable
- `changesRequired` ignores pure retains and is true only for install/replace/remove work

Still deliberately out of scope:

- filesystem discovery
- unknown/manual file cleanup
- unmanaged content deletion
- `MtnMinecraftContentList` installed-state adapter
- schema migration
- artifact/file selection
- file/path planning
- download/materialization
- real execution ordering
- transactions / backup / rollback
- enable/disable state
- `versionConstraint` interpretation
- automatic conflict winner selection
- cross-provider association
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_dependency_reconciliation_test.dart
00:00 +11: All tests passed!

dart test test/content_dependency_desired_state_test.dart
00:00 +10: All tests passed!

dart test test/content_dependency_install_policy_test.dart
00:00 +11: All tests passed!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +80: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated feature HEAD
de8b978d4c3a56ebb0a9ef01e3e59d12cae4aaeb
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_INSTALLED_STATE_RECONCILIATION.md
```

## Minecraft content dependency desired state foundation checkpoint

```text
Branch: feature/minecraft-content-dependency-desired-state
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #40
Baseline main: 28bc28c42feaec81013aebcb738d60fafbaaacfd
Validated feature HEAD: d97e9bf00a640c812a3a21d0aa3ac450873c057f
Merged feature HEAD: a35a8a25bec1a9fe0ae7fdd4a1676f489f42f46e
Production/test HEAD: 035df4bf9db4e4b95709e08e515499c3e3565062
Merge commit: 322bdf08325ae8a4c714bd9d84b2c127c27ab24b
```

Public/service surface:

- `MtnMinecraftContentDependencyDesiredVersion`
- `MtnMinecraftContentDependencyDesiredState`
- `MtnMinecraftContentService.composeDependencyInstallPlans(plans)`

Locked composition semantics:

- every install plan represents one direct/root desired version
- duplicate plan root `version.key` values are rejected
- plans preserve caller input order
- desired versions are canonicalized by first-seen `version.key`
- later same-key occurrences extend ownership without replacing the canonical version object
- every desired version records immutable direct-root ownership
- `direct` is derived from desired ownership and never mutates `MtnMinecraftContentVersion.direct`
- a dependency becomes direct when the same canonical version is also supplied as another root plan
- empty plan input produces an empty installable desired state
- all desired-state/result collections are immutable

Desired-state conflict boundary:

- root-local unresolved blockers and conflicts remain in their source install plans
- `state.conflicts` contains composition-level cross-root conflicts
- `state.installable` requires every source plan to be installable and `state.conflicts` to be empty
- cross-root multiple-version conflicts reuse `MtnMinecraftContentDependencyInstallConflictMultipleVersions`
- cross-root incompatibility conflicts reuse `MtnMinecraftContentDependencyInstallConflictIncompatible`
- exact incompatibility remains exact-version scoped
- content-level incompatibility remains logical-content scoped
- no automatic conflict winner is introduced
- root-local incompatibility is not duplicated merely by desired-state composition

Shared authority:

- `MtnMinecraftContentDependencyInstallConflictEvaluator` now owns common multiple-version and incompatibility matching
- the existing single-root install planner and the new desired-state composer both reuse that evaluator
- provider-specific behavior remains outside generic core

Still deliberately out of scope:

- current installed instance state
- filesystem/current-file discovery
- install/remove/replace/disable actions
- orphan cleanup
- installed-state reconciliation
- `versionConstraint` parsing/evaluation
- automatic conflict winner selection
- artifact/file selection
- download/materialization
- cross-provider association
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

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
clean

validated feature HEAD
d97e9bf00a640c812a3a21d0aa3ac450873c057f
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_DEPENDENCY_DESIRED_STATE.md
```

## Minecraft content dependency install / conflict policy foundation checkpoint

```text
Branch: feature/minecraft-content-dependency-install-policy
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #39
Baseline main: 8c67afc0e4726276fb4ac11b4622591f27208a2a
Validated feature HEAD: dca0bae51a6ababcb312705c0795149addb6dfb2
Merged feature HEAD: ae1381a8e00e73552c3d5a9d851f50a6a5b98812
Production/test HEAD: 4e41c35de65d9770388d5f2c955551ac6a505690
Merge commit: a6f5e60a9bc48974be611ced297b508bd4a0ccf2
```

Public/service surface:

- `MtnMinecraftContentDependencyInstallRequest`
- `MtnMinecraftContentDependencyInstallPlan`
- `MtnMinecraftContentDependencyInstallConflict`
- `MtnMinecraftContentDependencyInstallConflictMultipleVersions`
- `MtnMinecraftContentDependencyInstallConflictIncompatible`
- `MtnMinecraftContentService.planDependencyInstall(graph, request)`

Locked install traversal semantics:

- planner is synchronous, provider-independent, network-free, and filesystem-free
- exact graph root instance is always the first install version
- install reachability is recalculated from the root; `graph.versions` is not treated as an install list
- `required` and `embeddedLibrary` install their resolved target and continue traversal
- `optional` installs only when its resolved target `version.key` is selected
- optional selection cannot bypass an inactive parent branch
- `bundled` is not separately installed and terminates that policy branch
- `tool` is not installed and terminates that policy branch
- `incompatible` is not installed through its edge and is evaluated only as an active-source conflict rule
- classification lists contain only edges emitted by install-reachable source versions
- install versions are deduplicated by `version.key`
- graph cycles remain install edges but are not conflicts

Optional request rules:

- `selectedOptionalVersionKeys` is immutable
- every selected key must identify a resolved optional target somewhere in the supplied graph
- unknown or non-optional keys throw `ArgumentError`
- unresolved optional edges have no selectable version key and remain non-blocking

Blocking unresolved rules:

```text
required unresolved        -> blocking
embeddedLibrary unresolved -> blocking
optional unresolved        -> non-blocking
bundled unresolved         -> non-blocking
tool unresolved            -> non-blocking
incompatible unresolved    -> non-blocking
```

Conflict rules:

- multiple distinct install-reachable versions sharing one `content.key` produce `MtnMinecraftContentDependencyInstallConflictMultipleVersions`
- no automatic version winner is selected
- incompatible rules from inactive sources are ignored
- exact incompatible declarations match only their exact resolved version
- non-exact/content-level incompatible declarations match install-reachable versions by logical `content.key`
- a graph-selected version does not narrow a content-level incompatibility declaration
- unresolved incompatible edges remain non-blocking
- `installable` is false when unresolved install edges or conflicts are present

Mutation boundary:

- graph/content/version/dependency models are not mutated
- `MtnMinecraftContentVersion.direct` is not used or changed by the planner
- plan and request result collections are immutable

Still deliberately out of scope:

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
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

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
clean

validated feature HEAD
dca0bae51a6ababcb312705c0795149addb6dfb2
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_DEPENDENCY_INSTALL_POLICY.md
```

## Minecraft content dependency semantic normalization foundation checkpoint

```text
Branch: feature/minecraft-content-dependency-semantic-normalization
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #38
Baseline main: 604f0ad6964e6c1147f9969619e5c16b5391a5b6
Validated feature HEAD: c395e50d545d776223f978a486db2af8686c3f01
Merged feature HEAD: 6e436b08e62a15ad1adb6f4871d796e02d674cdb
Implementation HEAD: fd3793b062deccb19490185cff3be3c958272ebe
Merge commit: a6094999cf05c345fe9ffdc0c421e45ccd0e61dc
```

Generic dependency semantics:

- `required`
- `optional`
- `incompatible`
- `embeddedLibrary`
- `bundled`
- `tool`

Provider normalization:

```text
Modrinth required       -> required
Modrinth optional       -> optional
Modrinth incompatible   -> incompatible
Modrinth embedded       -> bundled

CurseForge EmbeddedLibrary    -> embeddedLibrary
CurseForge OptionalDependency -> optional
CurseForge RequiredDependency -> required
CurseForge Tool               -> tool
CurseForge Incompatible       -> incompatible
CurseForge Include            -> bundled
```

Locked boundaries:

- generic dependency names describe semantics rather than provider wire terminology
- provider wire tokens remain inside provider mapper implementations
- `MtnMinecraftContentRelationType.included/embedded` remains unchanged and separate from dependency semantics
- no backward-compatible dependency aliases are added before first release
- recursive graph traversal behavior remains unchanged
- all dependency types remain graph metadata only until install policy is implemented
- no install/conflict decision is made in this checkpoint

Still deliberately out of scope:

- dependency install policy
- optional user-selection policy
- incompatible conflict resolution
- embedded-library install policy
- bundled suppression policy
- tool policy
- `versionConstraint` interpretation
- artifact/file selection
- download/materialization
- installed-state reconciliation
- cross-provider association
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_modrinth_test.dart
00:00 +8: All tests passed!

dart test test/content_provider_curseforge_test.dart
00:00 +11: All tests passed!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +48: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated feature HEAD
c395e50d545d776223f978a486db2af8686c3f01
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_DEPENDENCY_SEMANTIC_NORMALIZATION.md
```

## Minecraft content recursive dependency graph foundation checkpoint

```text
Branch: feature/minecraft-content-recursive-dependency-graph
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #37
Baseline main: b6a729cd3cfb78141196b7774726ac4b06224da8
Validated feature HEAD: 4bcc8ee5a72129bec5d371366ceb6c94fda04f74
Merged feature HEAD: 05600a538a4d046879beeee913bd6cabf171e0a4
Production/test HEAD: 4fd032395c081f143a2186519569ac06f8cb54cf
Merge commit: 3238bf8d345b58b20c12643e01828bc6db3847d6
```

Public/service surface:

- `MtnMinecraftContentDependencyGraph`
- `MtnMinecraftContentDependencyGraphEdge`
- `MtnMinecraftContentService.resolveDependencyGraph(root, request)`

Locked semantics:

- caller-selected root version is preserved and becomes the first graph node
- traversal is deterministic depth-first in dependency declaration order
- every edge reuses the existing `resolveDependencyVersion()` behavior
- unresolved dependencies remain graph edges with no target
- unresolved edges do not abort graph construction
- resolved nodes are canonicalized by `version.key`
- shared nodes are stored and expanded once while every incoming edge remains visible
- the first runtime version object observed for a key becomes the canonical graph node
- direct and deep cycles are retained as `cyclic == true` edges and stop recursive expansion at that edge
- dependency types remain metadata only; required/optional/incompatible/embeddedLibrary/bundled/tool do not change traversal
- provider identity is never guessed or crossed
- graph collections are immutable
- root/version/dependency inputs are not mutated
- runtime graph edges remain distinct from persisted `MtnMinecraftContentRelation`

Still deliberately out of scope:

- root-version selection
- `versionConstraint` parsing/evaluation
- install policy
- incompatible conflict resolution
- embeddedLibrary/bundled/tool installation semantics
- dependency winner selection
- artifact/file selection
- download/materialization
- cross-provider association
- graph persistence/schema changes
- broader dependency failure aggregation/recovery policy
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_service_test.dart
00:00 +22: All tests passed!

dart test
00:00 +46: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated feature HEAD
4bcc8ee5a72129bec5d371366ceb6c94fda04f74
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_RECURSIVE_DEPENDENCY_GRAPH.md
```

## Minecraft content dependency version selection foundation checkpoint

```text
Branch: feature/minecraft-content-dependency-version-selection
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
PR: #36
Baseline main: 6c2cae386bd0b4a825fd7330d093de01f43c82dd
Validated feature HEAD: e64a5596817f4a174b1e5cb952ef619a04eaed15
Merged feature HEAD: 549a55bfd2c4f29bd136d3f8a36683ee4c077403
Merge commit: 519311136091e6ed85c90628ac3ce2393f166997
```

Public/service surface:

- `MtnMinecraftContentVersionSelectionRequest`
- `MtnMinecraftContentService.resolveDependencyVersion(dependency, request)`

Locked semantics:

- existing resolved versions are reused without provider version-list calls
- exact `providerVersionId` remains exact identity and is not replaced by selection policy
- provider identity is never guessed
- content identity resolves first through the existing `resolveDependency()`
- selection begins only for resolved content with no resolved version and an explicit provider
- selection filters are Minecraft version, mod loader, and release type
- public selection requests do not expose pagination
- provider pagination remains an internal service detail
- known `total` allows direct final-page lookup after the first page
- unknown `total` falls back to forward page traversal
- provider-normalized ordering remains authoritative and the final compatible normalized version is selected
- no compatible version preserves content-only resolution rather than throwing
- `versionConstraint` remains uninterpreted
- dependency relation type does not influence version choice
- no cross-provider fallback, lookup, association, filename heuristic, or dependency mutation occurs

Provider boundary:

- no Modrinth/CurseForge endpoint or wire behavior was added to generic core
- existing provider `getVersions()` implementations remain the provider-specific filtering/mapping boundary
- provider-specific filter limitations remain explicit rather than being hidden by generic approximation

Still deliberately out of scope:

- recursive dependency traversal / graph construction
- cycle and duplicate graph handling
- `versionConstraint` interpretation
- install policy for required/optional/incompatible/embeddedLibrary/bundled/tool relations
- artifact/file selection
- download/materialization
- cross-provider association
- broader provider-error aggregation policy
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_service_test.dart
00:00 +17: All tests passed!

dart test
00:00 +41: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated feature HEAD
e64a5596817f4a174b1e5cb952ef619a04eaed15
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_DEPENDENCY_VERSION_SELECTION.md
```

## Minecraft content dependency identity resolution foundation checkpoint

```text
Branch: feature/minecraft-content-dependency-identity-resolution
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Package: minecraft_content_service/
Validated feature HEAD: 4323cfae7244d18ba3859ae4cdbbb37c2e3c74ed
Merge commit: 2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

Public/service surface:

- `MtnMinecraftContentProvider.getVersion(id)`
- `MtnMinecraftContentService.getVersion(providerName, id)`
- `MtnMinecraftContentService.resolveDependency(dependency)`
- `MtnMinecraftContentDependencyResolution`

Locked semantics:

- already resolved dependency versions are reused without provider dispatch
- provider identity is never guessed
- explicit `providerVersionId` resolves through that exact registered ready provider
- exact version resolution also resolves the version's owning content
- declared `providerContentId` is validated against the resolved owning content
- content-only dependencies remain content-only when no exact version identity exists
- `fileName` and `versionConstraint` remain unresolved declarations
- no cross-provider fallback, lookup, association, deduplication or winner selection is performed
- the original `MtnMinecraftContentDependency` is not mutated

Provider integration:

- Modrinth exact version lookup remains under `src/provider/modrinth/`
- CurseForge exact file/version lookup remains under `src/provider/curseforge/`
- generic core contains no Modrinth/CurseForge endpoint, wire-token or special-case branch
- CurseForge GET/POST requests share the existing provider-owned readiness/rate-limit request path

Still deliberately out of scope:

- recursive dependency graph solving
- cycle detection
- version-selection policy
- Minecraft-version / loader / release preference policy
- dependency install/conflict policy
- version-constraint evaluation
- artifact selection
- download/materialization
- broader multi-provider error policy
- cross-provider association
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test test/content_provider_service_test.dart
00:00 +13: All tests passed!

dart test test/content_provider_modrinth_test.dart
00:00 +7: All tests passed!

dart test test/content_provider_curseforge_test.dart
00:00 +10: All tests passed!

dart test
00:00 +37: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated feature HEAD
4323cfae7244d18ba3859ae4cdbbb37c2e3c74ed

merged main HEAD supplied by user
2f9097e1cb1bf29bcede4709ab89d89ec43c6715
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_DEPENDENCY_IDENTITY_RESOLUTION.md
```

## Minecraft content multi-provider search foundation checkpoint

```text
Branch: feature/minecraft-content-multi-provider-search
Status: IMPLEMENTED / VALIDATED / CONTINUITY CLOSED / MERGED
Merge commit: 0655506983ee2300ede96df67d395bda2141a3b9
Package: minecraft_content_service/
```

Public/service surface:

- `MtnMinecraftContentService.searchAll(request)`
- `MtnMinecraftContentSearchResult.provider`

Locked semantics:

- one generic `MtnMinecraftContentSearchRequest` is dispatched to every registered provider that is currently `ready == true`
- registered providers with `ready == false` remain registered and visible but are skipped by `searchAll()`
- if no provider is ready, `searchAll()` returns an empty result list and performs no provider search calls
- provider search calls receive the same request object; the service does not rewrite provider-specific copies
- result groups preserve provider registration order
- each `MtnMinecraftContentSearchResult` identifies its source provider explicitly through `provider`
- each provider keeps its own `offset`, `limit`, `total`, and `hasMore`
- the service does not invent a merged/global pagination model
- equal names, slugs, or apparent projects from different providers remain separate results
- no cross-provider deduplication, merge, heuristic association, or winner selection is performed
- the caller/user remains responsible for choosing a provider result

Provider mapping:

- Modrinth search results are tagged with `modrinth`
- CurseForge search results are tagged with `curseforge`
- provider identity remains the existing extensible string contract rather than a closed enum

Validation on 2026-10-07:

```text
dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +33: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

validated production HEAD
7b36e4b890f71dc1a274a8ebb254972f02ea7c12
```

No `dart format` was run.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_MULTI_PROVIDER_SEARCH.md
```

## Minecraft content provider readiness / rate-limit foundation checkpoint

```text
Branch: feature/minecraft-content-provider-readiness-rate-limit
Status: IMPLEMENTED / VALIDATED
Package: minecraft_content_service/
```

Locked semantics:

- provider registration and provider readiness are independent
- `registered` means the registry knows the provider; it does not imply the provider can be used
- `ready` is decided by each concrete provider from its own configuration prerequisites
- temporary rate limiting does not change `ready`
- `MtnMinecraftContentProviderList.readyItems` exposes currently usable registered providers
- `requireReadyFromName()` rejects registered-but-not-ready providers with `MtnMinecraftContentProviderNotReadyException`
- `MtnMinecraftContentService` routes explicit provider operations only through ready providers
- direct built-in provider calls also guard readiness before network work starts

CurseForge readiness:

- CurseForge can now be constructed and registered without an API key
- missing / blank API key => `ready == false`
- setting a non-empty API key later => `ready == true`
- clearing the API key => `ready == false`
- the API key remains private and is never exposed through the public provider state

Request runtime:

- the base provider owns a serialized request gate/queue
- built-in provider HTTP operations pass through that gate
- requests queued behind a temporarily limited provider wait until its known reset point
- readiness is checked before queueing and again before execution
- provider-owned rate-limit state is exposed through immutable `MtnMinecraftContentProviderRateLimit` snapshots
- observable fields are `limit`, `remaining`, `resetAt`, `limited`, and derived `resetIn`

Modrinth rate-limit behavior:

- Modrinth response headers remain provider-specific and do not leak into generic core
- `X-Ratelimit-Limit`, `X-Ratelimit-Remaining`, and `X-Ratelimit-Reset` update generic rate-limit state
- no fixed 300/minute production constant is hardcoded
- a 429 response is retried at most once when Modrinth supplies a usable retry/reset duration

CurseForge rate-limit behavior:

- no undocumented fixed request quota is invented
- HTTP 429 is retried at most once only when `Retry-After` is actually returned and usable
- absence of a known retry duration leaves the provider-specific HTTP error visible to the caller

Validation on 2026-10-07:

```text
dart analyze
No issues found!

dart test
00:00 +31: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated production HEAD
bd2f43c028833a9095cd11840f021090da5c776a
```

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_PROVIDER_READINESS_RATE_LIMIT.md
```
## Minecraft content CurseForge provider foundation checkpoint

```text
Branch: feature/minecraft-content-provider-curseforge-foundation
Status: IMPLEMENTED / VALIDATED
Package: minecraft_content_service/
```

Public surface:

- `MtnMinecraftContentProviderCurseForge`
- `MtnMinecraftContentProviderCurseForgeException`

Implemented read-only operations:

- authenticated CurseForge search
- full mod/project read
- project description read
- paginated file/version listing

Locked architecture/behavior:

- CurseForge code lives under `src/provider/curseforge/` and extends the generic provider contract
- generic provider/service core contains no CurseForge branch or wire constants
- API key is required, kept private by the provider, and sent only as `x-api-key`
- optional injected `http.Client` supports deterministic tests and caller-owned transport
- provider-created HTTP client can be released through `close()`
- Minecraft game ID is provider-specific and remains inside the CurseForge provider
- CurseForge Minecraft content class IDs are discovered from the categories/classes endpoint and cached instead of hardcoded into generic core
- search requires exactly one generic content type
- search currently accepts at most one loader filter
- search game-version filtering supports the provider request shape used by the implementation
- generic pagination limit remains 1..50
- CurseForge's 10,000-result access boundary is enforced rather than silently returning incomplete generic pagination
- `getContent()` accepts canonical positive numeric CurseForge project IDs
- content keys use `curseforge:<projectId>`
- file/version keys use `curseforge:<fileId>`
- CurseForge numeric identities are normalized to strings in generic provider metadata
- raw project/category/author/image/file/dependency metadata is preserved where modeled
- project description is fetched separately and mapped into generic description
- file ID is preserved as provider file/version identity
- `downloadUrl == null` is preserved rather than synthesized
- SHA1 and MD5 hashes are normalized; future positive unknown hash enum values remain provider-qualified rather than guessed
- CurseForge fingerprint remains a fingerprint, not a cryptographic hash
- module name/fingerprint metadata maps to `MtnMinecraftContentFileModule`
- dependency relation enums map into required/optional/incompatible/embeddedLibrary/bundled/tool
- dependency project IDs are validated as positive and preserved as provider content IDs
- version/file `modId` must match the caller-supplied logical content's canonical CurseForge project ID
- returned versions keep the exact caller-supplied `MtnMinecraftContent` instance
- release-type filtering is applied generically after provider file retrieval
- mapped versions are ordered deterministically by publication date ascending so latest remains last
- non-mod content versions preserve the generic `[vanilla]` loader invariant
- a generic `vanilla` filter for non-mod content does not emit a fake CurseForge loader filter
- non-mod Fabric/Forge/etc. loader filters are rejected
- provider HTTP errors surface as `MtnMinecraftContentProviderCurseForgeException` without including the API key

Mapped generic project metadata includes:

- name/slug/summary/description
- authors
- categories and primary category
- website/source/issues/wiki links
- logo and screenshots
- created/modified/released timestamps

Mapped generic file/version metadata includes:

- file ID/name/display name
- release/beta/alpha type
- Minecraft versions
- loader compatibility
- publication date
- download URL availability
- file length / on-disk size
- SHA1/MD5 hashes
- fingerprint
- modules
- dependency relations

Validation on 2026-10-07:

```text
dart analyze
No issues found!

dart test
00:00 +25: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated production HEAD
7a504338029f58c0808190d1e43d3b9c79146526
```

Focused CurseForge coverage uses `MockClient`; no real API key is stored in the repository and no live CurseForge smoke has been recorded yet.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_PROVIDER_CURSEFORGE_FOUNDATION.md
```
## Minecraft content CLI example checkpoint

```text
Branch: feature/minecraft-content-cli-example
Status: IMPLEMENTED / VALIDATED / LIVE MODRINTH SMOKE PASSED
Package: minecraft_content_service/
```

Example:

```text
minecraft_content_service/example/mc_content.dart
```

CLI contract:

```text
--provider
--content
--filter
--mc-version
--loader
```

Validated command:

```powershell
dart run example/mc_content.dart --provider modrinth --content mod --filter "Skyblocker" --mc-version 26.1.2 --loader fabric
```

Live result:

```text
3 results returned
Skyblocker • Hypixel Skyblock
Bazaar Utils ✦ Hypixel Skyblock
CasualSkyblockZAddons [CSZA]
```

The live smoke confirms the full path:

```text
CLI args
→ generic search request
→ MtnMinecraftContentService
→ Modrinth provider
→ Modrinth search facets
→ normalized MtnMinecraftContent results
→ CLI presentation
```

Local validation supplied by the user:

```text
dart analyze
No issues found!

dart test
00:00 +17: All tests passed!

live Modrinth smoke
PASS
```

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_CLI_EXAMPLE.md
```
## Minecraft content Modrinth provider foundation checkpoint

```text
Branch: feature/minecraft-content-provider-modrinth-foundation
Status: IMPLEMENTED / VALIDATED
Package: minecraft_content_service/
```

Public surface:

- `MtnMinecraftContentProviderModrinth`
- `MtnMinecraftContentProviderModrinthException`

Implemented read-only operations:

- search through Modrinth v2 `/search`
- project/content read through `/project/{id-or-slug}`
- project version listing through `/project/{project-id}/version`

Locked architecture/behavior:

- Modrinth code lives under `src/provider/modrinth/` and extends the generic provider contract
- generic service/provider core contains no Modrinth switch or special-case branch
- caller supplies an application-specific non-empty `User-Agent`
- optional injected `http.Client` supports deterministic tests and caller-owned transport
- provider-created HTTP client can be released through `close()`
- search uses provider-independent query/type/game-version/loader request fields
- generic request limit remains capped at 50 even though provider capabilities may differ
- canonical logical keys are `modrinth:<projectId>` and `modrinth:<versionId>`
- full raw Modrinth project/search/version/file/dependency maps are preserved as provider metadata where modeled
- project primary type maps into the generic content subclass; additional Modrinth type information remains available in raw provider metadata
- Modrinth files do not receive invented provider file IDs
- file hashes preserve all returned hash algorithms
- when Modrinth marks no file primary, the first file is normalized as primary
- dependency declarations preserve project/version/file-name identity without inventing version constraints
- version `project_id` is validated against the existing logical content's canonical Modrinth project ID
- returned versions therefore retain the exact caller-supplied logical content object
- release-type filtering and generic pagination are applied after provider version mapping
- version results are sorted deterministically by publication date, oldest to newest, so latest remains last
- HTTP non-2xx responses surface as `MtnMinecraftContentProviderModrinthException`

Mapped generic metadata includes:

- project type/title/slug/summary/body
- categories and additional categories
- icon/gallery/license
- source/issues/wiki/Discord/donation links
- published/updated/approved timestamps
- release/beta/alpha version type
- game versions and loaders
- environment
- changelog/featured state
- files, hashes, size, download URL and primary state
- required/optional/incompatible/embedded dependencies

Validation on 2026-10-07:

```text
dart analyze
No issues found!

dart test
00:00 +17: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated production HEAD
f5003897401a6692b0fd67c1c6edace4d3fec254
```

Validation is deterministic MockClient coverage; no separate live Modrinth network smoke test was required for this checkpoint.

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_PROVIDER_MODRINTH_FOUNDATION.md
```
## Minecraft content provider/service foundation checkpoint

```text
Branch: feature/minecraft-content-provider-service-foundation
Status: IMPLEMENTED / VALIDATED
Package: minecraft_content_service/
```

Locked architecture:

- `MtnMinecraftContentProviderList` is the single provider registry authority
- providers do not self-register
- duplicate provider names are rejected and registration order is preserved
- `MtnMinecraftContentService` routes only through registered providers
- provider identity remains an extensible stable string
- search/version request filters are immutable
- common offset/limit pagination is bounded to 1..50
- `getVersions(providerName, content, request)` receives the existing logical content object
- concrete providers must attach returned versions to that same logical content instance
- generic core contains no Modrinth/CurseForge switch or provider-specific HTTP behavior
- multi-provider aggregation, dependency solving and materialization remain later work

Validation:

```text
dart analyze
No issues found!

dart test
00:00 +12: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated production HEAD
55534a1b4979dfcbf46c715716add01c9297bd01
```

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_PROVIDER_SERVICE_FOUNDATION.md
```
## Minecraft content model foundation checkpoint

```text
Branch: feature/minecraft-content-model-foundation
Status: IMPLEMENTED / VALIDATED
Package: minecraft_content_service/
```

Purpose:

- provide a reusable Pure Dart content-domain foundation independent from Modrinth, CurseForge and `minecraft_info_provider`
- model mods, modpacks, resource packs, shader packs and data packs through one shared content family
- preserve provider-specific metadata without forcing provider-specific fields into the generic domain
- support persistence without recursively serializing the runtime object graph

Locked public/model architecture:

- `MtnMinecraftContentModel` is the common serialization/parsing base
- one serialization authority: `toMap()`
- common `toJson()`, UTF-8 `encode()`, decode/parsing helpers and runtime-type `toString()`
- no database-style `recId` / `remoteRecId`
- `MtnMinecraftContent` remains abstract and exposes concrete Mod / ModPack / ResourcePack / ShaderPack / DataPack subclasses
- inheritance and `MtnMinecraftContentType` coexist; concrete subclasses fix their own type
- one logical content may preserve metadata from multiple providers through `MtnMinecraftContentProviderMetadata`
- provider identity is a stable string rather than a closed provider enum
- provider IDs are stored as strings so Modrinth and CurseForge identities fit the same model
- `MtnMinecraftContentVersion` owns release/version compatibility metadata
- `modLoaders` is required and non-empty
- mod versions may expose multiple loaders such as Fabric + Quilt or Forge + NeoForge
- non-mod content versions must use only `[vanilla]`
- `vanilla` cannot be combined with another loader
- `content.version` uses an explicit selection when present, otherwise `versions.last`
- version strings remain strings; no generic SemVer assumption is imposed
- `MtnMinecraftContentFile` models physical artifacts separately from logical versions
- file hash algorithms remain open strings
- CurseForge fingerprint/module metadata has explicit fields and is not misrepresented as a normal hash
- dependency declarations and resolved dependency targets live in `MtnMinecraftContentDependency`
- `included` / `embedded` ownership is represented separately by `MtnMinecraftContentRelation`
- relations are version-to-version, so the same source version can belong to multiple owner versions
- `MtnMinecraftContentList` is the graph/list authority
- the flat `versions` view is derived from content-owned version collections rather than maintained as a second mutable authority
- duplicate local keys and duplicate provider canonical identities are rejected
- persistence writes stable content/version keys instead of recursively embedding circular object references
- load reconstructs dependency and relation object references without network access
- schema version starts at 1

Provider compatibility represented in the generic model includes:

- Modrinth/CurseForge project metadata through normalized content fields plus provider metadata
- release / beta / alpha version types
- Minecraft game-version lists
- loader compatibility
- version environment metadata where available
- Modrinth-style multi-file versions
- CurseForge-style file/version identity, fingerprints and modules
- required / optional / incompatible / embedded / included / tool dependency semantics
- authors, categories, links, gallery/images, donations and license metadata

Deliberately not implemented in this checkpoint:

- provider HTTP clients
- Modrinth search/project/version adapters
- CurseForge search/project/file adapters
- provider registry/service orchestration
- download/materialization
- dependency constraint solving
- update/remove orphan reconciliation
- cross-provider heuristic deduplication
- `minecraft_info_provider` integration
- deferred item resource/rendering implementation

Final local validation on 2026-10-07:

```text
dart analyze
No issues found!

dart test
00:00 +7: All tests passed!

git diff --check main...HEAD
PASS

git status
clean

validated production HEAD
ed430670ba5b1ba4c27cb204b8aba5680a0df288
```

Dedicated handoff:

```text
docs/continuity/HANDOFF_2026-10-07_MINECRAFT_CONTENT_MODEL_FOUNDATION.md
```


Working milestone state:

```text
SERVER LIST CRUD + AUTO CHECK / HEALTH CHECK
COMPLETE / VALIDATED / MERGED
```

Working mod-loader discovery checkpoint:

```text
Branch: feature/mod-loader-discovery-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoModLoaderType`
- `MtnMinecraftInfoModLoader`
- `MtnMinecraftInfoProvider.readModLoader()`

Locked scope:

- reads only `<gameDirectory>/versions/version.json`
- interprets only `id` and `inheritsFrom`
- reports recognized loader type, loader version and Minecraft version
- missing profile or unknown loader returns null
- does not parse libraries, launcher arguments, assets, downloads or runtime metadata
- does not inspect loader JARs or the `mods/` directory

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused mod-loader discovery
9/9 passed

full package test suite
265/265 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed active profile signal:

```text
Mod loader: fabric
Loader version: 0.19.5
Minecraft version: 26.1.2
```


## Installed mod-file discovery checkpoint

```text
Branch: feature/installed-mod-file-discovery
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoMod`
- `MtnMinecraftInfoProvider.readMods()`

Locked behavior:

- scans only direct files under `<gameDirectory>/mods/`
- accepts `.jar` extension case-insensitively
- missing `mods/` returns an empty immutable list
- nested directories are not traversed
- non-JAR files are ignored
- results are sorted deterministically by file name
- At this historical checkpoint, the discovered file was the only modeled source.
- This file-only model was superseded by the dev.25 provider/graph checkpoint below; `MtnMinecraftInfoMod` now represents normalized logical mods with installed and embedded provenance.
- JAR contents and metadata were not read during the dev.24 checkpoint

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused installed mod-file discovery
7/7 passed

full package test suite
272/272 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
54 direct mod JAR files discovered
```

The real profile includes mixed naming conventions, reinforcing that file names
are discovery labels only and must not be treated as authoritative mod metadata
or loader compatibility.


## Fabric mod metadata and dependency graph checkpoint

```text
Branch: feature/fabric-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftModInfoProvider`
- `MtnMinecraftModInfoProviderFabric`
- `MtnMinecraftModList`
- `MtnMinecraftInfoMod`
- `MtnListEvent`
- `MtnMinecraftInfoProvider.readMods(modList)`

Locked behavior:

- `MtnMinecraftModList.providers` is the single parser registry authority.
- Every direct `mods/*.jar` file is offered to every registered provider.
- Provider recognition is represented by `MtnMinecraftInfoMod.modTypes`, using each provider's stable `name`.
- Logical mod identity is currently normalized by `id + version`.
- The same logical mod can be directly installed and embedded at the same time.
- Different versions remain distinct and can expose dependency/version conflicts.
- Fabric `fabric.mod.json` is parsed by the Fabric provider, not the generic info provider.
- Fabric `jars[].file` entries are verified inside the parent archive and recursively parsed in memory.
- Embedded JARs are not extracted to disk.
- Shared embedded dependencies are merged into one logical mod with multiple `parentMods`.
- `getDependencyList(mod, recursive: true)` traverses embedded dependency relationships.
- `remove(mod)` rejects embedded-only mods; installed roots can be removed while dependencies still referenced by another parent remain in the graph.
- `onItem(list, mod, event)` emits `MtnListEvent.add/update/remove` only for normalized visible-state changes.
- Core registry/list code does not hardcode Fabric/Forge/NeoForge/Quilt cases.

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused installed mod-file discovery
7/7 passed

focused mod-list registry / graph
8/8 passed

focused Fabric provider
10/10 passed

full package test suite
290/290 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
54 physical JAR files
188 normalized logical Fabric mods
```

Examples confirmed:

- direct mods with no parent
- embedded-only mods
- mods that are both directly installed and embedded
- one embedded dependency shared by several parent mods
- multiple versions of the same mod ID remaining distinct
- parent output disambiguated as `id@version`

Next launcher-facing extension after this checkpoint is mod presentation data such as icon lookup, followed later by richer metadata/dependency interpretation and additional loader providers.


## Mod icon lookup checkpoint

```text
Branch: feature/mod-icon-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoMod.hasIcon`
- `MtnMinecraftInfoMod.getIcon({int size = 128})`

Locked behavior:

- icon bytes are loaded lazily only when requested
- generic mod/core code does not interpret provider-specific icon metadata
- Fabric provider supports both a single icon path and size-to-path icon maps
- multi-size lookup selects the smallest icon width >= requested size, or the largest available icon when none are large enough
- installed mod icons reopen the root JAR lazily
- embedded mod icons reopen the root JAR and follow the embedded archive chain in memory
- embedded JARs and icons are never extracted to temporary files
- normalized `MtnMinecraftModList` entries retain working provider-backed icon resolvers
- missing icon files do not invalidate otherwise valid mods; icon lookup becomes unavailable instead
- non-positive requested sizes are rejected

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Fabric provider
15/15 passed

focused mod-list
9/9 passed

full package test suite
296/296 passed

git diff --check
PASS

working tree
clean
```

Real-profile smoke target:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
```

Observed:

```text
116 mods declared usable icons
116 icons loaded successfully
```

The successful reads included directly installed mods, embedded-only mods and mods that were both installed and embedded.

Example:

```text
minecraft_info_provider/example/mod_icons.dart
```


## Generic mod metadata checkpoint

```text
Branch: feature/generic-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public surface added to the provider-independent mod model:

- `MtnMinecraftInfoMod.contributors`
- `MtnMinecraftInfoMod.licenses`
- `MtnMinecraftInfoMod.urls`
- `MtnMinecraftInfoMod.clientSide`
- `MtnMinecraftInfoMod.serverSide`
- `MtnMinecraftInfoMod.dependencies`
- `MtnMinecraftInfoMod.providedIds`
- `MtnMinecraftInfoModUrls`
- `MtnMinecraftInfoModDependency`
- `MtnMinecraftInfoModDependencyType`

Locked generic metadata rules:

- `MtnMinecraftInfoMod` stays loader/provider independent.
- Provider-specific metadata tokens are normalized inside their provider implementation.
- URL metadata exposes first-class `homepage`, `source` and `issues` fields.
- Local metadata providers do not guess missing source URLs from issue-tracker or homepage URLs.
- Future Modrinth/CurseForge integration may enrich missing remote/project metadata only after a real remote match.
- `clientSide` and `serverSide` are independent booleans so client-only, server-only and both-side mods are representable.
- Fabric `environment` maps to those booleans; default/missing Fabric environment supports both sides.
- Dependency types are generic: required, recommended, suggested, conflict and incompatible.
- Provider version syntax remains raw in `versionConstraints`; multiple entries represent OR alternatives.
- `providedIds` stores provider-declared aliases without turning them into separate logical mods.
- The normalized mod list unions list metadata and side capabilities across providers and fills only missing URL fields.
- Forge/NeoForge-specific metadata parsing remains outside this checkpoint.

Fabric fields normalized in this checkpoint:

```text
authors
contributors
license
contact.homepage
contact.sources
contact.issues
environment
provides
depends
recommends
suggests
conflicts
breaks
```

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Fabric metadata
19/19 passed

focused mod-list
10/10 passed

full package test suite
301/301 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-fabric-3.5.0+26.3.jar
```

Observed normalized metadata:

```text
id: armor_hud
version: 3.5.0
license: MIT
homepage: https://modrinth.com/mod/armor-hud
source: https://github.com/SaolGhra/Armor-Hud
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: false
required: fabricloader >=0.15.0
required: minecraft ~26.3
required: fabric-api *
```

Example:

```text
minecraft_info_provider/example/mod_metadata.dart
```


## Forge mod metadata checkpoint

```text
Branch: feature/forge-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public/provider surface:

- `MtnMinecraftModInfoProviderForge`
- `MtnMinecraftInfoModDependencyType.optional`
- `MtnMinecraftInfoModDependencyOrdering.none`
- `MtnMinecraftInfoModDependencyOrdering.before`
- `MtnMinecraftInfoModDependencyOrdering.after`

Locked Forge scope:

- modern Forge metadata is read from root `META-INF/mods.toml`
- one JAR may declare multiple `[[mods]]` entries
- generic fields include ID, version, display name, description, authors, license, homepage and issue tracker
- Forge metadata does not provide a source repository URL in the validated Armor HUD JAR; `urls.source` therefore remains null
- `logoFile` uses the existing lazy provider-backed icon API
- missing logo files do not invalidate otherwise valid mod metadata
- dependency `mandatory=true` maps to generic required
- dependency `mandatory=false` maps to generic optional
- dependency `ordering=NONE/BEFORE/AFTER` maps to generic dependency ordering
- dependency `side=CLIENT/SERVER/BOTH` applies only to that dependency relationship
- dependency side is never promoted into mod-level `clientSide/serverSide`
- Forge `displayTest` is not treated as a physical-side declaration
- explicit file-level `clientSideOnly=true` maps to client-only; otherwise mod-level side remains conservatively both
- Forge `versionRange` syntax is preserved as raw generic `versionConstraints`
- `${file.jarVersion}` resolves from manifest `Implementation-Version`
- `${file.<property>}` resolves from Forge file-level `properties`
- declared JarJar entries are read from `META-INF/jarjar/metadata.json`
- embedded Forge mods are recursively parsed in memory
- JarJar libraries without Forge mod metadata do not become logical mods
- legacy `mcmod.info`, bytecode `@Mod` discovery and older Forge fallbacks remain outside this checkpoint

Shared archive infrastructure:

- Fabric and Forge now reuse the same internal ZIP signature validation, archive entry lookup and lazy root/embedded archive-chain reading implementation
- embedded JARs and icons remain in-memory/lazy and are not extracted to disk

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Forge provider
15/15 passed

focused Fabric provider regression
19/19 passed

full package test suite
316/316 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-forge-3.5.0+1.20.1.jar
```

Observed logical mods:

```text
armor_hud@3.5.0
mixinextras@0.4.1
```

Observed Armor HUD normalization:

```text
homepage: https://modrinth.com/mod/armor-hud
source: null
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: true
required: forge [47,) client=true server=false
required: minecraft [1.20.1] client=true server=false
```

The Forge dependency `CLIENT` scopes intentionally do not imply that the whole mod is client-only.

Example:

```text
minecraft_info_provider/example/mod_metadata.dart
```


## NeoForge mod metadata checkpoint

```text
Branch: feature/neoforge-mod-metadata-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public/provider surface:

- `MtnMinecraftModInfoProviderNeoForge`
- `MtnMinecraftInfoModDependencyType.discouraged`

Locked NeoForge scope:

- modern NeoForge metadata is read from root `META-INF/neoforge.mods.toml`
- one JAR may declare multiple `[[mods]]` entries
- generic fields include ID, version, display name, description, authors, license, homepage and issue tracker
- local metadata does not invent a source repository URL
- `iconFile` uses the existing lazy provider-backed icon API
- mod-level `iconFile` takes precedence over file-level `iconFile`
- NeoForge `logoFile` is not reinterpreted as `iconFile`
- missing icon files do not invalidate otherwise valid mod metadata
- dependency `type=required` maps to generic required
- dependency `type=optional` maps to generic optional
- dependency `type=incompatible` maps to generic incompatible
- dependency `type=discouraged` maps to generic discouraged
- dependency `ordering=NONE/BEFORE/AFTER` maps to generic dependency ordering
- dependency `side=CLIENT/SERVER/BOTH` applies only to the dependency relationship
- dependency side is never promoted into mod-level `clientSide/serverSide`
- this checkpoint does not scan NeoForge `@Mod(dist=...)` bytecode annotations
- without authoritative mod-level dist metadata, NeoForge mods remain conservatively `clientSide=true, serverSide=true`
- NeoForge `versionRange` syntax is preserved as raw generic `versionConstraints`
- `${file.jarVersion}` resolves from manifest `Implementation-Version`
- `${file.<property>}` resolves from file-level `properties`
- declared JarJar entries are read from `META-INF/jarjar/metadata.json`
- embedded NeoForge mods are recursively parsed in memory
- JarJar libraries without NeoForge metadata do not become logical mods

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused NeoForge provider
18/18 passed

focused Forge provider
15/15 passed

focused Fabric provider
19/19 passed

focused mod-list
10/10 passed

full package test suite
334/334 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-neoforge-3.5.0+26.3.jar
```

Observed normalization:

```text
armor_hud@3.5.0
name: Armor HUD
license: MIT
homepage: https://modrinth.com/mod/armor-hud
source: null
issues: https://github.com/SaolGhra/Armor-Hud/issues
clientSide: true
serverSide: true
modTypes: neoforge
required: neoforge [26.3,) client=true server=false
required: minecraft [26.3] client=true server=false
```

The dependency `CLIENT` scopes intentionally do not imply that the whole mod is client-only.

Example:

```text
minecraft_info_provider/example/mod_metadata.dart
```


## Mod asset/resource foundation checkpoint

```text
Branch: feature/mod-asset-resource-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoModAssetSource`
- `MtnMinecraftInfoMod.assetSources`
- `MtnMinecraftInfoMod.assetNamespaces`
- `MtnMinecraftModList.assetSources`
- `MtnMinecraftModList.assetNamespaces`
- `MtnMinecraftModList.getAssetSources(namespace)`

Locked architecture:

- Client resources are modeled at archive-source level rather than as authoritative logical-mod ownership.
- Namespace discovery scans `assets/<namespace>/...` entries in recognized mod archives.
- A namespace is never assumed to equal `MtnMinecraftInfoMod.id`.
- One archive may expose multiple namespaces, including `minecraft` or namespaces unrelated to a declared logical mod ID.
- One archive may contain multiple logical mods, so the same discovered asset source may be associated with multiple parsed mods.
- The normalized mod list deduplicates identical archive sources when multiple metadata providers recognize the same physical archive.
- `getAssetSources(namespace)` returns all candidate sources and does not invent resource-pack precedence.
- Namespace lists are validated, unique and sorted.
- Raw asset paths are validated as relative Minecraft resource paths.
- Asset bytes are loaded lazily only when `read(namespace, path)` is called.
- Installed root sources reopen their JAR lazily.
- Embedded sources retain the root path plus embedded archive chain and traverse it in memory without disk extraction.
- Fabric, Forge and NeoForge providers share the same archive-level asset discovery/read infrastructure.
- This checkpoint deliberately does not parse language files, client item definitions, models, textures or pack precedence.

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused mod asset/resource
7/7 passed

focused Fabric provider
19/19 passed

focused Forge provider
15/15 passed

focused NeoForge provider
18/18 passed

focused mod-list
10/10 passed

full package test suite
341/341 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
armor_hud-neoforge-3.5.0+26.3.jar
```

Observed namespace/source:

```text
Asset namespaces: armor_hud
armor_hud@3.5.0: armor_hud
  D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

Observed lazy raw asset read:

```text
armor_hud
textures/gui/hotbar_texture.png
source[0]: 1197 bytes
```

Example:

```text
minecraft_info_provider/example/mod_assets.dart
```

Next intended layer after this foundation is locale/language resource parsing, followed by item client-definition/model/texture resolution in separate checkpoints.

## Mod language/translation foundation checkpoint

```text
Branch: feature/mod-language-translation-foundation
Status: IMPLEMENTED / VALIDATED / REAL JAR TRANSLATION SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoModLanguage`
- `MtnMinecraftInfoModTranslation`
- `MtnMinecraftInfoModLanguageError`
- `MtnMinecraftInfoModLanguageException`
- `MtnMinecraftModList.readLanguages(namespace, locale: ...)`
- `MtnMinecraftModList.getTranslations(namespace, key, locale: ...)`

Locked behavior:

- language files are read from exact `assets/<namespace>/lang/<locale>.json` paths
- language JSON must decode to an object
- Minecraft-compatible primitive values are accepted: strings remain strings, numbers and booleans normalize through their string representation
- object, array and null translation values remain invalid and normalize to `MtnMinecraftInfoModLanguageError.invalidData`
- unsupported numeric format placeholders such as `%d` / `%f` normalize to `%s`, preserving positional indexes
- language maps are immutable snapshots
- locale names are validated before archive reads
- missing language files return no language candidate
- missing translation keys return no translation candidate and are not synthesized
- exact locale lookup does not silently fall back to `en_us`
- higher-level code may add an explicit Minecraft-style locale fallback policy later
- every translation result preserves its source, namespace, locale, key and value
- multiple asset sources contributing the same namespace/key remain separate candidates
- core does not select a resource winner or invent pack precedence
- embedded archive language files are read lazily through the existing archive-chain source infrastructure
- this checkpoint does not yet synthesize item translation keys or resolve item/model/texture resources

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused mod language/translation
8/8 passed

full package test suite
349/349 passed

git diff --check
PASS

working tree
clean
```

Real JAR smoke target:

```text
D:\development\armor_hud-neoforge-3.5.0+26.3.jar
```

Observed exact-locale table:

```text
namespace: armor_hud
locale: en_us
language candidates: 1
entries: 11
```

Observed real translation:

```text
key: armor_hud.config.title
value: Armor HUD Configuration
```

Example:

```text
minecraft_info_provider/example/mod_translations.dart
```

Next intended layer is item identity to translation-key/name resolution, kept separate from client item model and texture rendering.

Compatibility corrections landed during the dev.32 item-name checkpoint:

- Fabric empty optional license strings normalize to no license.
- Fabric empty author/contributor strings are ignored in the generic normalized model.
- Fabric metadata remains strict for wrong field types and missing required person object names.
- Language primitive parsing now matches Minecraft semantics for strings, numbers and booleans.
- Low-level language reads remain strict for composite/null translation values.
- High-level item-name resolution isolates an invalid candidate language source and continues checking independent sources.

## Item name resolution foundation checkpoint

```text
Branch: feature/item-name-resolution-foundation
Status: IMPLEMENTED / VALIDATED / REAL PROFILE POSITIVE SMOKE PASSED
```

Public surface:

- `MtnMinecraftInfoItemIdentity`
- `MtnMinecraftInfoItemNameKind`
- `MtnMinecraftInfoItemName`
- `MtnMinecraftInfoItemNameResolver`

Locked behavior:

- namespaced item identities use `namespace:path`
- conventional item keys derive as `item.<namespace>.<path>`
- conventional block-item keys derive as `block.<namespace>.<path>`
- slash-separated item paths map to dot-separated translation-key paths
- both item and block candidates are preserved; no winner is guessed
- item IDs do not imply that the matching language table must live under the same asset namespace
- every discovered asset namespace/source may contribute a candidate
- locale lookup remains exact and defaults to `en_us`
- no implicit locale fallback is applied
- no resource-pack/source precedence is invented
- no custom runtime description ID is guessed
- no runtime item registry is emulated
- invalid language sources are isolated only in the high-level item-name candidate resolver; strict low-level `readLanguages()` behavior remains unchanged
- persisted `customName` / `itemName` item components remain separate from registry/localization-derived default names

Real profile validation:

```text
C:\Provanas\profiles\02766803-f0e2-4101-a3b8-962e1f520bcb
54 direct mod JARs
Fabric 26.1.2 profile
```

Negative smoke:

```text
simplyswords:diamond_greataxe
sophisticatedbackpacks:gold_backpack
-> No conventional localized name candidate found.
```

Those IDs were not present in the active profile's discovered mod graph, so the clean miss is expected.

Positive smoke:

```text
item id: verity:flashlight
derived key: item.verity.flashlight
resolved value: Flashlight
language namespace: verity
source: ...\mods\verity-4.0.0.jar
```

Final validation on 2026-10-06:

```text
dart analyze
No issues found!

focused Fabric metadata
21/21 passed

focused mod language/translation
9/9 passed

focused item name resolution
9/9 passed

full package test suite
361/361 passed
```

Example:

```text
minecraft_info_provider/example/item_names.dart
```

Still out of scope:

- authoritative runtime description-ID discovery
- vanilla registry/default-name synthesis
- resource-pack precedence
- client item definitions under `assets/<namespace>/items/`
- legacy `models/item/` resolution
- model parent inheritance
- texture reference resolution
- PNG rendering/compositing


## Completed server-list management

`MtnMinecraftInfoProvider` now owns the complete saved-server mutation surface needed by the launcher/UI:

- `readServers()`
- `addServer(server, first: true|false)`
- `updateServer(server)`
- `removeServer(address)`

Locked behavior:

- default add remains append
- `first: true` inserts at index 0
- update preserves the matching entry's list position
- remove preserves remaining order
- update/remove target canonical server identity through `MtnMinecraftInfoServerAddress.sameIdentity()`
- bare default-port and explicit `:25565` addresses therefore match
- existing unrelated/unknown NBT tags are preserved
- writes remain serialized per target and atomically published
- caller policy decides whether a server should be added/updated/removed; there is no hidden provider-side dedup policy

Real Java Edition 1.8.9/launcher-profile smoke tests confirmed:

- existing saved servers are read correctly
- resource-pack prompt/disabled/enabled states round-trip as expected
- hidden server state is read correctly
- Provanas can be inserted first
- duplicate add is prevented by the example's canonical identity check
- update changes the chosen title/resource-pack policy in place
- remove deletes the matching entry and a second remove reports not found

## Server automatic status lifecycle

`MtnMinecraftInfoServer` now owns its own optional status refresh lifecycle.

Public/runtime behavior:

```dart
server.autoCheck       // default false
server.autoCheckSec    // default 15, minimum 15
server.dispose()
```

Locked semantics:

- values below 15 seconds clamp to 15
- enabling automatic checks never allows overlapping queries
- the first status query can be started immediately by the health-check coordinator
- after a query finishes, the next delay begins from completion time
- therefore cadence is: query -> wait interval -> query
- changing `autoCheckSec` while waiting reschedules the next check
- `dispose()` cancels waiting timers, disables auto-check and releases `onChange`
- an in-flight transport operation may finish, but after disposal it cannot publish a new status callback or schedule another automatic check
- querying or re-enabling auto-check on a disposed server is rejected

`MtnMinecraftInfoServer.clone()` preserves `autoCheckSec` but does not automatically start polling.

## Server health-check orchestration

Public coordinator:

```text
MtnMinecraftInfoServerHealthCheck
```

It owns collection/lifecycle orchestration while each server owns its timer and query logic.

Public surface includes:

- `servers` as an immutable view
- `intervalSec` with the same 15-second minimum
- `active`
- `add(server)`
- `remove(server)`
- `start()`
- `stop()`
- `dispose()`

Callbacks:

```dart
onAdd(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onChange(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onRemove(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
```

Lifecycle rules:

- add rejects duplicate object membership
- add wires the server's existing `onChange` into the checker callback chain instead of discarding it
- add starts one immediate `queryStatus()`
- if `start()` happens while that initial query is running, no second overlapping query is launched
- once the initial query completes, active auto-check scheduling begins
- changing checker `intervalSec` propagates to all managed servers
- `stop()` disables managed auto-check timers without disposing server snapshots
- `remove()` removes membership, disposes that server, then emits `onRemove`
- checker `dispose()` disposes every remaining managed server and emits `onRemove` for each

## Examples

### servers.dat CRUD

```text
minecraft_info_provider/example/servers_dat.dart
```

Actions:

```text
--add
--update
--remove
```

The example targets `oyna.provanas.com`, inserts it first when missing, updates the title/resource-pack policy, and removes it by canonical identity.

### Live server checker

```text
minecraft_info_provider/example/server_checker.dart
```

The example:

1. accepts a concrete `servers.dat` file path
2. reads every saved server
3. adds them to `MtnMinecraftInfoServerHealthCheck`
4. begins immediate status queries
5. prints add/change/remove callbacks until Ctrl+C
6. omits icon/favicon data from output
7. renders MOTD through the existing `MtnMinecraftText.plainText` representation

## Validation

Authoritative local validation on 2026-10-06:

```text
dart analyze
No issues found!

dart test
00:03 +256: All tests passed!

git diff --check
PASS

git status
clean
```

Live smoke validation used:

```text
C:\Provanas\profiles\919ffebe-f609-4019-afed-fe31537e3e5f\servers.dat
```

Observed real servers included:

- `oyna.provanas.com`
- `mc.hypixel.net`
- `play.zenitmc.com`

The live checker confirmed immediate first callbacks, repeated non-overlapping checks, online status, version/player/latency/MOTD updates, and clean remove callbacks during Ctrl+C shutdown.

## Completed item-read foundation

The core `MtnMinecraftInfoItemStack` read foundation remains complete.

Covered persisted information includes:

- item ID and count
- damage / repair cost / unbreakable
- active and stored enchantments
- custom name / item name / lore
- potion contents / duration scale
- attribute modifiers
- custom model data
- nested container contents / Bundle contents / charged projectiles / use remainder
- modern `minecraft:custom_data`
- exact legacy raw `tag`
- explicit removed component IDs

The authoritative completion note remains:

```text
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_READ_FOUNDATION_COMPLETE.md
```

## Locked item-read semantics

These remain unchanged:

- models represent persisted values, not synthesized registry defaults
- modern `components` are authoritative when present
- removed modern components remain explicit
- unknown future/modded IDs are tolerated where their schema is not recognized
- recognized malformed data remains strict
- legacy raw `tag` and modern `minecraft:custom_data` are distinct
- no Minecraft DataFixer behavior is guessed
- Pure Dart code is not auto-formatted unless explicitly requested

## Current backlog

Completed server-list CRUD and health-check work is no longer an open backlog item.

Remaining major areas include:

### Installed content / launcher presentation

- authoritative mod namespace -> owning mod mapping where such ownership can actually be proven
- item client-definition/model/texture resolution needed for launcher inventory rendering is now a separately designed, deferred work item
- resource precedence/conflict handling for higher-level effective resource selection is part of that planned resource-loader architecture

Deferred plan:

```text
docs/continuity/PLANNED_2026-10-07_MINECRAFT_RESOURCE_ITEM_RENDERING_FOUNDATION.md
```

Execution prerequisite outside this repository:

```text
MtnLauncher Modrinth API foundation
→ MtnLauncher CurseForge API foundation
→ launcher UI/presentation need
→ return to minecraft_tools resource foundation
```

The planned resource work is not the next active checkpoint and must not start without a new explicit implementation approval.

### World/player expansion

- richer world metadata / cross-version normalization
- dimension/map presentation
- pre-26.1 embedded `Data.Player` singleplayer identity handling
- additional persisted player/world data only when needed by launcher/UI

### Item write/effective architecture

- item writing foundation
- effective item/registry defaults
- registry-derived capacities/defaults
- safe mutation/persistence policy

### Player progress semantics

- statistics units/aggregation/writing
- advancement definitions/display metadata/requirements/rewards
- semantic completion progress
- advancement writing

### Runtime/gameplay semantics

- attribute registry/runtime calculations
- potion/effect registry/runtime calculations
- resource-pack/item-model resolution
- nested runtime/block-entity inventory discovery
- richer Minecraft text runtime resolvers

### Advanced custom-data tooling

- legacy-to-modern migration/DataFixer integration
- NBT path query/mutation
- custom-data matching/mutation
- SNBT tooling
- mod-specific custom-data interpretation

### Separate integration work

Exact live server/sub-game/activity discovery remains future client-mod communication work. It must not be guessed from server address/logs alone.

## Authoritative handoffs

Server work:

```text
docs/continuity/HANDOFF_2026-10-02_MINECRAFT_INFO_PROVIDER_SERVER_FOUNDATION.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_SERVER_MANAGEMENT_HEALTH_CHECK.md
```

Item read work:

```text
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CORE_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_TEXT_ITEM_DISPLAY.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_POTION_PROPERTIES.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_ATTRIBUTE_MODIFIERS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_MODEL_DATA.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_NESTED_STACKS.md
docs/continuity/HANDOFF_2026-10-05_MINECRAFT_INFO_PROVIDER_ITEM_CUSTOM_DATA.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_READ_FOUNDATION_COMPLETE.md
```

Mod resource/name work:

```text
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_MOD_LANGUAGE_TRANSLATION_FOUNDATION.md
docs/continuity/HANDOFF_2026-10-06_MINECRAFT_INFO_PROVIDER_ITEM_NAME_RESOLUTION_FOUNDATION.md
```

Planned content batch-download architecture:

```text
docs/continuity/PLANNED_2026-10-07_MINECRAFT_CONTENT_BATCH_DOWNLOAD_FOUNDATION.md
```

That document records the batch-first download architecture, neutral content download-plan boundary, provider-owned source resolution, one-plan-to-one-launcher-`DownloadList` integration direction, and the rule that generic content code must not submit one independent download-manager operation per mod.

Deferred resource/rendering design:

```text
docs/continuity/PLANNED_2026-10-07_MINECRAFT_RESOURCE_ITEM_RENDERING_FOUNDATION.md
```

That document records the full planned resource-loader/helper/source architecture, Minecraft-version boundaries, image/texture result model, single-frame animation policy, 14-step / ~72-substep implementation plan, and the launcher Modrinth + CurseForge prerequisite.

## Development rules

Always follow `docs/WORKING_RULES.md`.

In particular:

- no implementation without explicit user approval
- no merge without separate explicit approval
- keep checkpoints small and independently reviewable
- do not run `dart format` for Pure Dart unless explicitly requested
- use `dart analyze`, focused tests, `dart test`, `git diff --check`, `git status`
- architecture/naming/dependency boundaries are acceptance criteria
- do not modify `hypixel_api/`
- do not add backward compatibility unless explicitly approved

## Next action

### Latest completed checkpoint: dev.28 — Installation Recovery and Cancellation Boundary Hardening

```text
checkpoint: dev.28 — In-Process Recovery + Cancellation Validation
branch: feature/minecraft-content-installation-recovery-hardening
baseline main: 92598cffa96dca105afde41d2d8b24de35b3be90
validated production/test HEAD: 1ff74dfd78c0482f9c3559765c5a0bc7046af371
final feature HEAD: 25f6021173f27e47fdfb270ae3c40a91cd430b73
PR: #56
main squash merge: a0ff4ca33859c4f157b13bc0efaf9109940d643a
package: minecraft_content_service 1.0.0-dev.28
status: IMPLEMENTED / WINDOWS VALIDATED (257/257 TESTS) / ACTUAL-DIFF + RECOVERY REVIEWED / SQUASH MERGED / CLOSED
```

Dev.28 extends the existing coordinated materialization and installation
executor with optional policy-compatible IO authority composition, retaining
the same coordinator owner for in-process forward-only commit retry and
reversible rollback retry. It introduces deterministic test collaborators
rather than another transaction algorithm or public production failpoints.

User-supplied Windows validation on the production/test HEAD:
`dart analyze` no issues, installation execution tests 25/25,
coordinator tests 23/23, full package tests 257/257, clean
`git diff --check main...HEAD`, clean synchronized working tree.
After this validated commit only two continuity documents changed before
PR #56 squash merge. The recovery audit found no critical static blocker.

Explicit limitations remain: injected collaborator method failures do not
prove interruption of an OS-level backup deletion inside its implementation.
No process-crash durability, power-loss recovery, cross-process atomicity,
or automatic recovery of manual candidates without a combined handle is
claimed. Retain these boundaries when planning the launcher integration.

Authoritative dev.28 record:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_INSTALLATION_RECOVERY_HARDENING.md
```

Dev.27 and dev.28 merged feature branch cleanup is not yet confirmed.
No next implementation checkpoint is approved. Future implementation and
merges require separate explicit approval. No `dart format` for pure Dart.

### Previously completed checkpoint: dev.27 — RemVibe Batch-to-Coordinated Installation Execution

```text
checkpoint: dev.27 — RemVibe Batch-to-Coordinated Installation Execution
branch: feature/minecraft-content-remvibe-installation-execution
baseline main: 0556ec6a20360a9ab840dc0d4010451d480ee260
validated production/test HEAD: 0f32eab1e630412fbc4f1367bf63a1ba5e774235
final feature HEAD: 4695564356548732027d7627bce4547457aca3c6
PR: #55
main squash merge: d6adb12233dd9fc9395345f7d7bf56a6bf9cf44d
package: minecraft_content_service 1.0.0-dev.27
status: IMPLEMENTED / WINDOWS VALIDATED (244 TESTS) / ACTUAL-DIFF REVIEWED / SQUASH MERGED / CLOSED
```

Dev.27 adds an opt-in `minecraft_content_service_remvibe_io.dart` integration.
A canonical materialization plan uses one existing RemVibe download batch when
transfers are needed, validates completed staging sources and a refreshed target
filesystem preflight, then uses the dev.26 coordinator to finalize managed
files and `.mtn-content/installation.json`. Empty/retain/remove-only plans
skip RemVibe entirely while still completing the coordinated transaction.
Staging files and global RemVibe job/service ownership remain with their
existing callers. The executor exposes guarded recovery retry methods.

Windows verification supplied by the user at the production/test HEAD:
`dart analyze` no issues; new installation-execution tests 19/19;
previous download-execution tests 7/7 and coordinator tests 16/16;
full package tests 244/244; `git diff --check` clean and worktree clean.
Only documentation changed after the production/test validation commit.
Actual-diff/recovery audit found no critical static blocker for merge.

Recovery limitations: these tests do not inject partial commit/rollback IO
cleanup failures or cancellation during pending coordinated publication;
no process-crash-durable journal or cross-process atomicity is claimed.
The dev.27 feature branch has not yet been cleaned up after the merge.

Authoritative design, implementation and validation record:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_REMVIBE_BATCH_INSTALLATION_EXECUTION.md
```

No next production checkpoint is approved. Future implementation and merges
require separate explicit approval; do not run `dart format` for pure Dart.

### Previously completed checkpoint: dev.26

```text
dev.26 — Materialization + Manifest Coordination
branch: feature/minecraft-content-materialization-manifest-coordination
baseline main: 096b328e4cfa8ea0ba4a2b62f1d3f994034803a8
validated production/test HEAD: c9253473e9b31a6d1e8264db1478ebdd1193eac4
final feature HEAD: 10086f58b4fc262183914a05c7aa5c31357e9051
PR: #54
main squash merge commit: 195af95f8523edac35e02a582d2cd1c01fa211d0
package: minecraft_content_service 1.0.0-dev.26
status: IMPLEMENTED / ACTUAL-DIFF REVIEWED / WINDOWS VALIDATED (225 TESTS) / MERGED / CLOSED
```

Dev.26 unifies dev.24 managed-file publication and dev.25 manifest persistence
under one in-process exclusive installation-root lease. It verifies current
persisted manifest state against the canonical plan, publishes the resulting
manifest, checks both recovery states before destructive commit cleanup,
and rolls back manifest then files. Once cleanup begins, commit retry is
forward-only.

Windows validation (user-supplied): `dart analyze` no issues, 16/16 coordinated
focused tests, 225/225 full package tests, clean diff check and working tree.
The last feature commits after validation changed only continuity documents.
Post-merge continuity closure was written directly to main.

No crash-durable journal, power-loss or cross-process atomicity guarantee;
injected interruption between managed-file and manifest cleanup phases
was not covered by these tests. Dev.26 feature branch cleanup has not
been requested or confirmed.

Authoritative design, boundary and validation record:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_MATERIALIZATION_MANIFEST_COORDINATION.md
```

No next production checkpoint is approved. Future implementation and merge
require separate explicit approval; do not run `dart format` for pure Dart.

Historical completed checkpoint:

```text
dev.25 — Installation Manifest Filesystem Persistence Foundation
branch: feature/minecraft-content-installation-manifest-persistence
baseline main: 39d8dc148489cb4f6b8003869486abcf7dc42820
validated feature HEAD: 1488c7e2dbd9d221d80c04a940df36226987f0ae
PR: #53
main squash merge commit: 76b01cc4a4f465fdd27d4960fe12683e6ee874ec
package: minecraft_content_service 1.0.0-dev.25
status: IMPLEMENTED / REVIEWED / VALIDATED (209 TESTS) / MERGED / CLOSED
```

This checkpoint introduces reversible manifest IO, root-lease coordination with dev.24
transactions and the reserved .mtn-content namespace. Generic manifest schema v1 and
provider interfaces remain unchanged. Manifest + content transaction coordination is
a separate future checkpoint.

Design and validation contract:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_INSTALLATION_MANIFEST_FILESYSTEM_PERSISTENCE.md
```

Dev.25 merge was separately approved and completed. No next implementation checkpoint
has been approved. Future merges require separate explicit approval. Do not run dart format.

Historical completed checkpoint:

```text
dev.24 — Whole-plan Materialization Transaction Foundation
branch: feature/minecraft-content-materialization-transaction
baseline main: 6955f67833875b17aeab43bf7579268d3a44834a
validated feature HEAD: b0d6e50d645abec7fa034322fdb20dfbccdb0b2b
PR: #52
main squash merge commit: 596f794801ff1e4f3b20db479fa6be736c6d7db4
package: minecraft_content_service 1.0.0-dev.24
status: IMPLEMENTED / ACTUAL-DIFF REVIEWED / VALIDATED (192 TESTS) / MERGED / CLOSED
```

Dev.24 implementation includes whole-plan reversible publication/removal execution,
policy-normalized physical obsolete-path derivation, private recovery ledger,
commit/rollback prevalidation, retained-file and backup snapshots, and root-level
coordination with standalone dev.23 publication.

Authoritative design and validation checklist:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_WHOLE_PLAN_TRANSACTION.md
```

Dev.24 merge was explicitly approved and completed. Next implementation checkpoint is not yet selected.
Future merges require separate explicit approval. No dart format for Pure Dart.

Historical completed checkpoint:

```text
dev.23 — Single-target Safe Publication Foundation
branch: feature/minecraft-content-single-target-publication
baseline main: 58f598e2d43ecd1c75a49c83c88de4f8091e3feb
production/test HEAD: eba5888e36847ca504cac59ea26a28ab49e0bed0
status: IMPLEMENTED / ACTUAL-DIFF REVIEWED / VALIDATED / CONTINUITY CLOSED / MERGED
package: minecraft_content_service 1.0.0-dev.23
```

Implemented boundary:

```text
safe dev.22 filesystem preflight
        ↓
one canonical install/replacement target
        ↓
caller-owned source File
        ↓
target-parent sibling staging copy
        ↓
integrity revalidation
        ↓
managed backup if required
        ↓
same-parent promotion
        ↓
reversible publication handle
        ├─ commit()
        └─ rollback()
```

Locked design:

- generic content planning remains independent from filesystem and RemVibe details
- publication remains on the explicit IO surface
- RemVibe batch/execution types are not required by the publication primitive
- caller-owned source must be a regular file and is never deleted, renamed or written by publication
- source may live on another volume because publication copies into target-parent sibling staging before promotion
- canonical content size/checksum metadata is revalidated after the copy and before promotion
- provider-neutral file integrity logic is shared internally; the existing RemVibe integrity class remains a delegating public adapter
- metadata-less sources use a transient SHA-256 only for source-copy and publication-finalization safety; the digest is not persisted into domain models or manifests
- installation-root resolution and target snapshot are rechecked after dev.22 preflight
- target snapshot is checked again after source copy and immediately before target mutation
- missing parents are created one segment at a time; linked, ambiguous or non-directory parents are blocking
- directories created by a failed publication are removed best-effort in reverse order and never recursively
- policy-normalized same-target operations serialize across filesystem authority instances
- the target lock remains owned by a successful publication handle until explicit commit or rollback
- a missing target is published by same-parent staging rename
- an existing managed target is first moved to a same-parent backup, then sibling staging is promoted
- publication failure before successful promotion preserves the old public target where portable Dart filesystem primitives allow recovery
- promotion failure after backup attempts immediate backup restore
- if promotion and restore both fail, recovery candidates are preserved and surfaced through a typed recovery exception
- commit revalidates the published target before discarding backup state
- rollback revalidates the published target and backup entity before changing the public target
- rollback of a replacement restores the previous managed target
- rollback of a newly created target removes the published target and publication-created empty directories
- repeated commit of a committed handle and repeated rollback of a rolled-back handle are idempotent
- opposite finalization after commit/rollback is rejected
- publication handles can only be finalized by the filesystem authority instance that created them

Existing behavior intentionally preserved:

- dev.22 filesystem/preflight implementation body is unchanged; only publication wiring imports/parts were added
- RemVibe public integrity types and expectedSize/checksums/validate surface remain present
- RemVibe missing-file, size, checksum, alias, malformed-hash and immutable-checksum semantics remain backed by the shared integrity authority

Focused publication coverage contains 14 tests.

Portable Dart limitation:

- preflight and publication perform the narrowest possible repeated state checks, but Dart File.rename does not expose a portable no-replace rename primitive
- a non-cooperating external process can theoretically race in the tiny interval between the final target check and rename on platforms whose rename semantics replace an existing destination
- same-target serialization eliminates this race between cooperating content-service publication operations
- a future native filesystem backend may tighten this external-process boundary if required

Still out of scope:

- iterating every install/replacement in a materialization plan
- executing remove actions
- whole-plan ordering
- multi-artifact transaction commit/rollback
- installation-manifest filesystem persistence
- RemVibe batch-to-publication orchestration
- staging-root cleanup policy
- TaskService orchestration
- unmanaged/manual cleanup
- deferred resource rendering

Independent actual-diff review completed before local validation.

Authoritative local validation completed successfully on feature HEAD:

```text
494fc3769267d5a0366eefc7d249aec2ab853174
```

Validation:

```text
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

Dev.23 is validated, continuity-closed and merged.

```text
PR: #51
merge commit: d5fce84bef749d8f78e7916cb594b5ea582ebdc7
```

The next natural checkpoint is dev.24 — Whole-plan Materialization Transaction. Start with audit + architecture/design only; no production implementation without explicit approval.

Active continuity document:

```text
docs/continuity/PLANNED_2026-10-08_MINECRAFT_CONTENT_SINGLE_TARGET_PUBLICATION.md
```

Previous completed checkpoint:

```text
dev.22 — Materialization Filesystem Preflight Foundation
PR: #50
merge commit: 1b0a350578de4e2ef09b16a560ba1babfd21ae49
post-merge main: 58f598e2d43ecd1c75a49c83c88de4f8091e3feb
```
