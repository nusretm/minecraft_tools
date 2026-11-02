import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Content Service OS writer ownership', () {
    test('pending writer serializes another writer and retains lock-file identity', () async {
      final root = await Directory.systemTemp.createTemp('mtn-lock-');
      addTearDown(() => root.delete(recursive: true));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final first = await store.publish(installationRoot: root.absolute, manifest: _manifest());
      final lockFile = File(p.join(root.path, '.mtn-content.lock'));
      expect(await lockFile.exists(), isTrue);
      expect(await lockFile.length(), 0);
      bool secondAcquired = false;
      final pending = store.publish(installationRoot: root.absolute, manifest: _manifest()).then((value) {
        secondAcquired = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(secondAcquired, isFalse);
      await store.rollback(first);
      final second = await pending.timeout(const Duration(seconds: 10));
      await store.rollback(second);
      expect(await lockFile.exists(), isTrue, reason: 'The lock file must never be unlinked.');
      expect(await lockFile.length(), 0);
    });

    test('independent process lock prevents service publication until release', () async {
      final root = await Directory.systemTemp.createTemp('mtn-lock-');
      addTearDown(() => root.delete(recursive: true));
      final child = await _holder(root);
      addTearDown(() => _stop(child));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      bool acquired = false;
      final pending = store.publish(installationRoot: root.absolute, manifest: _manifest()).then((value) {
        acquired = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(acquired, isFalse);
      child.stdin.writeln('release');
      await child.stdin.flush();
      expect(await child.exitCode.timeout(const Duration(seconds: 10)), 0);
      final publication = await pending.timeout(const Duration(seconds: 10));
      await store.rollback(publication);
    });

    test('killed process releases lock; publication can acquire it again', () async {
      final root = await Directory.systemTemp.createTemp('mtn-lock-');
      addTearDown(() => root.delete(recursive: true));
      final child = await _holder(root);
      addTearDown(() => _stop(child));
      expect(child.kill(), isTrue);
      await child.exitCode.timeout(const Duration(seconds: 10));
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      final publication = await store.publish(installationRoot: root.absolute, manifest: _manifest())
          .timeout(const Duration(seconds: 10));
      await store.rollback(publication);
    });

    test('occupied, nonempty and linked lock paths fail closed', () async {
      final root = await Directory.systemTemp.createTemp('mtn-lock-');
      addTearDown(() => root.delete(recursive: true));
      final path = p.join(root.path, '.mtn-content.lock');
      final store = MtnMinecraftContentInstallationManifestFileSystem();
      await Directory(path).create();
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest()), throwsStateError);
      await Directory(path).delete();

      final lockFile = File(path);
      await lockFile.writeAsString('unowned');
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest()), throwsStateError);
      await lockFile.delete();

      final outside = File(p.join(root.path, 'unrelated.txt'));
      await outside.writeAsString('safe');
      try {
        await Link(path).create(outside.path);
      } on FileSystemException {
        return; // Windows machines without symlink privileges.
      }
      await expectLater(store.publish(installationRoot: root.absolute, manifest: _manifest()), throwsStateError);
      expect(await outside.readAsString(), 'safe');
      expect(await File(p.join(root.path, '.mtn-content', 'installation.json')).exists(), isFalse);
    });
  });
}

MtnMinecraftContentInstallationManifest _manifest() =>
    MtnMinecraftContentInstallationManifest.fromInstallationState(
      MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
    );

Future<Process> _holder(Directory root) async {
  final child = await Process.start(
    Platform.resolvedExecutable,
    <String>['run', 'test/support/content_writer_lock_holder.dart', p.join(root.path, '.mtn-content.lock')],
    workingDirectory: Directory.current.path,
  );
  final ready = await child.stdout.transform(utf8.decoder).transform(const LineSplitter()).first
      .timeout(const Duration(seconds: 45));
  expect(ready, 'locked');
  return child;
}

Future<void> _stop(Process child) async {
  child.kill();
  await child.exitCode.timeout(const Duration(seconds: 10));
}
