import 'dart:convert';

import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_dependency_desired_state.dart';
import '../service/minecraft_content_service.dart';
import 'minecraft_content_package.dart';

/// An isolated candidate for a later coordinated install, not an installed
/// update. The caller may publish [package] only after the existing installer
/// has downloaded, verified and committed the complete [desired] graph.
class MtnMinecraftContentPackageAutoUpdatePreparation {
  MtnMinecraftContentPackageAutoUpdatePreparation({
    required this.package,
    required this.desired,
    required Map<String, MtnMinecraftContentVersion> updatedRoots,
  }) : updatedRoots = Map<String, MtnMinecraftContentVersion>.unmodifiable(updatedRoots);

  /// Detached package with candidate root selections and no obsolete lock.
  final MtnMinecraftContentPackage package;

  /// Full dependency graph for all direct roots, not just changed ones.
  final MtnMinecraftContentDependencyDesiredState desired;

  /// Root item keys and their proposed newer published versions.
  final Map<String, MtnMinecraftContentVersion> updatedRoots;
}

/// Stages version updates without changing the source package, its exact lock,
/// its encrypted record or any files. Existing Content Service dependency
/// resolution is the authority; this planner never invents dependency versions.
class MtnMinecraftContentPackageAutoUpdatePlanner {
  const MtnMinecraftContentPackageAutoUpdatePlanner();

  /// Uses the package's already checked (possibly disk-restored) updateList.
  /// Call package.checkUpdates() first when its six-hour check is due.
  ///
  /// Returns null when no *direct* root is eligible for auto-application.
  /// A dependency-only version is chosen by the resolver, never directly
  /// promoted from a cached update candidate.
  ///
  /// Failed metadata resolution or conflicting dependencies throw without
  /// mutating the live source package. Download and publication are separate
  /// later stages of the existing coordinated content installer.
  Future<MtnMinecraftContentPackageAutoUpdatePreparation?> prepare(
    MtnMinecraftContentPackage source,
    MtnMinecraftContentService service,
  ) async {
    final updates = source.updateList;
    final roots = source.directItems;
    final chosen = <String, MtnMinecraftContentVersion>{};
    final existingLocks = <String, String>{
      for (final entry in source.lock?.versions ?? []) entry.itemKey: entry.versionId,
    };
    final baseline = source.toLocalMap()..remove('localUpdateCheck');
    final savedSelection = jsonEncode(baseline);
    final snapshotUpdates = <String, String>{
      for (final entry in updates.entries) entry.key.key: entry.value.key,
    };
    final draftMap = Map<String, dynamic>.from(baseline);
    draftMap.remove('lock');
    draftMap.remove('dependencyEdges');
    final copiedRoots = <Map<String, dynamic>>[];

    for (final root in roots) {
      final copy = Map<String, dynamic>.from(root.toLocalMap());
      final priorId = root.selectedVersionId ?? existingLocks[root.key];
      if (priorId != null) copy['selectedVersionId'] = priorId;

      final candidate = source.canSetAutoUpdate(root) && root.autoUpdate ? updates[root] : null;
      if (candidate != null) {
        final identities = candidate.providers.where((value) =>
          value.provider == root.provider && value.id != null && value.id!.isNotEmpty).toList(growable: false);
        if (identities.length != 1 ||
            !candidate.content.providers.any((value) => value.provider == root.provider && value.id == root.projectId) ||
            candidate.content.type != root.type ||
            !candidate.gameVersions.contains(source.minecraftVersion) ||
            (root.type == MtnMinecraftContentType.mod && !candidate.modLoaders.contains(source.modLoader)) ||
            candidate.publishedAt == null) {
          throw StateError('Invalid automatic update candidate for ${root.key}.');
        }
        final nextId = identities.single.id!;
        if (priorId != nextId) {
          if (priorId == null) throw StateError('Cannot update an unselected ContentItem: ${root.key}.');
          copy['selectedVersionId'] = nextId;
          chosen[root.key] = candidate;
        }
      }
      copiedRoots.add(copy);
    }

    if (chosen.isEmpty) return null;

    // A new root may require a different dependency version. Carrying
    // dependency-only exact pins forward would incorrectly block that resolver
    // decision; preserve only direct-root pins and let the graph rebuild them.
    draftMap['items'] = copiedRoots;
    final staged = MtnMinecraftContentPackage.fromLocalMap(draftMap);
    final desired = await staged.resolveDependencies(service);
    if (!desired.installable) {
      throw StateError('Automatic content update has unresolved or conflicting dependencies.');
    }

    final latestMap = source.toLocalMap()..remove('localUpdateCheck');
    final currentUpdates = source.updateList;
    if (jsonEncode(latestMap) != savedSelection || currentUpdates.length != snapshotUpdates.length ||
        currentUpdates.entries.any((entry) => snapshotUpdates[entry.key.key] != entry.value.key)) {
      throw StateError('Source Content Package changed during automatic update preparation.');
    }

    return MtnMinecraftContentPackageAutoUpdatePreparation(
      package: staged, desired: desired, updatedRoots: chosen,
    );
  }
}
