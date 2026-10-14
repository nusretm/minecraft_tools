import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

final key = Uint8List.fromList(List<int>.generate(32, (index) => index + 1));

MtnMinecraftContentPackageItem sampleItem(
  String id, {
  MtnMinecraftContentPackageSource source = MtnMinecraftContentPackageSource.local,
}) => MtnMinecraftContentPackageItem(
  provider: 'modrinth',
  projectId: id,
  title: id,
  type: MtnMinecraftContentType.mod,
  direct: true,
  source: source,
);

MtnMinecraftContentPackage samplePackage({
  required List<MtnMinecraftContentPackageItem> items,
  MtnMinecraftContentPackageLock? lock,
  MtnMinecraftContentPackageMutationPolicy policy = MtnMinecraftContentPackageMutationPolicy.appendOnly,
}) => MtnMinecraftContentPackage(
  id: 'skyblock',
  title: 'Hypixel Skyblock',
  minecraftVersion: '1.21.11',
  modLoader: MtnMinecraftModLoaderType.fabric,
  loaderVersion: '0.16.14',
  ramMiB: 6144,
  ownerName: 'Example publisher',
  createdAt: DateTime.utc(2026, 10, 13),
  updatedAt: DateTime.utc(2026, 10, 14),
  mutationPolicy: policy,
  items: items,
  lock: lock,
);

void main() {
  test('new content defaults to local; device-local source never appears in portable item map', () {
    final item = sampleItem('user-addon');
    expect(item.source, MtnMinecraftContentPackageSource.local);
    expect(item.toMap().containsKey('source'), isFalse);
    expect(item.toLocalMap()['source'], 'local');
    expect(MtnMinecraftContentPackageItem.fromLocalMap(item.toLocalMap()).source, MtnMinecraftContentPackageSource.local);
  });

  test('portable package import marks received items downloaded without changing exported bytes', () {
    final package = samplePackage(
      items: <MtnMinecraftContentPackageItem>[sampleItem('original-mod')],
      lock: MtnMinecraftContentPackageLock(
        versions: <MtnMinecraftContentPackageLockedVersion>[
          MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:original-mod', versionId: 'v1', fileName: 'original.jar', fileId: 'file-v1'),
        ],
        edges: const <MtnMinecraftContentPackageLockedEdge>[],
      ),
    );
    final portable = package.toJson();
    expect(portable, isNot(contains('"source"')));
    final imported = MtnMinecraftContentPackage.decode(package.encode());
    expect(imported.items.single.source, MtnMinecraftContentPackageSource.downloaded);
    expect(imported.toJson(), portable);

    final fakeSource = Map<String, dynamic>.from(package.toMap());
    final badItems = <Map<String, dynamic>>[Map<String, dynamic>.from((fakeSource['items'] as List).single as Map)];
    badItems.single['source'] = 'local';
    fakeSource['items'] = badItems;
    expect(() => MtnMinecraftContentPackage.fromMap(fakeSource), throwsFormatException);
  });

  test('downloaded package can persist mixed item sources in one encrypted local record', () async {
    final published = samplePackage(
      items: <MtnMinecraftContentPackageItem>[sampleItem('original-mod')],
      lock: MtnMinecraftContentPackageLock(
        versions: <MtnMinecraftContentPackageLockedVersion>[
          MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:original-mod', versionId: 'v1', fileName: 'original.jar', fileId: 'file-v1'),
        ],
        edges: const <MtnMinecraftContentPackageLockedEdge>[],
      ),
    );
    final imported = MtnMinecraftContentPackage.decode(published.encode());
    final userMod = sampleItem('user-addon');
    final draft = samplePackage(items: <MtnMinecraftContentPackageItem>[...imported.items, userMod]);
    final record = MtnMinecraftContentPackageRecord(
      package: draft,
      source: MtnMinecraftContentPackageSource.downloaded,
      remoteId: 'published-skyblock',
      publishedRevision: 4,
    );
    expect(record.package.canAdd, isTrue);
    expect(record.package.getItem('modrinth:original-mod')!.source, MtnMinecraftContentPackageSource.downloaded);
    expect(record.package.getItem('modrinth:user-addon')!.source, MtnMinecraftContentPackageSource.local);
    expect(record.toMap()['schemaVersion'], 2);

    final codec = MtnMinecraftContentPackageRecordCodec();
    final bytes = await codec.encrypt(record, key: key, keyId: 'test-key');
    final restored = await codec.decrypt(bytes, key: key, expectedKeyId: 'test-key');
    expect(restored.source, MtnMinecraftContentPackageSource.downloaded);
    expect(restored.publishedRevision, 4);
    expect(restored.package.lock, isNull);
    expect(restored.package.getItem('modrinth:original-mod')!.source, MtnMinecraftContentPackageSource.downloaded);
    expect(restored.package.getItem('modrinth:user-addon')!.source, MtnMinecraftContentPackageSource.local);
    expect(restored.package.toLocalMap()['items'], isA<List<Object?>>());
    expect(() => restored.package.encode(), throwsStateError);
  });

  test('local source decoding refuses missing or forged item provenance and old local record schema', () {
    final record = MtnMinecraftContentPackageRecord(package: samplePackage(items: <MtnMinecraftContentPackageItem>[sampleItem('original-mod')]), source: MtnMinecraftContentPackageSource.local);
    final raw = record.toMap();
    final localPackage = Map<String, dynamic>.from(raw['package'] as Map);
    final items = <Map<String, dynamic>>[Map<String, dynamic>.from((localPackage['items'] as List).single as Map)];
    localPackage['items'] = items;

    items.single.remove('source');
    expect(() => MtnMinecraftContentPackage.fromLocalMap(localPackage), throwsFormatException);
    items.single['source'] = 'unknown';
    expect(() => MtnMinecraftContentPackage.fromLocalMap(localPackage), throwsFormatException);
    expect(() => MtnMinecraftContentPackageRecord.fromMap(<String, dynamic>{...raw, 'schemaVersion': 1}), throwsFormatException);
  });
}
