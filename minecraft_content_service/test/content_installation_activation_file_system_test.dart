import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

MtnMinecraftContentInstallationArtifact _artifact(List<int> bytes) {
  final content = MtnMinecraftContentMod(
    key: 'modrinth:test', name: 'Test Mod',
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'test'),
    ],
  );
  final file = MtnMinecraftContentFile(
    fileName: 'test.jar', size: bytes.length, primary: true,
    hashes: <MtnMinecraftContentFileHash>[
      MtnMinecraftContentFileHash(algorithm: 'sha256', value: sha256.convert(bytes).toString()),
    ],
  );
  final version = MtnMinecraftContentVersion(
    key: 'version:test', name: 'Test release', version: '1',
    content: content, releaseType: MtnMinecraftContentVersionReleaseType.release,
    gameVersions: <String>['1.21.11'],
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
  );
  return MtnMinecraftContentInstallationArtifact(
    version: version, file: file, relativePath: 'mods/test.jar',
  );
}

Future<void> _seed(Directory root, MtnMinecraftContentInstallationArtifact artifact, List<int> bytes) async {
  final File source = File(p.join(root.path, 'mods', 'test.jar'));
  await source.parent.create(recursive: true);
  await source.writeAsBytes(bytes);
  final store = MtnMinecraftContentInstallationManifestFileSystem();
  final publication = await store.publish(
    installationRoot: root.absolute,
    manifest: MtnMinecraftContentInstallationManifest.fromInstallationState(
      MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[artifact]),
    ),
  );
  await store.commit(publication);
}

void main() {
  test('disable and re-enable move only a managed mod without changing its bytes or version', () async {
    final root = await Directory.systemTemp.createTemp('content-activation-');
    addTearDown(() => root.delete(recursive: true));
    final bytes = <int>[7, 9, 11, 13];
    final artifact = _artifact(bytes);
    await _seed(root, artifact, bytes);
    final activation = MtnMinecraftContentInstallationActivationFileSystem();
    final store = MtnMinecraftContentInstallationManifestFileSystem();

    final inactive = await activation.synchronize(
      installationRoot: root.absolute, enabledVersionKeys: <String>{},
    );
    expect(inactive.artifacts.single.relativePath, '.mtn-disabled/mods/test.jar');
    expect(await File(p.join(root.path, 'mods', 'test.jar')).exists(), isFalse);
    expect(await File(p.join(root.path, '.mtn-disabled', 'mods', 'test.jar')).readAsBytes(), bytes);
    expect((await store.read(installationRoot: root.absolute))!.installationState.artifacts.single.version.key, artifact.version.key);

    final same = await activation.synchronize(
      installationRoot: root.absolute, enabledVersionKeys: <String>{},
    );
    expect(same.artifacts.single.relativePath, inactive.artifacts.single.relativePath);

    final active = await activation.synchronize(
      installationRoot: root.absolute, enabledVersionKeys: <String>{artifact.version.key},
    );
    expect(active.artifacts.single.relativePath, 'mods/test.jar');
    expect(await File(p.join(root.path, 'mods', 'test.jar')).readAsBytes(), bytes);
    expect(await File(p.join(root.path, '.mtn-disabled', 'mods', 'test.jar')).exists(), isFalse);
    expect((await store.read(installationRoot: root.absolute))!.installationState.artifacts.single.relativePath, 'mods/test.jar');
  });

  test('occupied disabled destination remains untouched and manifest stays active', () async {
    final root = await Directory.systemTemp.createTemp('content-activation-collision-');
    addTearDown(() => root.delete(recursive: true));
    final bytes = <int>[3, 2, 1];
    await _seed(root, _artifact(bytes), bytes);
    final userFile = File(p.join(root.path, '.mtn-disabled', 'mods', 'test.jar'));
    await userFile.parent.create(recursive: true);
    await userFile.writeAsBytes(<int>[99]);
    final activation = MtnMinecraftContentInstallationActivationFileSystem();
    await expectLater(
      activation.synchronize(installationRoot: root.absolute, enabledVersionKeys: <String>{}),
      throwsStateError,
    );
    expect(await File(p.join(root.path, 'mods', 'test.jar')).readAsBytes(), bytes);
    expect(await userFile.readAsBytes(), <int>[99]);
    final manifest = await MtnMinecraftContentInstallationManifestFileSystem().read(installationRoot: root.absolute);
    expect(manifest!.installationState.artifacts.single.relativePath, 'mods/test.jar');
  });
}
