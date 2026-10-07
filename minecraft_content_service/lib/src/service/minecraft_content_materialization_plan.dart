import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_reconciliation.dart';
import 'minecraft_content_download_plan.dart';
import 'minecraft_content_installation_state.dart';

class MtnMinecraftContentMaterializationTarget {
  MtnMinecraftContentMaterializationTarget({
    required this.download,
    required String relativePath,
  }) : artifact = MtnMinecraftContentInstallationArtifact(
         version: download.selection.desired.version,
         file: download.selection.file,
         relativePath: relativePath,
       );

  final MtnMinecraftContentDownloadItem download;
  final MtnMinecraftContentInstallationArtifact artifact;

  String get relativePath => artifact.relativePath;
}

abstract class MtnMinecraftContentMaterializationAction {
  const MtnMinecraftContentMaterializationAction();
}

class MtnMinecraftContentMaterializationActionInstall extends MtnMinecraftContentMaterializationAction {
  const MtnMinecraftContentMaterializationActionInstall({
    required this.target,
  });

  final MtnMinecraftContentMaterializationTarget target;
}

class MtnMinecraftContentMaterializationActionRetain extends MtnMinecraftContentMaterializationAction {
  const MtnMinecraftContentMaterializationActionRetain({
    required this.desired,
    required this.artifact,
  });

  final MtnMinecraftContentDependencyDesiredVersion desired;
  final MtnMinecraftContentInstallationArtifact artifact;
}

class MtnMinecraftContentMaterializationActionReplace extends MtnMinecraftContentMaterializationAction {
  const MtnMinecraftContentMaterializationActionReplace({
    required this.replacement,
    required this.current,
    required this.target,
  });

  final MtnMinecraftContentDependencyReconciliationReplacement replacement;
  final MtnMinecraftContentInstallationArtifact current;
  final MtnMinecraftContentMaterializationTarget target;
}

class MtnMinecraftContentMaterializationActionRemove extends MtnMinecraftContentMaterializationAction {
  const MtnMinecraftContentMaterializationActionRemove({
    required this.artifact,
  });

  final MtnMinecraftContentInstallationArtifact artifact;
}

class MtnMinecraftContentMaterializationPlan {
  MtnMinecraftContentMaterializationPlan({
    required this.download,
    required this.installation,
    required List<MtnMinecraftContentMaterializationActionInstall> installs,
    required List<MtnMinecraftContentMaterializationActionRetain> retains,
    required List<MtnMinecraftContentMaterializationActionReplace> replacements,
    required List<MtnMinecraftContentMaterializationActionRemove> removals,
  }) : installs = List<MtnMinecraftContentMaterializationActionInstall>.unmodifiable(installs),
       retains = List<MtnMinecraftContentMaterializationActionRetain>.unmodifiable(retains),
       replacements = List<MtnMinecraftContentMaterializationActionReplace>.unmodifiable(replacements),
       removals = List<MtnMinecraftContentMaterializationActionRemove>.unmodifiable(removals) {
    if (!download.downloadable) throw ArgumentError.value(download, 'download', 'Materialization planning requires a fully downloadable plan.');

    final reconciliation = download.selection.reconciliation;
    if (!identical(reconciliation.current, installation.dependencyInstalledState)) throw ArgumentError.value(installation, 'installation', 'Materialization planning requires the exact installation state used to build reconciliation.');

    final downloadsByDesiredKey = <String, MtnMinecraftContentDownloadItem>{
      for (final item in download.items) item.selection.desired.version.key: item,
    };
    final currentArtifactsByVersionKey = <String, MtnMinecraftContentInstallationArtifact>{
      for (final artifact in installation.artifacts) artifact.version.key: artifact,
    };
    final installByDesiredKey = <String, MtnMinecraftContentDependencyDesiredVersion>{
      for (final item in reconciliation.installs) item.version.key: item,
    };
    final retainByDesiredKey = <String, MtnMinecraftContentDependencyDesiredVersion>{
      for (final item in reconciliation.retains) item.version.key: item,
    };
    final replacementByDesiredKey = <String, MtnMinecraftContentDependencyReconciliationReplacement>{
      for (final item in reconciliation.replacements) item.desired.version.key: item,
    };
    final removalByCurrentKey = <String, MtnMinecraftContentVersion>{
      for (final item in reconciliation.removals) item.key: item,
    };

    final representedDesiredKeys = <String>{};
    for (final action in this.installs) {
      final desired = action.target.download.selection.desired;
      if (!identical(installByDesiredKey[desired.version.key], desired)) throw ArgumentError.value(action, 'installs', 'Install actions must reference canonical reconciliation install entries.');
      if (!identical(downloadsByDesiredKey[desired.version.key], action.target.download)) throw ArgumentError.value(action, 'installs', 'Install actions must reference canonical download items.');
      if (!representedDesiredKeys.add(desired.version.key)) throw ArgumentError.value(action, 'installs', 'A materialization desired target cannot be represented more than once.');
    }

    for (final action in this.retains) {
      final desired = action.desired;
      if (!identical(retainByDesiredKey[desired.version.key], desired)) throw ArgumentError.value(action, 'retains', 'Retain actions must reference canonical reconciliation retain entries.');
      if (!identical(currentArtifactsByVersionKey[action.artifact.version.key], action.artifact)) throw ArgumentError.value(action, 'retains', 'Retain actions must reference canonical installed artifacts.');
      if (action.artifact.version.key != desired.version.key || action.artifact.version.content.key != desired.version.content.key) throw ArgumentError.value(action, 'retains', 'Retained artifacts must represent the retained desired version identity.');
      if (!representedDesiredKeys.add(desired.version.key)) throw ArgumentError.value(action, 'retains', 'A materialization desired target cannot be represented more than once.');
    }

    for (final action in this.replacements) {
      final replacement = action.replacement;
      final desired = replacement.desired;
      if (!identical(replacementByDesiredKey[desired.version.key], replacement)) throw ArgumentError.value(action, 'replacements', 'Replace actions must reference canonical reconciliation replacement entries.');
      if (!identical(currentArtifactsByVersionKey[replacement.current.key], action.current)) throw ArgumentError.value(action, 'replacements', 'Replace actions must reference canonical installed artifacts.');
      if (!identical(downloadsByDesiredKey[desired.version.key], action.target.download)) throw ArgumentError.value(action, 'replacements', 'Replace actions must reference canonical download items.');
      if (!representedDesiredKeys.add(desired.version.key)) throw ArgumentError.value(action, 'replacements', 'A materialization desired target cannot be represented more than once.');
    }

    final representedRemovalKeys = <String>{};
    for (final action in this.removals) {
      final version = action.artifact.version;
      if (!identical(removalByCurrentKey[version.key], version)) throw ArgumentError.value(action, 'removals', 'Remove actions must reference canonical reconciliation removal versions.');
      if (!identical(currentArtifactsByVersionKey[version.key], action.artifact)) throw ArgumentError.value(action, 'removals', 'Remove actions must reference canonical installed artifacts.');
      if (!representedRemovalKeys.add(version.key)) throw ArgumentError.value(action, 'removals', 'A materialization removal cannot be represented more than once.');
    }

    final expectedDesiredKeys = <String>{
      ...installByDesiredKey.keys,
      ...retainByDesiredKey.keys,
      ...replacementByDesiredKey.keys,
    };
    if (representedDesiredKeys.length != expectedDesiredKeys.length || !representedDesiredKeys.every(expectedDesiredKeys.contains)) throw ArgumentError('Materialization actions must cover every desired reconciliation action exactly once.');

    if (representedRemovalKeys.length != removalByCurrentKey.length || !representedRemovalKeys.every(removalByCurrentKey.containsKey)) throw ArgumentError('Materialization remove actions must cover every reconciliation removal exactly once.');

    final installArtifactByDesiredKey = <String, MtnMinecraftContentInstallationArtifact>{
      for (final action in this.installs) action.target.download.selection.desired.version.key: action.target.artifact,
    };
    final retainArtifactByDesiredKey = <String, MtnMinecraftContentInstallationArtifact>{
      for (final action in this.retains) action.desired.version.key: action.artifact,
    };
    final replacementArtifactByDesiredKey = <String, MtnMinecraftContentInstallationArtifact>{
      for (final action in this.replacements) action.replacement.desired.version.key: action.target.artifact,
    };

    final resultingArtifacts = <MtnMinecraftContentInstallationArtifact>[];
    for (final desired in reconciliation.desired.versions) {
      final artifact = installArtifactByDesiredKey[desired.version.key] ?? retainArtifactByDesiredKey[desired.version.key] ?? replacementArtifactByDesiredKey[desired.version.key];
      if (artifact == null) throw ArgumentError('Materialization actions do not produce a resulting artifact for desired version ${desired.version.key}.');
      resultingArtifacts.add(artifact);
    }

    resultingInstallationState = MtnMinecraftContentInstallationState(
      artifacts: resultingArtifacts,
    );
  }

  final MtnMinecraftContentDownloadPlan download;
  final MtnMinecraftContentInstallationState installation;
  final List<MtnMinecraftContentMaterializationActionInstall> installs;
  final List<MtnMinecraftContentMaterializationActionRetain> retains;
  final List<MtnMinecraftContentMaterializationActionReplace> replacements;
  final List<MtnMinecraftContentMaterializationActionRemove> removals;
  late final MtnMinecraftContentInstallationState resultingInstallationState;

  MtnMinecraftContentDependencyReconciliationPlan get reconciliation => download.selection.reconciliation;
}
