import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Whole-plan materialization transaction', () {
    test('reverses install, replace, reused removal path and obsolete removal together', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();

      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      expect(preflight.safe, isTrue);
      final transaction = await fileSystem.beginTransaction(
        preflight: preflight,
        sources: fixture.sources,
      );

      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.pending);
      expect(await fixture.read('mods/a.jar'), 'new-a');
      expect(await fixture.read('mods/x.jar'), 'new-x');
      expect(await fixture.exists('mods/obsolete.jar'), isFalse);
      expect(await fixture.read('mods/keep.jar'), 'keep');

      await fileSystem.rollbackTransaction(transaction);
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack);
      await fileSystem.rollbackTransaction(transaction);
      expect(await fixture.read('mods/a.jar'), 'old-a');
      expect(await fixture.read('mods/x.jar'), 'old-x');
      expect(await fixture.read('mods/obsolete.jar'), 'obsolete');
      expect(await fixture.read('mods/keep.jar'), 'keep');
      expect(await fixture.sources.first.source.readAsString(), 'new-a');
      await expectLater(fileSystem.commitTransaction(transaction), throwsStateError);
    });

    test('commits all publications and physical removals, preserving retained files', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await fileSystem.beginTransaction(preflight: preflight, sources: fixture.sources);

      await fileSystem.commitTransaction(transaction);
      await fileSystem.commitTransaction(transaction);
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.committed);
      expect(transaction.resultingInstallationState, same(fixture.plan.resultingInstallationState));
      expect(await fixture.read('mods/a.jar'), 'new-a');
      expect(await fixture.read('mods/x.jar'), 'new-x');
      expect(await fixture.exists('mods/obsolete.jar'), isFalse);
      expect(await fixture.read('mods/keep.jar'), 'keep');
      expect((await Directory(p.join(fixture.root.path, 'mods')).list().toList()).where(
        (entry) => p.basename(entry.path).startsWith('.mtn-content-'),
      ), isEmpty);
      await expectLater(fileSystem.rollbackTransaction(transaction), throwsStateError);
    });

    test('replacement moved to a different path restores the original path on rollback', () async {
      final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
      addTearDown(() => root.delete(recursive: true));
      final content = _content('a');
      final oldFile = _file('old.jar');
      final newFile = _file('new.jar');
      final oldVersion = _version('a:v1', content, oldFile);
      final newVersion = _version('a:v2', content, newFile);
      await _write(root, 'mods/old.jar', 'old');
      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[_artifact(oldVersion, oldFile, 'mods/old.jar')],
      );
      final plan = await _plan(installation, <MtnMinecraftContentVersion>[newVersion], <String, String>{'a:v2': 'mods/new.jar'});
      final source = await _source('new');
      addTearDown(() => source.parent.delete(recursive: true));
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: plan, installationRoot: root.absolute);
      expect(preflight.safe, isTrue);

      final transaction = await fileSystem.beginTransaction(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );
      expect(await File(p.join(root.path, 'mods/old.jar')).exists(), isFalse);
      expect(await File(p.join(root.path, 'mods/new.jar')).readAsString(), 'new');
      await fileSystem.rollbackTransaction(transaction);
      expect(await File(p.join(root.path, 'mods/old.jar')).readAsString(), 'old');
      expect(await File(p.join(root.path, 'mods/new.jar')).exists(), isFalse);
    });

    test('failure of a later publication automatically reverses previously published files', () async {
      final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
      addTearDown(() => root.delete(recursive: true));
      final first = _version('a:v1', _content('a'), _file('a.jar'));
      final second = _version('b:v1', _content('b'), _file('b.jar', expectedSize: 999));
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final plan = await _plan(installation, <MtnMinecraftContentVersion>[first, second], <String, String>{
        'a:v1': 'mods/a.jar',
        'b:v1': 'mods/b.jar',
      });
      final source = await _source('a');
      addTearDown(() => source.parent.delete(recursive: true));
      final secondSource = File(p.join(source.parent.path, 'second.jar'));
      await secondSource.writeAsString('b');
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: plan, installationRoot: root.absolute);

      MtnMinecraftContentMaterializationFileSystemTransactionException? failure;
      try {
        await fileSystem.beginTransaction(
          preflight: preflight,
          sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[0].target, source: source),
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[1].target, source: secondSource),
          ],
        );
      } on MtnMinecraftContentMaterializationFileSystemTransactionException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.failure, MtnMinecraftContentMaterializationFileSystemTransactionFailure.applicationFailure);
      expect(failure.transaction!.state, MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack);
      expect(await File(p.join(root.path, 'mods/a.jar')).exists(), isFalse);
      expect(await File(p.join(root.path, 'mods/b.jar')).exists(), isFalse);
      expect(await source.readAsString(), 'a');
    });

    test('caller-owned source cannot alias another managed mutation target', () async {
      final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
      addTearDown(() => root.delete(recursive: true));
      final oldFile = _file('old.jar');
      final oldVersion = _version('old:v1', _content('old'), oldFile);
      final newVersion = _version('new:v1', _content('new'), _file('new.jar'));
      final existing = await _write(root, 'mods/old.jar', 'old');
      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[_artifact(oldVersion, oldFile, 'mods/old.jar')],
      );
      final plan = await _plan(installation, <MtnMinecraftContentVersion>[newVersion], <String, String>{'new:v1': 'mods/new.jar'});
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: plan, installationRoot: root.absolute);
      expect(preflight.safe, isTrue);
      await expectLater(
        fileSystem.beginTransaction(
          preflight: preflight,
          sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: existing),
          ],
        ),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemTransactionException>()),
      );
      expect(await existing.readAsString(), 'old');
      expect(await File(p.join(root.path, 'mods/new.jar')).exists(), isFalse);
    });

    test('commit rejects modified retained content without discarding recovery state', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await fileSystem.beginTransaction(preflight: preflight, sources: fixture.sources);

      await _write(fixture.root, 'mods/keep.jar', 'tampered');
      await expectLater(fileSystem.commitTransaction(transaction), throwsA(isA<MtnMinecraftContentMaterializationFileSystemTransactionException>()));
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.pending);
      await _write(fixture.root, 'mods/keep.jar', 'keep');
      await fileSystem.rollbackTransaction(transaction);
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack);
    });

    test('rejects finalization from another filesystem authority', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final first = MtnMinecraftContentMaterializationFileSystem();
      final second = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await first.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await first.beginTransaction(preflight: preflight, sources: fixture.sources);
      await expectLater(second.commitTransaction(transaction), throwsArgumentError);
      await first.rollbackTransaction(transaction);
    });

    test('backup tampering blocks rollback until the original recovery content is restored', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await fileSystem.beginTransaction(preflight: preflight, sources: fixture.sources);

      final mods = Directory(p.join(fixture.root.path, 'mods'));
      final backups = (await mods.list().toList()).where(
        (entry) => p.basename(entry.path).startsWith('.mtn-content-backup-'),
      ).map((entry) => File(entry.path)).toList();
      expect(backups, hasLength(2));
      File? backupA;
      for (final backup in backups) {
        if (await backup.readAsString() == 'old-a') {
          backupA = backup;
        }
      }
      expect(backupA, isNotNull);
      await backupA!.writeAsString('tampered-backup');
      await expectLater(
        fileSystem.rollbackTransaction(transaction),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemTransactionException>()),
      );
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.pending);
      expect(await fixture.read('mods/a.jar'), 'new-a');
      await backupA.writeAsString('old-a');
      await fileSystem.rollbackTransaction(transaction);
      expect(await fixture.read('mods/a.jar'), 'old-a');
    });

    test('external occupancy of removed path blocks rollback without overwrite', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await fileSystem.beginTransaction(preflight: preflight, sources: fixture.sources);

      final external = await _write(fixture.root, 'mods/obsolete.jar', 'manual');
      await expectLater(
        fileSystem.rollbackTransaction(transaction),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemTransactionException>()),
      );
      expect(await external.readAsString(), 'manual');
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.pending);
      await external.delete();
      await fileSystem.rollbackTransaction(transaction);
      expect(await fixture.read('mods/obsolete.jar'), 'obsolete');
    });

    test('removal backup tampering blocks commit and keeps tombstone recoverable', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await fileSystem.beginTransaction(preflight: preflight, sources: fixture.sources);

      final removals = (await Directory(p.join(fixture.root.path, 'mods')).list().toList()).where(
        (entry) => p.basename(entry.path).startsWith('.mtn-content-removal-'),
      ).toList();
      expect(removals, hasLength(1));
      final backup = File(removals.single.path);
      expect(await backup.readAsString(), 'obsolete');
      await backup.writeAsString('modified');
      await expectLater(
        fileSystem.commitTransaction(transaction),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemTransactionException>()),
      );
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.pending);
      await backup.writeAsString('obsolete');
      await fileSystem.rollbackTransaction(transaction);
      expect(await fixture.read('mods/obsolete.jar'), 'obsolete');
    });

    test('already-missing managed removals remain no-ops when they stay missing', () async {
      final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
      addTearDown(() => root.delete(recursive: true));
      final file = _file('old.jar');
      final version = _version('old:v1', _content('old'), file);
      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[_artifact(version, file, 'mods/old.jar')],
      );
      final plan = await _plan(installation, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: plan, installationRoot: root.absolute);
      expect(preflight.safe, isTrue);
      final transaction = await fileSystem.beginTransaction(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      await fileSystem.commitTransaction(transaction);
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.committed);
      expect(await File(p.join(root.path, 'mods/old.jar')).exists(), isFalse);
    });

    test('exclusive transaction blocks standalone publication on the same root until rollback', () async {
      final fixture = await _mixedFixture();
      addTearDown(fixture.dispose);
      final owner = MtnMinecraftContentMaterializationFileSystem();
      final standalone = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await owner.preflight(plan: fixture.plan, installationRoot: fixture.root.absolute);
      final transaction = await owner.beginTransaction(preflight: preflight, sources: fixture.sources);

      bool completed = false;
      final pendingPublication = standalone.publish(
        preflight: preflight,
        target: fixture.plan.replacements.single.target,
        source: fixture.sources.first.source,
      ).then((publication) {
        completed = true;
        return publication;
      });

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(completed, isFalse);
      await owner.rollbackTransaction(transaction);
      final publication = await pendingPublication;
      expect(await fixture.read('mods/a.jar'), 'new-a');
      await standalone.commit(publication);
      expect(completed, isTrue);
    });

    test('empty plan commits without mutation', () async {
      final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
      addTearDown(() => root.delete(recursive: true));
      final plan = await _plan(
        MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
        const <MtnMinecraftContentVersion>[],
        const <String, String>{},
      );
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();
      final preflight = await fileSystem.preflight(plan: plan, installationRoot: root.absolute);
      final transaction = await fileSystem.beginTransaction(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      await fileSystem.commitTransaction(transaction);
      expect(transaction.state, MtnMinecraftContentMaterializationFileSystemTransactionState.committed);
    });
  });
}

class _MixedFixture {
  const _MixedFixture({
    required this.root,
    required this.sourceRoot,
    required this.plan,
    required this.sources,
  });

  final Directory root;
  final Directory sourceRoot;
  final MtnMinecraftContentMaterializationPlan plan;
  final List<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources;

  Future<String> read(String path) => File(p.joinAll(<String>[root.path, ...path.split('/')])).readAsString();
  Future<bool> exists(String path) => File(p.joinAll(<String>[root.path, ...path.split('/')])).exists();

  Future<void> dispose() async {
    await root.delete(recursive: true);
    await sourceRoot.delete(recursive: true);
  }
}

Future<_MixedFixture> _mixedFixture() async {
  final root = await Directory.systemTemp.createTemp('mtn-tx-root-');
  final sourceRoot = await Directory.systemTemp.createTemp('mtn-tx-source-');

  final a = _content('a');
  final oldAFile = _file('old-a.jar');
  final newAFile = _file('new-a.jar');
  final oldA = _version('a:v1', a, oldAFile);
  final newA = _version('a:v2', a, newAFile);

  final keepFile = _file('keep.jar');
  final keep = _version('keep:v1', _content('keep'), keepFile);
  final xFile = _file('old-x.jar');
  final x = _version('x:v1', _content('x'), xFile);
  final obsoleteFile = _file('obsolete.jar');
  final obsolete = _version('obsolete:v1', _content('obsolete'), obsoleteFile);
  final newX = _version('new-x:v1', _content('new-x'), _file('new-x.jar'));

  final installation = MtnMinecraftContentInstallationState(
    artifacts: <MtnMinecraftContentInstallationArtifact>[
      _artifact(oldA, oldAFile, 'mods/a.jar'),
      _artifact(keep, keepFile, 'mods/keep.jar'),
      _artifact(x, xFile, 'mods/x.jar'),
      _artifact(obsolete, obsoleteFile, 'mods/obsolete.jar'),
    ],
  );
  await _write(root, 'mods/a.jar', 'old-a');
  await _write(root, 'mods/keep.jar', 'keep');
  await _write(root, 'mods/x.jar', 'old-x');
  await _write(root, 'mods/obsolete.jar', 'obsolete');

  final plan = await _plan(
    installation,
    <MtnMinecraftContentVersion>[newA, keep, newX],
    <String, String>{'a:v2': 'mods/a.jar', 'new-x:v1': 'mods/x.jar'},
  );
  final first = File(p.join(sourceRoot.path, 'new-a.jar'));
  final second = File(p.join(sourceRoot.path, 'new-x.jar'));
  await first.writeAsString('new-a');
  await second.writeAsString('new-x');

  return _MixedFixture(
    root: root,
    sourceRoot: sourceRoot,
    plan: plan,
    sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
      MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: first),
      MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: second),
    ],
  );
}

Future<File> _source(String data) async {
  final root = await Directory.systemTemp.createTemp('mtn-tx-source-');
  final source = File(p.join(root.path, 'source.jar'));
  await source.writeAsString(data);
  return source;
}

Future<File> _write(Directory root, String relativePath, String content) async {
  final file = File(p.joinAll(<String>[root.path, ...relativePath.split('/')]));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return file;
}

Future<MtnMinecraftContentMaterializationPlan> _plan(
  MtnMinecraftContentInstallationState installation,
  List<MtnMinecraftContentVersion> desiredVersions,
  Map<String, String> paths,
) async {
  final service = MtnMinecraftContentService();
  final desired = desiredVersions.isEmpty
      ? service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[])
      : service.composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[_installPlan(desiredVersions.first, desiredVersions)]);
  final reconciliation = service.reconcileDependencyState(installation.dependencyInstalledState, desired);
  final selection = service.selectReconciliationFiles(reconciliation);
  final downloads = await service.planSelectedFileDownloads(selection);
  final targets = downloads.items.map(
    (item) => MtnMinecraftContentMaterializationTarget(
      download: item,
      relativePath: paths[item.selection.desired.version.key]!,
    ),
  );
  return service.planContentMaterialization(downloads, installation, targets);
}

MtnMinecraftContentMod _content(String key) => MtnMinecraftContentMod(key: key, name: key);

MtnMinecraftContentFile _file(String name, {int? expectedSize}) => MtnMinecraftContentFile(
  fileName: name,
  size: expectedSize,
  primary: true,
  available: true,
  downloadUrl: 'https://cdn.example/$name',
);

MtnMinecraftContentVersion _version(String key, MtnMinecraftContent content, MtnMinecraftContentFile file) => MtnMinecraftContentVersion(
  key: key,
  content: content,
  name: key,
  version: key,
  releaseType: MtnMinecraftContentVersionReleaseType.release,
  modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
  files: <MtnMinecraftContentFile>[file],
);

MtnMinecraftContentInstallationArtifact _artifact(MtnMinecraftContentVersion version, MtnMinecraftContentFile file, String path) =>
    MtnMinecraftContentInstallationArtifact(version: version, file: file, relativePath: path);

MtnMinecraftContentDependencyInstallPlan _installPlan(MtnMinecraftContentVersion root, List<MtnMinecraftContentVersion> versions) {
  return MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: versions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
  );
}
