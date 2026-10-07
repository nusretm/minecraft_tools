import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentInstallationState', () {
    test('preserves canonical artifacts and exposes reconciliation installed state in artifact order', () {
      final contentA = _content('a');
      final contentB = _content('b');
      final fileA = _file('a.jar');
      final fileB = _file('b.jar');
      final versionA = _version('a:v1', contentA, fileA);
      final versionB = _version('b:v1', contentB, fileB);
      final artifactA = MtnMinecraftContentInstallationArtifact(
        version: versionA,
        file: fileA,
        relativePath: 'mods/a.jar',
      );
      final artifactB = MtnMinecraftContentInstallationArtifact(
        version: versionB,
        file: fileB,
        relativePath: 'managed/content/b.jar',
      );
      final source = <MtnMinecraftContentInstallationArtifact>[artifactA, artifactB];

      final state = MtnMinecraftContentInstallationState(artifacts: source);
      source.clear();

      expect(state.artifacts, <MtnMinecraftContentInstallationArtifact>[artifactA, artifactB]);
      expect(state.dependencyInstalledState.versions, <MtnMinecraftContentVersion>[versionA, versionB]);
      expect(() => state.artifacts.clear(), throwsUnsupportedError);
      expect(() => state.dependencyInstalledState.versions.clear(), throwsUnsupportedError);
    });

    test('requires the exact canonical file instance owned by the installed version', () {
      final content = _content('a');
      final canonical = _file('a.jar');
      final equivalentButDifferent = _file('a.jar');
      final version = _version('a:v1', content, canonical);

      expect(
        () => MtnMinecraftContentInstallationArtifact(
          version: version,
          file: equivalentButDifferent,
          relativePath: 'mods/a.jar',
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate version and logical-content ownership', () {
      final contentA = _content('a');
      final firstFile = _file('a-v1.jar');
      final secondFile = _file('a-v2.jar');
      final first = _version('a:v1', contentA, firstFile);
      final second = _version('a:v2', contentA, secondFile);
      final duplicateKeyFile = _file('other.jar');
      final duplicateKey = _version('a:v1', _content('other'), duplicateKeyFile);

      expect(
        () => MtnMinecraftContentInstallationState(
          artifacts: <MtnMinecraftContentInstallationArtifact>[
            _artifact(first, firstFile, 'mods/a-v1.jar'),
            _artifact(second, secondFile, 'mods/a-v2.jar'),
          ],
        ),
        throwsArgumentError,
      );

      expect(
        () => MtnMinecraftContentInstallationState(
          artifacts: <MtnMinecraftContentInstallationArtifact>[
            _artifact(first, firstFile, 'mods/a-v1.jar'),
            _artifact(duplicateKey, duplicateKeyFile, 'mods/other.jar'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate exact managed target paths', () {
      final fileA = _file('a.jar');
      final fileB = _file('b.jar');
      final versionA = _version('a:v1', _content('a'), fileA);
      final versionB = _version('b:v1', _content('b'), fileB);

      expect(
        () => MtnMinecraftContentInstallationState(
          artifacts: <MtnMinecraftContentInstallationArtifact>[
            _artifact(versionA, fileA, 'mods/shared.jar'),
            _artifact(versionB, fileB, 'mods/shared.jar'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('keeps path collision semantics OS-neutral and case-sensitive', () {
      final fileA = _file('A.jar');
      final fileB = _file('a.jar');
      final versionA = _version('a:v1', _content('a'), fileA);
      final versionB = _version('b:v1', _content('b'), fileB);

      final state = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(versionA, fileA, 'mods/A.jar'),
          _artifact(versionB, fileB, 'mods/a.jar'),
        ],
      );

      expect(state.artifacts, hasLength(2));
    });

    test('rejects unsafe or non-neutral relative artifact paths', () {
      final file = _file('a.jar');
      final version = _version('a:v1', _content('a'), file);
      final invalidPaths = <String>[
        '',
        '/mods/a.jar',
        'C:/mods/a.jar',
        r'mods\a.jar',
        '../a.jar',
        'mods/../a.jar',
        './mods/a.jar',
        'mods//a.jar',
        'mods/a.jar/',
      ];

      for (final relativePath in invalidPaths) {
        expect(
          () => MtnMinecraftContentInstallationArtifact(
            version: version,
            file: file,
            relativePath: relativePath,
          ),
          throwsArgumentError,
          reason: relativePath,
        );
      }
    });

    test('allows the same file name under different caller-owned relative directories', () {
      final fileA = _file('same.jar');
      final fileB = _file('same.jar');
      final versionA = _version('a:v1', _content('a'), fileA);
      final versionB = _version('b:v1', _content('b'), fileB);

      final state = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(versionA, fileA, 'mods/same.jar'),
          _artifact(versionB, fileB, 'resourcepacks/same.jar'),
        ],
      );

      expect(state.artifacts, hasLength(2));
    });

    test('supports an empty managed installation state', () {
      final state = MtnMinecraftContentInstallationState(
        artifacts: const <MtnMinecraftContentInstallationArtifact>[],
      );

      expect(state.artifacts, isEmpty);
      expect(state.dependencyInstalledState.versions, isEmpty);
    });
  });
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentFile _file(String fileName) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
  );
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content,
  MtnMinecraftContentFile file,
) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
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
