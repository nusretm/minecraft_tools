import 'dart:math';
import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Runtime smoke of encrypted local draft, without embedding a fixed key.
/// Production callers obtain the 32-byte key from their own trusted service.
Future<void> main() async {
  final random = Random.secure();
  final sessionKey = Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  final codec = MtnMinecraftContentPackageRecordCodec();

  final draft = MtnMinecraftContentPackage(
    id: 'sample-local',
    title: 'My Local Minecraft Package',
    minecraftVersion: '1.21.11',
    modLoader: MtnMinecraftModLoaderType.fabric,
    loaderVersion: '0.16.14', ramMiB: 4096, ownerName: 'Test Publisher', createdAt: DateTime.utc(2026, 10, 13), updatedAt: DateTime.utc(2026, 10, 14),
    items: <MtnMinecraftContentPackageItem>[
      MtnMinecraftContentPackageItem(
        provider: 'modrinth',
        projectId: 'y6DuFGwJ',
        type: MtnMinecraftContentType.mod,
        title: 'Skyblocker',
        direct: true,
      ),
    ],
  );
  final record = MtnMinecraftContentPackageRecord(
    package: draft,
    source: MtnMinecraftContentPackageSource.local,
    remoteId: 'sample-remote-reference',
    publishedRevision: 2,
  );

  final bytes = await codec.encrypt(record, key: sessionKey, keyId: 'example-session');
  final restored = await codec.decrypt(bytes, key: sessionKey, expectedKeyId: codec.readKeyId(bytes));
  if (restored.source != MtnMinecraftContentPackageSource.local ||
      restored.package.id != draft.id ||
      restored.publishedRevision != 2 ||
      restored.package.lock != null) {
    throw StateError('Local Content Package Record AES-GCM roundtrip failed.');
  }

  print('PASS encrypted local draft bytes=${bytes.length} keyId=${codec.readKeyId(bytes)}');
  print('source=${restored.source.name} package=${restored.package.id} publishedRevision=${restored.publishedRevision}');
  print('portable export remains locked-only; record codec never fetches a key from the network.');
}
