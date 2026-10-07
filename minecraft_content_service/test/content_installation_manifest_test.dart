import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentInstallationManifest', () {
    test('keeps the supplied installation state and serializes canonical selected file indexes', () {
      final content = _content('a');
      final firstFile = _file('a-client.jar');
      final secondFile = _file(
        'a-server.jar',
        primary: false,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha1', value: 'abc123'),
        ],
      );
      final version = _version('a:v1', content, <MtnMinecraftContentFile>[firstFile, secondFile]);
      final state = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(version, secondFile, 'mods/a.jar'),
        ],
      );

      final manifest = MtnMinecraftContentInstallationManifest.fromInstallationState(state);
      final map = manifest.toMap();
      final artifactMap = (map['artifacts'] as List<Object?>).single as Map<String, dynamic>;

      expect(manifest.installationState, same(state));
      expect(map['schemaVersion'], MtnMinecraftContentInstallationManifest.currentSchemaVersion);
      expect(artifactMap['relativePath'], 'mods/a.jar');
      expect(artifactMap['fileIndex'], 1);
      expect(artifactMap['content'], isA<Map<String, dynamic>>());
      expect(artifactMap['version'], isA<Map<String, dynamic>>());
    });

    test('round trips map json and UTF-8 while restoring canonical file identity and order', () {
      final firstContent = _content(
        'a',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'source', id: 'content-a'),
        ],
      );
      final secondContent = _content('b');

      final firstFile = _file(
        'a.jar',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'source', id: 'file-a'),
        ],
        size: 42,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha256', value: 'deadbeef'),
        ],
      );
      final alternateFile = _file('a-alt.jar', primary: false);
      final secondFile = _file('b.jar');

      final firstVersion = _version(
        'a:v1',
        firstContent,
        <MtnMinecraftContentFile>[alternateFile, firstFile],
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'source', id: 'version-a'),
        ],
      );
      final secondVersion = _version('b:v1', secondContent, <MtnMinecraftContentFile>[secondFile]);

      final state = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(firstVersion, firstFile, 'mods/a.jar'),
          _artifact(secondVersion, secondFile, 'mods/b.jar'),
        ],
      );
      final manifest = MtnMinecraftContentInstallationManifest.fromInstallationState(state);

      final fromMap = MtnMinecraftContentInstallationManifest.fromMap(manifest.toMap());
      final fromJson = MtnMinecraftContentInstallationManifest.fromJson(manifest.toJson());
      final decoded = MtnMinecraftContentInstallationManifest.decode(manifest.encode());

      for (final restored in <MtnMinecraftContentInstallationManifest>[fromMap, fromJson, decoded]) {
        expect(restored.installationState.artifacts.map((artifact) => artifact.version.key), <String>['a:v1', 'b:v1']);
        expect(restored.installationState.artifacts.map((artifact) => artifact.relativePath), <String>['mods/a.jar', 'mods/b.jar']);

        final first = restored.installationState.artifacts.first;
        expect(first.version.content.key, 'a');
        expect(first.version.content.providers.single.id, 'content-a');
        expect(first.version.providers.single.id, 'version-a');
        expect(first.file, same(first.version.files[1]));
        expect(first.file.fileName, 'a.jar');
        expect(first.file.size, 42);
        expect(first.file.providers.single.id, 'file-a');
        expect(first.file.hashes.single.algorithm, 'sha256');
        expect(first.file.hashes.single.value, 'deadbeef');
      }

      expect(decoded.toJson(), manifest.toJson());
    });

    test('supports an empty installation manifest', () {
      final manifest = MtnMinecraftContentInstallationManifest.fromInstallationState(
        MtnMinecraftContentInstallationState(
          artifacts: const <MtnMinecraftContentInstallationArtifact>[],
        ),
      );

      final restored = MtnMinecraftContentInstallationManifest.decode(manifest.encode());

      expect(restored.installationState.artifacts, isEmpty);
      expect(restored.toMap()['artifacts'], isEmpty);
    });

    test('rejects unsupported or malformed root schema values', () {
      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 2,
            'artifacts': <Object?>[],
          },
        ),
        throwsFormatException,
      );

      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': '1',
            'artifacts': <Object?>[],
          },
        ),
        throwsFormatException,
      );

      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 1,
            'artifacts': <String, dynamic>{},
          },
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed artifact snapshot shapes without permissive fallback', () {
      final valid = _manifestArtifactMap();

      final invalidArtifacts = <Map<String, dynamic>>[
        <String, dynamic>{...valid, 'relativePath': 1},
        <String, dynamic>{...valid, 'content': 'a'},
        <String, dynamic>{...valid, 'version': 'a:v1'},
        <String, dynamic>{...valid, 'fileIndex': '0'},
      ];

      for (final artifact in invalidArtifacts) {
        expect(
          () => MtnMinecraftContentInstallationManifest.fromMap(
            <String, dynamic>{
              'schemaVersion': 1,
              'artifacts': <Object?>[artifact],
            },
          ),
          throwsFormatException,
        );
      }

      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 1,
            'artifacts': <Object?>['invalid'],
          },
        ),
        throwsFormatException,
      );
    });

    test('rejects version snapshots owned by a different embedded content snapshot', () {
      final artifact = _manifestArtifactMap();
      final versionMap = Map<String, dynamic>.from(artifact['version'] as Map<String, dynamic>);
      versionMap['content'] = 'other';
      artifact['version'] = versionMap;

      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 1,
            'artifacts': <Object?>[artifact],
          },
        ),
        throwsFormatException,
      );
    });

    test('rejects negative and out-of-range selected file indexes', () {
      final negative = _manifestArtifactMap();
      negative['fileIndex'] = -1;

      final outOfRange = _manifestArtifactMap();
      outOfRange['fileIndex'] = 1;

      for (final artifact in <Map<String, dynamic>>[negative, outOfRange]) {
        expect(
          () => MtnMinecraftContentInstallationManifest.fromMap(
            <String, dynamic>{
              'schemaVersion': 1,
              'artifacts': <Object?>[artifact],
            },
          ),
          throwsFormatException,
        );
      }
    });

    test('reuses installation-state path and ownership invariants during decode', () {
      final unsafePath = _manifestArtifactMap(contentKey: 'a', versionKey: 'a:v1', relativePath: '../a.jar');
      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 1,
            'artifacts': <Object?>[unsafePath],
          },
        ),
        throwsArgumentError,
      );

      final duplicateA = _manifestArtifactMap(contentKey: 'a', versionKey: 'a:v1', relativePath: 'mods/shared.jar');
      final duplicateB = _manifestArtifactMap(contentKey: 'b', versionKey: 'b:v1', relativePath: 'mods/shared.jar');
      expect(
        () => MtnMinecraftContentInstallationManifest.fromMap(
          <String, dynamic>{
            'schemaVersion': 1,
            'artifacts': <Object?>[duplicateA, duplicateB],
          },
        ),
        throwsArgumentError,
      );
    });

    test('decode rejects non-object JSON and UTF-8 payloads through the shared model codec', () {
      expect(
        () => MtnMinecraftContentInstallationManifest.fromJson('[]'),
        throwsFormatException,
      );

      expect(
        () => MtnMinecraftContentInstallationManifest.decode(Uint8List.fromList(<int>[91, 93])),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _manifestArtifactMap({
  String contentKey = 'a',
  String versionKey = 'a:v1',
  String relativePath = 'mods/a.jar',
}) {
  final content = _content(contentKey);
  final file = _file('$contentKey.jar');
  final version = _version(versionKey, content, <MtnMinecraftContentFile>[file]);
  return <String, dynamic>{
    'relativePath': relativePath,
    'content': MtnMinecraftContentModel.jsonDecode(content.toJson()),
    'version': MtnMinecraftContentModel.jsonDecode(version.toJson()),
    'fileIndex': 0,
  };
}

MtnMinecraftContentMod _content(
  String key, {
  List<MtnMinecraftContentProviderMetadata>? providers,
}) {
  return MtnMinecraftContentMod(
    key: key,
    name: key,
    providers: providers,
  );
}

MtnMinecraftContentFile _file(
  String fileName, {
  bool primary = true,
  List<MtnMinecraftContentProviderMetadata>? providers,
  int? size,
  List<MtnMinecraftContentFileHash>? hashes,
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: primary,
    available: true,
    downloadUrl: 'https://cdn.example/$fileName',
    providers: providers,
    size: size,
    hashes: hashes,
  );
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content,
  List<MtnMinecraftContentFile> files, {
  List<MtnMinecraftContentProviderMetadata>? providers,
}) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    providers: providers,
    files: files,
  );
}

MtnMinecraftContentInstallationArtifact _artifact(
  MtnMinecraftContentVersion version,
  MtnMinecraftContentFile file,
  String relativePath,
) {
  return MtnMinecraftContentInstallationArtifact(
    version: version,
    file: file,
    relativePath: relativePath,
  );
}
