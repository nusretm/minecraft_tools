import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 18);

  MtnMinecraftContentPackage sample({String? image, MtnMinecraftContentPackageLogoImageMode mode = MtnMinecraftContentPackageLogoImageMode.fit}) =>
      MtnMinecraftContentPackage(
        id: 'logo-test',
        title: 'Test Game',
        minecraftVersion: '26.1.2',
        modLoader: MtnMinecraftModLoaderType.vanilla,
        ramMiB: 4096,
        ownerName: 'User',
        createdAt: now,
        updatedAt: now,
        logoImageFileName: image,
        logoImageMode: mode,
        items: const <MtnMinecraftContentPackageItem>[],
        lock: MtnMinecraftContentPackageLock(
          versions: const <MtnMinecraftContentPackageLockedVersion>[],
          edges: const <MtnMinecraftContentPackageLockedEdge>[],
        ),
      );

  test('portable and encrypted-record model maps retain logo association and mode', () {
    final String fileName = '${'a' * 64}.png';
    final MtnMinecraftContentPackage package = sample(
      image: fileName, mode: MtnMinecraftContentPackageLogoImageMode.center,
    );
    final local = MtnMinecraftContentPackage.fromLocalMap(package.toLocalMap());
    final portable = MtnMinecraftContentPackage.fromMap(package.toMap());
    for (final restored in <MtnMinecraftContentPackage>[local, portable]) {
      expect(restored.logoImageFileName, fileName);
      expect(restored.logoImageMode, MtnMinecraftContentPackageLogoImageMode.center);
    }
  });

  test('older schema-2 records without optional logo properties remain readable', () {
    final Map<String, dynamic> original = sample().toLocalMap()
      ..remove('logoImageMode')
      ..remove('logoImageFileName');
    final MtnMinecraftContentPackage restored = MtnMinecraftContentPackage.fromLocalMap(original);
    expect(restored.logoImageFileName, isNull);
    expect(restored.logoImageMode, MtnMinecraftContentPackageLogoImageMode.fit);
  });

  test('invalid paths and unsupported image modes are rejected', () {
    expect(() => sample(image: '../file.png'), throwsArgumentError);
    expect(() => sample(image: '${'b' * 64}.gif'), throwsArgumentError);
    final Map<String, dynamic> original = sample().toLocalMap()..['logoImageMode'] = 'unknown';
    expect(() => MtnMinecraftContentPackage.fromLocalMap(original), throwsFormatException);
  });
}
