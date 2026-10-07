import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_install_plan.dart';

class MtnMinecraftContentDependencyDesiredVersion {
  MtnMinecraftContentDependencyDesiredVersion({
    required this.version,
    required List<MtnMinecraftContentVersion> roots,
  }) : roots = List<MtnMinecraftContentVersion>.unmodifiable(roots) {
    if (this.roots.isEmpty) throw ArgumentError.value(this.roots, 'roots', 'Desired versions must belong to at least one direct root.');
    if (this.roots.map((root) => root.key).toSet().length != this.roots.length) throw ArgumentError.value(this.roots, 'roots', 'Desired version roots cannot contain duplicate version keys.');
  }

  final MtnMinecraftContentVersion version;
  final List<MtnMinecraftContentVersion> roots;

  bool get direct => roots.any((root) => root.key == version.key);
}

class MtnMinecraftContentDependencyDesiredState {
  MtnMinecraftContentDependencyDesiredState({
    required List<MtnMinecraftContentDependencyInstallPlan> plans,
    required List<MtnMinecraftContentVersion> directVersions,
    required List<MtnMinecraftContentDependencyDesiredVersion> versions,
    required List<MtnMinecraftContentDependencyInstallConflict> conflicts,
  }) : plans = List<MtnMinecraftContentDependencyInstallPlan>.unmodifiable(plans),
       directVersions = List<MtnMinecraftContentVersion>.unmodifiable(directVersions),
       versions = List<MtnMinecraftContentDependencyDesiredVersion>.unmodifiable(versions),
       conflicts = List<MtnMinecraftContentDependencyInstallConflict>.unmodifiable(conflicts),
       _installVersions = List<MtnMinecraftContentVersion>.unmodifiable(versions.map((item) => item.version)) {
    final directKeys = this.directVersions.map((version) => version.key).toSet();
    if (directKeys.length != this.directVersions.length) throw ArgumentError.value(this.directVersions, 'directVersions', 'Direct versions cannot contain duplicate version keys.');
    if (this.versions.map((item) => item.version.key).toSet().length != this.versions.length) throw ArgumentError.value(this.versions, 'versions', 'Desired versions cannot contain duplicate version keys.');

    final planRootKeys = this.plans.map((plan) => plan.root.key).toSet();
    if (planRootKeys.length != this.plans.length) throw ArgumentError.value(this.plans, 'plans', 'Desired state plans cannot contain duplicate root version keys.');
    if (planRootKeys.length != directKeys.length || !planRootKeys.every(directKeys.contains)) throw ArgumentError.value(this.directVersions, 'directVersions', 'Direct versions must match the install-plan roots.');

    final desiredByKey = <String, MtnMinecraftContentDependencyDesiredVersion>{
      for (final item in this.versions) item.version.key: item,
    };
    for (final desired in this.versions) {
      if (desired.roots.any((root) => !directKeys.contains(root.key))) throw ArgumentError.value(desired.roots, 'versions', 'Desired version roots must reference direct versions.');
    }
    for (final directVersion in this.directVersions) {
      final desired = desiredByKey[directVersion.key];
      if (desired == null || !desired.direct) throw ArgumentError.value(directVersion, 'directVersions', 'Every direct version must exist as a direct desired version.');
    }
  }

  final List<MtnMinecraftContentDependencyInstallPlan> plans;
  final List<MtnMinecraftContentVersion> directVersions;
  final List<MtnMinecraftContentDependencyDesiredVersion> versions;
  final List<MtnMinecraftContentDependencyInstallConflict> conflicts;
  final List<MtnMinecraftContentVersion> _installVersions;

  List<MtnMinecraftContentVersion> get installVersions => _installVersions;

  bool get installable => plans.every((plan) => plan.installable) && conflicts.isEmpty;
}
