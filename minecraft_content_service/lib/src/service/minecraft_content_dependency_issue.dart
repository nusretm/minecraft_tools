import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_graph.dart';
import 'minecraft_content_dependency_install_plan.dart';

/// An explanation of a failed dependency plan, not the Item's metadata/hydration state.
enum MtnMinecraftContentDependencyIssueType { unresolvedRequired, incompatible, multipleVersions }

final class MtnMinecraftContentDependencyIssue {
  const MtnMinecraftContentDependencyIssue({
    required this.type,
    required this.rootVersionKey,
    required this.rootContentKey,
    this.sourceVersionKey,
    this.sourceContentKey,
    this.dependencyProvider,
    this.dependencyProjectId,
    this.dependencyContentKey,
    this.dependencyName,
    this.dependencyVersionId,
    this.versionConstraint,
    this.fileName,
    this.conflictingVersionKey,
  });

  factory MtnMinecraftContentDependencyIssue.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'];
    final type = MtnMinecraftContentDependencyIssueType.values.where((value) => value.name == typeName).firstOrNull;
    if (type == null || map['rootVersionKey'] is! String || map['rootContentKey'] is! String ||
        map['rootVersionKey'] == '' || map['rootContentKey'] == '') {
      throw const FormatException('Invalid dependency issue identity.');
    }
    for (final key in const <String>['sourceVersionKey', 'sourceContentKey', 'dependencyProvider',
      'dependencyProjectId', 'dependencyContentKey', 'dependencyName', 'dependencyVersionId', 'versionConstraint', 'fileName', 'conflictingVersionKey']) {
      if (map[key] != null && map[key] is! String) throw FormatException('Invalid dependency issue field $key.');
    }
    return MtnMinecraftContentDependencyIssue(
      type: type,
      rootVersionKey: map['rootVersionKey'] as String,
      rootContentKey: map['rootContentKey'] as String,
      sourceVersionKey: map['sourceVersionKey'] as String?,
      sourceContentKey: map['sourceContentKey'] as String?,
      dependencyProvider: map['dependencyProvider'] as String?,
      dependencyProjectId: map['dependencyProjectId'] as String?,
      dependencyContentKey: map['dependencyContentKey'] as String?,
      dependencyName: map['dependencyName'] as String?,
      dependencyVersionId: map['dependencyVersionId'] as String?,
      versionConstraint: map['versionConstraint'] as String?,
      fileName: map['fileName'] as String?,
      conflictingVersionKey: map['conflictingVersionKey'] as String?,
    );
  }

  final MtnMinecraftContentDependencyIssueType type;
  /// The explicitly selected root mod version affected by the failure.
  final String rootVersionKey;
  final String rootContentKey;
  /// The requesting dependency source, potentially nested below the root.
  final String? sourceVersionKey;
  final String? sourceContentKey;
  final String? dependencyProvider;
  final String? dependencyProjectId;
  final String? dependencyContentKey;
  final String? dependencyName;
  final String? dependencyVersionId;
  final String? versionConstraint;
  final String? fileName;
  final String? conflictingVersionKey;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type.name,
    'rootVersionKey': rootVersionKey,
    'rootContentKey': rootContentKey,
    if (sourceVersionKey != null) 'sourceVersionKey': sourceVersionKey,
    if (sourceContentKey != null) 'sourceContentKey': sourceContentKey,
    if (dependencyProvider != null) 'dependencyProvider': dependencyProvider,
    if (dependencyProjectId != null) 'dependencyProjectId': dependencyProjectId,
    if (dependencyContentKey != null) 'dependencyContentKey': dependencyContentKey,
    if (dependencyName != null) 'dependencyName': dependencyName,
    if (dependencyVersionId != null) 'dependencyVersionId': dependencyVersionId,
    if (versionConstraint != null) 'versionConstraint': versionConstraint,
    if (fileName != null) 'fileName': fileName,
    if (conflictingVersionKey != null) 'conflictingVersionKey': conflictingVersionKey,
  };

  /// Match a direct dependency declaration without assuming provider-specific wire formats.
  bool matchesDependency({
    required String? provider,
    required String? projectId,
    required String? versionId,
    String? contentKey,
  }) => (dependencyProvider != null && dependencyProvider == provider &&
      ((dependencyProjectId != null && dependencyProjectId == projectId) ||
       (dependencyVersionId != null && dependencyVersionId == versionId))) ||
      (dependencyContentKey != null && dependencyContentKey == contentKey);
}

/// Snapshot built exclusively from the existing multi-root install plans.
/// No provider query, package mutation, or duplicate resolver is performed.
final class MtnMinecraftContentDependencyReport {
  MtnMinecraftContentDependencyReport(Iterable<MtnMinecraftContentDependencyIssue> issues)
      : issues = List<MtnMinecraftContentDependencyIssue>.unmodifiable(issues);

  factory MtnMinecraftContentDependencyReport.fromMap(Map<String, dynamic> map) {
    if (map['issues'] is! List) throw const FormatException('Dependency issue list is missing.');
    return MtnMinecraftContentDependencyReport((map['issues'] as List).map((value) {
      if (value is! Map) throw const FormatException('Invalid dependency issue.');
      return MtnMinecraftContentDependencyIssue.fromMap(Map<String, dynamic>.from(value));
    }));
  }

  factory MtnMinecraftContentDependencyReport.fromDesired(MtnMinecraftContentDependencyDesiredState desired) {
    final issues = <MtnMinecraftContentDependencyIssue>[];
    final signatures = <String>{};

    void add(MtnMinecraftContentDependencyIssue issue) {
      final signature = issue.toMap().toString();
      if (signatures.add(signature)) issues.add(issue);
    }

    MtnMinecraftContentDependencyIssue forEdge(
      MtnMinecraftContentDependencyIssueType type,
      MtnMinecraftContentDependencyGraphEdge edge,
      String rootVersionKey,
      String rootContentKey, {
      String? conflictingVersionKey,
    }) => MtnMinecraftContentDependencyIssue(
      type: type,
      rootVersionKey: rootVersionKey,
      rootContentKey: rootContentKey,
      sourceVersionKey: edge.source.key,
      sourceContentKey: edge.source.content.key,
      dependencyProvider: edge.dependency.provider,
      dependencyProjectId: edge.dependency.providerContentId,
      dependencyContentKey: edge.resolution.content?.key ?? edge.dependency.content?.key,
      dependencyName: edge.resolution.content?.name ?? edge.dependency.content?.name,
      dependencyVersionId: edge.dependency.providerVersionId,
      versionConstraint: edge.dependency.versionConstraint,
      fileName: edge.dependency.fileName,
      conflictingVersionKey: conflictingVersionKey,
    );

    for (final MtnMinecraftContentDependencyInstallPlan plan in desired.plans) {
      for (final edge in plan.unresolvedInstallEdges) {
        add(forEdge(MtnMinecraftContentDependencyIssueType.unresolvedRequired,
          edge, plan.root.key, plan.root.content.key));
      }
    }

    // Conflicts can arise between separate roots, even if every plan is
    // individually installable. Keep all impacted direct roots.
    final conflicts = <MtnMinecraftContentDependencyInstallConflict>[
      for (final plan in desired.plans) ...plan.conflicts,
      ...desired.conflicts,
    ];
    for (final conflict in conflicts) {
      if (conflict is MtnMinecraftContentDependencyInstallConflictMultipleVersions) {
        for (final version in conflict.versions) {
          final roots = desired.versions.where((entry) => entry.version.key == version.key)
              .expand((entry) => entry.roots);
          for (final root in roots) {
            add(MtnMinecraftContentDependencyIssue(
              type: MtnMinecraftContentDependencyIssueType.multipleVersions,
              rootVersionKey: root.key, rootContentKey: root.content.key,
              sourceVersionKey: version.key, sourceContentKey: conflict.contentKey,
              conflictingVersionKey: version.key,
            ));
          }
        }
      } else if (conflict is MtnMinecraftContentDependencyInstallConflictIncompatible) {
        for (final plan in desired.plans) {
          if (!plan.incompatibleEdges.any((edge) => identical(edge, conflict.edge))) continue;
          add(forEdge(MtnMinecraftContentDependencyIssueType.incompatible,
            conflict.edge, plan.root.key, plan.root.content.key,
            conflictingVersionKey: conflict.conflictingVersion.key));
        }
      }
    }

    return MtnMinecraftContentDependencyReport(issues);
  }

  final List<MtnMinecraftContentDependencyIssue> issues;
  bool get hasIssues => issues.isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'issues': <Map<String, dynamic>>[for (final issue in issues) issue.toMap()],
  };
}
