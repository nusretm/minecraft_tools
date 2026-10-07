# Minecraft Tools — Managed Installation Manifest Persistence Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.18 — Managed Installation Manifest Persistence Foundation
Branch: feature/minecraft-content-installation-manifest
Baseline main: fc29bda41c9fe659bb789ad7c9e33402afd4aeff
Production/test HEAD: 7aa0555336ab85c011fe7c34c9f0a6f5bb5a1d52
Validated feature HEAD: c702247bc9cad837fd7ec997695d7c08b53799ea
Implementation: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: APPROVED
Package version: 1.0.0-dev.18
```

No `dart format` was run.

## Goal

Provide restart-safe, provider-neutral persistence for the managed installation artifact state introduced in dev.16 and consumed by dev.17 materialization planning.

```text
MtnMinecraftContentInstallationState
        ↓
MtnMinecraftContentInstallationManifest
        ↓
Map / JSON / UTF-8
        ↓
application restart
        ↓
MtnMinecraftContentInstallationState
```

## Public surface

```dart
MtnMinecraftContentInstallationManifest

MtnMinecraftContentInstallationManifest.fromInstallationState(...)
MtnMinecraftContentInstallationManifest.fromMap(...)
MtnMinecraftContentInstallationManifest.fromJson(...)
MtnMinecraftContentInstallationManifest.decode(...)

installationState
toMap()
toJson()
encode()
```

## Persisted artifact identity

Each managed artifact stores:

- neutral installation-root-relative `relativePath`
- normalized content snapshot
- normalized version snapshot
- selected `fileIndex`

The selected file is not restored by filename.

Decode reconstructs:

```text
restored version
    ↓
version.files[fileIndex]
    ↓
MtnMinecraftContentInstallationArtifact
```

so the restored file is the exact canonical object instance owned by the restored version.

## Locked validation behavior

- schema version must be an integer and equal the supported current version
- artifact list must be a list
- each artifact/content/version entry must have the expected object shape
- persisted version content key must equal the embedded content snapshot key
- selected file index must be an integer and in range
- dev.16 path validation remains authoritative
- dev.16 canonical selected-file ownership remains authoritative
- dev.16 duplicate version/content/path ownership validation remains authoritative
- artifact order is preserved
- empty installation state round-trips

## Architecture boundary

The manifest is managed physical-artifact ownership persistence.

It is deliberately not `MtnMinecraftContentList` and does not become catalog/dependency-graph authority.

Version dependency records can be preserved as snapshot metadata, but dev.18 does not resolve those records or rebuild a dependency graph.

## Explicitly out of scope

- `dart:io`
- manifest filesystem location/name
- file read/write
- atomic manifest publication
- filesystem discovery
- byte transfer
- launcher DownloadJob / DownloadManager integration
- staging
- integrity verification
- target-OS path collision policy
- materialization execution
- copy/rename/delete
- rollback/transactions
- unmanaged/manual file cleanup
- deferred resource rendering

## Validation

Authoritative user-supplied local validation on 2026-10-08:

```text
dart analyze
No issues found!

content_installation_manifest_test.dart
9/9 passed

content_installation_state_test.dart
8/8 passed

content_materialization_plan_test.dart
9/9 passed

content_download_plan_test.dart
9/9 passed

dart test
127/127 passed

git diff --check main...HEAD
PASS

git status
working tree clean

git rev-parse HEAD
c702247bc9cad837fd7ec997695d7c08b53799ea
```

## Next boundary

The content-service planning/persistence chain is now restart-safe:

```text
desired state
    ↓
reconciliation
    ↓
file selection
    ↓
download source plan
    ↓
materialization plan
    ↓
resulting installation state
    ↓
installation manifest persistence
```

A later launcher-side checkpoint can adapt the planned downloads into one batch download job and implement staging/verification/publication/removal around the resulting state.
