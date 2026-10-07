import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';

class MtnMinecraftContentDependencyInstalledState {
  MtnMinecraftContentDependencyInstalledState({
    required List<MtnMinecraftContentVersion> versions,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions) {
    final versionKeys = this.versions.map((version) => version.key).toSet();
    if (versionKeys.length != this.versions.length) throw ArgumentError.value(this.versions, 'versions', 'Installed state cannot contain duplicate version keys.');

    final contentKeys = this.versions.map((version) => version.content.key).toSet();
    if (contentKeys.length != this.versions.length) throw ArgumentError.value(this.versions, 'versions', 'Installed state cannot contain more than one version for the same logical content.');
  }

  final List<MtnMinecraftContentVersion> versions;
}

class MtnMinecraftContentDependencyReconciliationReplacement {
  MtnMinecraftContentDependencyReconciliationReplacement({
    required this.current,
    required this.desired,
  }) {
    if (current.content.key != desired.version.content.key) throw ArgumentError.value(desired, 'desired', 'Replacement versions must belong to the same logical content.');
    if (current.key == desired.version.key) throw ArgumentError.value(desired, 'desired', 'Replacement versions must have different version keys.');
  }

  final MtnMinecraftContentVersion current;
  final MtnMinecraftContentDependencyDesiredVersion desired;
}

class MtnMinecraftContentDependencyReconciliationPlan {
  MtnMinecraftContentDependencyReconciliationPlan({
    required this.current,
    required this.desired,
    required List<MtnMinecraftContentDependencyDesiredVersion> installs,
    required List<MtnMinecraftContentDependencyDesiredVersion> retains,
    required List<MtnMinecraftContentDependencyReconciliationReplacement> replacements,
    required List<MtnMinecraftContentVersion> removals,
  }) : installs = List<MtnMinecraftContentDependencyDesiredVersion>.unmodifiable(installs),
       retains = List<MtnMinecraftContentDependencyDesiredVersion>.unmodifiable(retains),
       replacements = List<MtnMinecraftContentDependencyReconciliationReplacement>.unmodifiable(replacements),
       removals = List<MtnMinecraftContentVersion>.unmodifiable(removals) {
    final desiredKeys = <String>{
      ...this.installs.map((item) => item.version.key),
      ...this.retains.map((item) => item.version.key),
      ...this.replacements.map((item) => item.desired.version.key),
    };
    if (desiredKeys.length != this.installs.length + this.retains.length + this.replacements.length) throw ArgumentError('Reconciliation desired actions cannot overlap.');

    final currentKeys = <String>{
      ...this.retains.map((item) => item.version.key),
      ...this.replacements.map((item) => item.current.key),
      ...this.removals.map((item) => item.key),
    };
    if (currentKeys.length != this.retains.length + this.replacements.length + this.removals.length) throw ArgumentError('Reconciliation current actions cannot overlap.');
  }

  final MtnMinecraftContentDependencyInstalledState current;
  final MtnMinecraftContentDependencyDesiredState desired;
  final List<MtnMinecraftContentDependencyDesiredVersion> installs;
  final List<MtnMinecraftContentDependencyDesiredVersion> retains;
  final List<MtnMinecraftContentDependencyReconciliationReplacement> replacements;
  final List<MtnMinecraftContentVersion> removals;

  bool get changesRequired => installs.isNotEmpty || replacements.isNotEmpty || removals.isNotEmpty;
}
