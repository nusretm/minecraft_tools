import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_graph.dart';

class MtnMinecraftContentDependencyInstallRequest {
  MtnMinecraftContentDependencyInstallRequest({
    List<String>? selectedOptionalVersionKeys,
  }) : selectedOptionalVersionKeys = List<String>.unmodifiable(selectedOptionalVersionKeys ?? <String>[]) {
    if (this.selectedOptionalVersionKeys.any((key) => key.isEmpty)) throw ArgumentError.value(this.selectedOptionalVersionKeys, 'selectedOptionalVersionKeys', 'Optional version keys cannot be empty.');
    if (this.selectedOptionalVersionKeys.toSet().length != this.selectedOptionalVersionKeys.length) throw ArgumentError.value(this.selectedOptionalVersionKeys, 'selectedOptionalVersionKeys', 'Optional version keys cannot contain duplicates.');
  }

  final List<String> selectedOptionalVersionKeys;
}

class MtnMinecraftContentDependencyInstallPlan {
  MtnMinecraftContentDependencyInstallPlan({
    required this.root,
    required List<MtnMinecraftContentVersion> installVersions,
    required List<MtnMinecraftContentDependencyGraphEdge> installEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> optionalEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> selectedOptionalEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> bundledEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> toolEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> incompatibleEdges,
    required List<MtnMinecraftContentDependencyGraphEdge> unresolvedInstallEdges,
    required List<MtnMinecraftContentDependencyInstallConflict> conflicts,
  }) : installVersions = List<MtnMinecraftContentVersion>.unmodifiable(installVersions),
       installEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(installEdges),
       optionalEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(optionalEdges),
       selectedOptionalEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(selectedOptionalEdges),
       bundledEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(bundledEdges),
       toolEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(toolEdges),
       incompatibleEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(incompatibleEdges),
       unresolvedInstallEdges = List<MtnMinecraftContentDependencyGraphEdge>.unmodifiable(unresolvedInstallEdges),
       conflicts = List<MtnMinecraftContentDependencyInstallConflict>.unmodifiable(conflicts) {
    if (this.installVersions.isEmpty || !identical(this.installVersions.first, root)) throw ArgumentError.value(this.installVersions, 'installVersions', 'Install plan versions must begin with the exact root version instance.');
  }

  final MtnMinecraftContentVersion root;
  final List<MtnMinecraftContentVersion> installVersions;
  final List<MtnMinecraftContentDependencyGraphEdge> installEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> optionalEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> selectedOptionalEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> bundledEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> toolEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> incompatibleEdges;
  final List<MtnMinecraftContentDependencyGraphEdge> unresolvedInstallEdges;
  final List<MtnMinecraftContentDependencyInstallConflict> conflicts;

  bool get installable => unresolvedInstallEdges.isEmpty && conflicts.isEmpty;
}

abstract class MtnMinecraftContentDependencyInstallConflict {
  const MtnMinecraftContentDependencyInstallConflict();
}

class MtnMinecraftContentDependencyInstallConflictMultipleVersions extends MtnMinecraftContentDependencyInstallConflict {
  MtnMinecraftContentDependencyInstallConflictMultipleVersions({
    required this.contentKey,
    required List<MtnMinecraftContentVersion> versions,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions) {
    if (contentKey.isEmpty) throw ArgumentError.value(contentKey, 'contentKey', 'Content key cannot be empty.');
    if (this.versions.length < 2) throw ArgumentError.value(this.versions, 'versions', 'Multiple-version conflicts require at least two versions.');
    if (this.versions.any((version) => version.content.key != contentKey)) throw ArgumentError.value(this.versions, 'versions', 'Every conflicting version must belong to the conflict content key.');
    if (this.versions.map((version) => version.key).toSet().length != this.versions.length) throw ArgumentError.value(this.versions, 'versions', 'Multiple-version conflicts cannot contain duplicate version keys.');
  }

  final String contentKey;
  final List<MtnMinecraftContentVersion> versions;
}

class MtnMinecraftContentDependencyInstallConflictIncompatible extends MtnMinecraftContentDependencyInstallConflict {
  MtnMinecraftContentDependencyInstallConflictIncompatible({
    required this.edge,
    required this.conflictingVersion,
  }) {
    if (edge.dependency.type != MtnMinecraftContentDependencyType.incompatible) throw ArgumentError.value(edge, 'edge', 'Incompatible conflicts require an incompatible dependency edge.');
  }

  final MtnMinecraftContentDependencyGraphEdge edge;
  final MtnMinecraftContentVersion conflictingVersion;
}
