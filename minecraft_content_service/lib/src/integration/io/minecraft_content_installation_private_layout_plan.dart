part of 'minecraft_content_materialization_file_system.dart';

/// Classification from a read-only Content Service private-layout preflight.
enum MtnMinecraftContentInstallationManifestFileSystemMigrationStatus {
  absent,
  alreadyModern,
  ready,
}

/// A verified disabled-content move proposed by the plan. This digest is
/// evidence for PRIVATE-1C to recheck, not permission to move later.
final class MtnMinecraftContentInstallationManifestFileSystemMigrationMove {
  const MtnMinecraftContentInstallationManifestFileSystemMigrationMove({
    required this.sourceRelativePath,
    required this.destinationRelativePath,
    required this.sourceLength,
    required this.sourceSha256,
  });

  final String sourceRelativePath;
  final String destinationRelativePath;
  final int sourceLength;
  final String sourceSha256;
}

/// Immutable migration snapshot. PRIVATE-1B never changes the filesystem.
final class MtnMinecraftContentInstallationManifestFileSystemMigrationPlan {
  MtnMinecraftContentInstallationManifestFileSystemMigrationPlan({
    required this.status,
    required this.resolvedInstallationRoot,
    required this.sourceManifestSha256,
    required this.sourceManifestLength,
    required this.resultingManifest,
    required this.resultingManifestSha256,
    required List<MtnMinecraftContentInstallationManifestFileSystemMigrationMove> moves,
  }) : moves = List<MtnMinecraftContentInstallationManifestFileSystemMigrationMove>.unmodifiable(moves);

  final MtnMinecraftContentInstallationManifestFileSystemMigrationStatus status;
  final Directory resolvedInstallationRoot;
  final String? sourceManifestSha256;
  final int? sourceManifestLength;
  final MtnMinecraftContentInstallationManifest? resultingManifest;
  final String? resultingManifestSha256;
  final List<MtnMinecraftContentInstallationManifestFileSystemMigrationMove> moves;
}

/// Uses the Content Service's existing filesystem and manifest authorities;
/// there is no second root coordinator or independent security scanner.
extension _PrivateLayoutMigrationPlanner on MtnMinecraftContentInstallationManifestFileSystem {
  Future<MtnMinecraftContentInstallationManifestFileSystemMigrationPlan> _buildPrivateLayoutMigrationPlan(
    Directory installationRoot,
  ) async {
    final root = await _resolveRoot(installationRoot);
    final release = await _acquireMaterializationRootFor(root, policy, exclusive: false);
    try {
      await _assertRootStable(installationRoot, root);
      final layout = await _inspectLayoutWithinCoordinator(root);
      final legacyLocation = await _inspectLocation(root);
      final legacyDisabled = await _privateLayoutDirectory(root.path, '.mtn-disabled');
      final private = await _privateLayoutDirectory(root.path, privateDirectoryName);

      if (layout.kind == MtnMinecraftContentInstallationManifestFileSystemLayoutKind.absent) {
        if (legacyDisabled != null || legacyLocation.directory != null) {
          throw StateError('Private layout contains legacy data without a manifest.');
        }
        if (private != null) {
          final content = await _privateLayoutDirectory(private.path, privateContentDirectoryName);
          final disabled = await _privateLayoutDirectory(private.path, 'disabled');
          if (content != null || disabled != null) {
            throw StateError('Private layout contains unclaimed Content Service directories.');
          }
        }
        return MtnMinecraftContentInstallationManifestFileSystemMigrationPlan(
          status: MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.absent,
          resolvedInstallationRoot: root,
          sourceManifestSha256: null,
          sourceManifestLength: null,
          resultingManifest: null,
          resultingManifestSha256: null,
          moves: const <MtnMinecraftContentInstallationManifestFileSystemMigrationMove>[],
        );
      }

      if (layout.kind == MtnMinecraftContentInstallationManifestFileSystemLayoutKind.modern) {
        if (legacyDisabled != null || legacyLocation.directory != null) {
          throw StateError('Modern installation conflicts with legacy Content Service data.');
        }
        // Even an already-current classification must not normalize a
        // linked, ambiguous, or non-directory inactive namespace.
        await _privateLayoutDirectory(private!.path, 'disabled');
        return MtnMinecraftContentInstallationManifestFileSystemMigrationPlan(
          status: MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.alreadyModern,
          resolvedInstallationRoot: root,
          sourceManifestSha256: layout.sha256,
          sourceManifestLength: layout.length,
          resultingManifest: layout.manifest,
          resultingManifestSha256: layout.sha256,
          moves: const <MtnMinecraftContentInstallationManifestFileSystemMigrationMove>[],
        );
      }

      // A recoverable manifest stage/backup or other unknown legacy file
      // must not be silently abandoned by a later content migration.
      await _verifyLegacyManifestInventory(legacyLocation.directory);

      // Until PRIVATE-1C provides a journal, even an empty target folder
      // cannot be assumed to belong to this migration.
      if (private != null) {
        if (await _privateLayoutDirectory(private.path, privateContentDirectoryName) != null ||
            await _privateLayoutDirectory(private.path, 'disabled') != null) {
          throw StateError('Migration destination is already occupied.');
        }
      }

      final previous = layout.manifest!;
      final rewritten = <MtnMinecraftContentInstallationArtifact>[];
      final moves = <MtnMinecraftContentInstallationManifestFileSystemMigrationMove>[];
      final expectedSourcePaths = <String>{};
      final issues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];

      _inspector._validateStatePaths(
        previous.installationState, MtnMinecraftContentMaterializationFileSystemStateScope.current, issues,
      );
      if (issues.isNotEmpty) {
        throw StateError('Legacy manifest contains unsafe or colliding managed paths.');
      }

      for (final artifact in previous.installationState.artifacts) {
        final segments = artifact.relativePath.split('/');
        final inactive = segments.first == '.mtn-disabled';
        final depth = inactive ? 3 : 2;
        if (segments.length != depth) {
          throw StateError('Unsupported managed artifact path: ${artifact.relativePath}');
        }
        final kind = inactive ? segments[1] : segments.first;
        if (!const <String>['mods', 'resourcepacks', 'shaderpacks'].contains(kind)) {
          throw StateError('Unsupported managed artifact kind: ${artifact.relativePath}');
        }

        final destinationPath = inactive
            ? '.mtn/disabled/${segments[1]}/${segments[2]}'
            : artifact.relativePath;
        final target = inactive
            ? MtnMinecraftContentInstallationArtifact(
                version: artifact.version, file: artifact.file, relativePath: destinationPath,
              )
            : artifact;
        rewritten.add(target);
        if (!inactive) continue;

        final identity = _inspector._pathIdentity(artifact.relativePath);
        if (!expectedSourcePaths.add(identity)) {
          throw StateError('Duplicate or case-colliding managed source: ${artifact.relativePath}');
        }
        final sourceState = await _inspector._inspectArtifact(
          root, artifact, MtnMinecraftContentMaterializationFileSystemStateScope.current, issues,
        );
        final targetState = await _inspector._inspectArtifact(
          root, target, MtnMinecraftContentMaterializationFileSystemStateScope.resulting, issues,
        );
        if (sourceState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file ||
            targetState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.missing ||
            issues.isNotEmpty) {
          throw StateError('Managed source or target is unsafe: ${artifact.relativePath}');
        }

        final source = File(sourceState.physicalPath);
        final initial = await source.stat();
        final integrity = MtnMinecraftContentFileIntegrity.fromFile(artifact.file);
        if (integrity != null) {
          await integrity.validate(source, subject: 'Private layout migration source');
        }
        final digest = await MtnMinecraftContentFileIntegrity.calculateSha256(source);
        final after = await source.stat();
        if (initial.type != FileSystemEntityType.file || after.type != FileSystemEntityType.file ||
            initial.size != after.size || initial.modified != after.modified) {
          throw StateError('Managed source changed during migration preflight.');
        }

        moves.add(MtnMinecraftContentInstallationManifestFileSystemMigrationMove(
          sourceRelativePath: artifact.relativePath,
          destinationRelativePath: destinationPath,
          sourceLength: after.size,
          sourceSha256: digest,
        ));
      }

      final resultingState = MtnMinecraftContentInstallationState(artifacts: rewritten);
      _inspector._validateStatePaths(
        resultingState, MtnMinecraftContentMaterializationFileSystemStateScope.resulting, issues,
      );
      if (issues.isNotEmpty) {
        throw StateError('New manifest has colliding or unsafe managed paths.');
      }

      await _verifyLegacyDisabledInventory(legacyDisabled, expectedSourcePaths);

      final resultingManifest = MtnMinecraftContentInstallationManifest.fromInstallationState(resultingState);
      final bytes = resultingManifest.encode();
      MtnMinecraftContentInstallationManifest.decode(bytes);
      await _assertRootStable(installationRoot, root);
      final observed = await _inspectLayoutWithinCoordinator(root);
      if (observed.kind != MtnMinecraftContentInstallationManifestFileSystemLayoutKind.legacy ||
          observed.sha256 != layout.sha256 || observed.length != layout.length) {
        throw StateError('Legacy manifest changed during private layout preflight.');
      }

      return MtnMinecraftContentInstallationManifestFileSystemMigrationPlan(
        status: MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.ready,
        resolvedInstallationRoot: root,
        sourceManifestSha256: layout.sha256,
        sourceManifestLength: layout.length,
        resultingManifest: resultingManifest,
        resultingManifestSha256: sha256.convert(bytes).toString(),
        moves: moves,
      );
    } finally {
      release();
    }
  }

  Future<Directory?> _privateLayoutDirectory(String parent, String segment) async {
    final match = await _inspector._resolveChild(parent, segment);
    if (match.inaccessible || match.matches.length > 1) {
      throw StateError('Private layout directory inaccessible or ambiguous: $segment');
    }
    if (match.matches.isEmpty) return null;
    final found = match.matches.single;
    if (found.type != FileSystemEntityType.directory) {
      throw StateError('Private layout path is not a regular directory: $segment');
    }
    return Directory(found.path);
  }

  Future<void> _verifyLegacyManifestInventory(Directory? directory) async {
    if (directory == null) {
      throw StateError('Legacy manifest directory disappeared during preflight.');
    }
    final entries = await directory.list(followLinks: false).toList();
    if (entries.length != 1 ||
        p.basename(entries.single.path) != manifestFileName ||
        await FileSystemEntity.type(entries.single.path, followLinks: false) != FileSystemEntityType.file) {
      throw StateError('Legacy manifest directory contains unowned or recoverable files.');
    }
  }

  Future<void> _verifyLegacyDisabledInventory(
    Directory? legacyDisabled,
    Set<String> expectedPaths,
  ) async {
    if (legacyDisabled == null) {
      if (expectedPaths.isNotEmpty) {
        throw StateError('Legacy disabled directory is missing required managed files.');
      }
      return;
    }
    final observed = <String>{};
    await for (final entry in legacyDisabled.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entry.path, followLinks: false);
      final relative = p.relative(entry.path, from: legacyDisabled.path)
          .replaceAll(Platform.pathSeparator, '/');
      final segments = relative.split('/');
      if (type == FileSystemEntityType.directory) {
        if (segments.length != 1 ||
            !const <String>['mods', 'resourcepacks', 'shaderpacks'].contains(segments.first)) {
          throw StateError('Unexpected directory in inactive content: $relative');
        }
        continue;
      }
      if (type != FileSystemEntityType.file || segments.length != 2 ||
          !const <String>['mods', 'resourcepacks', 'shaderpacks'].contains(segments.first)) {
        throw StateError('Unknown file or link in inactive content: $relative');
      }
      final identity = _inspector._pathIdentity('.mtn-disabled/$relative');
      if (!expectedPaths.contains(identity) || !observed.add(identity)) {
        throw StateError('Unmanaged or duplicated inactive content: $relative');
      }
    }
    if (observed.length != expectedPaths.length) {
      throw StateError('Managed inactive content inventory is incomplete.');
    }
  }
}
