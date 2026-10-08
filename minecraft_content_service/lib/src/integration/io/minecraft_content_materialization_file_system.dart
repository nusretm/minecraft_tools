library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../service/minecraft_content_installation_state.dart';
import '../../service/minecraft_content_materialization_plan.dart';

part 'minecraft_content_materialization_file_system_policy.dart';
part 'minecraft_content_materialization_file_system_preflight.dart';

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
      } else if (state.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
            artifact: owners.first,
            physicalPath: state.physicalPath,
            entityType: state.entityType,
            reason: MtnMinecraftContentMaterializationFileSystemManagedArtifactReason.expectedRegularFile,
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
        base == 'CONIN$' ||
        base == 'CONOUT$' ||
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
