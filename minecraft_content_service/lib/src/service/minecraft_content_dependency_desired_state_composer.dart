import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_install_conflict_evaluator.dart';
import 'minecraft_content_dependency_install_plan.dart';

class MtnMinecraftContentDependencyDesiredStateComposer {
  const MtnMinecraftContentDependencyDesiredStateComposer();

  MtnMinecraftContentDependencyDesiredState compose(
    Iterable<MtnMinecraftContentDependencyInstallPlan> sourcePlans,
  ) {
    final plans = List<MtnMinecraftContentDependencyInstallPlan>.unmodifiable(sourcePlans);
    final rootKeys = <String>{};
    for (final plan in plans) {
      if (!rootKeys.add(plan.root.key)) throw ArgumentError.value(plan.root.key, 'plans', 'Desired state cannot contain more than one install plan for the same root version key.');
    }

    final canonicalVersionsByKey = <String, MtnMinecraftContentVersion>{};
    for (final plan in plans) {
      for (final version in plan.installVersions) {
        canonicalVersionsByKey.putIfAbsent(version.key, () => version);
      }
    }

    final directVersions = <MtnMinecraftContentVersion>[];
    final rootsByVersionKey = <String, List<MtnMinecraftContentVersion>>{};

    for (final plan in plans) {
      final canonicalRoot = canonicalVersionsByKey[plan.root.key]!;
      directVersions.add(canonicalRoot);

      for (final version in plan.installVersions) {
        final roots = rootsByVersionKey.putIfAbsent(version.key, () => <MtnMinecraftContentVersion>[]);
        if (roots.any((root) => root.key == canonicalRoot.key)) continue;
        roots.add(canonicalRoot);
      }
    }

    final desiredVersions = <MtnMinecraftContentDependencyDesiredVersion>[
      for (final entry in canonicalVersionsByKey.entries)
        MtnMinecraftContentDependencyDesiredVersion(
          version: entry.value,
          roots: rootsByVersionKey[entry.key]!,
        ),
    ];

    const conflictEvaluator = MtnMinecraftContentDependencyInstallConflictEvaluator();
    final conflicts = <MtnMinecraftContentDependencyInstallConflict>[];

    for (final conflict in conflictEvaluator.multipleVersions(canonicalVersionsByKey.values)) {
      final conflictRootKeys = <String>{
        for (final version in conflict.versions)
          for (final root in rootsByVersionKey[version.key]!) root.key,
      };
      if (conflictRootKeys.length < 2) continue;
      conflicts.add(conflict);
    }

    for (final plan in plans) {
      final planVersionKeys = plan.installVersions.map((version) => version.key).toSet();
      final crossPlanCandidates = canonicalVersionsByKey.values.where((version) => !planVersionKeys.contains(version.key));

      for (final edge in plan.incompatibleEdges) {
        conflicts.addAll(conflictEvaluator.incompatible(edge, crossPlanCandidates));
      }
    }

    return MtnMinecraftContentDependencyDesiredState(
      plans: plans,
      directVersions: directVersions,
      versions: desiredVersions,
      conflicts: conflicts,
    );
  }
}
