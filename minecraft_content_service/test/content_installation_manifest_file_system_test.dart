import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Installation manifest filesystem persistence', () {
    test('missing manifest reads null without creating metadata directory', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      expect(await store.read(installationRoot: root.absolute), isNull);
      expect(await Directory(p.join(root.path, '.mtn-content')).exists(), isFalse);
    });

    test('first publication is reversible, read-only after commit and idempotent', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final manifest = _manifest('a:v1');
      final published = await store.publish(installationRoot: root.absolute, manifest: manifest);

      expect(published.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending);
      expect(published.previousTargetExisted, isFalse);
      expect(await File(p.join(root.path, '.mtn-content', 'installation.json')).readAsString(), manifest.toJson());
      await store.commit(published);
      await store.commit(published);
      expect(published.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.committed);
      final restored = await store.read(installationRoot: root.absolute);
      expect(restored!.installationState.artifacts.single.version.key, 'a:v1');
      expect(restored.toJson(), manifest.toJson());
      await expectLater(store.rollback(published), throwsStateError);
    });

    test('first publication rollback restores absent state', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1'));
      await store.rollback(publication);
      await store.rollback(publication);
      expect(publication.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.rolledBack);
      expect(await store.read(installationRoot: root.absolute), isNull);
      expect(await Directory(p.join(root.path, '.mtn-content')).exists(), isFalse);
      await expectLater(store.commit(publication), throwsStateError);
    });

    test('replacing manifest rollback restores exact original raw bytes', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final manifestFile = await _manifestFile(root);
      final oldManifest = _manifest('a:v1');
      final previousBytes = const JsonEncoder.withIndent('    ').convert(oldManifest.toMap());
      await manifestFile.writeAsString(previousBytes);

      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v2'));
      expect(publication.previousTargetExisted, isTrue);
      expect(await manifestFile.readAsString(), _manifest('a:v2').toJson());
      expect(await publication.backup!.readAsString(), previousBytes);
      await store.rollback(publication);

      expect(await manifestFile.readAsString(), previousBytes);
      expect(await publication.backup!.exists(), isFalse);
      expect((await store.read(installationRoot: root.absolute))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('replacement commit keeps new manifest and removes its backup', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final oldFile = await _manifestFile(root);
      await oldFile.writeAsString(_manifest('a:v1').toJson());
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v2'));
      final backup = publication.backup!;
      await store.commit(publication);

      expect(await backup.exists(), isFalse);
      expect((await store.read(installationRoot: root.absolute))!.installationState.artifacts.single.version.key, 'a:v2');
    });

    test('corrupt existing manifest is never interpreted as absent or overwritten', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final oldFile = await _manifestFile(root);
      await oldFile.writeAsString('{invalid-json');
      final store = MtnMinecraftContentInstallationManifestFileSystem();

      await expectLater(store.read(installationRoot: root.absolute), throwsFormatException);
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest('a:v2')), throwsFormatException);
      expect(await oldFile.readAsString(), '{invalid-json');
    });

    test('directory or link at manifest target cannot be adopted', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final target = File(p.join(root.path, '.mtn-content', 'installation.json'));
      await Directory(target.path).create(recursive: true);
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      await expectLater(store.read(installationRoot: root.absolute), throwsStateError);
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1')), throwsStateError);
      expect(await Directory(target.path).exists(), isTrue);
    });

    test('linked manifest directory is rejected without following it', () async {
      final root = await _root();
      final outside = await _root();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => outside.delete(recursive: true));
      final link = Link(p.join(root.path, '.mtn-content'));
      try {
        await link.create(outside.path);
      } on FileSystemException {
        return; // Windows configurations without symlink creation privileges.
      }
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      await expectLater(store.read(installationRoot: root.absolute), throwsStateError);
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1')), throwsStateError);
      expect((await outside.list().toList()), isEmpty);
    });

    test('changed published manifest blocks commit and rollback without losing the backup', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final oldFile = await _manifestFile(root);
      final original = _manifest('a:v1').toJson();
      await oldFile.writeAsString(original);
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final replacement = _manifest('a:v2');
      final publication = await store.publish(installationRoot: root.absolute, manifest: replacement);
      await oldFile.writeAsString('external');
      await expectLater(store.commit(publication), throwsStateError);
      await expectLater(store.rollback(publication), throwsStateError);
      expect(publication.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending);
      expect(await publication.backup!.readAsString(), original);
      await oldFile.writeAsString(replacement.toJson());
      await store.rollback(publication);
      expect(await oldFile.readAsString(), original);
    });

    test('changed raw backup is never restored or silently cleaned', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final oldFile = await _manifestFile(root);
      final original = _manifest('a:v1').toJson();
      await oldFile.writeAsString(original);
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v2'));
      await publication.backup!.writeAsString('tampered');
      await expectLater(store.rollback(publication), throwsStateError);
      await expectLater(store.commit(publication), throwsStateError);
      expect(publication.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.pending);
      expect(await oldFile.readAsString(), _manifest('a:v2').toJson());
      await publication.backup!.writeAsString(original);
      await store.rollback(publication);
      expect(await oldFile.readAsString(), original);
    });

    test('rejects finalization by another authority', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final first = MtnMinecraftContentInstallationManifestFileSystem();
      final second = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await first.publish(installationRoot: root.absolute, manifest: _manifest('a:v1'));
      await expectLater(second.commit(publication), throwsArgumentError);
      await first.rollback(publication);
    });

    test('concurrent finalize attempts cannot both mutate a publication', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1'));
      final committing = store.commit(publication);
      await expectLater(store.rollback(publication), throwsStateError);
      await committing;
      expect(publication.state, MtnMinecraftContentInstallationManifestFileSystemPublicationState.committed);
    });

    test('read waits for pending manifest publication finalization', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1'));
      bool completed = false;
      final pendingRead = store.read(installationRoot: root.absolute).then((result) {
        completed = true;
        return result;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(completed, isFalse);
      await store.rollback(publication);
      expect(await pendingRead, isNull);
      expect(completed, isTrue);
    });

    test('manifest publication waits for pending dev.24 materialization transaction', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final materializer = MtnMinecraftContentMaterializationFileSystem();
      final state = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final plan = await _emptyDesiredPlan(state);
      final preflight = await materializer.preflight(plan: plan, installationRoot: root.absolute);
      final transaction = await materializer.beginTransaction(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );

      bool completed = false;
      final pending = store.publish(installationRoot: root.absolute, manifest: _manifest('a:v1')).then((publication) {
        completed = true;
        return publication;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(completed, isFalse);
      await materializer.rollbackTransaction(transaction);
      final publication = await pending;
      expect(completed, isTrue);
      await store.commit(publication);
    });

    test('managed files cannot occupy reserved manifest namespace', () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final version = _version('a:v1');
      final artifact = MtnMinecraftContentInstallationArtifact(
        version: version,
        file: version.files.single,
        relativePath: '.mtn-content/rogue.jar',
      );
      final state = MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[artifact]);
      final plan = await _emptyDesiredPlan(state);
      final materializer = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await materializer.preflight(plan: plan, installationRoot: root.absolute);
      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath>().any(
          (issue) => issue.reason == MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.reservedManifestNamespace,
        ),
        isTrue,
      );
    });
  });
}

Future<Directory> _root() => Directory.systemTemp.createTemp('mtn-manifest-fs-');

Future<File> _manifestFile(Directory root) async {
  final dir = Directory(p.join(root.path, '.mtn-content'));
  await dir.create(recursive: true);
  return File(p.join(dir.path, 'installation.json'));
}

MtnMinecraftContentInstallationManifest _manifest(String key) {
  final version = _version(key);
  return MtnMinecraftContentInstallationManifest.fromInstallationState(
    MtnMinecraftContentInstallationState(
      artifacts: <MtnMinecraftContentInstallationArtifact>[
        MtnMinecraftContentInstallationArtifact(
          version: version,
          file: version.files.single,
          relativePath: 'mods/a.jar',
        ),
      ],
    ),
  );
}

MtnMinecraftContentVersion _version(String key) {
  final content = MtnMinecraftContentMod(key: 'a', name: 'A');
  final file = MtnMinecraftContentFile(fileName: 'a.jar', primary: true, available: true, downloadUrl: 'https://cdn.example/a.jar');
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

Future<MtnMinecraftContentMaterializationPlan> _emptyDesiredPlan(MtnMinecraftContentInstallationState state) async {
  final service = MtnMinecraftContentService();
  final desired = service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[]);
  final reconciliation = service.reconcileDependencyState(state.dependencyInstalledState, desired);
  final selection = service.selectReconciliationFiles(reconciliation);
  final download = await service.planSelectedFileDownloads(selection);
  return service.planContentMaterialization(download, state, const <MtnMinecraftContentMaterializationTarget>[]);
}
