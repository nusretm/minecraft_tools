import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PRIVATE-1B read-only private layout preflight', () {
    late Directory root;
    late MtnMinecraftContentInstallationManifestFileSystem store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('mtn-private-layout-');
      store = MtnMinecraftContentInstallationManifestFileSystem();
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });

    Future<File> legacyManifest(
      String relativePath, {
      int? expectedSize,
    }) async {
      final target = File(p.join(root.path, '.mtn-content', 'installation.json'));
      await target.parent.create(recursive: true);
      final manifest = _manifest(relativePath, expectedSize: expectedSize);
      await target.writeAsString(manifest.toJson());
      return target;
    }

    Future<File> managedFile(String relativePath, String bytes) async {
      final file = File(p.joinAll(<String>[root.path, ...relativePath.split('/')]));
      await file.parent.create(recursive: true);
      await file.writeAsString(bytes);
      return file;
    }

    test('missing installation is a no-op without creating .mtn', () async {
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.status, MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.absent);
      expect(plan.moves, isEmpty);
      expect(plan.resultingManifest, isNull);
      expect(await root.list().toList(), isEmpty);
    });

    test('existing .mtn/chat is preserved when no manifest exists', () async {
      final chat = File(p.join(root.path, '.mtn', 'chat', 'latest.chat'));
      await chat.parent.create(recursive: true);
      await chat.writeAsString('private chat archive');
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.status, MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.absent);
      expect(await chat.readAsString(), 'private chat archive');
      expect(await Directory(p.join(root.path, '.mtn', 'content')).exists(), isFalse);
    });

    test('already-modern manifest is a no-op and retains bytes', () async {
      final modern = File(p.join(root.path, '.mtn', 'content', 'installation.json'));
      await modern.parent.create(recursive: true);
      final original = _manifest('.mtn/disabled/mods/sample.jar').toJson();
      await modern.writeAsString(original);
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.status, MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.alreadyModern);
      expect(plan.moves, isEmpty);
      expect(plan.resultingManifest!.toJson(), original);
      expect(plan.sourceManifestSha256, sha256.convert(utf8.encode(original)).toString());
      expect(await modern.readAsString(), original);
    });

    test('enabled content path is unchanged in a legacy manifest plan', () async {
      final manifest = await legacyManifest('mods/sample.jar');
      final original = await manifest.readAsString();
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.status, MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.ready);
      expect(plan.moves, isEmpty);
      expect(plan.resultingManifest!.installationState.artifacts.single.relativePath, 'mods/sample.jar');
      expect(plan.sourceManifestLength, utf8.encode(original).length);
      expect(plan.sourceManifestSha256, sha256.convert(utf8.encode(original)).toString());
      expect(await manifest.readAsString(), original);
      expect(await Directory(p.join(root.path, '.mtn')).exists(), isFalse);
    });

    test('managed inactive file is fingerprinted and manifest path rewritten', () async {
      final manifest = await legacyManifest('.mtn-disabled/mods/sample.jar');
      final source = await managedFile('.mtn-disabled/mods/sample.jar', 'game content bytes');
      final original = await manifest.readAsString();
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.status, MtnMinecraftContentInstallationManifestFileSystemMigrationStatus.ready);
      expect(plan.moves, hasLength(1));
      final move = plan.moves.single;
      expect(move.sourceRelativePath, '.mtn-disabled/mods/sample.jar');
      expect(move.destinationRelativePath, '.mtn/disabled/mods/sample.jar');
      expect(move.sourceLength, utf8.encode('game content bytes').length);
      expect(move.sourceSha256, sha256.convert(utf8.encode('game content bytes')).toString());
      expect(plan.resultingManifest!.installationState.artifacts.single.relativePath,
          '.mtn/disabled/mods/sample.jar');
      expect(plan.resultingManifestSha256,
          sha256.convert(plan.resultingManifest!.encode()).toString());
      expect(() => plan.moves.clear(), throwsUnsupportedError);
      expect(await manifest.readAsString(), original);
      expect(await source.readAsString(), 'game content bytes');
      expect(await Directory(p.join(root.path, '.mtn')).exists(), isFalse);
    });

    test('preserves existing .mtn/chat while planning an inactive move', () async {
      await legacyManifest('.mtn-disabled/mods/sample.jar');
      await managedFile('.mtn-disabled/mods/sample.jar', 'immutable');
      final chat = await managedFile('.mtn/chat/latest.chat', '{"text":"hello"}');
      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.moves, hasLength(1));
      expect(await chat.readAsString(), '{"text":"hello"}');
      expect(await Directory(p.join(root.path, '.mtn', 'disabled')).exists(), isFalse);
    });

    test('missing managed disabled source is rejected without writing', () async {
      final manifest = await legacyManifest('.mtn-disabled/mods/sample.jar');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await manifest.exists(), isTrue);
      expect(await Directory(p.join(root.path, '.mtn')).exists(), isFalse);
    });

    test('invalid declared source size refuses migration preflight', () async {
      final manifest = await legacyManifest('.mtn-disabled/mods/sample.jar', expectedSize: 999);
      final source = await managedFile('.mtn-disabled/mods/sample.jar', 'short');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsA(isA<MtnMinecraftContentFileIntegrityException>()));
      expect(await manifest.exists(), isTrue);
      expect(await source.readAsString(), 'short');
    });

    test('unknown file in inactive directory is not silently discarded', () async {
      await legacyManifest('.mtn-disabled/mods/sample.jar');
      await managedFile('.mtn-disabled/mods/sample.jar', 'original');
      final extra = await managedFile('.mtn-disabled/mods/unknown.jar', 'other');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await extra.readAsString(), 'other');
    });

    test('unexpected nested inactive folder is rejected', () async {
      await legacyManifest('.mtn-disabled/mods/sample.jar');
      await managedFile('.mtn-disabled/mods/sample.jar', 'original');
      final extra = await managedFile('.mtn-disabled/mods/nested/extra.jar', 'other');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await extra.exists(), isTrue);
    });

    test('empty but preexisting destination directory is a conflict', () async {
      await legacyManifest('.mtn-disabled/mods/sample.jar');
      await managedFile('.mtn-disabled/mods/sample.jar', 'original');
      final destination = Directory(p.join(root.path, '.mtn', 'disabled'));
      await destination.create(recursive: true);
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await destination.exists(), isTrue);
    });

    test('empty modern manifest directory blocks a legacy migration', () async {
      await legacyManifest('mods/sample.jar');
      final destination = Directory(p.join(root.path, '.mtn', 'content'));
      await destination.create(recursive: true);
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await destination.exists(), isTrue);
    });

    test('legacy inactive directory without manifest is not an absent installation', () async {
      await managedFile('.mtn-disabled/mods/unknown.jar', 'unknown');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
    });

    test('unsupported artifact paths and extra depths fail closed', () async {
      for (final relative in <String>[
        'config/unsafe.cfg',
        '.mtn-disabled/config/unsafe.cfg',
        '.mtn-disabled/mods/sub/fake.jar',
        '.mtn/chat/private.chat',
      ]) {
        final manifest = await legacyManifest(relative);
        await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
            throwsStateError, reason: relative);
        expect(await manifest.exists(), isTrue);
      }
    });

    test('linked legacy disabled source is rejected without following', () async {
      await legacyManifest('.mtn-disabled/mods/sample.jar');
      final outside = await Directory.systemTemp.createTemp('mtn-private-link-');
      addTearDown(() => outside.delete(recursive: true));
      final real = File(p.join(outside.path, 'actual.jar'));
      await real.writeAsString('private source');
      final link = Link(p.join(root.path, '.mtn-disabled', 'mods', 'sample.jar'));
      await link.parent.create(recursive: true);
      try {
        await link.create(real.path);
      } on FileSystemException {
        return; // Windows test hosts may lack the required link permission.
      }
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await real.readAsString(), 'private source');
    });

    test('modern layout refuses lingering legacy metadata and artifacts', () async {
      final modern = File(p.join(root.path, '.mtn', 'content', 'installation.json'));
      await modern.parent.create(recursive: true);
      await modern.writeAsString(_manifest('mods/sample.jar').toJson());
      final legacy = await legacyManifest('mods/sample.jar');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await legacy.exists(), isTrue);
      expect(await modern.exists(), isTrue);
    });
  });
}

MtnMinecraftContentInstallationManifest _manifest(
  String relativePath, {
  int? expectedSize,
}) {
  final content = MtnMinecraftContentMod(key: 'sample', name: 'Sample');
  final file = MtnMinecraftContentFile(
    fileName: 'sample.jar',
    size: expectedSize,
    primary: true,
    available: true,
    downloadUrl: 'https://cdn.example/sample.jar',
  );
  final version = MtnMinecraftContentVersion(
    key: 'sample:v1',
    content: content,
    name: 'Sample v1',
    version: 'v1',
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
  );
  return MtnMinecraftContentInstallationManifest.fromInstallationState(
    MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[
      MtnMinecraftContentInstallationArtifact(version: version, file: file, relativePath: relativePath),
    ]),
  );
}
