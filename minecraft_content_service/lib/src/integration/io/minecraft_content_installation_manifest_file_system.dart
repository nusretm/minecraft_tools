part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentInstallationManifestFileSystemPublicationState {
  pending,
  committed,
  rolledBack,
  commitIncomplete,
  rollbackIncomplete,
}

class MtnMinecraftContentInstallationManifestFileSystemException implements Exception {
  const MtnMinecraftContentInstallationManifestFileSystemException(
    this.message, {
    this.cause,
    this.recoveryCandidates = const <File>[],
  });

  final String message;
  final Object? cause;
  final List<File> recoveryCandidates;

  @override
  String toString() => 'MtnMinecraftContentInstallationManifestFileSystemException: $message';
}

class MtnMinecraftContentInstallationManifestFileSystemPublication {
  MtnMinecraftContentInstallationManifestFileSystemPublication._({
    required this.installationRoot,
    required this.resolvedInstallationRoot,
    required this.target,
    required this.backup,
    required this.previousTargetPath,
    required this.createdManifestDirectory,
    required this.publishedLength,
    required this.publishedSha256,
    required this.previousLength,
    required this.previousSha256,
    required MtnMinecraftContentInstallationManifestFileSystem owner,
    required void Function() release,
  }) : _owner = owner, _release = release;

  final Directory installationRoot;
  final Directory resolvedInstallationRoot;
  final File target;
  final File? backup;
  final String? previousTargetPath;
  final bool createdManifestDirectory;
  final int publishedLength;
  final String publishedSha256;
  final int? previousLength;
  final String? previousSha256;

  final MtnMinecraftContentInstallationManifestFileSystem _owner;
  final void Function() _release;
  bool _released = false;
  bool _finalizing = false;
  MtnMinecraftContentInstallationManifestFileSystemPublicationState _state = MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending;

  MtnMinecraftContentInstallationManifestFileSystemPublicationState get state => _state;
  bool get previousTargetExisted => previousTargetPath != null;

  void _releaseOnce() {
    if (_released) return;
    _released = true;
    _release();
  }
}

class MtnMinecraftContentInstallationManifestFileSystem {
  MtnMinecraftContentInstallationManifestFileSystem({
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
  }) : policy = policy ?? MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    _inspector = MtnMinecraftContentMaterializationFileSystem(policy: this.policy);
  }

  static const String manifestDirectoryName = '.mtn-content';
  static const String manifestFileName = 'installation.json';

  final MtnMinecraftContentMaterializationFileSystemPolicy policy;
  late final MtnMinecraftContentMaterializationFileSystem _inspector;

  Future<MtnMinecraftContentInstallationManifest?> read({
    required Directory installationRoot,
  }) async {
    final root = await _resolveRoot(installationRoot);
    final release = await _acquireMaterializationRootFor(root, policy, exclusive: false);
    try {
      await _assertRootStable(installationRoot, root);
      final location = await _inspectLocation(root);
      if (!location.exists) return null;
      return MtnMinecraftContentInstallationManifest.decode(await location.target.readAsBytes());
    } finally {
      release();
    }
  }

  Future<MtnMinecraftContentInstallationManifestFileSystemPublication> publish({
    required Directory installationRoot,
    required MtnMinecraftContentInstallationManifest manifest,
  }) async {
    final root = await _resolveRoot(installationRoot);
    final bytes = manifest.encode();
    MtnMinecraftContentInstallationManifest.decode(bytes);

    final release = await _acquireMaterializationRootFor(root, policy, exclusive: true);
    File? staging;
    File? backup;
    String? previousTargetPath;
    int? previousLength;
    String? previousSha256;
    bool createdDirectory = false;
    bool preserveRecovery = false;
    bool published = false;
    try {
      await _assertRootStable(installationRoot, root);
      var location = await _inspectLocation(root);
      if (location.exists) {
        final oldBytes = await location.target.readAsBytes();
        MtnMinecraftContentInstallationManifest.decode(oldBytes);
        previousTargetPath = location.target.path;
        previousLength = oldBytes.length;
        previousSha256 = sha256.convert(oldBytes).toString();
      }

      if (location.directory == null) {
        final newDirectory = Directory(p.join(root.path, manifestDirectoryName));
        await newDirectory.create();
        createdDirectory = true;
        location = await _inspectLocation(root);
        if (location.directory == null || location.exists) {
          throw StateError('Manifest directory changed during creation.');
        }
      }

      staging = await _reservePublicationSibling(location.target, 'manifest-stage');
      await staging.writeAsBytes(bytes, flush: true);
      final publishedSha256 = sha256.convert(bytes).toString();
      if (await staging.length() != bytes.length ||
          await MtnMinecraftContentFileIntegrity.calculateSha256(staging) != publishedSha256) {
        throw StateError('Manifest staging failed integrity verification.');
      }

      await _assertRootStable(installationRoot, root);
      final freshLocation = await _inspectLocation(root);
      if (freshLocation.exists != (previousTargetPath != null) ||
          _identity(freshLocation.target.path) != _identity(location.target.path)) {
        throw StateError('Manifest target changed before publication.');
      }
      if (previousTargetPath != null) {
        final original = freshLocation.target;
        if (await original.length() != previousLength ||
            await MtnMinecraftContentFileIntegrity.calculateSha256(original) != previousSha256) {
          throw StateError('Existing manifest changed before backup.');
        }

        backup = await _reservePublicationSibling(original, 'manifest-backup');
        await backup.delete();
        await original.rename(backup.path);
        try {
          if (await backup.length() != previousLength ||
              await MtnMinecraftContentFileIntegrity.calculateSha256(backup) != previousSha256) {
            throw StateError('Original manifest backup changed during rename.');
          }
        } catch (error) {
          preserveRecovery = true;
          throw MtnMinecraftContentInstallationManifestFileSystemException(
            'Original manifest backup could not be verified; manual recovery is required.',
            cause: error,
            recoveryCandidates: <File>[if (backup != null) backup, if (staging != null) staging],
          );
        }
      }

      try {
        await staging.rename(location.target.path);
        published = true;
        staging = null;
      } catch (error) {
        if (backup != null) {
          try {
            await backup.rename(previousTargetPath!);
            backup = null;
          } catch (restoreError) {
            preserveRecovery = true;
            throw MtnMinecraftContentInstallationManifestFileSystemException(
              'Manifest promotion and restoration failed; manual recovery is required.',
              cause: restoreError,
              recoveryCandidates: <File>[if (backup != null) backup, if (staging != null) staging],
            );
          }
        }
        rethrow;
      }

      return MtnMinecraftContentInstallationManifestFileSystemPublication._(
        installationRoot: installationRoot,
        resolvedInstallationRoot: root,
        target: location.target,
        backup: backup,
        previousTargetPath: previousTargetPath,
        createdManifestDirectory: createdDirectory,
        publishedLength: bytes.length,
        publishedSha256: publishedSha256,
        previousLength: previousLength,
        previousSha256: previousSha256,
        owner: this,
        release: release,
      );
    } catch (_) {
      if (staging != null && !preserveRecovery) {
        await _deletePublicationFileBestEffort(staging);
      }
      if (createdDirectory && !preserveRecovery && !published) {
        await _deleteManifestDirectoryIfEmpty(root);
      }
      if (!preserveRecovery) {
        release();
      }
      rethrow;
    }
  }

  Future<void> commit(
    MtnMinecraftContentInstallationManifestFileSystemPublication publication,
  ) async {
    _assertOwner(publication);
    if (publication._finalizing) throw StateError('Manifest publication finalization is already in progress.');
    publication._finalizing = true;
    try {
      if (publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.committed) return;
      if (publication.state != MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending &&
          publication.state != MtnMinecraftContentInstallationManifestFileSystemPublicationState.commitIncomplete) {
        throw StateError('Manifest publication cannot be committed after rollback.');
      }

      await _validatePublished(publication);
      if (publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending) {
        await _validateBackup(publication);
      } else if (publication.backup != null) {
        final kind = await FileSystemEntity.type(publication.backup!.path, followLinks: false);
        if (kind == FileSystemEntityType.file) {
          await _validateBackup(publication);
        } else if (kind != FileSystemEntityType.notFound) {
          throw StateError('Manifest backup path was replaced after a partial commit.');
        }
      }

      publication._state = MtnMinecraftContentInstallationManifestFileSystemPublicationState.commitIncomplete;
      try {
        if (publication.backup != null) {
          final kind = await FileSystemEntity.type(publication.backup!.path, followLinks: false);
          if (kind == FileSystemEntityType.file) {
            await publication.backup!.delete();
          } else if (kind != FileSystemEntityType.notFound) {
            throw StateError('Manifest backup path is no longer a regular file.');
          }
        }
      } catch (error) {
        throw MtnMinecraftContentInstallationManifestFileSystemException(
          'Manifest backup cleanup failed; retry commit.',
          cause: error,
          recoveryCandidates: <File>[if (publication.backup != null) publication.backup!],
        );
      }

      publication._state = MtnMinecraftContentInstallationManifestFileSystemPublicationState.committed;
      publication._releaseOnce();
    } finally {
      publication._finalizing = false;
    }
  }

  Future<void> rollback(
    MtnMinecraftContentInstallationManifestFileSystemPublication publication,
  ) async {
    _assertOwner(publication);
    if (publication._finalizing) throw StateError('Manifest publication finalization is already in progress.');
    publication._finalizing = true;
    try {
      if (publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.rolledBack) return;
      if (publication.state != MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending &&
          publication.state != MtnMinecraftContentInstallationManifestFileSystemPublicationState.rollbackIncomplete) {
        throw StateError('Manifest publication cannot be rolled back after commit.');
      }

      final retry = publication.state == MtnMinecraftContentInstallationManifestFileSystemPublicationState.rollbackIncomplete;
      if (!retry) {
        await _validatePublished(publication);
      } else {
        await _validateRootAndParent(publication);
        final kind = await FileSystemEntity.type(publication.target.path, followLinks: false);
        if (kind == FileSystemEntityType.file) {
          await _validatePublished(publication);
        } else if (kind != FileSystemEntityType.notFound) {
          throw StateError('Manifest recovery target was unexpectedly replaced.');
        }
      }
      await _validateBackup(publication);

      publication._state = MtnMinecraftContentInstallationManifestFileSystemPublicationState.rollbackIncomplete;
      try {
        if (await FileSystemEntity.type(publication.target.path, followLinks: false) == FileSystemEntityType.file) {
          await publication.target.delete();
        }
        if (publication.backup != null) {
          await publication.backup!.rename(publication.previousTargetPath!);
        }
      } catch (error) {
        throw MtnMinecraftContentInstallationManifestFileSystemException(
          'Manifest rollback was interrupted; retry rollback.',
          cause: error,
          recoveryCandidates: <File>[if (publication.backup != null) publication.backup!],
        );
      }

      if (publication.createdManifestDirectory && publication.backup == null) {
        await _deleteManifestDirectoryIfEmpty(publication.installationRoot);
      }
      publication._state = MtnMinecraftContentInstallationManifestFileSystemPublicationState.rolledBack;
      publication._releaseOnce();
    } finally {
      publication._finalizing = false;
    }
  }

  void _assertOwner(MtnMinecraftContentInstallationManifestFileSystemPublication publication) {
    if (!identical(publication._owner, this)) throw ArgumentError.value(publication, 'publication', 'Manifest publication belongs to another filesystem authority.');
  }

  Future<Directory> _resolveRoot(Directory root) async {
    if (!p.isAbsolute(root.path) || !await root.exists()) {
      throw ArgumentError.value(root.path, 'installationRoot', 'Installation root must be an existing absolute directory.');
    }
    return Directory(await root.resolveSymbolicLinks());
  }

  Future<void> _assertRootStable(Directory requested, Directory resolved) async {
    try {
      final observed = await requested.resolveSymbolicLinks();
      if (_identity(observed) != _identity(resolved.path)) {
        throw StateError('Installation root changed after manifest preflight.');
      }
    } catch (error) {
      throw MtnMinecraftContentInstallationManifestFileSystemException(
        'Installation root cannot be resolved safely.',
        cause: error,
      );
    }
  }

  String _identity(String path) {
    final canonical = p.normalize(p.absolute(path));
    return policy.caseSensitive ? canonical : canonical.toLowerCase();
  }

  Future<_ManifestFileLocation> _inspectLocation(Directory root) async {
    final directoryMatch = await _inspector._resolveChild(root.path, manifestDirectoryName);
    if (directoryMatch.inaccessible || directoryMatch.matches.length > 1) {
      throw StateError('Manifest directory is inaccessible or ambiguous.');
    }
    if (directoryMatch.matches.isEmpty) {
      return _ManifestFileLocation(
        directory: null,
        target: File(p.join(root.path, manifestDirectoryName, manifestFileName)),
        exists: false,
      );
    }
    final matchedDirectory = directoryMatch.matches.single;
    if (matchedDirectory.type != FileSystemEntityType.directory) {
      throw StateError('Manifest directory must be a regular directory, not a link or file.');
    }
    final directory = Directory(matchedDirectory.path);
    final fileMatch = await _inspector._resolveChild(directory.path, manifestFileName);
    if (fileMatch.inaccessible || fileMatch.matches.length > 1) {
      throw StateError('Manifest file is inaccessible or ambiguous.');
    }
    if (fileMatch.matches.isEmpty) {
      return _ManifestFileLocation(
        directory: directory,
        target: File(p.join(directory.path, manifestFileName)),
        exists: false,
      );
    }
    final matchedFile = fileMatch.matches.single;
    if (matchedFile.type != FileSystemEntityType.file) {
      throw StateError('Manifest must be a regular file, not a link or directory.');
    }
    return _ManifestFileLocation(directory: directory, target: File(matchedFile.path), exists: true);
  }

  Future<void> _validateRootAndParent(MtnMinecraftContentInstallationManifestFileSystemPublication publication) async {
    await _assertRootStable(publication.installationRoot, publication.resolvedInstallationRoot);
    final location = await _inspectLocation(publication.resolvedInstallationRoot);
    if (location.directory == null || _identity(location.target.path) != _identity(publication.target.path)) {
      throw StateError('Manifest directory or physical path changed before finalization.');
    }
  }

  Future<void> _validatePublished(MtnMinecraftContentInstallationManifestFileSystemPublication publication) async {
    await _validateRootAndParent(publication);
    final kind = await FileSystemEntity.type(publication.target.path, followLinks: false);
    if (kind != FileSystemEntityType.file ||
        await publication.target.length() != publication.publishedLength ||
        await MtnMinecraftContentFileIntegrity.calculateSha256(publication.target) != publication.publishedSha256) {
      throw StateError('Published installation manifest changed before finalization.');
    }
  }

  Future<void> _validateBackup(MtnMinecraftContentInstallationManifestFileSystemPublication publication) async {
    final backup = publication.backup;
    if (backup == null) return;
    if (await FileSystemEntity.type(backup.path, followLinks: false) != FileSystemEntityType.file ||
        await backup.length() != publication.previousLength ||
        await MtnMinecraftContentFileIntegrity.calculateSha256(backup) != publication.previousSha256) {
      throw StateError('Original installation manifest backup was removed or changed.');
    }
  }

  Future<void> _deleteManifestDirectoryIfEmpty(Directory root) async {
    try {
      final location = await _inspectLocation(Directory(await root.resolveSymbolicLinks()));
      final directory = location.directory;
      if (directory != null && await directory.list(followLinks: false).isEmpty) {
        await directory.delete();
      }
    } catch (_) {
      // Best-effort only: never remove nonempty, linked or externally modified metadata directories.
      // Cleanup failure must not shadow the original publication error or strand the root lease.
    }
  }
}

class _ManifestFileLocation {
  const _ManifestFileLocation({
    required this.directory,
    required this.target,
    required this.exists,
  });

  final Directory? directory;
  final File target;
  final bool exists;
}
