import 'dart:io';

import 'package:path/path.dart' as p;

import '../../service/minecraft_content_installation_state.dart';
import '../../service/minecraft_content_materialization_plan.dart';

enum MtnMinecraftContentMaterializationFileSystemPlatform {
  windows,
  posix,
}

class MtnMinecraftContentMaterializationFileSystemPolicy {
  const MtnMinecraftContentMaterializationFileSystemPolicy({
    required this.platform,
    required this.caseSensitive,
  });

  factory MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    if (Platform.isWindows) {
      return const MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.windows,
        caseSensitive: false,
      );
    }
    if (Platform.isMacOS) {
      return const MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
        caseSensitive: false,
      );
    }
    return const MtnMinecraftContentMaterializationFileSystemPolicy(
      platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
      caseSensitive: true,
    );
  }

  final MtnMinecraftContentMaterializationFileSystemPlatform platform;
  final bool caseSensitive;
}

enum MtnMinecraftContentMaterializationFileSystemEntityType {
  missing,
  file,
  directory,
  link,
  other,
}

enum MtnMinecraftContentMaterializationFileSystemStateScope {
  current,
  resulting,
}

enum MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason {
  windowsInvalidSegment,
  ancestorNotDirectory,
  ambiguousPhysicalIdentity,
  inaccessible,
}

enum MtnMinecraftContentMaterializationFileSystemManagedArtifactReason {
  retainedArtifactMissing,
  expectedRegularFile,
}

class MtnMinecraftContentMaterializationFileSystemArtifactState {
  const MtnMinecraftContentMaterializationFileSystemArtifactState({
    required this.artifact,
    required this.target,
    required this.physicalPath,
    required this.entityType,
  });

  final MtnMinecraftContentInstallationArtifact artifact;
  final File target;
  final String physicalPath;
  final MtnMinecraftContentMaterializationFileSystemEntityType entityType;
}

abstract class MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssue();
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision({
    required this.scope,
    required this.first,
    required this.second,
  });

  final MtnMinecraftContentMaterializationFileSystemStateScope scope;
  final MtnMinecraftContentInstallationArtifact first;
  final MtnMinecraftContentInstallationArtifact second;
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision({
    required this.scope,
    required this.ancestor,
    required this.descendant,
  });

  final MtnMinecraftContentMaterializationFileSystemStateScope scope;
  final MtnMinecraftContentInstallationArtifact ancestor;
  final MtnMinecraftContentInstallationArtifact descendant;
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath({
    required this.scope,
    required this.artifact,
    required this.physicalPath,
    required this.reason,
    this.segment,
  });

  final MtnMinecraftContentMaterializationFileSystemStateScope scope;
  final MtnMinecraftContentInstallationArtifact artifact;
  final String physicalPath;
  final MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason reason;
  final String? segment;
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact({
    required this.artifact,
    required this.physicalPath,
    required this.entityType,
    required this.reason,
  });

  final MtnMinecraftContentInstallationArtifact artifact;
  final String physicalPath;
  final MtnMinecraftContentMaterializationFileSystemEntityType entityType;
  final MtnMinecraftContentMaterializationFileSystemManagedArtifactReason reason;
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy({
    required this.artifact,
    required this.physicalPath,
    required this.entityType,
  });

  final MtnMinecraftContentInstallationArtifact artifact;
  final String physicalPath;
  final MtnMinecraftContentMaterializationFileSystemEntityType entityType;
}

class MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink extends MtnMinecraftContentMaterializationFileSystemPreflightIssue {
  const MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink({
    required this.scope,
    required this.artifact,
    required this.physicalPath,
  });

  final MtnMinecraftContentMaterializationFileSystemStateScope scope;
  final MtnMinecraftContentInstallationArtifact artifact;
  final String physicalPath;
}

class MtnMinecraftContentMaterializationFileSystemPreflight {
  MtnMinecraftContentMaterializationFileSystemPreflight._({
    required this.plan,
    required this.installationRoot,
    required this.resolvedInstallationRoot,
    required this.policy,
    required List<MtnMinecraftContentMaterializationFileSystemArtifactState> currentArtifacts,
    required List<MtnMinecraftContentMaterializationFileSystemArtifactState> resultingArtifacts,
    required List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues,
  }) : currentArtifacts = List<MtnMinecraftContentMaterializationFileSystemArtifactState>.unmodifiable(currentArtifacts),
       resultingArtifacts = List<MtnMinecraftContentMaterializationFileSystemArtifactState>.unmodifiable(resultingArtifacts),
       issues = List<MtnMinecraftContentMaterializationFileSystemPreflightIssue>.unmodifiable(issues);

  final MtnMinecraftContentMaterializationPlan plan;
  final Directory installationRoot;
  final Directory resolvedInstallationRoot;
  final MtnMinecraftContentMaterializationFileSystemPolicy policy;
  final List<MtnMinecraftContentMaterializationFileSystemArtifactState> currentArtifacts;
  final List<MtnMinecraftContentMaterializationFileSystemArtifactState> resultingArtifacts;
  final List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues;

  bool get safe => issues.isEmpty;
}

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
      final inspection = await _inspectArtifact(
        resolvedInstallationRoot,
        artifact,
        MtnMinecraftContentMaterializationFileSystemStateScope.current,
        issues,
      );
      currentArtifacts.add(inspection.state);

      if (inspection.state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.link) {
        continue;
      }
      if (inspection.state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing) {
        if (retainedArtifacts.contains(artifact)) {
          issues.add(
            MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
              artifact: artifact,
              physicalPath: inspection.state.physicalPath,
              entityType: inspection.state.entityType,
              reason: MtnMinecraftContentMaterializationFileSystemManagedArtifactReason.retainedArtifactMissing,
            ),
          );
        }
        continue;
      }
      if (inspection.state.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
            artifact: artifact,
            physicalPath: inspection.state.physicalPath,
            entityType: inspection.state.entityType,
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
      final inspection = await _inspectArtifact(
        resolvedInstallationRoot,
        artifact,
        MtnMinecraftContentMaterializationFileSystemStateScope.resulting,
        issues,
      );
      resultingArtifacts.add(inspection.state);

      final entityType = inspection.state.entityType;
      if (entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing ||
          entityType == MtnMinecraftContentMaterializationFileSystemEntityType.link) {
        continue;
      }

      final owners = currentOwners[_pathIdentity(artifact.relativePath)] ?? const <MtnMinecraftContentInstallationArtifact>[];
      if (owners.isEmpty) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy(
            artifact: artifact,
            physicalPath: inspection.state.physicalPath,
            entityType: entityType,
          ),
        );
      } else if (entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact(
            artifact: owners.first,
            physicalPath: inspection.state.physicalPath,
            entityType: entityType,
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

  Future<_ArtifactInspection> _inspectArtifact(
    Directory root,
    MtnMinecraftContentInstallationArtifact artifact,
    MtnMinecraftContentMaterializationFileSystemStateScope scope,
    List<MtnMinecraftContentMaterializationFileSystemPreflightIssue> issues,
  ) async {
    final segments = artifact.relativePath.split('/');
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
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: physicalPath,
            entityType: MtnMinecraftContentMaterializationFileSystemEntityType.other,
          ),
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
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: physicalPath,
            entityType: MtnMinecraftContentMaterializationFileSystemEntityType.other,
          ),
        );
      }

      if (resolution.matches.isEmpty) {
        final targetPath = p.joinAll(<String>[currentPath, ...segments.sublist(index)]);
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: targetPath,
            entityType: MtnMinecraftContentMaterializationFileSystemEntityType.missing,
          ),
        );
      }

      final match = resolution.matches.single;
      final entityType = _entityType(match.type);

      if (match.type == FileSystemEntityType.link) {
        issues.add(
          MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink(
            scope: scope,
            artifact: artifact,
            physicalPath: match.path,
          ),
        );
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: match.path,
            entityType: entityType,
          ),
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
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: match.path,
            entityType: entityType,
          ),
        );
      }

      if (isFinal) {
        return _ArtifactInspection(
          state: MtnMinecraftContentMaterializationFileSystemArtifactState(
            artifact: artifact,
            target: File(p.joinAll(<String>[root.path, ...segments])),
            physicalPath: match.path,
            entityType: entityType,
          ),
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

class _ArtifactInspection {
  const _ArtifactInspection({
    required this.state,
  });

  final MtnMinecraftContentMaterializationFileSystemArtifactState state;
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
