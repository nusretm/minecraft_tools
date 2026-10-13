import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

// Deliberately fixed ONLY in the test; no production or launcher key is embedded.
final testKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
final wrongKey = Uint8List.fromList(List<int>.filled(32, 2));

MtnMinecraftContentPackageRecord draftRecord() => MtnMinecraftContentPackageRecord(
  source: MtnMinecraftContentPackageSource.local,
  remoteId: 'remote-my-pack',
  publishedRevision: 2,
  package: MtnMinecraftContentPackage(
    id: 'my-pack',
    title: 'Editable Draft',
    minecraftVersion: '1.21.11',
    modLoader: MtnMinecraftModLoaderType.fabric,
    revision: 3,
    items: <MtnMinecraftContentPackageItem>[
      MtnMinecraftContentPackageItem(
        provider: 'modrinth',
        projectId: 'project-a',
        type: MtnMinecraftContentType.mod,
        title: 'Example Mod',
        direct: true,
      ),
    ],
  ),
);

void main() {
  test('local draft survives AES-256-GCM record roundtrip without a published lock', () async {
    final codec = MtnMinecraftContentPackageRecordCodec();
    final record = draftRecord();
    expect(() => record.package.encode(), throwsStateError);

    final ciphertext = await codec.encrypt(record, key: testKey, keyId: 'server-key-1');
    expect(codec.readKeyId(ciphertext), 'server-key-1');
    expect(String.fromCharCodes(ciphertext), isNot(contains('Editable Draft')));

    final restored = await codec.decrypt(ciphertext, key: testKey, expectedKeyId: 'server-key-1');
    expect(restored.source, MtnMinecraftContentPackageSource.local);
    expect(restored.remoteId, 'remote-my-pack');
    expect(restored.publishedRevision, 2);
    expect(restored.package.revision, 3);
    expect(restored.package.lock, isNull);
    expect(restored.package.items.single.projectId, 'project-a');
    expect(restored.package.items.single.state, MtnMinecraftContentItemState.notLoaded);
    expect(() => restored.package.toJson(), throwsStateError);
  });

  test('random nonce makes successive encryptions distinct', () async {
    final codec = MtnMinecraftContentPackageRecordCodec();
    final first = await codec.encrypt(draftRecord(), key: testKey, keyId: 'key-1');
    final second = await codec.encrypt(draftRecord(), key: testKey, keyId: 'key-1');
    expect(first, isNot(orderedEquals(second)));
    expect((await codec.decrypt(first, key: testKey)).package.id, 'my-pack');
    expect((await codec.decrypt(second, key: testKey)).package.id, 'my-pack');
  });

  test('wrong key, modified keyId, ciphertext or authentication tag fail closed', () async {
    final codec = MtnMinecraftContentPackageRecordCodec();
    final original = await codec.encrypt(draftRecord(), key: testKey, keyId: 'key-1');
    await expectLater(codec.decrypt(original, key: wrongKey), throwsA(anything));

    final modifiedId = Uint8List.fromList(original);
    modifiedId[7] ^= 1; // authenticated keyId header
    await expectLater(codec.decrypt(modifiedId, key: testKey), throwsA(anything));

    final modifiedCiphertext = Uint8List.fromList(original);
    modifiedCiphertext[modifiedCiphertext.length - 20] ^= 1;
    await expectLater(codec.decrypt(modifiedCiphertext, key: testKey), throwsA(anything));

    final modifiedTag = Uint8List.fromList(original);
    modifiedTag[modifiedTag.length - 1] ^= 1;
    await expectLater(codec.decrypt(modifiedTag, key: testKey), throwsA(anything));
    await expectLater(codec.decrypt(original, key: testKey, expectedKeyId: 'other-key'), throwsFormatException);
  });

  test('malformed envelopes and invalid keys are rejected', () async {
    final codec = MtnMinecraftContentPackageRecordCodec();
    final original = await codec.encrypt(draftRecord(), key: testKey, keyId: 'key-1');
    expect(() => codec.readKeyId(Uint8List.fromList(<int>[0, 1, 2])), throwsFormatException);
    final wrongMagic = Uint8List.fromList(original);
    wrongMagic[0] = 1;
    expect(() => codec.readKeyId(wrongMagic), throwsFormatException);
    await expectLater(codec.decrypt(original, key: Uint8List(16)), throwsArgumentError);
    await expectLater(codec.encrypt(draftRecord(), key: Uint8List(16), keyId: 'key'), throwsArgumentError);
    await expectLater(codec.encrypt(draftRecord(), key: testKey, keyId: ''), throwsArgumentError);
    await expectLater(codec.decrypt(original.sublist(0, 8), key: testKey), throwsFormatException);
  });

  test('downloaded record source is local-only and never enters portable package bytes', () async {
    final locked = MtnMinecraftContentPackage(
      id: 'downloaded',
      title: 'From Server',
      minecraftVersion: '1.21.11',
      modLoader: MtnMinecraftModLoaderType.fabric,
      items: <MtnMinecraftContentPackageItem>[
        MtnMinecraftContentPackageItem(provider: 'modrinth', projectId: 'a', type: MtnMinecraftContentType.mod, title: 'A', direct: true),
      ],
      lock: MtnMinecraftContentPackageLock(
        versions: <MtnMinecraftContentPackageLockedVersion>[
          MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:a', versionId: 'v1', fileName: 'a.jar', fileId: 'file-a'),
        ],
        edges: const <MtnMinecraftContentPackageLockedEdge>[],
      ),
    );
    final record = MtnMinecraftContentPackageRecord(package: locked, source: MtnMinecraftContentPackageSource.downloaded, remoteId: 'content-1');
    final codec = MtnMinecraftContentPackageRecordCodec();
    final ciphertext = await codec.encrypt(record, key: testKey, keyId: 'server-key-2');
    final restored = await codec.decrypt(ciphertext, key: testKey);
    expect(restored.source, MtnMinecraftContentPackageSource.downloaded);
    expect(restored.package.toJson(), locked.toJson());
    expect(locked.toJson(), isNot(contains('"source"')));
    expect(locked.toJson(), isNot(contains('remoteId')));
  });
}
