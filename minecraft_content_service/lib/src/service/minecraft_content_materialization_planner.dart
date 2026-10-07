import 'minecraft_content_download_plan.dart';
import 'minecraft_content_installation_state.dart';
import 'minecraft_content_materialization_plan.dart';

class MtnMinecraftContentMaterializationPlanner {
  const MtnMinecraftContentMaterializationPlanner();

  MtnMinecraftContentMaterializationPlan plan(
    MtnMinecraftContentDownloadPlan download,
    MtnMinecraftContentInstallationState installation,
    Iterable<MtnMinecraftContentMaterializationTarget> targets,
  ) {
    if (!download.downloadable) throw StateError('Download plan must be fully downloadable before materialization planning.');

    final reconciliation = download.selection.reconciliation;
    if (!identical(reconciliation.current, installation.dependencyInstalledState)) throw StateError('Materialization planning requires the exact installation state used to build reconciliation.');

    final targetList = List<MtnMinecraftContentMaterializationTarget>.unmodifiable(targets);
    if (targetList.length != download.items.length) throw ArgumentError.value(targetList, 'targets', 'Materialization targets must cover every download item exactly once.');

    final seenDownloads = <MtnMinecraftContentDownloadItem>{};
    for (final target in targetList) {
      if (!download.items.any((item) => identical(item, target.download))) throw ArgumentError.value(target, 'targets', 'Materialization targets must reference canonical download items from the download plan.');
      if (!seenDownloads.add(target.download)) throw ArgumentError.value(target, 'targets', 'A download item cannot have more than one materialization target.');
    }
    if (seenDownloads.length != download.items.length || !download.items.every(seenDownloads.contains)) throw ArgumentError.value(targetList, 'targets', 'Materialization targets must cover every download item exactly once.');

    final targetByDesiredKey = <String, MtnMinecraftContentMaterializationTarget>{
      for (final target in targetList) target.download.selection.desired.version.key: target,
    };
    final artifactByVersionKey = <String, MtnMinecraftContentInstallationArtifact>{
      for (final artifact in installation.artifacts) artifact.version.key: artifact,
    };

    final installs = <MtnMinecraftContentMaterializationActionInstall>[];
    for (final desired in reconciliation.installs) {
      final target = targetByDesiredKey[desired.version.key];
      if (target == null) throw StateError('Missing materialization target for install ${desired.version.key}.');
      installs.add(MtnMinecraftContentMaterializationActionInstall(target: target));
    }

    final retains = <MtnMinecraftContentMaterializationActionRetain>[];
    for (final desired in reconciliation.retains) {
      final artifact = artifactByVersionKey[desired.version.key];
      if (artifact == null) throw StateError('Missing installed artifact for retain ${desired.version.key}.');
      retains.add(
        MtnMinecraftContentMaterializationActionRetain(
          desired: desired,
          artifact: artifact,
        ),
      );
    }

    final replacements = <MtnMinecraftContentMaterializationActionReplace>[];
    for (final replacement in reconciliation.replacements) {
      final current = artifactByVersionKey[replacement.current.key];
      if (current == null) throw StateError('Missing installed artifact for replacement ${replacement.current.key}.');
      final target = targetByDesiredKey[replacement.desired.version.key];
      if (target == null) throw StateError('Missing materialization target for replacement ${replacement.desired.version.key}.');
      replacements.add(
        MtnMinecraftContentMaterializationActionReplace(
          replacement: replacement,
          current: current,
          target: target,
        ),
      );
    }

    final removals = <MtnMinecraftContentMaterializationActionRemove>[];
    for (final version in reconciliation.removals) {
      final artifact = artifactByVersionKey[version.key];
      if (artifact == null) throw StateError('Missing installed artifact for removal ${version.key}.');
      removals.add(MtnMinecraftContentMaterializationActionRemove(artifact: artifact));
    }

    return MtnMinecraftContentMaterializationPlan(
      download: download,
      installation: installation,
      installs: installs,
      retains: retains,
      replacements: replacements,
      removals: removals,
    );
  }
}
