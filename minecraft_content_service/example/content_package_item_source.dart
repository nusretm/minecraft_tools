import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Real disk smoke: a downloaded item plus a locally added item share one
/// encrypted record without leaking item provenance to portable JSON.
Future<void> main() async {
  final temp = await Directory.systemTemp.createTemp('mtn-item-source-');
  final random = Random.secure();
  final key = Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  const recordId = '51b86b22-5206-4c9a-9eae-2b74de7a1a1d';
  final storage = MtnMinecraftContentPackageRecordStorage(directory: Directory('${temp.path}${Platform.pathSeparator}records'));

  try {
    final record = MtnMinecraftContentPackageRecord(
      source: MtnMinecraftContentPackageSource.downloaded,
      remoteId: 'hypixel-skyblock',
      publishedRevision: 2,
      package: MtnMinecraftContentPackage(
        id: 'hypixel-skyblock',
        title: 'Hypixel Skyblock',
        minecraftVersion: '1.21.11',
        modLoader: MtnMinecraftModLoaderType.fabric,
        loaderVersion: '0.16.14',
        ramMiB: 6144,
        ownerName: 'Skyblock Team',
        createdAt: DateTime.utc(2026, 10, 13),
        updatedAt: DateTime.utc(2026, 10, 14),
        mutationPolicy: MtnMinecraftContentPackageMutationPolicy.appendOnly,
        items: <MtnMinecraftContentPackageItem>[
          MtnMinecraftContentPackageItem(
            provider: 'modrinth', projectId: 'publisher-mod', title: 'Publisher Mod',
            type: MtnMinecraftContentType.mod, direct: true,
            source: MtnMinecraftContentPackageSource.downloaded,
          ),
          MtnMinecraftContentPackageItem(
            provider: 'modrinth', projectId: 'user-mod', title: 'User Mod',
            type: MtnMinecraftContentType.mod, direct: true,
          ),
        ],
      ),
    );

    await storage.save(recordId, record, key: key, keyId: 'session-key');
    final reopened = MtnMinecraftContentPackageRecordStorage(directory: storage.directory);
    final restored = await reopened.load(recordId, key: key);
    if (restored?.source != MtnMinecraftContentPackageSource.downloaded ||
        restored?.package.getItem('modrinth:publisher-mod')?.source != MtnMinecraftContentPackageSource.downloaded ||
        restored?.package.getItem('modrinth:user-mod')?.source != MtnMinecraftContentPackageSource.local) {
      throw StateError('Item source was not preserved after encrypted disk roundtrip.');
    }

    print('CP-08 PASS: downloaded item and local item retained separate source values after disk reload.');
    if (await reopened.delete(recordId) != true) throw StateError('Record cleanup failed.');
  } finally {
    if (await temp.exists()) await temp.delete(recursive: true);
  }
}
