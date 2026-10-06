import 'dart:convert';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Minecraft mod-loader discovery', () {
    late Directory gameDirectory;
    late MtnMinecraftInfoProvider provider;
    late Directory versionsDirectory;
    late File versionFile;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-info-mod-loader-',
      );
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
      versionsDirectory = Directory(p.join(gameDirectory.path, 'versions'));
      versionFile = File(p.join(versionsDirectory.path, 'version.json'));
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    Future<void> writeVersionJson(Object? value) async {
      await versionsDirectory.create(recursive: true);
      await versionFile.writeAsString(jsonEncode(value));
    }

    test('missing version.json means no discovered loader', () async {
      expect(await provider.readModLoader(), isNull);
    });

    test('reads Fabric loader type, version and inherited Minecraft version', () async {
      await writeVersionJson(<String, Object?>{
        'id': 'fabric-loader-0.19.5-26.1.2',
        'inheritsFrom': '26.1.2',
        'libraries': <Object?>[
          <String, Object?>{'name': 'ignored:library:1.0.0'},
        ],
      });

      final MtnMinecraftInfoModLoader? loader =
          await provider.readModLoader();

      expect(loader, isNotNull);
      expect(loader!.type, MtnMinecraftInfoModLoaderType.fabric);
      expect(loader.version, '0.19.5');
      expect(loader.minecraftVersion, '26.1.2');
    });

    test('reads Quilt loader profile', () async {
      await writeVersionJson(<String, Object?>{
        'id': 'quilt-loader-0.28.1-1.21.1',
        'inheritsFrom': '1.21.1',
      });

      final MtnMinecraftInfoModLoader? loader =
          await provider.readModLoader();

      expect(loader, isNotNull);
      expect(loader!.type, MtnMinecraftInfoModLoaderType.quilt);
      expect(loader.version, '0.28.1');
      expect(loader.minecraftVersion, '1.21.1');
    });

    test('reads Forge loader profile', () async {
      await writeVersionJson(<String, Object?>{
        'id': '1.20.1-forge-47.4.0',
        'inheritsFrom': '1.20.1',
      });

      final MtnMinecraftInfoModLoader? loader =
          await provider.readModLoader();

      expect(loader, isNotNull);
      expect(loader!.type, MtnMinecraftInfoModLoaderType.forge);
      expect(loader.version, '47.4.0');
      expect(loader.minecraftVersion, '1.20.1');
    });

    test('reads NeoForge loader profile', () async {
      await writeVersionJson(<String, Object?>{
        'id': '1.21.1-neoforge-21.1.93',
        'inheritsFrom': '1.21.1',
      });

      final MtnMinecraftInfoModLoader? loader =
          await provider.readModLoader();

      expect(loader, isNotNull);
      expect(loader!.type, MtnMinecraftInfoModLoaderType.neoForge);
      expect(loader.version, '21.1.93');
      expect(loader.minecraftVersion, '1.21.1');
    });

    test('unknown profile id is not guessed as vanilla or another loader', () async {
      await writeVersionJson(<String, Object?>{
        'id': 'custom-loader-profile',
      });

      expect(await provider.readModLoader(), isNull);
    });

    test('recognized loader requires inheritsFrom', () async {
      await writeVersionJson(<String, Object?>{
        'id': 'fabric-loader-0.19.5-26.1.2',
      });

      await expectLater(
        provider.readModLoader(),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidData,
          ),
        ),
      );
    });

    test('recognized malformed loader id is invalid data', () async {
      await writeVersionJson(<String, Object?>{
        'id': 'fabric-loader-26.1.2',
        'inheritsFrom': '26.1.2',
      });

      await expectLater(
        provider.readModLoader(),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidData,
          ),
        ),
      );
    });

    test('malformed JSON is invalid data', () async {
      await versionsDirectory.create(recursive: true);
      await versionFile.writeAsString('{');

      await expectLater(
        provider.readModLoader(),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidData,
          ),
        ),
      );
    });
  });
}
