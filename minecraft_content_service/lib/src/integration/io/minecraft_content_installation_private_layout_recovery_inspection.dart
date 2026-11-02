part of 'minecraft_content_materialization_file_system.dart';

/// Read-only classification: callers MUST NOT resume or migrate on their own.
enum MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus {
  absent,
  legacy,
  modern,
  recoveryRequired,
  blocked,
}

final class MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection {
  const MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection({
    required this.status,
    this.journal,
    this.reason,
  });

  final MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus status;
  final MtnMinecraftContentInstallationManifestFileSystemJournal? journal;
  final String? reason;

  bool get requiresIntervention =>
      status == MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.recoveryRequired ||
      status == MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked;
}

/// The shared root lease is only a Dart-runtime gate, not an OS process lock.
/// This inspector has no filesystem mutation API and does not attempt
/// automatic recovery, even for a valid journal.
extension _PrivateLayoutRecoveryInspector on MtnMinecraftContentInstallationManifestFileSystem {
  Future<MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection> _detectPrivateLayoutRecovery(
    Directory installationRoot,
  ) async {
    final root = await _resolveRoot(installationRoot);
    final release = await _acquireMaterializationRootFor(root, policy, exclusive: false);
    try {
      await _assertRootStable(installationRoot, root);
      try {
        final private = await _privateLayoutDirectory(root.path, MtnMinecraftContentInstallationManifestFileSystem.privateDirectoryName);
        final migration = private == null ? null : await _privateLayoutDirectory(
          private.path, MtnMinecraftContentInstallationManifestFileSystemJournal.directoryName,
        );
        if (migration != null) {
          // Only this one journal filename is recognized by C0. New versions
          // must explicitly add their stage/backup inventory rules.
          final entries = await migration.list(followLinks: false).toList();
          if (entries.length != 1) {
            throw const FormatException('Migration journal directory has missing or unknown entries.');
          }
          final child = await _inspector._resolveChild(
            migration.path, MtnMinecraftContentInstallationManifestFileSystemJournal.fileName,
          );
          if (child.inaccessible || child.matches.length != 1 ||
              child.matches.single.type != FileSystemEntityType.file ||
              p.normalize(child.matches.single.path) != p.normalize(entries.single.path)) {
            throw const FormatException('Migration journal is not one unambiguous regular file.');
          }
          final file = File(child.matches.single.path);
          final length = await file.length();
          if (length <= 0 || length > MtnMinecraftContentInstallationManifestFileSystemJournal.maxJournalBytes) {
            throw const FormatException('Migration journal size is unsafe.');
          }
          final encoded = await file.readAsString();
          if (utf8.encode(encoded).length != length) {
            throw const FormatException('Migration journal changed while being inspected.');
          }
          final journal = MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(encoded);
          final rootDigest = sha256.convert(utf8.encode(_identity(root.path))).toString();
          if (journal.rootIdentitySha256 != rootDigest) {
            throw const FormatException('Migration journal belongs to another installation root.');
          }
          // A journal must be investigated BEFORE dual-layout discovery:
          // cutover can leave both manifests, or temporarily neither.
          return MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
            status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.recoveryRequired,
            journal: journal,
          );
        }

        // A bare migration folder is not assumed to be harmless; the
        // preceding branch blocks it. With no journal, legacy/modern checks
        // retain their original fail-closed ambiguity rules.
        final layout = await _inspectLayoutWithinCoordinator(root);
        final legacyLocation = await _inspectLocation(root);
        final legacyDisabled = await _privateLayoutDirectory(root.path, '.mtn-disabled');
        final modernContent = private == null ? null : await _privateLayoutDirectory(
          private.path, MtnMinecraftContentInstallationManifestFileSystem.privateContentDirectoryName,
        );
        final modernDisabled = private == null ? null : await _privateLayoutDirectory(private.path, 'disabled');
        switch (layout.kind) {
          case MtnMinecraftContentInstallationManifestFileSystemLayoutKind.absent:
            if (legacyLocation.directory != null || legacyDisabled != null ||
                modernContent != null || modernDisabled != null) {
              throw const FormatException('Unclaimed private content folders exist without a manifest or journal.');
            }
            return const MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
              status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.absent,
            );
          case MtnMinecraftContentInstallationManifestFileSystemLayoutKind.legacy:
            if (modernContent != null || modernDisabled != null) {
              throw const FormatException('Modern content folders exist beside legacy authority without a journal.');
            }
            return const MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
              status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.legacy,
            );
          case MtnMinecraftContentInstallationManifestFileSystemLayoutKind.modern:
            if (legacyLocation.directory != null || legacyDisabled != null) {
              throw const FormatException('Legacy content folders exist beside modern authority without a journal.');
            }
            return const MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
              status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.modern,
            );
        }
      } on FormatException catch (error) {
        return MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
          status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked,
          reason: error.message,
        );
      } on StateError catch (error) {
        return MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
          status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked,
          reason: error.message,
        );
      } on FileSystemException catch (error) {
        return MtnMinecraftContentInstallationManifestFileSystemRecoveryInspection(
          status: MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked,
          reason: error.message,
        );
      }
    } finally {
      release();
    }
  }
}
