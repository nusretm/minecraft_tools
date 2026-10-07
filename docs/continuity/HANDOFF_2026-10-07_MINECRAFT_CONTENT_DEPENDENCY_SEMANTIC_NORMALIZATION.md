# Minecraft Tools — Minecraft Content Dependency Semantic Normalization Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-dependency-semantic-normalization
Implementation: COMPLETE
Validation: PENDING USER-SUPPLIED LOCAL DART VALIDATION
Continuity: OPEN UNTIL VALIDATION
Merge: NOT REQUESTED
Baseline main:
604f0ad6964e6c1147f9969619e5c16b5391a5b6
Implementation HEAD before continuity updates:
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

Authoritative local validation is pending.

Required validation:

```text
cd D:\development\cross-platform\minecraft_tools\minecraft_content_service

dart analyze
dart test test/content_provider_modrinth_test.dart
dart test test/content_provider_curseforge_test.dart
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

If validation fails, fix only this approved semantic-normalization checkpoint.

If validation passes, record the supplied results here and in `docs/continuity/CURRENT_TARGET.md`, close continuity, and wait for separate explicit merge approval.

Dependency install/conflict policy remains the likely next content-service checkpoint, but it is not automatically approved.
