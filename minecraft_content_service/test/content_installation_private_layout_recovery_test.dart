import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PRIVATE-1C0 read-only migration journal and recovery inspection', () {
    late Directory root;
    late MtnMinecraftContentInstallationManifestFileSystem store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('mtn-private-recovery-');
      store = MtnMinecraftContentInstallationManifestFileSystem();
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });

    Future<File> put(String relative, String contents) async {
      final file = File(p.joinAll(<String>[root.path, ...relative.split('/')]));
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
      return file;
    }

    Future<MtnMinecraftContentInstallationManifestFileSystemJournal> validJournal({
      MtnMinecraftContentInstallationManifestFileSystemJournalPhase phase =
          MtnMinecraftContentInstallationManifestFileSystemJournalPhase.prepared,
      String? rootSha,
      List<MtnMinecraftContentInstallationManifestFileSystemJournalMove>? moves,
      List<String> copied = const <String>[],
    }) async {
      final canonicalRoot = p.normalize(await root.resolveSymbolicLinks());
      final identity = store.policy.caseSensitive ? canonicalRoot : canonicalRoot.toLowerCase();
      return MtnMinecraftContentInstallationManifestFileSystemJournal(
        migrationId: 'migration_20261102',
        rootIdentitySha256: rootSha ?? sha256.convert(utf8.encode(identity)).toString(),
        generation: 1,
        phase: phase,
        legacyManifestLength: 20,
        legacyManifestSha256: 'a' * 64,
        modernManifestLength: 24,
        modernManifestSha256: 'b' * 64,
        moves: moves ?? <MtnMinecraftContentInstallationManifestFileSystemJournalMove>[],
        copiedSourcePaths: copied,
      );
    }

    test('journal codec round-trips exact fields and guards immutable lists', () async {
      final move = MtnMinecraftContentInstallationManifestFileSystemJournalMove(
        sourceRelativePath: '.mtn-disabled/mods/sample.jar',
        destinationRelativePath: '.mtn/disabled/mods/sample.jar',
        sourceLength: 42,
        sourceSha256: 'c' * 64,
      );
      final original = await validJournal(
        phase: MtnMinecraftContentInstallationManifestFileSystemJournalPhase.copying,
        moves: <MtnMinecraftContentInstallationManifestFileSystemJournalMove>[move],
        copied: <String>['.mtn-disabled/mods/sample.jar'],
      );
      final decoded = MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(original.toJson());
      expect(decoded.toJson(), original.toJson());
      expect(decoded.phase, MtnMinecraftContentInstallationManifestFileSystemJournalPhase.copying);
      expect(decoded.moves.single.sourceSha256, 'c' * 64);
      expect(decoded.copiedSourcePaths.single, '.mtn-disabled/mods/sample.jar');
      expect(() => decoded.moves.clear(), throwsUnsupportedError);
      expect(() => decoded.copiedSourcePaths.clear(), throwsUnsupportedError);
    });

    test('unknown phase, future schema and changed payload fail closed', () async {
      final original = await validJournal();
      final map = jsonDecode(original.toJson()) as Map<String, dynamic>;
      map['phase'] = 'forced';
      expect(
        () => MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(_signed(map)),
        throwsFormatException,
      );
      map['phase'] = 'prepared';
      map['schemaVersion'] = 99;
      expect(
        () => MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(_signed(map)),
        throwsFormatException,
      );
      final tampered = jsonDecode(original.toJson()) as Map<String, dynamic>;
      tampered['migrationId'] = 'migration_99999999';
      expect(
        () => MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(jsonEncode(tampered)),
        throwsFormatException,
      );
    });

    test('malicious, noncanonical and duplicate paths are rejected by the codec', () async {
      for (final file in <String>['../evil.jar', 'CON.jar', 'x:evil.jar', 'name.']) {
        expect(
          () => MtnMinecraftContentInstallationManifestFileSystemJournalMove(
            sourceRelativePath: '.mtn-disabled/mods/$file',
            destinationRelativePath: '.mtn/disabled/mods/$file',
            sourceLength: 1,
            sourceSha256: 'a' * 64,
          ),
          throwsFormatException,
        );
      }
      final one = MtnMinecraftContentInstallationManifestFileSystemJournalMove(
        sourceRelativePath: '.mtn-disabled/mods/Alpha.jar',
        destinationRelativePath: '.mtn/disabled/mods/Alpha.jar',
        sourceLength: 1, sourceSha256: 'a' * 64,
      );
      final other = MtnMinecraftContentInstallationManifestFileSystemJournalMove(
        sourceRelativePath: '.mtn-disabled/mods/alpha.jar',
        destinationRelativePath: '.mtn/disabled/mods/alpha.jar',
        sourceLength: 1, sourceSha256: 'b' * 64,
      );
      expect(
        () => MtnMinecraftContentInstallationManifestFileSystemJournal(
          migrationId: 'migration_20261102',
          rootIdentitySha256: 'a' * 64,
          generation: 1,
          phase: MtnMinecraftContentInstallationManifestFileSystemJournalPhase.prepared,
          legacyManifestLength: 1, legacyManifestSha256: 'a' * 64,
          modernManifestLength: 1, modernManifestSha256: 'b' * 64,
          moves: <MtnMinecraftContentInstallationManifestFileSystemJournalMove>[one, other],
          copiedSourcePaths: const <String>[],
        ),
        throwsFormatException,
      );
    });

    test('copied files must be listed and prepared phase cannot claim copies', () async {
      final move = MtnMinecraftContentInstallationManifestFileSystemJournalMove(
        sourceRelativePath: '.mtn-disabled/mods/x.jar',
        destinationRelativePath: '.mtn/disabled/mods/x.jar',
        sourceLength: 1, sourceSha256: 'c' * 64,
      );
      expect(
        () => MtnMinecraftContentInstallationManifestFileSystemJournal(
          migrationId: 'migration_20261102', rootIdentitySha256: 'a' * 64,
          generation: 1, phase: MtnMinecraftContentInstallationManifestFileSystemJournalPhase.prepared,
          legacyManifestLength: 1, legacyManifestSha256: 'a' * 64,
          modernManifestLength: 1, modernManifestSha256: 'b' * 64,
          moves: <MtnMinecraftContentInstallationManifestFileSystemJournalMove>[move],
          copiedSourcePaths: const <String>['.mtn-disabled/mods/x.jar'],
        ),
        throwsFormatException,
      );
      await expectLater(
        validJournal(
          phase: MtnMinecraftContentInstallationManifestFileSystemJournalPhase.copying,
          copied: <String>['.mtn-disabled/mods/unknown.jar'],
        ),
        throwsFormatException,
      );
    });

    test('empty game folder is absent and not modified by inspection', () async {
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.absent);
      expect(result.requiresIntervention, isFalse);
      expect(await root.list().toList(), isEmpty);
    });

    test('chat archive alone does not trigger migration or modification', () async {
      final chat = await put('.mtn/chat/latest.chat', 'important history');
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.absent);
      expect(await chat.readAsString(), 'important history');
      expect(await Directory(p.join(root.path, '.mtn', 'migration')).exists(), isFalse);
    });

    test('healthy legacy manifest is classified without mutation', () async {
      final legacy = await put('.mtn-content/installation.json', _manifest().toJson());
      final previous = await legacy.readAsString();
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.legacy);
      expect(await legacy.readAsString(), previous);
    });

    test('healthy modern manifest is classified without mutation', () async {
      final modern = await put('.mtn/content/installation.json', _manifest().toJson());
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.modern);
      expect(await modern.exists(), isTrue);
    });

    test('dual manifests without journal are blocked and preserved', () async {
      final legacy = await put('.mtn-content/installation.json', _manifest().toJson());
      final modern = await put('.mtn/content/installation.json', _manifest().toJson());
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(result.requiresIntervention, isTrue);
      expect(await legacy.exists(), isTrue);
      expect(await modern.exists(), isTrue);
    });

    test('valid journal takes precedence over dual manifest conflict', () async {
      final chat = await put('.mtn/chat/latest.chat', 'private history');
      final legacy = await put('.mtn-content/installation.json', _manifest().toJson());
      final modern = await put('.mtn/content/installation.json', _manifest().toJson());
      final journal = await validJournal(
        phase: MtnMinecraftContentInstallationManifestFileSystemJournalPhase.cutoverPending,
      );
      final file = await put('.mtn/migration/journal.json', journal.toJson());
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.recoveryRequired);
      expect(result.requiresIntervention, isTrue);
      expect(result.journal!.phase, MtnMinecraftContentInstallationManifestFileSystemJournalPhase.cutoverPending);
      expect(await file.readAsString(), journal.toJson());
      expect(await legacy.exists(), isTrue);
      expect(await modern.exists(), isTrue);
      expect(await chat.readAsString(), 'private history');
    });

    test('journal can flag interruption before any manifest publication', () async {
      final journal = await validJournal();
      await put('.mtn/migration/journal.json', journal.toJson());
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.recoveryRequired);
      expect(result.journal!.phase, MtnMinecraftContentInstallationManifestFileSystemJournalPhase.prepared);
      expect(await Directory(p.join(root.path, '.mtn', 'content')).exists(), isFalse);
    });

    test('journal at a different package root is blocked', () async {
      final journal = await validJournal(rootSha: 'f' * 64);
      final file = await put('.mtn/migration/journal.json', journal.toJson());
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await file.readAsString(), journal.toJson());
    });

    test('invalid checksum and malformed journal are blocked without deletion', () async {
      final journal = await validJournal();
      final file = await put('.mtn/migration/journal.json', journal.toJson().replaceFirst(
        'migration_20261102', 'migration_20261103',
      ));
      final first = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(first.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await file.exists(), isTrue);
      await file.writeAsString('{bad json');
      final again = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(again.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await file.readAsString(), '{bad json');
    });

    test('empty migration folder and unknown siblings are blocked', () async {
      final migration = Directory(p.join(root.path, '.mtn', 'migration'));
      await migration.create(recursive: true);
      expect((await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute)).status,
          MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      final journal = await validJournal();
      await put('.mtn/migration/journal.json', journal.toJson());
      final extra = await put('.mtn/migration/unowned.tmp', 'must not delete');
      expect((await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute)).status,
          MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await extra.readAsString(), 'must not delete');
    });

    test('orphaned modern directories without a journal are blocked', () async {
      final dir = Directory(p.join(root.path, '.mtn', 'disabled'));
      await dir.create(recursive: true);
      expect((await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute)).status,
          MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await dir.exists(), isTrue);
    });

    test('symlinked migration directory is rejected without following', () async {
      final outside = await Directory.systemTemp.createTemp('mtn-recovery-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final mtn = Directory(p.join(root.path, '.mtn'));
      await mtn.create();
      final link = Link(p.join(mtn.path, 'migration'));
      try {
        await link.create(outside.path);
      } on FileSystemException {
        return;
      }
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await outside.list().toList(), isEmpty);
    });

    test('symlinked journal is rejected without following', () async {
      final outside = await Directory.systemTemp.createTemp('mtn-recovery-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final external = File(p.join(outside.path, 'journal.json'));
      await external.writeAsString((await validJournal()).toJson());
      final migration = Directory(p.join(root.path, '.mtn', 'migration'));
      await migration.create(recursive: true);
      final link = Link(p.join(migration.path, 'journal.json'));
      try {
        await link.create(external.path);
      } on FileSystemException {
        return;
      }
      final result = await store.inspectPrivateLayoutRecovery(installationRoot: root.absolute);
      expect(result.status, MtnMinecraftContentInstallationManifestFileSystemRecoveryStatus.blocked);
      expect(await external.exists(), isTrue);
    });
  });
}

String _signed(Map<String, dynamic> data) {
  final payload = Map<String, dynamic>.of(data)..remove('journalSha256');
  data['journalSha256'] = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  return jsonEncode(data);
}

MtnMinecraftContentInstallationManifest _manifest() {
  final content = MtnMinecraftContentMod(key: 'sample', name: 'Sample');
  final file = MtnMinecraftContentFile(
    fileName: 'sample.jar', primary: true, available: true,
    downloadUrl: 'https://cdn.example/sample.jar',
  );
  final version = MtnMinecraftContentVersion(
    key: 'sample:v1', content: content, name: 'Sample v1', version: 'v1',
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
  );
  return MtnMinecraftContentInstallationManifest.fromInstallationState(
    MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[
      MtnMinecraftContentInstallationArtifact(version: version, file: file, relativePath: 'mods/sample.jar'),
    ]),
  );
}
