part of 'minecraft_content_materialization_file_system.dart';

extension _PrivateLayoutMigration on MtnMinecraftContentInstallationManifestFileSystem {
  Future<MtnMinecraftContentInstallationManifestFileSystemMigrationPlan> _migratePrivateLayout(
    Directory installationRoot,
  ) async {
    final root = await _resolveRoot(installationRoot);
    final lease = await _acquireMaterializationCoordinatedRootLease(root, policy);
    try {
      await _assertRootStable(installationRoot, root);
      final plan = await _buildPrivateLayoutMigrationPlan(installationRoot, lease: lease);
      if (plan.status != MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.ready) return plan;

      final legacyContent = Directory(p.join(root.path, legacyManifestDirectoryName));
      final legacyDisabled = Directory(p.join(root.path, '.mtn-disabled'));
      final privateRoot = Directory(p.join(root.path, privateDirectoryName));
      final modernContent = Directory(p.join(privateRoot.path, privateContentDirectoryName));
      final modernDisabled = Directory(p.join(privateRoot.path, 'disabled'));
      final original = File(p.join(legacyContent.path, manifestFileName));
      final oldBytes = await original.readAsBytes();
      if (oldBytes.length != plan.sourceManifestLength ||
          sha256.convert(oldBytes).toString() != plan.sourceManifestSha256) {
        throw StateError('Legacy manifest changed after migration preflight.');
      }

      final existingPrivate = await _privateLayoutDirectory(root.path, privateDirectoryName);
      if (existingPrivate != null && await _privateLayoutDirectory(existingPrivate.path, 'migration') != null) {
        throw StateError('Existing migration metadata needs manual inspection.');
      }

      bool disabledMoved = false;
      bool contentMoved = false;
      bool manifestBackedUp = false;
      bool manifestPromoted = false;
      final backup = File(p.join(modernContent.path, '.installation.json.old'));
      final staged = File(p.join(modernContent.path, '.installation.json.new'));
      final modernManifest = File(p.join(modernContent.path, manifestFileName));
      try {
        if (existingPrivate == null) await privateRoot.create();
        if (await legacyDisabled.exists()) {
          await legacyDisabled.rename(modernDisabled.path);
          disabledMoved = true;
        }
        await legacyContent.rename(modernContent.path);
        contentMoved = true;

        for (final move in plan.moves) {
          final target = File(p.joinAll(<String>[root.path, ...move.destinationRelativePath.split('/')]));
          if (await FileSystemEntity.type(target.path, followLinks: false) != FileSystemEntityType.file ||
              await target.length() != move.sourceLength ||
              await MtnMinecraftContentFileIntegrity.calculateSha256(target) != move.sourceSha256) {
            throw StateError('Inactive artifact failed verification: ${move.destinationRelativePath}');
          }
        }

        final bytes = plan.resultingManifest!.encode();
        await staged.create(exclusive: true);
        await staged.writeAsBytes(bytes, flush: true);
        if (await staged.length() != bytes.length ||
            await MtnMinecraftContentFileIntegrity.calculateSha256(staged) != plan.resultingManifestSha256) {
          throw StateError('Updated manifest failed staging verification.');
        }
        await modernManifest.rename(backup.path);
        manifestBackedUp = true;
        await staged.rename(modernManifest.path);
        manifestPromoted = true;
        if (await MtnMinecraftContentFileIntegrity.calculateSha256(modernManifest) != plan.resultingManifestSha256) {
          throw StateError('Updated manifest failed final verification.');
        }
        await backup.delete();
        return plan;
      } catch (error) {
        // Restore the existing folders when an ordinary in-process error occurs.
        // No journal or automatic process-crash recovery is attempted.
        try {
          if (manifestPromoted) await modernManifest.delete();
          if (manifestBackedUp) await backup.rename(modernManifest.path);
          if (await FileSystemEntity.type(staged.path, followLinks: false) == FileSystemEntityType.file) {
            await staged.delete();
          }
          if (contentMoved) await modernContent.rename(legacyContent.path);
          if (disabledMoved) await modernDisabled.rename(legacyDisabled.path);
          if (existingPrivate == null && await privateRoot.list(followLinks: false).isEmpty) {
            await privateRoot.delete();
          }
        } catch (restoreError) {
          throw StateError('Migration rollback failed; preserve files for manual inspection. Original: $error; restore: $restoreError');
        }
        rethrow;
      }
    } finally {
      lease.release();
    }
  }
}
