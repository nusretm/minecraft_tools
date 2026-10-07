# Minecraft Tools — Managed Installation Manifest Persistence Foundation

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.18 — Managed Installation Manifest Persistence Foundation
Branch: feature/minecraft-content-installation-manifest
Baseline main: fc29bda41c9fe659bb789ad7c9e33402afd4aeff
Production/test HEAD: 7aa0555336ab85c011fe7c34c9f0a6f5bb5a1d52
Package version: 1.0.0-dev.18
Implementation: COMPLETE
Validation: PENDING
Merge: NOT REQUESTED
```

No `dart format` was run.

## Why this checkpoint exists

Dev.16 introduced authoritative managed installation artifact ownership and dev.17 can produce the resulting state after a materialization plan.

Without a portable persistence contract, that ownership exists only for the current process lifetime.

After restart, replace/remove logic must not guess an old managed artifact from a provider version or filename.

```text
successful materialization
        ↓
resultingInstallationState
        ↓
portable manifest
        ↓
application restart
        ↓
authoritative installation state restored
        ↓
next reconciliation
```

## Public surface

```dart
MtnMinecraftContentInstallationManifest

MtnMinecraftContentInstallationManifest.fromInstallationState(...)
MtnMinecraftContentInstallationManifest.fromMap(...)
MtnMinecraftContentInstallationManifest.fromJson(...)
MtnMinecraftContentInstallationManifest.decode(...)

manifest.installationState
manifest.toMap()
manifest.toJson()
manifest.encode()
```

The manifest reuses the existing `MtnMinecraftContentModel` codec for JSON and UTF-8 serialization.

## Schema

Current schema version:

```text
1
```

Logical shape:

```text
schemaVersion: 1
artifacts:
  - relativePath
    content
    version
    fileIndex
```

Each artifact carries enough normalized metadata to reconstruct a valid dev.16 installation artifact without provider calls or filesystem inspection.

## Content and version snapshots

Each artifact stores:

- the normalized content snapshot
- the normalized version snapshot

These snapshots preserve provider metadata, file metadata and other normalized version fields already represented by the generic models.

This manifest is not a replacement for `MtnMinecraftContentList`.

It does not own:

- full catalog membership
- selected catalog versions
- cross-content relation graphs
- dependency graph resolution

Dependency declarations contained in a version remain serialized metadata. Decoding this manifest does not resolve those declarations into a complete dependency graph.

## Canonical selected-file reconstruction

The selected file is persisted as:

```text
fileIndex
```

inside the persisted version file list.

It is deliberately not restored by filename.

During decode:

```text
version snapshot
        ↓
MtnMinecraftContentVersion.fromMap(...)
        ↓
version.files[fileIndex]
        ↓
MtnMinecraftContentInstallationArtifact
```

Therefore the restored artifact file is the exact object instance owned by the restored version and dev.16's canonical identity invariant is satisfied.

## Version/content ownership validation

`MtnMinecraftContentVersion.fromMap(..., content)` receives the owner content externally and does not itself consume the persisted `version.content` key.

The manifest therefore validates before version construction:

```text
version snapshot content key
        ==
embedded content snapshot key
```

A mismatch is invalid persistence and fails fast.

## Strict parsing

The persistence boundary does not use permissive fallback conversion for structural fields.

Required structural rules include:

- `schemaVersion` must be an integer
- only the current supported schema version is accepted
- `artifacts` must be a list
- every artifact must be an object
- `relativePath` must be a string
- `content` must be an object
- `version` must be an object
- `fileIndex` must be an integer
- `fileIndex` must be within the restored version file list

Malformed persistence is rejected rather than silently normalized to an empty/default value.

## Reused dev.16 invariants

After snapshot reconstruction, the existing constructors remain authoritative for:

- relative-path safety
- canonical selected-file ownership
- duplicate version keys
- duplicate logical-content ownership
- duplicate exact relative paths
- immutable installation state

Dev.18 does not duplicate those policies.

## Round-trip boundary

Supported portable transformations:

```text
InstallationState
    ↕
InstallationManifest
    ↕
Map<String, dynamic>
    ↕
JSON String
    ↕
UTF-8 Uint8List
```

The manifest contains no machine-specific absolute path.

## Explicitly out of scope

- `dart:io`
- choosing the manifest file location/name
- reading/writing a filesystem file
- atomic file replacement
- filesystem discovery
- file existence checks
- byte download execution
- launcher DownloadJob / DownloadManager integration
- staging
- integrity verification
- target-OS collision preflight
- materialization execution
- file copy/rename/delete
- rollback/transactions
- unmanaged/manual artifact cleanup
- resource/item rendering

## Validation required

Run from `minecraft_content_service/`:

```text
dart analyze
dart test test/content_installation_manifest_test.dart
dart test test/content_installation_state_test.dart
dart test test/content_materialization_plan_test.dart
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
7aa0555336ab85c011fe7c34c9f0a6f5bb5a1d52
```

Do not merge without separate explicit user approval.
