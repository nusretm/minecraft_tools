import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_reconciliation.dart';

class MtnMinecraftContentInstallationArtifact {
  MtnMinecraftContentInstallationArtifact({
    required this.version,
    required this.file,
    required String relativePath,
  }) : relativePath = _validateRelativePath(relativePath) {
    if (!version.files.any((item) => identical(item, file))) throw ArgumentError.value(file, 'file', 'Installation artifact file must be the canonical file instance owned by the version.');
  }

  final MtnMinecraftContentVersion version;
  final MtnMinecraftContentFile file;
  final String relativePath;

  static String _validateRelativePath(String value) {
    if (value.isEmpty) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path cannot be empty.');
    if (value.contains('\\')) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path must use forward-slash separators.');
    if (value.startsWith('/')) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path must be relative.');
    if (RegExp(r'^[A-Za-z]:').hasMatch(value)) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path must not contain a Windows drive prefix.');
    if (value.contains('\u0000')) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path cannot contain a null character.');

    final segments = value.split('/');
    if (segments.any((segment) => segment.isEmpty || segment == '.' || segment == '..')) throw ArgumentError.value(value, 'relativePath', 'Installation artifact path must not contain empty, current-directory, or parent-directory segments.');

    return value;
  }
}

class MtnMinecraftContentInstallationState {
  MtnMinecraftContentInstallationState({
    required List<MtnMinecraftContentInstallationArtifact> artifacts,
  }) : artifacts = List<MtnMinecraftContentInstallationArtifact>.unmodifiable(artifacts) {
    final versionKeys = <String>{};
    final contentKeys = <String>{};
    final relativePaths = <String>{};

    for (final artifact in this.artifacts) {
      if (!versionKeys.add(artifact.version.key)) throw ArgumentError.value(artifact.version.key, 'artifacts', 'Managed installation cannot contain duplicate version keys.');
      if (!contentKeys.add(artifact.version.content.key)) throw ArgumentError.value(artifact.version.content.key, 'artifacts', 'Managed installation cannot contain more than one version for the same logical content.');
      if (!relativePaths.add(artifact.relativePath)) throw ArgumentError.value(artifact.relativePath, 'artifacts', 'Managed installation cannot contain duplicate relative artifact paths.');
    }

    dependencyInstalledState = MtnMinecraftContentDependencyInstalledState(
      versions: this.artifacts.map((artifact) => artifact.version).toList(growable: false),
    );
  }

  final List<MtnMinecraftContentInstallationArtifact> artifacts;
  late final MtnMinecraftContentDependencyInstalledState dependencyInstalledState;
}
