import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_reconciliation.dart';

class MtnMinecraftContentDependencyReconciler {
  const MtnMinecraftContentDependencyReconciler();

  MtnMinecraftContentDependencyReconciliationPlan reconcile(
    MtnMinecraftContentDependencyInstalledState current,
    MtnMinecraftContentDependencyDesiredState desired,
  ) {
    if (!desired.installable) throw StateError('Dependency desired state must be installable before reconciliation.');

    final currentByContentKey = <String, MtnMinecraftContentVersion>{};
    final currentByVersionKey = <String, MtnMinecraftContentVersion>{};
    for (final version in current.versions) {
      currentByContentKey[version.content.key] = version;
      currentByVersionKey[version.key] = version;
    }

    final desiredByContentKey = <String, MtnMinecraftContentDependencyDesiredVersion>{};
    for (final desiredVersion in desired.versions) {
      final existing = desiredByContentKey[desiredVersion.version.content.key];
      if (existing != null) throw StateError('Installable desired state cannot contain more than one version for logical content ${desiredVersion.version.content.key}.');
      desiredByContentKey[desiredVersion.version.content.key] = desiredVersion;

      final sameVersionKey = currentByVersionKey[desiredVersion.version.key];
      if (sameVersionKey != null && sameVersionKey.content.key != desiredVersion.version.content.key) {
        throw StateError('Version key ${desiredVersion.version.key} identifies different logical content across current and desired states.');
      }
    }

    final installs = <MtnMinecraftContentDependencyDesiredVersion>[];
    final retains = <MtnMinecraftContentDependencyDesiredVersion>[];
    final replacements = <MtnMinecraftContentDependencyReconciliationReplacement>[];

    for (final desiredVersion in desired.versions) {
      final currentVersion = currentByContentKey[desiredVersion.version.content.key];
      if (currentVersion == null) {
        installs.add(desiredVersion);
        continue;
      }

      if (currentVersion.key == desiredVersion.version.key) {
        retains.add(desiredVersion);
        continue;
      }

      replacements.add(
        MtnMinecraftContentDependencyReconciliationReplacement(
          current: currentVersion,
          desired: desiredVersion,
        ),
      );
    }

    final removals = <MtnMinecraftContentVersion>[];
    for (final currentVersion in current.versions) {
      if (!desiredByContentKey.containsKey(currentVersion.content.key)) removals.add(currentVersion);
    }

    return MtnMinecraftContentDependencyReconciliationPlan(
      current: current,
      desired: desired,
      installs: installs,
      retains: retains,
      replacements: replacements,
      removals: removals,
    );
  }
}
