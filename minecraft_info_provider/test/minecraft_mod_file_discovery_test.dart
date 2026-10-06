import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Minecraft installed mod-file discovery', () {
    late Directory gameDirectory;
    late Directory modsDirectory;
    late MtnMinecraftInfoProvider provider;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-info-mods-',
      );
      modsDirectory = Directory(p.join(gameDirectory.path, 'mods'));
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('missing mods directory reads as an empty immutable list', () async {
      final List<MtnMinecraftInfoMod> mods = await provider.readMods();

      expect(mods, isEmpty);
      expect(
        () => mods.add(
          MtnMinecraftInfoMod(
            file: File(p.join(gameDirectory.path, 'x.jar')),
            fileName: 'x.jar',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('discovers direct jar files in deterministic file-name order', () async {
      await modsDirectory.create();
      await File(p.join(modsDirectory.path, 'z-last.jar')).writeAsBytes(<int>[1]);
      await File(p.join(modsDirectory.path, 'a-first.jar')).writeAsBytes(<int>[2]);

      final List<MtnMinecraftInfoMod> mods = await provider.readMods();

      expect(
        mods.map((MtnMinecraftInfoMod mod) => mod.fileName).toList(),
        <String>['a-first.jar', 'z-last.jar'],
      );
      expect(
        mods.map((MtnMinecraftInfoMod mod) => mod.file.path).toList(),
        <String>[
          p.join(modsDirectory.path, 'a-first.jar'),
          p.join(modsDirectory.path, 'z-last.jar'),
        ],
      );
    });

    test('jar extension matching is case-insensitive', () async {
      await modsDirectory.create();
      await File(p.join(modsDirectory.path, 'Example.JAR')).writeAsBytes(<int>[1]);

      final List<MtnMinecraftInfoMod> mods = await provider.readMods();

      expect(mods, hasLength(1));
      expect(mods.single.fileName, 'Example.JAR');
    });

    test('ignores non-jar files', () async {
      await modsDirectory.create();
      await File(p.join(modsDirectory.path, 'readme.txt')).writeAsString('x');
      await File(p.join(modsDirectory.path, 'disabled.jar.disabled')).writeAsBytes(<int>[1]);
      await File(p.join(modsDirectory.path, 'actual.jar')).writeAsBytes(<int>[2]);

      final List<MtnMinecraftInfoMod> mods = await provider.readMods();

      expect(mods, hasLength(1));
      expect(mods.single.fileName, 'actual.jar');
    });

    test('does not recurse into nested directories', () async {
      final Directory nested = Directory(p.join(modsDirectory.path, 'nested'));
      await nested.create(recursive: true);
      await File(p.join(nested.path, 'nested.jar')).writeAsBytes(<int>[1]);
      await File(p.join(modsDirectory.path, 'direct.jar')).writeAsBytes(<int>[2]);

      final List<MtnMinecraftInfoMod> mods = await provider.readMods();

      expect(mods, hasLength(1));
      expect(mods.single.fileName, 'direct.jar');
    });

    test('mods path must be a directory when present', () async {
      await File(modsDirectory.path).writeAsString('not-a-directory');

      await expectLater(
        provider.readMods(),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('game directory must exist', () async {
      await gameDirectory.delete(recursive: true);

      await expectLater(
        provider.readMods(),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });
  });
}
