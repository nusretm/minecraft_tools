part of 'minecraft_content_materialization_file_system.dart';

/// Switches only manifest-owned content between Minecraft's scanned folders and
/// a private inactive folder. Exact versions and downloaded bytes are preserved.
class MtnMinecraftContentInstallationActivationFileSystem {
  MtnMinecraftContentInstallationActivationFileSystem({
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
  }) : policy = policy ?? MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    _inspector = MtnMinecraftContentMaterializationFileSystem(policy: this.policy);
    _manifest = MtnMinecraftContentInstallationManifestFileSystem(policy: this.policy);
  }

  static const String inactiveDirectoryName = '.mtn-disabled';

  final MtnMinecraftContentMaterializationFileSystemPolicy policy;
  late final MtnMinecraftContentMaterializationFileSystem _inspector;
  late final MtnMinecraftContentInstallationManifestFileSystem _manifest;

  /// [enabledVersionKeys] is computed from the resolved dependency graph:
  /// dependencies of any enabled root remain enabled even if independently
  /// disabled in the editor. Only tracked artifacts may be moved.
  Future<MtnMinecraftContentInstallationState> synchronize({
    required Directory installationRoot,
    required Set<String> enabledVersionKeys,
  }) async {
    final Directory root = await _manifest._resolveRoot(installationRoot);
    final _MaterializationCoordinatedRootLease lease =
        await _acquireMaterializationCoordinatedRootLease(root, policy);
    final List<(File, File, MtnMinecraftContentInstallationArtifact)> moved =
        <(File, File, MtnMinecraftContentInstallationArtifact)>[];
    MtnMinecraftContentInstallationManifestFileSystemPublication? publication;
    try {
      final _ManifestReadSnapshot snapshot = await _manifest._readSnapshotWithinCoordinator(
        installationRoot: installationRoot, lease: lease,
      );
      final MtnMinecraftContentInstallationManifest? existing = snapshot.manifest;
      if (existing == null) {
        return MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[]);
      }

      final List<MtnMinecraftContentInstallationArtifact> targetArtifacts =
          <MtnMinecraftContentInstallationArtifact>[];
      final List<(MtnMinecraftContentInstallationArtifact, MtnMinecraftContentInstallationArtifact)> changes =
          <(MtnMinecraftContentInstallationArtifact, MtnMinecraftContentInstallationArtifact)>[];
      for (final MtnMinecraftContentInstallationArtifact current in existing.installationState.artifacts) {
        final String old = current.relativePath;
        final bool inactive = old.startsWith('$inactiveDirectoryName/');
        final String base = inactive ? old.substring(inactiveDirectoryName.length + 1) : old;
        if (!<String>['mods', 'resourcepacks', 'shaderpacks'].contains(base.split('/').first) ||
            base.split('/').length != 2) {
          throw StateError('Activation does not support the managed content path "$old".');
        }
        final bool enabled = enabledVersionKeys.contains(current.version.key);
        final String next = enabled ? base : '$inactiveDirectoryName/$base';
        final MtnMinecraftContentInstallationArtifact target = next == old ? current :
            MtnMinecraftContentInstallationArtifact(
              version: current.version, file: current.file, relativePath: next,
            );
        targetArtifacts.add(target);
        if (next != old) changes.add((current, target));
      }
      if (changes.isEmpty) return existing.installationState;

      final MtnMinecraftContentInstallationState targetState =
          MtnMinecraftContentInstallationState(artifacts: targetArtifacts);
      final List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues =
          <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];
      _inspector._validateStatePaths(existing.installationState,
        MtnMinecraftContentMaterializationFileSystemStateScope.current, issues);
      _inspector._validateStatePaths(targetState,
        MtnMinecraftContentMaterializationFileSystemStateScope.resulting, issues);
      final Set<String> occupied = <String>{
        for (final entry in existing.installationState.artifacts)
          _inspector._pathIdentity(entry.relativePath),
      };
      for (final (current, target) in changes) {
        final oldState = await _inspector._inspectArtifact(root, current,
          MtnMinecraftContentMaterializationFileSystemStateScope.current, issues);
        final nextState = await _inspector._inspectArtifact(root, target,
          MtnMinecraftContentMaterializationFileSystemStateScope.resulting, issues);
        if (oldState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file ||
            nextState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.missing ||
            occupied.contains(_inspector._pathIdentity(target.relativePath))) {
          throw StateError('Unsafe managed content activation: "${current.relativePath}" -> "${target.relativePath}".');
        }
      }
      if (issues.isNotEmpty) {
        throw StateError('Managed content activation failed filesystem path preflight.');
      }
      // Validate all source bytes before making the first physical change.
      for (final (current, _) in changes) {
        final File source = File(p.joinAll(<String>[root.path, ...current.relativePath.split('/')]));
        final MtnMinecraftContentFileIntegrity? integrity =
            MtnMinecraftContentFileIntegrity.fromFile(current.file);
        if (integrity != null) {
          await integrity.validate(source, subject: 'Managed content activation source');
        }
      }

      for (final (current, target) in changes) {
        final File source = File(p.joinAll(<String>[root.path, ...current.relativePath.split('/')]));
        final File destination = File(p.joinAll(<String>[root.path, ...target.relativePath.split('/')]));
        if (await FileSystemEntity.type(source.path, followLinks: false) != FileSystemEntityType.file ||
            await FileSystemEntity.type(destination.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Managed content changed during activation; refusing to overwrite files.');
        }
        await destination.parent.create(recursive: true);
        if (await FileSystemEntity.type(destination.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Activation destination became occupied.');
        }
        await source.rename(destination.path);
        moved.add((source, destination, current));
      }

      publication = await _manifest._publishWithinCoordinator(
        installationRoot: installationRoot,
        manifest: MtnMinecraftContentInstallationManifest.fromInstallationState(targetState),
        lease: lease,
        expected: snapshot,
      );
      await _manifest.commit(publication);
      return targetState;
    } catch (error) {
      // A manifest publication which cannot be safely rolled back must keep
      // its moved files intact for recovery; never fabricate a valid old state.
      if (publication != null) {
        if (publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending ||
            publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.rollbackIncomplete) {
          await _manifest.rollback(publication);
        } else {
          rethrow;
        }
      }
      for (final (source, destination, _) in moved.reversed) {
        if (await FileSystemEntity.type(destination.path, followLinks: false) != FileSystemEntityType.file ||
            await FileSystemEntity.type(source.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Activation rollback requires manual recovery: ${destination.path}');
        }
        await destination.rename(source.path);
      }
      rethrow;
    } finally {
      lease.release();
    }
  }
}
