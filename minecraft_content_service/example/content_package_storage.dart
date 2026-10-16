import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Real filesystem smoke: save, update, reopen, inspect key ID and delete.
/// Key is ephemeral for this example; production callers provide it externally.
Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('mtn-content-package-cp07-');
  final random = Random.secure();
  final key = Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  const recordId = '8ae68885-0e10-42ba-943b-9c241f9a1ebd';
  final storage = MtnMinecraftContentPackageRecordStorage(directory: Directory('${root.path}${Platform.pathSeparator}packages'));

  MtnMinecraftContentPackageRecord record(String title) => MtnMinecraftContentPackageRecord(
    source: MtnMinecraftContentPackageSource.local,
    remoteId: 'hypixel-skyblock',
    publishedRevision: 2,
    package: MtnMinecraftContentPackage(
      id: 'hypixel-skyblock',
      title: title,
      ownerName: 'Skyblock Team',
      description: '# Hypixel Skyblock\nRun the package from the launcher.',
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

  try {
    await storage.save(recordId, record('Hypixel Skyblock'), key: key, keyId: 'example-key-1');
    await storage.save(recordId, record('Hypixel Skyblock — Updated'), key: key, keyId: 'example-key-1');

    // A new instance proves that the result is actually persisted on disk.
    final reopened = MtnMinecraftContentPackageRecordStorage(directory: storage.directory);
    if (await reopened.getKeyId(recordId) != 'example-key-1') throw StateError('Key ID was not persisted.');
    final restored = await reopened.load(recordId, key: key);
    if (restored?.package.title != 'Hypixel Skyblock — Updated' ||
        restored?.package.ramMiB != 6144 ||
        restored?.package.serverAddress != 'mc.hypixel.net' ||
        restored?.package.ownerName != 'Skyblock Team' ||
        restored?.publishedRevision != 2) {
      throw StateError('Encrypted disk roundtrip did not preserve package metadata.');
    }
    if ((await reopened.listRecordIds()).single != recordId) throw StateError('Stored record listing failed.');
    var wrongKeyRejected = false;
    try {
      await reopened.load(recordId, key: Uint8List(32));
    } catch (_) {
      wrongKeyRejected = true;
    }
    if (!wrongKeyRejected) throw StateError('Incorrect AES-GCM key unexpectedly decrypted the record.');
    final saved = File('${storage.directory.path}${Platform.pathSeparator}$recordId${Platform.pathSeparator}${MtnMinecraftContentPackageRecordStorage.fileName}');
    if (!await saved.exists()) throw StateError('Stable encrypted game package file is missing.');
    print('Storage PASS: stable encrypted package updated, metadata and keyId=${await reopened.getKeyId(recordId)}');
    if (!await reopened.delete(recordId)) throw StateError('Record deletion failed.');
    print('Storage PASS: wrong key rejected; encrypted record deletion completed.');
  } finally {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
