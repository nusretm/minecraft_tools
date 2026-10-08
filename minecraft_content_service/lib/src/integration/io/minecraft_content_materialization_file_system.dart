library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../minecraft_content_file_integrity.dart';
import '../../service/minecraft_content_installation_state.dart';
import '../../service/minecraft_content_materialization_plan.dart';

part 'minecraft_content_materialization_file_system_policy.dart';
part 'minecraft_content_materialization_file_system_preflight.dart';
part 'minecraft_content_materialization_file_system_publication.dart';

class MtnMinecraftContentMaterializationFileSystem {
  MtnMinecraftContentMaterializationFileSystem({
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
  }) : policy = policy ?? MtnMinecraftContentMaterializationFileSystemPolicy.host();

  final MtnMinecraftContentMaterializationFileSystemPolicy policy;

  Future<MtnMinecraftContentMaterializationFileSystemPreflight> preflight({
    required MtnMinecraftContentMaterializationPlan plan,
    required Directory installationRoot,
  }) async {
    if (!p.isAbsolute(installationRoot.path)) {
      throw ArgumentError.value(installationRoot.path, 'installationRoot', 'Installation root must be absolute.');
    }
    if (!await installationRoot.exists()) {
      throw ArgumentError.value(installationRoot.path, 'installationRoot', 'Installation root must be an existing directory.');
    }

    final resolvedInstallationRoot = Directory(await installationRoot.resolveSymbolicLinks());
    final issues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];

    _validateStatePaths(
      plan.installation,
      MtnMinecraftContentMaterializationFileSystemStateScope.current,
      issues,
    );
    _validateStatePaths(
      plan.resultingInstallationState,
      MtnMinecraftContentMaterializationFileSystemStateScope.resulting,
      issues,
    );

    final retainedArtifacts = <MtnMinecraftContentInstallationArtifact>{
      for (final action in plan.retains) action.artifact,
    };

    final currentArtifacts = <MtnMinecraftContentMaterializationFileSystemArtifactState>[];
    for (final artifact in plan.installation.artifacts) {
      final state = await _inspectArtifact(
        resolvedInstallationRoot,
        artifact,
        MtnMinecraftContentMaterializationFileSystemStateScope.current,
        issues,
      );
      currentArtifacts.add(state);

      if (state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.link ||
          state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.blocked) {
        continue;
      }
      if (state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing) {
        if (retainedArtifacts.contains(artifact)) {
          issues.add(
            MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
              artifact: artifact,
              physicalPath: state.physicalPath,
              entityType: state.entityType,
              reason: MtnMinecraftContentMaterializationFileSystemManagedArtifactReason.retainedArtifactMissing,
            ),
          );
        }
        continue;
      }
      if (state.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
            artifact: artifact,
            physicalPath: state.physicalPath,
            entityType: state.entityType,
            reason: MtnMinecraftContentMaterializationFileSystemManagedArtifactReason.expectedRegularFile,
          ),
        );
      }
    }

    final currentOwners = <String, List<MtnMinecraftContentInstallationArtifact>>{};
    for (final artifact in plan.installation.artifacts) {
      currentOwners.putIfAbsent(_pathIdentity(artifact.relativePath), () => <MtnMinecraftContentInstallationArtifact>[]).add(artifact);
    }

    final resultingArtifacts = <MtnMinecraftContentMaterializationFileSystemArtifactState>[];
    for (final artifact in plan.resultingInstallationState.artifacts) {
      final state = await _inspectArtifact(
        resolvedInstallationRoot,
        artifact,
        MtnMinecraftContentMaterializationFileSystemStateScope.resulting,
        issues,
      );
      resultingArtifacts.add(state);

      if (state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing ||
          state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.link ||
          state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.blocked) {
        continue;
      }

      final owners = currentOwners[_pathIdentity(artifact.relativePath)] ?? const <MtnMinecraftContentInstallationArtifact>[];
      if (owners.isEmpty) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy(
            artifact: artifact,
            physicalPath: state.physicalPath,
            entityType: state.entityType,
          ),
        );
      }
    }

    return MtnMinecraftContentMaterializationFileSystemPreflight._(
      plan: plan,
      installationRoot: installationRoot,
      resolvedInstallationRoot: resolvedInstallationRoot,
      policy: policy,
      currentArtifacts: currentArtifacts,
      resultingArtifacts: resultingArtifacts,
      issues: issues,
    );
  }


  final Object _publicationAuthorityToken = Object();

  static final Map<String, Completer<void>> _publicationTargetTails = <String, Completer<void>>{};
  static int _publicationTemporarySequence = 0;

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

    final lockKey = _publicationLockKey(preflight, target.relativePath);
    final release = await _acquirePublicationTarget(lockKey);
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
        authorityToken: _publicationAuthorityToken,
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
        await backup.delete();
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

  static Future<void Function()> _acquirePublicationTarget(String key) async {
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

  static Future<File> _reservePublicationSibling(
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

  void _validatePublicationAuthority(
    MtnMinecraftContentMaterializationFileSystemPublication publication,
  ) {
    if (!identical(publication._authorityToken, _publicationAuthorityToken)) {
      throw ArgumentError.value(publication, 'publication', 'Publication belongs to a different filesystem authority instance.');
    }
  }

  static Future<void> _deletePublicationFileBestEffort(File file) async {
    try {
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.notFound) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> _deletePublicationDirectoriesBestEffort(
    List<Directory> directories,
  ) async {
    for (final directory in directories.reversed) {
      try {
        await directory.delete();
      } catch (_) {}
    }
  }

  void _validateStatePaths(
    MtnMinecraftContentInstallationState state,
    MtnMinecraftContentMaterializationFileSystemStateScope scope,
    List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues,
  ) {
    for (final artifact in state.artifacts) {
      if (policy.platform == MtnMinecraftContentMaterializationFileSystemPlatform.windows) {
        for (final segment in artifact.relativePath.split('/')) {
          if (!_validWindowsSegment(segment)) {
            issues.add(
              MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath(
                scope: scope,
                artifact: artifact,
                physicalPath: artifact.relativePath,
                reason: MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.windowsInvalidSegment,
                segment: segment,
              ),
            );
          }
        }
      }
    }

    for (var firstIndex = 0; firstIndex < state.artifacts.length; firstIndex++) {
      final first = state.artifacts[firstIndex];
      final firstIdentity = _pathIdentity(first.relativePath);

      for (var secondIndex = firstIndex + 1; secondIndex < state.artifacts.length; secondIndex++) {
        final second = state.artifacts[secondIndex];
        final secondIdentity = _pathIdentity(second.relativePath);

        if (firstIdentity == secondIdentity) {
          issues.add(
            MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision(
              scope: scope,
              first: first,
              second: second,
            ),
          );
          continue;
        }

        if (_isAncestor(firstIdentity, secondIdentity)) {
          issues.add(
            MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision(
              scope: scope,
              ancestor: first,
              descendant: second,
            ),
          );
        } else if (_isAncestor(secondIdentity, firstIdentity)) {
          issues.add(
            MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision(
              scope: scope,
              ancestor: second,
              descendant: first,
            ),
          );
        }
      }
    }
  }

  Future<MtnMinecraftContentMaterializationFileSystemArtifactState> _inspectArtifact(
    Directory root,
    MtnMinecraftContentInstallationArtifact artifact,
    MtnMinecraftContentMaterializationFileSystemStateScope scope,
    List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues,
  ) async {
    final segments = artifact.relativePath.split('/');
    final target = File(p.joinAll(<String>[root.path, ...segments]));
    var currentPath = root.path;

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final isFinal = index == segments.length - 1;
      final resolution = await _resolveChild(currentPath, segment);

      if (resolution.inaccessible) {
        final physicalPath = p.join(currentPath, segment);
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath(
            scope: scope,
            artifact: artifact,
            physicalPath: physicalPath,
            reason: MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.inaccessible,
            segment: segment,
          ),
        );
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: physicalPath,
          entityType: MtnMinecraftContentMaterializationFileSystemEntityType.blocked,
        );
      }

      if (resolution.matches.length > 1) {
        final physicalPath = p.join(currentPath, segment);
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath(
            scope: scope,
            artifact: artifact,
            physicalPath: physicalPath,
            reason: MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.ambiguousPhysicalIdentity,
            segment: segment,
          ),
        );
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: physicalPath,
          entityType: MtnMinecraftContentMaterializationFileSystemEntityType.blocked,
        );
      }

      if (resolution.matches.isEmpty) {
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: p.joinAll(<String>[currentPath, ...segments.sublist(index)]),
          entityType: MtnMinecraftContentMaterializationFileSystemEntityType.missing,
        );
      }

      final match = resolution.matches.single;
      if (match.type == FileSystemEntityType.link) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink(
            scope: scope,
            artifact: artifact,
            physicalPath: match.path,
          ),
        );
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: match.path,
          entityType: isFinal
              ? MtnMinecraftContentMaterializationFileSystemEntityType.link
              : MtnMinecraftContentMaterializationFileSystemEntityType.blocked,
        );
      }

      if (!isFinal && match.type != FileSystemEntityType.directory) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath(
            scope: scope,
            artifact: artifact,
            physicalPath: match.path,
            reason: MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.ancestorNotDirectory,
            segment: segment,
          ),
        );
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: match.path,
          entityType: MtnMinecraftContentMaterializationFileSystemEntityType.blocked,
        );
      }

      if (isFinal) {
        return MtnMinecraftContentMaterializationFileSystemArtifactState(
          artifact: artifact,
          target: target,
          physicalPath: match.path,
          entityType: _entityType(match.type),
        );
      }

      currentPath = match.path;
    }

    throw StateError('Artifact path inspection did not produce a final state.');
  }

  Future<_ChildResolution> _resolveChild(String parentPath, String requestedSegment) async {
    final matches = <_PhysicalEntry>[];
    try {
      await for (final entity in Directory(parentPath).list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (_segmentIdentity(name) != _segmentIdentity(requestedSegment)) {
          continue;
        }
        matches.add(
          _PhysicalEntry(
            path: entity.path,
            type: await FileSystemEntity.type(entity.path, followLinks: false),
          ),
        );
      }
      return _ChildResolution(matches: matches, inaccessible: false);
    } on FileSystemException {
      return const _ChildResolution(
        matches: <_PhysicalEntry>[],
        inaccessible: true,
      );
    }
  }

  String _pathIdentity(String relativePath) {
    return relativePath.split('/').map(_segmentIdentity).join('/');
  }

  String _segmentIdentity(String value) {
    return policy.caseSensitive ? value : value.toLowerCase();
  }

  bool _isAncestor(String ancestor, String descendant) {
    return descendant.startsWith('$ancestor/');
  }

  bool _validWindowsSegment(String segment) {
    if (segment.endsWith('.') || segment.endsWith(' ')) {
      return false;
    }
    if (segment.codeUnits.any((value) => value < 32)) {
      return false;
    }
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(segment)) {
      return false;
    }

    final base = segment.split('.').first.toUpperCase();
    if (base == 'CON' ||
        base == 'PRN' ||
        base == 'AUX' ||
        base == 'NUL' ||
        base == r'CONIN$' ||
        base == r'CONOUT$' ||
        RegExp(r'^COM[1-9]$').hasMatch(base) ||
        RegExp(r'^LPT[1-9]$').hasMatch(base)) {
      return false;
    }

    return true;
  }

  MtnMinecraftContentMaterializationFileSystemEntityType _entityType(FileSystemEntityType type) {
    if (type == FileSystemEntityType.notFound) {
      return MtnMinecraftContentMaterializationFileSystemEntityType.missing;
    }
    if (type == FileSystemEntityType.file) {
      return MtnMinecraftContentMaterializationFileSystemEntityType.file;
    }
    if (type == FileSystemEntityType.directory) {
      return MtnMinecraftContentMaterializationFileSystemEntityType.directory;
    }
    if (type == FileSystemEntityType.link) {
      return MtnMinecraftContentMaterializationFileSystemEntityType.link;
    }
    return MtnMinecraftContentMaterializationFileSystemEntityType.other;
  }
}

class _ChildResolution {
  const _ChildResolution({
    required this.matches,
    required this.inaccessible,
  });

  final List<_PhysicalEntry> matches;
  final bool inaccessible;
}

class _PhysicalEntry {
  const _PhysicalEntry({
    required this.path,
    required this.type,
  });

  final String path;
  final FileSystemEntityType type;
}
