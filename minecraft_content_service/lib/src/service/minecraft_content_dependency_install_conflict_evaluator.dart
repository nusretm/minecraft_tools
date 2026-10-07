import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_graph.dart';
import 'minecraft_content_dependency_install_plan.dart';

class MtnMinecraftContentDependencyInstallConflictEvaluator {
  const MtnMinecraftContentDependencyInstallConflictEvaluator();

  List<MtnMinecraftContentDependencyInstallConflictMultipleVersions> multipleVersions(
    Iterable<MtnMinecraftContentVersion> versions,
  ) {
    final versionsByContentKey = <String, List<MtnMinecraftContentVersion>>{};

    for (final version in versions) {
      final contentVersions = versionsByContentKey.putIfAbsent(version.content.key, () => <MtnMinecraftContentVersion>[]);
      if (contentVersions.any((item) => item.key == version.key)) continue;
      contentVersions.add(version);
    }

    final conflicts = <MtnMinecraftContentDependencyInstallConflictMultipleVersions>[];
    for (final entry in versionsByContentKey.entries) {
      if (entry.value.length < 2) continue;
      conflicts.add(
        MtnMinecraftContentDependencyInstallConflictMultipleVersions(
          contentKey: entry.key,
          versions: entry.value,
        ),
      );
    }

    return conflicts;
  }

  List<MtnMinecraftContentDependencyInstallConflictIncompatible> incompatible(
    MtnMinecraftContentDependencyGraphEdge edge,
    Iterable<MtnMinecraftContentVersion> versions,
  ) {
    if (edge.dependency.type != MtnMinecraftContentDependencyType.incompatible) throw ArgumentError.value(edge, 'edge', 'Conflict evaluation requires an incompatible dependency edge.');
    if (edge.target == null) return const <MtnMinecraftContentDependencyInstallConflictIncompatible>[];

    final candidates = versions.toList(growable: false);
    final dependency = edge.dependency;
    final providerVersionId = dependency.providerVersionId;
    final exactVersion = dependency.version;
    final exactDeclaration = exactVersion != null || (providerVersionId != null && providerVersionId.isNotEmpty);

    if (exactDeclaration) {
      final versionKey = exactVersion?.key ?? edge.target!.key;
      for (final candidate in candidates) {
        if (candidate.key != versionKey) continue;
        return <MtnMinecraftContentDependencyInstallConflictIncompatible>[
          MtnMinecraftContentDependencyInstallConflictIncompatible(
            edge: edge,
            conflictingVersion: candidate,
          ),
        ];
      }
      return const <MtnMinecraftContentDependencyInstallConflictIncompatible>[];
    }

    final contentKey = edge.resolution.content?.key ?? dependency.content?.key ?? edge.target!.content.key;
    final conflicts = <MtnMinecraftContentDependencyInstallConflictIncompatible>[];
    for (final candidate in candidates) {
      if (candidate.content.key != contentKey) continue;
      conflicts.add(
        MtnMinecraftContentDependencyInstallConflictIncompatible(
          edge: edge,
          conflictingVersion: candidate,
        ),
      );
    }

    return conflicts;
  }
}
