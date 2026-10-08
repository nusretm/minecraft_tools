# Minecraft Tools — dev.25 Installation Manifest Filesystem Persistence

Date: 2026-10-08

## State

- Repository: nusretm/minecraft_tools
- Branch: feature/minecraft-content-installation-manifest-persistence
- Baseline main: 39d8dc148489cb4f6b8003869486abcf7dc42820
- Package: minecraft_content_service 1.0.0-dev.25
- Production and tests: implemented in feature branch
- Local Windows validation: pending
- Merge: not approved / not performed
- Authoritative rules: docs/WORKING_RULES.md

## Architecture

The generic MtnMinecraftContentInstallationManifest schema-v1 serializer, installation state and model remain unchanged.

The explicit minecraft_content_service_io.dart entrypoint exposes:
- MtnMinecraftContentInstallationManifestFileSystem
- MtnMinecraftContentInstallationManifestFileSystemPublication
- MtnMinecraftContentInstallationManifestFileSystemPublicationState

The fixed installation-root-relative metadata path is:
  .mtn-content/installation.json

The entire .mtn-content directory is reserved by IO filesystem preflight against managed artifact paths, honoring the filesystem policy's case identity. No arbitrary user-selected metadata path or provider-specific format is introduced.

## Public lifecycle

- read(installationRoot): returns null only when no manifest file exists; valid file decodes with the existing strict codec. Corruption and unsafe filesystem entities raise an error; they never create an empty state or allow silent overwrite.
- publish(installationRoot, manifest): writes and flushes an encoded, integrity-verified sibling staging file and promotes it via rename. A previous valid manifest is moved to a sibling backup; its raw bytes are preserved, not reserialized. Returns a pending reversible publication.
- commit(publication): revalidates published bytes, path, backup and authority; removes retained backup and releases root lease.
- rollback(publication): revalidates published bytes, path, backup and authority; removes published manifest and restores exact previous raw bytes, or restores initial absence.
- Terminal same-direction finalization is idempotent; opposing finalizations and concurrent finalizations are rejected.
- Cleanup errors after destructive steps retain commitIncomplete/rollbackIncomplete for same-direction retries.

## Ownership, safety and coordination

- Metadata content and paths remain outside Minecraft-managed artifact target ownership.
- Manifest reads acquire a shared in-process installation root lease; manifest publication keeps an exclusive root lease until commit or rollback, using the same policy-normalized gate as dev.24 transactions.
- Current root and metadata ancestry are rechecked; symlink/ambiguous/non-file metadata paths are rejected.
- No startup auto-repair, no silent adoption, and no deletion of unmanaged paths.
- Caller-owned content model is not mutated.
- No durable process-crash journal, cross-process lock, or ACID isolation guarantee. External filesystem processes may race between portable Dart checks.
- If restoration fails before a publication handle can be returned, recovery candidate files are retained for manual recovery; the in-process lease remains held to avoid unsafe cooperating mutations.

## Deliberate next boundary

Dev.25 does not coordinate the manifest and dev.24 content transaction as one compound transaction. The combined ordering, fail/rollback semantics and activation boundary remain a separate checkpoint (candidate dev.26).

## Validation checklist

From minecraft_content_service:

    dart pub get
    dart analyze
    dart test test/content_installation_manifest_file_system_test.dart
    dart test test/content_installation_manifest_test.dart
    dart test test/content_materialization_file_system_preflight_test.dart
    dart test test/content_materialization_file_system_transaction_test.dart
    dart test test/content_materialization_file_system_publication_test.dart
    dart test

From repository root:

    git diff --check main...HEAD
    git status
    git rev-parse HEAD

Do not run dart format. Do not merge without separate explicit user approval.
