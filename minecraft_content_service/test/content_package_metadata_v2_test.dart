import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentPackage packageWithMetadata({
  MtnMinecraftModLoaderType loader = MtnMinecraftModLoaderType.fabric,
  String? loaderVersion = '0.16.14',
  int ramMiB = 6144,
  String ownerName = 'Skyblock Team',
  String? serverAddress = 'mc.hypixel.net',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return MtnMinecraftContentPackage(
    id: 'hypixel-pack',
    title: 'Hypixel Skyblock',
    description: '# Hypixel Skyblock\n*Play together*',
    ownerName: ownerName,
    minecraftVersion: '1.21.11',
    modLoader: loader,
    loaderVersion: loaderVersion,
    ramMiB: ramMiB,
    serverAddress: serverAddress,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 13, 10),
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 14, 12),
    revision: 5,
    items: const <MtnMinecraftContentPackageItem>[],
    lock: MtnMinecraftContentPackageLock(
      versions: const <MtnMinecraftContentPackageLockedVersion>[],
      edges: const <MtnMinecraftContentPackageLockedEdge>[],
    ),
  );
}

void main() {
  test('schema v2 preserves game launch, Markdown, owner and lifecycle metadata', () {
    final original = packageWithMetadata();
    final map = original.toMap();
    expect(map['schemaVersion'], 2);
    expect(map['ownerName'], 'Skyblock Team');
    expect(map['loaderVersion'], '0.16.14');
    expect(map['ramMiB'], 6144);
    expect(map['serverAddress'], 'mc.hypixel.net');
    expect(map['createdAt'], '2026-10-13T10:00:00.000Z');
    expect(map['updatedAt'], '2026-10-14T12:00:00.000Z');
    expect(map['description'], contains('*Play together*'));

    final restored = MtnMinecraftContentPackage.decode(original.encode());
    expect(restored.toJson(), original.toJson());
    expect(restored.ownerName, original.ownerName);
    expect(restored.ramMiB, original.ramMiB);
    expect(restored.modLoader, MtnMinecraftModLoaderType.fabric);
    expect(restored.loaderVersion, '0.16.14');
    expect(restored.serverAddress, 'mc.hypixel.net');
    expect(restored.revision, 5);
    expect(restored.createdAt.isUtc, isTrue);
  });

  test('strict v2 parsing rejects unsupported old schema and missing launch metadata', () {
    final map = packageWithMetadata().toMap();
    expect(() => MtnMinecraftContentPackage.fromMap(<String, dynamic>{...map, 'schemaVersion': 1}), throwsFormatException);
    expect(() => MtnMinecraftContentPackage.fromMap(<String, dynamic>{...map}..remove('ramMiB')), throwsFormatException);
    expect(() => MtnMinecraftContentPackage.fromMap(<String, dynamic>{...map}..remove('ownerName')), throwsFormatException);
    expect(() => MtnMinecraftContentPackage.fromMap(<String, dynamic>{...map, 'createdAt': '2026-10-13T10:00:00+03:00'}), throwsFormatException);
    expect(() => MtnMinecraftContentPackage.fromMap(<String, dynamic>{...map, 'updatedAt': 'invalid'}), throwsFormatException);
  });

  test('Minecraft loader, memory, identity and UTC chronology are checked', () {
    expect(() => packageWithMetadata(ramMiB: 0), throwsArgumentError);
    expect(() => packageWithMetadata(ownerName: '   '), throwsArgumentError);
    expect(() => packageWithMetadata(serverAddress: ' a b '), throwsArgumentError);
    expect(() => packageWithMetadata(loaderVersion: null), throwsArgumentError);
    expect(() => packageWithMetadata(loader: MtnMinecraftModLoaderType.vanilla, loaderVersion: '1.0'), throwsArgumentError);
    expect(() => packageWithMetadata(createdAt: DateTime(2026, 10, 14)), throwsArgumentError);
    expect(() => packageWithMetadata(updatedAt: DateTime.utc(2026, 10, 1)), throwsArgumentError);
    final vanilla = packageWithMetadata(loader: MtnMinecraftModLoaderType.vanilla, loaderVersion: null, serverAddress: null);
    expect(vanilla.toMap().containsKey('loaderVersion'), isFalse);
    expect(vanilla.toMap().containsKey('serverAddress'), isFalse);
  });
}
