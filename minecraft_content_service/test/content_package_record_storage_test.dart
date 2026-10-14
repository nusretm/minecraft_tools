import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const recordId = '13b7c070-0fa9-47ac-b907-ff1822404ca9';
const otherId = '13b7c070-0fa9-47ac-b907-ff1822404caa';
final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
final wrongKey = Uint8List.fromList(List<int>.filled(32, 7));

MtnMinecraftContentPackageRecord makeRecord({String title = 'Hypixel Skyblock'}) {
  return MtnMinecraftContentPackageRecord(
    source: MtnMinecraftContentPackageSource.local,
    remoteId: 'remote-hypixel',
    publishedRevision: 2,
    package: MtnMinecraftContentPackage(
      id: 'hypixel-skyblock',
      title: title,
      ownerName: 'Server Admin',
      description: '# Skyblock\nWelcome to the server!',
      minecraftVersion: '1.21.11',
      modLoader: MtnMinecraftModLoaderType.fabric,
      loaderVersion: '0.16.14',
      ramMiB: 6144,
      serverAddress: 'mc.hypixel.net',
      createdAt: DateTime.utc(2026, 10, 13),
      updatedAt: DateTime.utc(2026, 10, 14),
      revision: 3,
      items: const <MtnMinecraftContentPackageItem>[],
    ),
  );
}

void main() {
  late Directory temp;
  late MtnMinecraftContentPackageRecordStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mtn-package-storage-test-');
    storage = MtnMinecraftContentPackageRecordStorage(directory: Directory(p.join(temp.path, 'storage')));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('missing records do not create directories and do not need an external key', () async {
    expect(await storage.listRecordIds(), isEmpty);
    expect(await storage.getKeyId(recordId), isNull);
    expect(await storage.load(recordId, key: key), isNull);
    expect(await storage.delete(recordId), isFalse);
    expect(await storage.directory.exists(), isFalse);
  });

  test('real disk roundtrip preserves metadata and keeps plaintext encrypted', () async {
    await storage.save(recordId, makeRecord(), key: key, keyId: 'content-key-v1');
    final ids = await storage.listRecordIds();
    expect(ids, <String>[recordId]);
    expect(await storage.getKeyId(recordId), 'content-key-v1');
    final restored = (await storage.load(recordId, key: key))!;
    expect(restored.source, MtnMinecraftContentPackageSource.local);
    expect(restored.package.title, 'Hypixel Skyblock');
    expect(restored.package.ownerName, 'Server Admin');
    expect(restored.package.ramMiB, 6144);
    expect(restored.package.loaderVersion, '0.16.14');
    expect(restored.package.serverAddress, 'mc.hypixel.net');
    expect(restored.package.description, '# Skyblock\nWelcome to the server!');
    expect(restored.package.createdAt, DateTime.utc(2026, 10, 13));
    expect(restored.package.updatedAt, DateTime.utc(2026, 10, 14));
    expect(restored.package.revision, 3);
    expect(restored.publishedRevision, 2);
    expect(restored.package.lock, isNull);
    expect(() => restored.package.toJson(), throwsStateError);

    final saved = File(p.join(temp.path, 'storage', recordId, '000000000001.mtncr'));
    expect(await saved.exists(), isTrue);
    expect(String.fromCharCodes(await saved.readAsBytes()), isNot(contains('Hypixel Skyblock')));
    await expectLater(storage.load(recordId, key: wrongKey), throwsA(anything));
    expect(await saved.exists(), isTrue);
  });

  test('new generations preserve old snapshots; incomplete stages do not win', () async {
    await storage.save(recordId, makeRecord(title: 'Draft 1'), key: key, keyId: 'key-v1');
    await storage.save(recordId, makeRecord(title: 'Draft 2'), key: key, keyId: 'key-v2');
    final folder = Directory(p.join(temp.path, 'storage', recordId));
    expect(await File(p.join(folder.path, '000000000001.mtncr')).exists(), isTrue);
    expect(await File(p.join(folder.path, '000000000002.mtncr')).exists(), isTrue);
    await File(p.join(folder.path, '.000000000003.mtncr.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.tmp')).writeAsString('incomplete');

    final restored = await storage.load(recordId, key: key);
    expect(restored!.package.title, 'Draft 2');
    expect(await storage.getKeyId(recordId), 'key-v2');
    expect(await storage.listRecordIds(), <String>[recordId]);
    expect(await storage.delete(recordId), isTrue);
    expect(await storage.delete(recordId), isFalse);
    expect(await storage.listRecordIds(), isEmpty);
  });

  test('corrupt latest generation fails closed instead of silently loading older one', () async {
    await storage.save(recordId, makeRecord(title: 'Previous'), key: key, keyId: 'same-key');
    await storage.save(recordId, makeRecord(title: 'Current'), key: key, keyId: 'same-key');
    final latest = File(p.join(temp.path, 'storage', recordId, '000000000002.mtncr'));
    final original = await latest.readAsBytes();
    original[original.length - 1] ^= 1;
    await latest.writeAsBytes(original, flush: true);
    await expectLater(storage.load(recordId, key: key), throwsA(anything));
    expect(await storage.getKeyId(recordId), 'same-key');
    expect(await latest.exists(), isTrue);
  });

  test('concurrent writers on one storage instance allocate distinct ordered generations', () async {
    await Future.wait(<Future<void>>[
      for (var n = 1; n <= 5; n++)
        storage.save(recordId, makeRecord(title: 'Draft $n'), key: key, keyId: 'key'),
    ]);
    final folder = Directory(p.join(temp.path, 'storage', recordId));
    for (var n = 1; n <= 5; n++) {
      expect(await File(p.join(folder.path, '${n.toString().padLeft(12, '0')}.mtncr')).exists(), isTrue);
    }
    expect((await storage.load(recordId, key: key))!.package.title, 'Draft 5');
  });

  test('UUID validation prevents traversal and unexpected files block delete', () async {
    expect(() => storage.save('../escape', makeRecord(), key: key, keyId: 'key'), throwsArgumentError);
    await expectLater(storage.load(recordId.toUpperCase(), key: key), throwsArgumentError);
    expect(() => storage.delete('../../other'), throwsArgumentError);
    await storage.save(recordId, makeRecord(), key: key, keyId: 'key');
    final foreign = File(p.join(temp.path, 'storage', recordId, 'user-notes.txt'));
    await foreign.writeAsString('retain me');
    await expectLater(storage.delete(recordId), throwsA(isA<FileSystemException>()));
    expect(await foreign.readAsString(), 'retain me');
    expect(await storage.listRecordIds(), <String>[recordId]);
  });

  test('two independent record IDs are listed in sorted order and retain unique content', () async {
    await storage.save(otherId, makeRecord(title: 'Other Pack'), key: key, keyId: 'key');
    await storage.save(recordId, makeRecord(title: 'Primary Pack'), key: key, keyId: 'key');
    expect(await storage.listRecordIds(), <String>[recordId, otherId]);
    expect((await storage.load(otherId, key: key))!.package.title, 'Other Pack');
    expect((await storage.load(recordId, key: key))!.package.title, 'Primary Pack');
  });
}
