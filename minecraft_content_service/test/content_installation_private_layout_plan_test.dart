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
      List<MtnMinecraftContentFileHash>? hashes,
    }) async {
      final target = File(p.join(root.path, '.mtn-content', 'installation.json'));
      await target.parent.create(recursive: true);
      final manifest = _manifest(relativePath, expectedSize: expectedSize, hashes: hashes);
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

    test('multiple disabled files retain independent ownership and digests', () async {
      final manifest = File(p.join(root.path, '.mtn-content', 'installation.json'));
      await manifest.parent.create(recursive: true);
      await manifest.writeAsString(_manifestWithPaths(
        const <String>[
          '.mtn-disabled/mods/first.jar',
          '.mtn-disabled/resourcepacks/second.jar',
        ],
      ).toJson());
      await managedFile('.mtn-disabled/mods/first.jar', 'first bytes');
      await managedFile('.mtn-disabled/resourcepacks/second.jar', 'second bytes');

      final plan = await store.planPrivateLayoutMigration(installationRoot: root.absolute);
      expect(plan.moves, hasLength(2));
      expect(plan.moves.map((move) => move.destinationRelativePath),
          <String>['.mtn/disabled/mods/first.jar', '.mtn/disabled/resourcepacks/second.jar']);
      expect(plan.moves.map((move) => move.sourceSha256), <String>[
        sha256.convert(utf8.encode('first bytes')).toString(),
        sha256.convert(utf8.encode('second bytes')).toString(),
      ]);
      expect(plan.resultingManifest!.installationState.artifacts.map((artifact) =>
          artifact.version.content.key), <String>['first', 'second']);
      expect(await manifest.exists(), isTrue);
      expect(await Directory(p.join(root.path, '.mtn')).exists(), isFalse);
    });

    test('case-colliding managed files are rejected under Windows path policy', () async {
      final manifest = File(p.join(root.path, '.mtn-content', 'installation.json'));
      await manifest.parent.create(recursive: true);
      await manifest.writeAsString(_manifestWithPaths(
        const <String>[
          '.mtn-disabled/mods/Alpha.jar',
          '.mtn-disabled/mods/alpha.jar',
        ],
      ).toJson());
      const windows = MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.windows,
        caseSensitive: false,
      );
      final windowsStore = MtnMinecraftContentInstallationManifestFileSystem(policy: windows);
      await expectLater(windowsStore.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await manifest.exists(), isTrue);
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
          throwsA(isA<Exception>()));
      expect(await manifest.exists(), isTrue);
      expect(await source.readAsString(), 'short');
    });

    test('declared SHA256 mismatch refuses the source without touching files', () async {
      final manifest = await legacyManifest('.mtn-disabled/mods/sample.jar',
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(
            algorithm: 'sha256',
            value: '0000000000000000000000000000000000000000000000000000000000000000',
          ),
        ],
      );
      final source = await managedFile('.mtn-disabled/mods/sample.jar', 'actual content');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsA(isA<Exception>()));
      expect(await manifest.exists(), isTrue);
      expect(await source.readAsString(), 'actual content');
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

    test('recoverable or unknown old manifest siblings block migration', () async {
      final manifest = await legacyManifest('mods/sample.jar');
      final recovery = File(p.join(manifest.parent.path, 'manifest-backup'));
      await recovery.writeAsString('uncommitted previous manifest');
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await manifest.exists(), isTrue);
      expect(await recovery.readAsString(), 'uncommitted previous manifest');
    });

    test('foreign old content root link cannot be accepted as an inventory', () async {
      await legacyManifest('mods/sample.jar');
      final outside = await Directory.systemTemp.createTemp('mtn-plan-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final target = Link(p.join(root.path, '.mtn-disabled'));
      try {
        await target.create(outside.path);
      } on FileSystemException {
        return;
      }
      await expectLater(store.planPrivateLayoutMigration(installationRoot: root.absolute),
          throwsStateError);
      expect(await outside.list().toList(), isEmpty);
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
  List<MtnMinecraftContentFileHash>? hashes,
}) {
  final content = MtnMinecraftContentMod(key: 'sample', name: 'Sample');
  final file = MtnMinecraftContentFile(
    fileName: 'sample.jar',
    size: expectedSize,
    hashes: hashes,
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

MtnMinecraftContentInstallationManifest _manifestWithPaths(
  List<String> paths,
) {
  final artifacts = <MtnMinecraftContentInstallationArtifact>[];
  for (var index = 0; index < paths.length; index++) {
    final id = index == 0 ? 'first' : 'second';
    final content = MtnMinecraftContentMod(key: id, name: id);
    final file = MtnMinecraftContentFile(
      fileName: '$id.jar', primary: true, available: true,
      downloadUrl: 'https://cdn.example/$id.jar',
    );
    final version = MtnMinecraftContentVersion(
      key: '$id:v1', content: content, name: id, version: 'v1',
      releaseType: MtnMinecraftContentVersionReleaseType.release,
      modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      files: <MtnMinecraftContentFile>[file],
    );
    artifacts.add(MtnMinecraftContentInstallationArtifact(
      version: version, file: file, relativePath: paths[index],
    ));
  }
  return MtnMinecraftContentInstallationManifest.fromInstallationState(
    MtnMinecraftContentInstallationState(artifacts: artifacts),
  );
}
