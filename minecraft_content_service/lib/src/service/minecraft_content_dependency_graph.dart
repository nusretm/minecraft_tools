import '../model/minecraft_content_models.dart';
import '../provider/minecraft_content_provider_models.dart';

class MtnMinecraftContentDependencyGraph {
  MtnMinecraftContentDependencyGraph({
    required this.root,
    required List<MtnMinecraftContentVersion> versions,
    required List<MtnMinecraftContentDependencyGraphEdge> edges,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions),
       edges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(edges) {
    if (this.versions.isEmpty || this.versions.first.key != root.key) throw ArgumentError.value(this.versions, 'versions', 'Dependency graph versions must begin with the root version.');
  }

  final MtnMinecraftContentVersion root;
  final List<MtnMinecraftContentVersion> versions;
  final List<MtnMinecraftContentDependencyGraphEdge> edges;

  List<MtnMinecraftContentDependencyGraphEdge> get unresolvedEdges {
    return List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(edges.where((edge) => !edge.resolved));
  }

  List<MtnMinecraftContentDependencyGraphEdge> get cyclicEdges {
    return List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(edges.where((edge) => edge.cyclic));
  }
}

class MtnMinecraftContentDependencyGraphEdge {
  MtnMinecraftContentDependencyGraphEdge({
    required this.source,
    required this.dependency,
    required this.resolution,
    required this.target,
    required this.cyclic,
  }) {
    if (!identical(resolution.dependency, dependency)) throw ArgumentError.value(resolution, 'resolution', 'Dependency graph edge resolution must reference the same dependency declaration.');
    final resolvedVersion = resolution.version;
    if (target == null && resolvedVersion != null) throw ArgumentError.value(target, 'target', 'Resolved dependency graph edges must expose a target version.');
    if (target != null && (resolvedVersion == null || target!.key != resolvedVersion.key)) throw ArgumentError.value(target, 'target', 'Dependency graph edge target must match the resolved version key.');
    if (cyclic && target == null) throw ArgumentError.value(cyclic, 'cyclic', 'Only resolved dependency graph edges can be cyclic.');
  }

  final MtnMinecraftContentVersion source;
  final MtnMinecraftContentDependency dependency;
  final MtnMinecraftContentDependencyResolution resolution;
  final MtnMinecraftContentVersion? target;
  final bool cyclic;

  bool get resolved => target != null;
}
