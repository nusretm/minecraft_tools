part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemEntityType {
  missing,
  file,
  directory,
  link,
  blocked,
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
