import 'dart:typed_data';

import '../model/minecraft_content_models.dart';
import 'minecraft_content_installation_state.dart';

class MtnMinecraftContentInstallationManifest extends MtnMinecraftContentModel {
  MtnMinecraftContentInstallationManifest._(this.installationState);

  factory MtnMinecraftContentInstallationManifest.fromInstallationState(
    MtnMinecraftContentInstallationState installationState,
  ) {
    return MtnMinecraftContentInstallationManifest._(installationState);
  }

  factory MtnMinecraftContentInstallationManifest.fromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) throw const FormatException('Installation manifest schemaVersion must be an integer.');
    if (schemaVersion != currentSchemaVersion) throw FormatException('Unsupported Minecraft content installation manifest schema version: $schemaVersion');

    final artifactValues = map['artifacts'];
    if (artifactValues is! List<Object?>) throw const FormatException('Installation manifest artifacts must be a list.');

    final artifacts = <MtnMinecraftContentInstallationArtifact>[];
    for (var index = 0; index < artifactValues.length; index++) {
      final artifactValue = artifactValues[index];
      if (artifactValue is! Map<Object?, Object?>) throw FormatException('Installation manifest artifact at index $index must be an object.');
      final artifactMap = artifactValue.map((key, value) => MapEntry(key.toString(), value));

      final relativePathValue = artifactMap['relativePath'];
      if (relativePathValue is! String) throw FormatException('Installation manifest artifact at index $index has an invalid relativePath.');

      final contentValue = artifactMap['content'];
      if (contentValue is! Map<Object?, Object?>) throw FormatException('Installation manifest artifact at index $index has an invalid content snapshot.');
      final contentMap = contentValue.map((key, value) => MapEntry(key.toString(), value));
      final content = MtnMinecraftContent.fromMap(contentMap);

      final versionValue = artifactMap['version'];
      if (versionValue is! Map<Object?, Object?>) throw FormatException('Installation manifest artifact at index $index has an invalid version snapshot.');
      final versionMap = versionValue.map((key, value) => MapEntry(key.toString(), value));

      final versionContentKey = versionMap['content'];
      if (versionContentKey is! String || versionContentKey != content.key) {
        throw FormatException('Installation manifest artifact at index $index has a version/content ownership mismatch.');
      }

      final version = MtnMinecraftContentVersion.fromMap(versionMap, content);

      final fileIndexValue = artifactMap['fileIndex'];
      if (fileIndexValue is! int) throw FormatException('Installation manifest artifact at index $index has an invalid fileIndex.');
      if (fileIndexValue < 0 || fileIndexValue >= version.files.length) throw FormatException('Installation manifest artifact at index $index fileIndex is out of range.');

      artifacts.add(
        MtnMinecraftContentInstallationArtifact(
          version: version,
          file: version.files[fileIndexValue],
          relativePath: relativePathValue,
        ),
      );
    }

    return MtnMinecraftContentInstallationManifest._(
      MtnMinecraftContentInstallationState(
        artifacts: artifacts,
      ),
    );
  }

  factory MtnMinecraftContentInstallationManifest.fromJson(String value) {
    return MtnMinecraftContentInstallationManifest.fromMap(MtnMinecraftContentModel.jsonDecode(value));
  }

  factory MtnMinecraftContentInstallationManifest.decode(Uint8List value) {
    return MtnMinecraftContentInstallationManifest.fromMap(MtnMinecraftContentModel.decode(value));
  }

  static const int currentSchemaVersion = 1;

  final MtnMinecraftContentInstallationState installationState;

  @override
  Map<String, dynamic> toMap() {
    final artifacts = <Map<String, dynamic>>[];

    for (final artifact in installationState.artifacts) {
      final fileIndex = artifact.version.files.indexWhere((file) => identical(file, artifact.file));
      if (fileIndex < 0) throw StateError('Installation artifact file is no longer owned by version ${artifact.version.key}.');

      artifacts.add(
        <String, dynamic>{
          'relativePath': artifact.relativePath,
          'content': MtnMinecraftContentModel.jsonDecode(artifact.version.content.toJson()),
          'version': MtnMinecraftContentModel.jsonDecode(artifact.version.toJson()),
          'fileIndex': fileIndex,
        },
      );
    }

    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'artifacts': artifacts,
    };
  }
}
