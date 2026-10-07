# Minecraft Tools — Minecraft Content Recursive Dependency Graph Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-recursive-dependency-graph
Implementation: COMPLETE
Validation: PENDING USER-SUPPLIED LOCAL DART VALIDATION
Continuity: OPEN UNTIL VALIDATION
Merge: NOT REQUESTED
Baseline main:
b6a729cd3cfb78141196b7774726ac4b06224da8
Production/test HEAD before final continuity sync:
4fd032395c081f143a2186519569ac06f8cb54cf
```

Package version: `1.0.0-dev.9`.

No `dart format` was run.

## Goal

Add a provider-independent recursive dependency graph layer on top of the completed identity and version-selection foundations.

The graph describes dependency declarations and their runtime resolution results. It does not produce an install plan or interpret dependency relation types as policy.

## Public surface

New graph model:

```dart
MtnMinecraftContentDependencyGraph
```

Public fields:

```dart
root
versions
edges
unresolvedEdges
cyclicEdges
```

New edge model:

```dart
MtnMinecraftContentDependencyGraphEdge
```

Public fields:

```dart
source
dependency
resolution
target
cyclic
resolved
```

New service operation:

```dart
Future<MtnMinecraftContentDependencyGraph> resolveDependencyGraph(
  MtnMinecraftContentVersion root,
  MtnMinecraftContentVersionSelectionRequest request,
)
```

Graph models live under `src/service/` because they represent service orchestration results rather than provider wire/contracts.

## Locked graph semantics

1. the caller supplies the root version; graph resolution does not choose or replace the root
2. the root version is the first graph version
3. each version's dependency declarations are traversed in declaration order
4. traversal is deterministic depth-first
5. every dependency edge is resolved through the existing `resolveDependencyVersion()` path
6. dependency identity/version-selection behavior is therefore not reimplemented in the graph layer
7. unresolved dependencies are retained as edges with `target == null`
8. unresolved dependencies are not graph-construction errors
9. resolved version identity uses `MtnMinecraftContentVersion.key` as the graph node identity
10. the first version object observed for a key becomes the canonical graph version object
11. later edges resolving to the same version key point to that canonical node
12. shared nodes are expanded only once
13. all declaring edges are preserved even when they point to an already expanded shared node
14. direct and deep cycles are retained as edges with `cyclic == true`
15. a cyclic edge stops recursion at that edge rather than throwing
16. dependency relation type is preserved only as declaration metadata
17. required/optional/incompatible/embedded/included/tool do not change traversal behavior
18. provider identity remains authoritative per dependency; no provider is guessed
19. the input root/version/dependency models are not mutated
20. graph result collections are immutable

## Deterministic traversal example

For:

```text
A
├─ B
│  └─ D
└─ C
   └─ D
```

the depth-first graph order is:

```text
versions:
A, B, D, C

edges:
A -> B
B -> D
A -> C
C -> D
```

`D` is one graph node while both declaring edges remain present.

## Cycle example

For:

```text
A -> B -> C -> A
```

the graph contains:

```text
A -> B
B -> C
C -> A  cyclic=true
```

and traversal terminates normally.

Direct self-dependency `A -> A` is handled by the same path rule.

## Existing boundaries preserved

The graph layer does not alter:

- `resolveDependency()`
- `resolveDependencyVersion()`
- provider registration/readiness
- provider-specific exact lookup
- provider-specific version listing/filtering
- `MtnMinecraftContentRelation`

`MtnMinecraftContentRelation` remains the persisted version-to-version included/embedded relation model. Runtime dependency graph edges are a separate concept.

## Deliberately not implemented

- root-version selection
- `versionConstraint` parsing/evaluation
- required/optional install policy
- incompatible conflict resolution
- embedded/included/tool installation semantics
- dependency winner selection
- artifact/file selection
- download/materialization
- cross-provider lookup or association
- dependency failure aggregation/recovery policy
- graph persistence/schema changes
- CurseForge live smoke
- deferred item client-definition/model/texture rendering

Provider errors that already surface from identity/version selection continue to propagate. Broader graph error policy is a later checkpoint.

## Tests added

Service coverage includes:

- deterministic depth-first traversal
- exact-version child resolution
- content-only child version selection
- unresolved leaf preservation
- all current dependency relation types preserved without policy
- diamond/shared dependency node collapse
- shared nodes expanded once while all incoming edges remain
- deep cycle detection
- direct self-cycle detection
- provider isolation
- graph collection immutability
- input dependency non-mutation

A dedicated multi-content fake provider is used only by tests so existing provider-service fixtures keep their established behavior.

## Validation

Authoritative local validation is pending.

Required validation:

```text
cd D:\development\cross-platform\minecraft_tools\minecraft_content_service

dart analyze
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

If validation fails, fix only this approved recursive dependency graph checkpoint.

If validation passes, record the supplied results here and in `docs/continuity/CURRENT_TARGET.md`, close continuity, and wait for separate explicit merge approval.

Install/conflict policy and artifact/materialization work remain separate future checkpoints and are not automatically approved.
