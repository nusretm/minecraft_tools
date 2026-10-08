import 'dart:async';
import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/content_recovery_test_authorities.dart';

void main() {
  group('Coordinated materialization + manifest transaction', () {
    test('first install commits managed file and manifest together', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final target = _version('a:v1', 'a', 'a.jar');
      final source = await fixture.source('a.jar', 'hello');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[target], <String, String>{'a:v1': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      expect(preflight.safe, isTrue);

      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: source),
        ],
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending);
      expect(await fixture.readFile('mods/a.jar'), 'hello');

      await fixture.coordinator.commit(tx);
      await fixture.coordinator.commit(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed);
      final loaded = await fixture.manifests.read(installationRoot: fixture.root.absolute);
      expect(loaded!.installationState.artifacts.single.version.key, 'a:v1');
      expect(loaded.installationState.artifacts.single.relativePath, 'mods/a.jar');
      await expectLater(fixture.coordinator.rollback(tx), throwsStateError);
    });

    test('first install rollback restores missing manifest and managed file', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final version = _version('a:v1', 'a', 'a.jar');
      final source = await fixture.source('a.jar', 'a');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: source),
        ],
      );
      await fixture.coordinator.rollback(tx);
      await fixture.coordinator.rollback(tx);

      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      expect(await fixture.manifests.read(installationRoot: fixture.root.absolute), isNull);
      await expectLater(fixture.coordinator.commit(tx), throwsStateError);
    });

    test('replacement commit updates bytes and installed version snapshot', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a-old.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'a-new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );
      await fixture.coordinator.commit(tx);
      expect(await fixture.readFile('mods/a.jar'), 'new');
      final loaded = await fixture.manifests.read(installationRoot: fixture.root.absolute);
      expect(loaded!.installationState.artifacts.single.version.key, 'a:v2');
    });

    test('removal-only plan restores old content and manifest on rollback', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      await fixture.coordinator.rollback(tx);
      expect(await fixture.readFile('mods/a.jar'), 'old');
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('removal-only plan commits empty persisted manifest', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      await fixture.coordinator.commit(tx);
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      final loaded = await fixture.manifests.read(installationRoot: fixture.root.absolute);
      expect(loaded, isNotNull);
      expect(loaded!.installationState.artifacts, isEmpty);
    });

    test('empty plan publishes an empty manifest as a valid state', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final plan = await _plan(_emptyState(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      await fixture.coordinator.commit(tx);
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts, isEmpty);
    });

    test('absent manifest cannot authorize an existing managed installation', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.writeFile('mods/a.jar', 'old');
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      await expectLater(
        fixture.coordinator.begin(preflight: preflight, sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[]),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(await fixture.readFile('mods/a.jar'), 'old');
      expect(await fixture.manifests.read(installationRoot: fixture.root.absolute), isNull);
    });

    test('stale current plan is rejected without changing manifest or managed file', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final stale = _version('a:v0', 'a', 'outdated.jar');
      final staleState = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(stale, 'mods/a.jar')]);
      final plan = await _plan(staleState, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      await expectLater(
        fixture.coordinator.begin(preflight: preflight, sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[]),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(await fixture.readFile('mods/a.jar'), 'old');
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('corrupt manifest fails closed without creating content files', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      await fixture.writeFile('.mtn-content/installation.json', 'corrupt');
      final version = _version('a:v1', 'a', 'a.jar');
      final source = await fixture.source('a.jar', 'hello');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      await expectLater(
        fixture.coordinator.begin(
          preflight: preflight,
          sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: source),
          ],
        ),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      expect(await fixture.readFile('.mtn-content/installation.json'), 'corrupt');
    });

    test('changed manifest after initial snapshot rolls back applied managed files', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      await fixture.writeFile('.mtn-content/notes.txt', 'caller');
      final version = _version('a:v1', 'a', 'a.jar');
      final source = await fixture.source('a.jar', 'hello');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final sources = _MutationOnIteration(
        MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs.single.target, source: source),
        () => Directory(p.join(fixture.root.path, '.mtn-content', 'installation.json')).createSync(),
      );
      await expectLater(
        fixture.coordinator.begin(preflight: preflight, sources: sources),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      expect(await fixture.readFile('.mtn-content/notes.txt'), 'caller');
    });

    test('later content source integrity failure rolls back previously published files', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final first = _version('a:v1', 'a', 'a.jar');
      final second = _version('b:v1', 'b', 'b.jar', expectedSize: 999);
      final a = await fixture.source('a.jar', 'alpha');
      final b = await fixture.source('b.jar', 'beta');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[first, second], <String, String>{
        'a:v1': 'mods/a.jar',
        'b:v1': 'mods/b.jar',
      });
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      await expectLater(
        fixture.coordinator.begin(
          preflight: preflight,
          sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[0].target, source: a),
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[1].target, source: b),
          ],
        ),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      expect(await fixture.fileExists('mods/b.jar'), isFalse);
      expect(await fixture.manifests.read(installationRoot: fixture.root.absolute), isNull);
    });

    test('tampered manifest blocks coordinated commit before any backup destruction', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );

      final target = File(p.join(fixture.root.path, '.mtn-content', 'installation.json'));
      final originalNew = await target.readAsBytes();
      await target.writeAsString('tamper');
      await expectLater(
        fixture.coordinator.commit(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending);
      expect(
        (await Directory(p.join(fixture.root.path, '.mtn-content')).list().toList())
            .any((entity) => p.basename(entity.path).startsWith('.mtn-content-manifest-backup-')),
        isTrue,
      );
      await target.writeAsBytes(originalNew);
      await fixture.coordinator.rollback(tx);
      expect(await fixture.readFile('mods/a.jar'), 'old');
    });

    test('tampered managed file blocks commit while manifest recovery is preserved', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );
      await fixture.writeFile('mods/a.jar', 'tamper');
      await expectLater(
        fixture.coordinator.commit(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending);
      expect(
        (await Directory(p.join(fixture.root.path, '.mtn-content')).list().toList())
            .any((entity) => p.basename(entity.path).startsWith('.mtn-content-manifest-backup-')),
        isTrue,
      );
      await fixture.writeFile('mods/a.jar', 'new');
      await fixture.coordinator.rollback(tx);
      expect(await fixture.readFile('mods/a.jar'), 'old');
    });

    test('precommit manifest integrity failure is reversible and can be retried before cleanup', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );

      final published = File(p.join(fixture.root.path, '.mtn-content', 'installation.json'));
      final correct = await published.readAsBytes();
      await published.writeAsString('tampered');
      await expectLater(
        fixture.coordinator.commit(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.commitFailure)
            .having((error) => error.transaction, 'transaction', same(tx))),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending);
      expect(await fixture.readFile('mods/a.jar'), 'new');

      await published.writeAsBytes(correct);
      await fixture.coordinator.commit(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed);
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts.single.version.key, 'a:v2');
      expect(await fixture.readFile('mods/a.jar'), 'new');
      await expectLater(fixture.coordinator.rollback(tx), throwsStateError);
    });

    test('manifest backup corruption keeps lease and retryRollback restores manifest after managed rollback', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );

      final manifestDirectory = Directory(p.join(fixture.root.path, '.mtn-content'));
      final backups = await manifestDirectory.list(followLinks: false).where(
        (entity) => p.basename(entity.path).startsWith('.mtn-content-manifest-backup-'),
      ).toList();
      expect(backups, hasLength(1));
      final backup = File(backups.single.path);
      final oldBytes = await backup.readAsBytes();
      await backup.writeAsString('invalid-backup');

      await expectLater(
        fixture.coordinator.rollback(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.rollbackFailure)),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete);
      expect(await fixture.readFile('mods/a.jar'), 'old');

      var readFinished = false;
      final blockedRead = fixture.manifests.read(installationRoot: fixture.root.absolute).then((manifest) {
        readFinished = true;
        return manifest;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(readFinished, isFalse);

      await backup.writeAsBytes(oldBytes);
      await fixture.coordinator.rollback(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack);
      expect((await blockedRead.timeout(const Duration(seconds: 5)))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('managed replacement backup corruption retains lease until retryRollback restores old bytes', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );
      final backups = await Directory(p.join(fixture.root.path, 'mods')).list(followLinks: false).where(
        (entity) => p.basename(entity.path).startsWith('.mtn-content-backup-'),
      ).toList();
      expect(backups, hasLength(1));
      final backup = File(backups.single.path);
      final oldBytes = await backup.readAsBytes();
      await backup.writeAsString('tampered-backup');

      await expectLater(
        fixture.coordinator.rollback(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.rollbackFailure)),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete);
      expect(await fixture.readFile('mods/a.jar'), 'new');

      await backup.writeAsBytes(oldBytes);
      await fixture.coordinator.rollback(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack);
      expect(await fixture.readFile('mods/a.jar'), 'old');
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('exclusive combined lease blocks standalone manifest reads and content transactions', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final plan = await _plan(_emptyState(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      bool readDone = false;
      bool materializationDone = false;
      final readFuture = fixture.manifests.read(installationRoot: fixture.root.absolute).then((item) {
        readDone = true;
        return item;
      });
      final pendingContent = fixture.fileSystem.beginTransaction(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      ).then((next) {
        materializationDone = true;
        return next;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(readDone, isFalse);
      expect(materializationDone, isFalse);
      await fixture.coordinator.rollback(tx);

      // Async manifest root resolution may queue the writer before the reader.
      // Finalize the writer first, so the assertion does not depend on queue order.
      final standalone = await pendingContent.timeout(const Duration(seconds: 5));
      await fixture.fileSystem.rollbackTransaction(standalone);
      expect(await readFuture.timeout(const Duration(seconds: 5)), isNull);
      expect(materializationDone, isTrue);
    });

    test('simultaneous commit and rollback are rejected and finalization belongs to one coordinator', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final plan = await _plan(_emptyState(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );
      final another = MtnMinecraftContentMaterializationFileSystemCoordinator();
      await expectLater(another.commit(tx), throwsArgumentError);
      final commit = fixture.coordinator.commit(tx);
      await expectLater(fixture.coordinator.rollback(tx), throwsStateError);
      await expectLater(fixture.coordinator.commit(tx), throwsStateError);
      await commit;
      await fixture.coordinator.commit(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed);
    });

    test('injected manifest authority with a mismatched policy is rejected at construction', () {
      final host = MtnMinecraftContentMaterializationFileSystemPolicy.host();
      final incompatible = MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: host.platform,
        caseSensitive: !host.caseSensitive,
      );
      final manifestIO = InterruptedManifestIO();
      expect(
        () => MtnMinecraftContentMaterializationFileSystemCoordinator(
          policy: incompatible,
          manifestFileSystem: manifestIO,
        ),
        throwsArgumentError,
      );
    });

    test('interrupted manifest cleanup after managed commit requires forward-only retry', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final manifestIO = InterruptedManifestIO()..interruptCommitOnce = true;
      final authority = MtnMinecraftContentMaterializationFileSystemCoordinator(manifestFileSystem: manifestIO);
      final old = _version('a:v1', 'a', 'old.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final next = _version('a:v2', 'a', 'new.jar');
      final source = await fixture.source('new.jar', 'new');
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/a.jar'});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await authority.begin(
        preflight: preflight,
        sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
          MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.replacements.single.target, source: source),
        ],
      );

      await expectLater(
        authority.commit(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.commitFailure)
            .having((error) => error.transaction, 'transaction', same(tx))),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.commitIncomplete);
      expect(await fixture.readFile('mods/a.jar'), 'new');
      expect(manifestIO.commitAttempts, 1);
      await expectLater(authority.rollback(tx), throwsStateError);

      var finished = false;
      final pendingRead = fixture.manifests.read(installationRoot: fixture.root.absolute).then((manifest) {
        finished = true;
        return manifest;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(finished, isFalse);
      await authority.commit(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed);
      expect(manifestIO.commitAttempts, 2);
      expect((await pendingRead.timeout(const Duration(seconds: 5)))!.installationState.artifacts.single.version.key, 'a:v2');
      expect(await fixture.readFile('mods/a.jar'), 'new');
    });

    test('manifest rollback interruption restores managed files and completes on retry', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final manifestIO = InterruptedManifestIO()..interruptRollbackOnce = true;
      final authority = MtnMinecraftContentMaterializationFileSystemCoordinator(manifestFileSystem: manifestIO);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await authority.begin(
        preflight: preflight,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      );

      await expectLater(
        authority.rollback(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.rollbackFailure)),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete);
      expect(await fixture.readFile('mods/a.jar'), 'old');
      expect(manifestIO.rollbackAttempts, 1);

      await authority.rollback(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack);
      expect(manifestIO.rollbackAttempts, 2);
      expect((await fixture.manifests.read(installationRoot: fixture.root.absolute))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('failed coordinated begin releases lease when rollback fully succeeds', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final first = _version('a:v1', 'a', 'a.jar');
      final second = _version('b:v1', 'b', 'b.jar', expectedSize: 500);
      final a = await fixture.source('a.jar', 'good');
      final b = await fixture.source('b.jar', 'bad');
      final plan = await _plan(_emptyState(), <MtnMinecraftContentVersion>[first, second], <String, String>{
        'a:v1': 'mods/a.jar', 'b:v1': 'mods/b.jar',
      });
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      await expectLater(
        fixture.coordinator.begin(
          preflight: preflight,
          sources: <MtnMinecraftContentMaterializationFileSystemTransactionSource>[
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[0].target, source: a),
            MtnMinecraftContentMaterializationFileSystemTransactionSource(target: plan.installs[1].target, source: b),
          ],
        ),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()
            .having((error) => error.failure, 'failure', MtnMinecraftContentMaterializationFileSystemCoordinationFailure.applicationFailure)),
      );
      expect(await fixture.fileExists('mods/a.jar'), isFalse);
      expect(await fixture.fileExists('mods/b.jar'), isFalse);
      expect(await fixture.manifests.read(installationRoot: fixture.root.absolute).timeout(const Duration(seconds: 5)), isNull);

      final empty = await _plan(_emptyState(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final fresh = await fixture.fileSystem.preflight(plan: empty, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(
        preflight: fresh,
        sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[],
      ).timeout(const Duration(seconds: 5));
      await fixture.coordinator.rollback(tx);
    });

    test('manifest publication rollback protects against outside tampering', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, String>{'mods/a.jar': 'old'});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final preflight = await fixture.fileSystem.preflight(plan: plan, installationRoot: fixture.root.absolute);
      final tx = await fixture.coordinator.begin(preflight: preflight, sources: const <MtnMinecraftContentMaterializationFileSystemTransactionSource>[]);
      final raw = await File(p.join(fixture.root.path, '.mtn-content', 'installation.json')).readAsBytes();
      await fixture.writeFile('.mtn-content/installation.json', 'modified');
      await expectLater(
        fixture.coordinator.rollback(tx),
        throwsA(isA<MtnMinecraftContentMaterializationFileSystemCoordinationException>()),
      );
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete);
      await File(p.join(fixture.root.path, '.mtn-content', 'installation.json')).writeAsBytes(raw);
      await fixture.coordinator.rollback(tx);
      expect(tx.state, MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack);
      expect(await fixture.readFile('mods/a.jar'), 'old');
    });
  });
}

class _Fixture {
  _Fixture(this.root, this.sourceRoot);

  final Directory root;
  final Directory sourceRoot;

  final MtnMinecraftContentMaterializationFileSystem fileSystem = MtnMinecraftContentMaterializationFileSystem();
  final MtnMinecraftContentMaterializationFileSystemCoordinator coordinator = MtnMinecraftContentMaterializationFileSystemCoordinator();
  final MtnMinecraftContentInstallationManifestFileSystem manifests = MtnMinecraftContentInstallationManifestFileSystem();

  Future<void> dispose() async {
    await root.delete(recursive: true);
    await sourceRoot.delete(recursive: true);
  }

  Future<File> source(String name, String content) async {
    final file = File(p.join(sourceRoot.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<void> writeFile(String relative, String content) async {
    final file = File(p.joinAll(<String>[root.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<String> readFile(String relative) => File(p.joinAll(<String>[root.path, ...relative.split('/')])).readAsString();

  Future<bool> fileExists(String relative) => File(p.joinAll(<String>[root.path, ...relative.split('/')])).exists();

  Future<void> existing(MtnMinecraftContentInstallationState state, Map<String, String> contents) async {
    for (final entry in contents.entries) {
      await writeFile(entry.key, entry.value);
    }
    final manifest = MtnMinecraftContentInstallationManifest.fromInstallationState(state);
    final publication = await manifests.publish(installationRoot: root.absolute, manifest: manifest);
    await manifests.commit(publication);
  }
}

Future<_Fixture> _fixture() async {
  final root = await Directory.systemTemp.createTemp('mtn-coord-root-');
  final source = await Directory.systemTemp.createTemp('mtn-coord-source-');
  return _Fixture(root, source);
}

MtnMinecraftContentInstallationState _emptyState() =>
    MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);

MtnMinecraftContentInstallationState _state(List<MtnMinecraftContentInstallationArtifact> artifacts) =>
    MtnMinecraftContentInstallationState(artifacts: artifacts);

MtnMinecraftContentInstallationArtifact _artifact(MtnMinecraftContentVersion version, String relativePath) =>
    MtnMinecraftContentInstallationArtifact(version: version, file: version.files.single, relativePath: relativePath);

MtnMinecraftContentVersion _version(String key, String contentKey, String fileName, {int? expectedSize}) {
  final content = MtnMinecraftContentMod(key: contentKey, name: contentKey);
  final file = MtnMinecraftContentFile(
    fileName: fileName,
    size: expectedSize,
    primary: true,
    available: true,
    downloadUrl: 'https://cdn.example/$fileName',
  );
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

Future<MtnMinecraftContentMaterializationPlan> _plan(
  MtnMinecraftContentInstallationState installation,
  List<MtnMinecraftContentVersion> desiredVersions,
  Map<String, String> paths,
) async {
  final service = MtnMinecraftContentService();
  final desired = desiredVersions.isEmpty
      ? service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[])
      : service.composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[
          MtnMinecraftContentDependencyInstallPlan(
            root: desiredVersions.first,
            installVersions: desiredVersions,
            installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
          ),
        ]);
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

class _MutationOnIteration extends Iterable<MtnMinecraftContentMaterializationFileSystemTransactionSource> {
  _MutationOnIteration(this._source, this._mutation);

  final MtnMinecraftContentMaterializationFileSystemTransactionSource _source;
  final void Function() _mutation;

  @override
  Iterator<MtnMinecraftContentMaterializationFileSystemTransactionSource> get iterator {
    _mutation();
    return <MtnMinecraftContentMaterializationFileSystemTransactionSource>[_source].iterator;
  }
}
