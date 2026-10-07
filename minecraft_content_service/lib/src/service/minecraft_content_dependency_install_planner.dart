import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_graph.dart';
import 'minecraft_content_dependency_install_conflict_evaluator.dart';
import 'minecraft_content_dependency_install_plan.dart';

class MtnMinecraftContentDependencyInstallPlanner {
  const MtnMinecraftContentDependencyInstallPlanner();

  MtnMinecraftContentDependencyInstallPlan plan(
    MtnMinecraftContentDependencyGraph graph,
    MtnMinecraftContentDependencyInstallRequest request,
  ) {
    final optionalVersionKeys = <String>{
      for (final edge in graph.edges)
        if (edge.dependency.type == MtnMinecraftContentDependencyType.optional && edge.target != null) edge.target!.key,
    };
    for (final selectedKey in request.selectedOptionalVersionKeys) {
      if (!optionalVersionKeys.contains(selectedKey)) throw ArgumentError.value(selectedKey, 'request.selectedOptionalVersionKeys', 'Selected optional version key does not belong to a resolved optional dependency in this graph.');
    }

    final edgesBySourceKey = <String, List<MtnMinecraftContentDependencyGraphEdge>>{};
    for (final edge in graph.edges) {
      edgesBySourceKey.putIfAbsent(edge.source.key, () => <MtnMinecraftContentDependencyGraphEdge>[]).add(edge);
    }

    final selectedOptionalVersionKeys = request.selectedOptionalVersionKeys.toSet();
    final installVersions = <MtnMinecraftContentVersion>[];
    final installVersionsByKey = <String, MtnMinecraftContentVersion>{};
    final installEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final optionalEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final selectedOptionalEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final bundledEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final toolEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final incompatibleEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final unresolvedInstallEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final expandedVersionKeys = <String>{};

    void includeVersion(MtnMinecraftContentVersion version) {
      if (installVersionsByKey.containsKey(version.key)) return;
      installVersionsByKey[version.key] = version;
      installVersions.add(version);
    }

    void expand(MtnMinecraftContentVersion source) {
      if (!expandedVersionKeys.add(source.key)) return;

      for (final edge in edgesBySourceKey[source.key] ?? const <MtnMinecraftContentDependencyGraphEdge>[]) {
        final target = edge.target;

        switch (edge.dependency.type) {
          case MtnMinecraftContentDependencyType.required:
          case MtnMinecraftContentDependencyType.embeddedLibrary:
            if (target == null) {
              unresolvedInstallEdges.add(edge);
              continue;
            }
            installEdges.add(edge);
            includeVersion(target);
            expand(target);
            break;

          case MtnMinecraftContentDependencyType.optional:
            optionalEdges.add(edge);
            if (target == null || !selectedOptionalVersionKeys.contains(target.key)) continue;
            selectedOptionalEdges.add(edge);
            installEdges.add(edge);
            includeVersion(target);
            expand(target);
            break;

          case MtnMinecraftContentDependencyType.bundled:
            bundledEdges.add(edge);
            break;

          case MtnMinecraftContentDependencyType.tool:
            toolEdges.add(edge);
            break;

          case MtnMinecraftContentDependencyType.incompatible:
            incompatibleEdges.add(edge);
            break;
        }
      }
    }

    includeVersion(graph.root);
    expand(graph.root);

    const conflictEvaluator = MtnMinecraftContentDependencyInstallConflictEvaluator();
    final conflicts = <MtnMinecraftContentDependencyInstallConflict>[
      ...conflictEvaluator.multipleVersions(installVersions),
      for (final edge in incompatibleEdges) ...conflictEvaluator.incompatible(edge, installVersions),
    ];

    return MtnMinecraftContentDependencyInstallPlan(
      root: graph.root,
      installVersions: installVersions,
      installEdges: installEdges,
      optionalEdges: optionalEdges,
      selectedOptionalEdges: selectedOptionalEdges,
      bundledEdges: bundledEdges,
      toolEdges: toolEdges,
      incompatibleEdges: incompatibleEdges,
      unresolvedInstallEdges: unresolvedInstallEdges,
      conflicts: conflicts,
    );
  }
}
