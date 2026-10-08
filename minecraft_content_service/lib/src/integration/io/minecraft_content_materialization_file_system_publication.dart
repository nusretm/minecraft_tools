part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemPublicationState {
  pending,
  committed,
  rolledBack,
}

enum MtnMinecraftContentMaterializationFileSystemPublicationFailure {
  sourceNotRegularFile,
  sourceAliasesTarget,
  sourceChangedDuringCopy,
  stalePreflight,
  integrityFailure,
  fileSystemFailure,
  recoveryFailure,
}

class MtnMinecraftContentMaterializationFileSystemPublicationException implements Exception {
  const MtnMinecraftContentMaterializationFileSystemPublicationException({
    required this.failure,
    required this.message,
    this.cause,
    this.backup,
    this.staging,
  });

  final MtnMinecraftContentMaterializationFileSystemPublicationFailure failure;
  final String message;
  final Object? cause;
  final File? backup;
  final File? staging;

  @override
  String toString() => 'MtnMinecraftContentMaterializationFileSystemPublicationException: $message';
}

class MtnMinecraftContentMaterializationFileSystemPublication {
  MtnMinecraftContentMaterializationFileSystemPublication._({
    required this.preflight,
    required this.materializationTarget,
    required this.source,
    required this.target,
    required this.previousTargetExisted,
    required this.backup,
    required List<Directory> createdDirectories,
    required Object authorityToken,
    required void Function() release,
  }) : createdDirectories = List<Directory>.unmodifiable(createdDirectories),
       _authorityToken = authorityToken,
       _release = release;

  final MtnMinecraftContentMaterializationFileSystemPreflight preflight;
  final MtnMinecraftContentMaterializationTarget materializationTarget;
  final File source;
  final File target;
  final bool previousTargetExisted;
  final File? backup;
  final List<Directory> createdDirectories;
  final Object _authorityToken;
  final void Function() _release;

  MtnMinecraftContentMaterializationFileSystemPublicationState _state = MtnMinecraftContentMaterializationFileSystemPublicationState.pending;
  bool _released = false;

  MtnMinecraftContentMaterializationFileSystemPublicationState get state => _state;

  void _releaseOnce() {
    if (_released) {
      return;
    }
    _released = true;
    _release();
  }
}


final Expando<Object> _publicationAuthorityTokens = Expando<Object>();
final Map<String, Completer<void>> _publicationTargetTails = <String, Completer<void>>{};
int _publicationTemporarySequence = 0;

extension MtnMinecraftContentMaterializationFileSystemPublicationOperations on MtnMinecraftContentMaterializationFileSystem {
  Future<MtnMinecraftContentMaterializationFileSystemPublication> publish({
    required MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    required MtnMinecraftContentMaterializationTarget target,
    required File source,
  }) async {
    if (!preflight.safe) {
      throw StateError('Publication requires a safe filesystem preflight.');
    }
    if (preflight.policy.platform != policy.platform || preflight.policy.caseSensitive != policy.caseSensitive) {
      throw ArgumentError.value(preflight, 'preflight', 'Publication requires a preflight built with the same filesystem policy.');
    }
    if (!_isPublicationTarget(preflight.plan, target)) {
      throw ArgumentError.value(target, 'target', 'Publication target must be the exact canonical install or replacement target from the preflight plan.');
    }

    final expectedStates = preflight.resultingArtifacts.where((item) => identical(item.artifact, target.artifact)).toList(growable: false);
    if (expectedStates.length != 1) {
      throw StateError('Preflight must expose exactly one canonical resulting artifact state for the publication target.');
    }
    final expectedState = expectedStates.single;
    if (expectedState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.missing &&
        expectedState.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
      throw StateError('Safe publication requires an expected missing or regular-file target state.');
    }

    final integrity = MtnMinecraftContentFileIntegrity.fromFile(target.artifact.file);
    final sourceType = await FileSystemEntity.type(source.path, followLinks: false);
    if (sourceType != FileSystemEntityType.file) {
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceNotRegularFile,
        message: 'Publication source is missing or is not a regular file: "${source.path}".',
      );
    }

    final release = await _acquirePublicationTarget(_publicationLockKey(preflight, target.relativePath));
    final createdDirectories = <Directory>[];
    File? siblingStaging;
    File? backup;
    bool preserveRecovery = false;

    try {
      await _assertInstallationRootStable(preflight);
      await _assertTargetSnapshot(preflight, target, expectedState);

      final parent = await _ensureTargetParent(
        preflight: preflight,
        target: target,
        createdDirectories: createdDirectories,
      );
      final targetFile = File(p.join(parent.path, target.relativePath.split('/').last));
      if (_absolutePathIdentity(source.path) == _absolutePathIdentity(targetFile.path)) {
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceAliasesTarget,
          message: 'Publication source must not be the managed target itself: "${source.path}".',
        );
      }

      final sourceLengthBefore = await source.length();
      siblingStaging = await _reservePublicationSibling(targetFile, 'staging');
      await source.openRead().pipe(siblingStaging.openWrite());
      final sourceTypeAfter = await FileSystemEntity.type(source.path, followLinks: false);
      final sourceLengthAfter = sourceTypeAfter == FileSystemEntityType.file ? await source.length() : -1;
      final stagedLength = await siblingStaging.length();

      if (sourceTypeAfter != FileSystemEntityType.file || sourceLengthAfter != sourceLengthBefore || stagedLength != sourceLengthBefore) {
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceChangedDuringCopy,
          message: 'Publication source changed while it was being copied: "${source.path}".',
        );
      }

      if (integrity != null) {
        try {
          await integrity.validate(
            siblingStaging,
            subject: 'Publication staging file',
          );
        } on MtnMinecraftContentFileIntegrityException catch (error) {
          throw MtnMinecraftContentMaterializationFileSystemPublicationException(
            failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.integrityFailure,
            message: error.message,
            cause: error,
          );
        }
      }

      await _assertTargetSnapshot(preflight, target, expectedState);

      if (expectedState.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.file) {
        final observed = await _inspectArtifact(
          preflight.resolvedInstallationRoot,
          target.artifact,
          MtnMinecraftContentMaterializationFileSystemStateScope.resulting,
          <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[],
        );
        final existingTarget = File(observed.physicalPath);
        backup = await _reservePublicationSibling(existingTarget, 'backup');
        await backup.delete();
        try {
          await existingTarget.rename(backup.path);
        } catch (error) {
          await _deletePublicationFileBestEffort(backup);
          backup = null;
          throw MtnMinecraftContentMaterializationFileSystemPublicationException(
            failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.fileSystemFailure,
            message: 'Failed to move the current managed target to a publication backup: "${existingTarget.path}".',
            cause: error,
          );
        }
      }

      try {
        await siblingStaging.rename(targetFile.path);
        siblingStaging = null;
      } catch (promotionError) {
        if (backup != null) {
          try {
            await backup.rename(targetFile.path);
            backup = null;
          } catch (restoreError) {
            preserveRecovery = true;
            throw MtnMinecraftContentMaterializationFileSystemPublicationException(
              failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
              message: 'Failed to publish "${targetFile.path}" and restore the previous managed file. Recovery candidates were preserved.',
              cause: restoreError,
              backup: backup,
              staging: siblingStaging,
            );
          }
        }
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.fileSystemFailure,
          message: 'Failed to promote publication staging to "${targetFile.path}".',
          cause: promotionError,
        );
      }

      return MtnMinecraftContentMaterializationFileSystemPublication._(
        preflight: preflight,
        materializationTarget: target,
        source: source,
        target: targetFile,
        previousTargetExisted: expectedState.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.file,
        backup: backup,
        createdDirectories: createdDirectories,
        authorityToken: _publicationAuthorityToken(this),
        release: release,
      );
    } catch (_) {
      if (!preserveRecovery && siblingStaging != null) {
        await _deletePublicationFileBestEffort(siblingStaging);
      }
      if (!preserveRecovery) {
        await _deletePublicationDirectoriesBestEffort(createdDirectories);
      }
      release();
      rethrow;
    }
  }

  Future<void> commit(
    MtnMinecraftContentMaterializationFileSystemPublication publication,
  ) async {
    _validatePublicationAuthority(publication);
    if (publication.state == MtnMinecraftContentMaterializationFileSystemPublicationState.committed) {
      return;
    }
    if (publication.state != MtnMinecraftContentMaterializationFileSystemPublicationState.pending) {
      throw StateError('A rolled-back publication cannot be committed.');
    }

    final backup = publication.backup;
    if (backup != null) {
      final backupType = await FileSystemEntity.type(backup.path, followLinks: false);
      if (backupType != FileSystemEntityType.notFound && backupType != FileSystemEntityType.file) {
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
          message: 'Publication backup is no longer a regular file and will not be deleted: "${backup.path}".',
        );
      }
      if (backupType == FileSystemEntityType.file) {
        try {
          await backup.delete();
        } catch (error) {
          throw MtnMinecraftContentMaterializationFileSystemPublicationException(
            failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
            message: 'Publication backup could not be deleted safely: "${backup.path}".',
            cause: error,
            backup: backup,
          );
        }
      }
    }

    publication._state = MtnMinecraftContentMaterializationFileSystemPublicationState.committed;
    publication._releaseOnce();
  }

  Future<void> rollback(
    MtnMinecraftContentMaterializationFileSystemPublication publication,
  ) async {
    _validatePublicationAuthority(publication);
    if (publication.state == MtnMinecraftContentMaterializationFileSystemPublicationState.rolledBack) {
      return;
    }
    if (publication.state != MtnMinecraftContentMaterializationFileSystemPublicationState.pending) {
      throw StateError('A committed publication cannot be rolled back.');
    }

    final targetType = await FileSystemEntity.type(publication.target.path, followLinks: false);
    if (targetType != FileSystemEntityType.file) {
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
        message: 'Published target is no longer a regular file and cannot be rolled back safely: "${publication.target.path}".',
      );
    }

    final displaced = await _reservePublicationSibling(publication.target, 'rollback');
    await displaced.delete();
    try {
      await publication.target.rename(displaced.path);
    } catch (error) {
      await _deletePublicationFileBestEffort(displaced);
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
        message: 'Failed to move the published target aside for rollback: "${publication.target.path}".',
        cause: error,
      );
    }

    final backup = publication.backup;
    if (backup != null) {
      try {
        await backup.rename(publication.target.path);
      } catch (restoreError) {
        try {
          await displaced.rename(publication.target.path);
        } catch (publishedRestoreError) {
          throw MtnMinecraftContentMaterializationFileSystemPublicationException(
            failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
            message: 'Rollback failed and the published target could not be restored. Recovery candidates were preserved.',
            cause: publishedRestoreError,
            backup: backup,
            staging: displaced,
          );
        }
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
          message: 'Rollback could not restore the previous managed file; the published target was restored.',
          cause: restoreError,
          backup: backup,
        );
      }
      await _deletePublicationFileBestEffort(displaced);
    } else {
      await _deletePublicationFileBestEffort(displaced);
      await _deletePublicationDirectoriesBestEffort(publication.createdDirectories);
    }

    publication._state = MtnMinecraftContentMaterializationFileSystemPublicationState.rolledBack;
    publication._releaseOnce();
  }

  bool _isPublicationTarget(
    MtnMinecraftContentMaterializationPlan plan,
    MtnMinecraftContentMaterializationTarget target,
  ) {
    return plan.installs.any((action) => identical(action.target, target)) ||
        plan.replacements.any((action) => identical(action.target, target));
  }

  Future<void> _assertInstallationRootStable(
    MtnMinecraftContentMaterializationFileSystemPreflight preflight,
  ) async {
    try {
      final resolved = await preflight.installationRoot.resolveSymbolicLinks();
      if (!p.equals(p.normalize(resolved), p.normalize(preflight.resolvedInstallationRoot.path))) {
        throw const MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          message: 'Installation root no longer resolves to the preflight root.',
        );
      }
    } on MtnMinecraftContentMaterializationFileSystemPublicationException {
      rethrow;
    } catch (error) {
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
        message: 'Installation root can no longer be resolved safely.',
        cause: error,
      );
    }
  }

  Future<void> _assertTargetSnapshot(
    MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    MtnMinecraftContentMaterializationTarget target,
    MtnMinecraftContentMaterializationFileSystemArtifactState expected,
  ) async {
    final observedIssues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];
    final observed = await _inspectArtifact(
      preflight.resolvedInstallationRoot,
      target.artifact,
      MtnMinecraftContentMaterializationFileSystemStateScope.resulting,
      observedIssues,
    );

    if (observedIssues.isNotEmpty || observed.entityType != expected.entityType) {
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
        message: 'Target filesystem state changed after preflight for "${target.relativePath}".',
      );
    }
    if (expected.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.file &&
        _absolutePathIdentity(observed.physicalPath) != _absolutePathIdentity(expected.physicalPath)) {
      throw MtnMinecraftContentMaterializationFileSystemPublicationException(
        failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
        message: 'Managed target identity changed after preflight for "${target.relativePath}".',
      );
    }
  }

  Future<Directory> _ensureTargetParent({
    required MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    required MtnMinecraftContentMaterializationTarget target,
    required List<Directory> createdDirectories,
  }) async {
    final segments = target.relativePath.split('/');
    var currentPath = preflight.resolvedInstallationRoot.path;

    for (final segment in segments.take(segments.length - 1)) {
      var resolution = await _resolveChild(currentPath, segment);
      if (resolution.inaccessible || resolution.matches.length > 1) {
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          message: 'Target parent cannot be resolved safely below "$currentPath".',
        );
      }

      if (resolution.matches.isEmpty) {
        final requested = Directory(p.join(currentPath, segment));
        bool createdByPublication = false;
        Object? createError;
        try {
          await requested.create();
          createdByPublication = true;
        } on FileSystemException catch (error) {
          createError = error;
        }

        resolution = await _resolveChild(currentPath, segment);
        if (resolution.matches.length != 1 || resolution.matches.single.type != FileSystemEntityType.directory) {
          throw MtnMinecraftContentMaterializationFileSystemPublicationException(
            failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
            message: 'Target parent could not be created or resolved safely below "$currentPath".',
            cause: createError,
          );
        }
        if (createdByPublication) {
          createdDirectories.add(Directory(resolution.matches.single.path));
        }
      }

      if (resolution.matches.length != 1 || resolution.matches.single.type != FileSystemEntityType.directory) {
        throw MtnMinecraftContentMaterializationFileSystemPublicationException(
          failure: MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          message: 'Target parent is no longer a regular directory below "$currentPath".',
        );
      }
      currentPath = resolution.matches.single.path;
    }

    return Directory(currentPath);
  }

  String _publicationLockKey(
    MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    String relativePath,
  ) {
    final root = _absolutePathIdentity(preflight.resolvedInstallationRoot.path);
    return '${policy.platform.name}:${policy.caseSensitive}:$root/${_pathIdentity(relativePath)}';
  }

  String _absolutePathIdentity(String value) {
    final normalized = p.normalize(p.absolute(value));
    return policy.caseSensitive ? normalized : normalized.toLowerCase();
  }

  void _validatePublicationAuthority(
    MtnMinecraftContentMaterializationFileSystemPublication publication,
  ) {
    if (!identical(publication._authorityToken, _publicationAuthorityToken(this))) {
      throw ArgumentError.value(publication, 'publication', 'Publication belongs to a different filesystem authority instance.');
    }
  }
}

Object _publicationAuthorityToken(
  MtnMinecraftContentMaterializationFileSystem fileSystem,
) {
  final existing = _publicationAuthorityTokens[fileSystem];
  if (existing != null) {
    return existing;
  }
  final token = Object();
  _publicationAuthorityTokens[fileSystem] = token;
  return token;
}

Future<void Function()> _acquirePublicationTarget(String key) async {
  final previous = _publicationTargetTails[key];
  final current = Completer<void>();
  _publicationTargetTails[key] = current;

  if (previous != null) {
    await previous.future;
  }

  bool released = false;
  return () {
    if (released) {
      return;
    }
    released = true;
    current.complete();
    if (identical(_publicationTargetTails[key], current)) {
      _publicationTargetTails.remove(key);
    }
  };
}

Future<File> _reservePublicationSibling(
  File target,
  String purpose,
) async {
  while (true) {
    final sequence = _publicationTemporarySequence++;
    final candidate = File(
      p.join(target.parent.path, '.mtn-content-$purpose-$pid-$sequence'),
    );
    try {
      return await candidate.create(exclusive: true);
    } on FileSystemException {
      final type = await FileSystemEntity.type(
        candidate.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        rethrow;
      }
    }
  }
}

Future<void> _deletePublicationFileBestEffort(File file) async {
  try {
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.notFound) {
      await file.delete();
    }
  } catch (_) {}
}

Future<void> _deletePublicationDirectoriesBestEffort(
  List<Directory> directories,
) async {
  for (final directory in directories.reversed) {
    try {
      await directory.delete();
    } catch (_) {}
  }
}
