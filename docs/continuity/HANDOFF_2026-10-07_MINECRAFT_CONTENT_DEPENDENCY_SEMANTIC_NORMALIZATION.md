# Minecraft Tools — Minecraft Content Dependency Semantic Normalization Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-semantic-normalization
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
Baseline main:
604f0ad6964e6c1147f9969619e5c16b5391a5b6
Validated feature HEAD:
c395e50d545d776223f978a486db2af8686c3f01
Implementation HEAD:
fd3793b062deccb19490185cff3be3c958272ebe
```

Package version: `1.0.0-dev.10`.

No `dart format` was run.

## Goal

Remove provider-ambiguous dependency type names before install/conflict policy is introduced.

The generic dependency enum now describes provider-independent semantics rather than reusing provider wire terminology.

## Generic dependency semantics

```dart
enum MtnMinecraftContentDependencyType {
  required,
  optional,
  incompatible,
  embeddedLibrary,
  bundled,
  tool,
}
```

Meanings:

- `required`: external dependency required by the declaring version
- `optional`: external dependency that is not automatically required
- `incompatible`: exclusion/conflict declaration
- `embeddedLibrary`: dependency represented externally and semantically intended as an installable embedded library dependency
- `bundled`: dependency already bundled/included by the declaring artifact and not semantically equivalent to an external embedded library
- `tool`: tool/informational dependency

This checkpoint names semantics only. It does not yet decide install behavior.

## Provider normalization

Modrinth:

```text
required       -> required
optional       -> optional
incompatible   -> incompatible
embedded       -> bundled
```

CurseForge:

```text
relationType 1 / EmbeddedLibrary    -> embeddedLibrary
relationType 2 / OptionalDependency -> optional
relationType 3 / RequiredDependency -> required
relationType 4 / Tool               -> tool
relationType 5 / Incompatible       -> incompatible
relationType 6 / Include            -> bundled
```

Provider wire tokens remain inside their provider mapper boundaries.

Generic core contains no Modrinth/CurseForge special-case policy.

## Persisted relation boundary

`MtnMinecraftContentRelationType` remains unchanged:

```dart
enum MtnMinecraftContentRelationType {
  included,
  embedded,
}
```

These values describe persisted version-to-version relations and are not the same concept as runtime dependency declarations.

No relation schema migration is part of this checkpoint.

## Backward compatibility

No deprecated aliases for dependency `embedded` or `included` were added.

The repository is still pre-first-release and `docs/WORKING_RULES.md` explicitly avoids backward-compatibility shims unless requested.

Serialized dependency enum names therefore follow the new semantic names.

## Graph behavior

Recursive dependency graph behavior is intentionally unchanged.

All dependency types are still graph metadata only in this checkpoint:

```text
required
optional
incompatible
embeddedLibrary
bundled
tool
```

The graph continues to resolve every dependency declaration through the existing dependency/version resolution path.

Install traversal behavior will be introduced only in the later install-policy checkpoint.

## Tests added/updated

Provider coverage now explicitly verifies:

- Modrinth `embedded` maps to generic `bundled`
- CurseForge relation types 1 through 6 map to:
  - `embeddedLibrary`
  - `optional`
  - `required`
  - `tool`
  - `incompatible`
  - `bundled`
- existing recursive graph tests use the normalized semantic enum names

Existing `required` behavior and all provider identity/version behavior remain unchanged.

## Deliberately not implemented

- install policy
- optional dependency user-selection policy
- incompatible conflict resolution
- embedded-library install policy
- bundled dependency suppression policy
- tool policy
- version-constraint parsing/evaluation
- artifact/file selection
- download/materialization
- installed-state reconciliation
- cross-provider association
- graph persistence/schema changes
- deferred item client-definition/model/texture rendering

## Validation

Authoritative user-supplied local validation on 2026-10-07:

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
On branch feature/minecraft-content-dependency-semantic-normalization
Your branch is up to date with 'origin/feature/minecraft-content-dependency-semantic-normalization'.
nothing to commit, working tree clean

git rev-parse HEAD
c395e50d545d776223f978a486db2af8686c3f01
```

No `dart format` was run.

## Next action

This checkpoint is implementation-complete, validated, and continuity-closed.

Merge is not yet requested and still requires separate explicit user approval.

Dependency install/conflict policy remains the likely next content-service checkpoint, but it is not automatically approved.
