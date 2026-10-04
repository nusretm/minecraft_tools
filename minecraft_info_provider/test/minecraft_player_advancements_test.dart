import 'dart:convert';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuidA = '00112233-4455-6677-8899-aabbccddeeff';
const String _uuidB = '11112222-3333-4444-aaaa-bbbbccccdddd';

void main() {
  group('Minecraft Info Provider player advancements', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;
    late MtnMinecraftInfoPlayer player;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-advancements-',
      );
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
      worldDirectory = Directory(
        p.join(gameDirectory.path, 'saves', 'World'),
      );
      await worldDirectory.create(recursive: true);
      world = MtnMinecraftInfoWorld.available(
        directory: worldDirectory,
        directoryName: 'World',
      );
      player = MtnMinecraftInfoPlayer.available(
        uuid: _uuidA,
        dataFile: File(
          p.join(worldDirectory.path, 'playerdata', '$_uuidA.dat'),
        ),
        storageLayout: MtnMinecraftInfoPlayerStorageLayout.legacy,
      );
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('missing advancements file returns null', () async {
      expect(await provider.readPlayerAdvancements(world, player), isNull);
    });

    test('reads legacy advancements and preserves unknown IDs', () async {
      final File file = await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 3465,
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{
              'crafting_table': '2026-10-04 10:15:30 +0300',
            },
            'done': true,
          },
          'example:future/custom': <String, Object?>{
            'criteria': <String, Object?>{
              'first': '2026-10-03 23:45:00 -0230',
            },
            'done': false,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(advancements.uuid, _uuidA);
      expect(advancements.file.path, file.path);
      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
      );
      expect(
        advancements.state,
        MtnMinecraftInfoPlayerAdvancementsState.available,
      );
      expect(advancements.error, isNull);
      expect(advancements.dataVersion, 3465);
      expect(advancements.advancements.keys, contains('example:future/custom'));

      final MtnMinecraftInfoPlayerAdvancement root =
          advancements.advancements['minecraft:story/root']!;
      expect(root.id, 'minecraft:story/root');
      expect(root.done, isTrue);
      expect(
        root.criteria['crafting_table'],
        DateTime.utc(2026, 10, 4, 7, 15, 30),
      );

      final MtnMinecraftInfoPlayerAdvancement custom =
          advancements.advancements['example:future/custom']!;
      expect(custom.done, isFalse);
      expect(
        custom.criteria['first'],
        DateTime.utc(2026, 10, 4, 2, 15),
      );
    });

    test('reads modern players/advancements layout', () async {
      final File file = await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{},
            'done': false,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(advancements.file.path, file.path);
      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
      );
      expect(advancements.dataVersion, isNull);
      expect(
        advancements.advancements['minecraft:story/root']?.done,
        isFalse,
      );
    });

    test('advancements layout is independent from player-data layout',
        () async {
      final MtnMinecraftInfoPlayer modernPlayer =
          MtnMinecraftInfoPlayer.available(
        uuid: _uuidA,
        dataFile: File(
          p.join(
            worldDirectory.path,
            'players',
            'data',
            '$_uuidA.dat',
          ),
        ),
        storageLayout: MtnMinecraftInfoPlayerStorageLayout.modern,
      );
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{},
            'done': true,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, modernPlayer))!;

      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
      );
    });

    test('valid modern advancements do not depend on legacy storage shape',
        () async {
      await File(
        p.join(worldDirectory.path, 'advancements'),
      ).writeAsString('x');
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
        data: <String, Object?>{
          'DataVersion': 5000,
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
      );
      expect(advancements.dataVersion, 5000);
      expect(advancements.advancements, isEmpty);
    });

    test('modern advancements win when UUID exists in both layouts',
        () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 1,
        },
      );
      final File modern = await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
        data: <String, Object?>{
          'DataVersion': 2,
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
      );
      expect(advancements.file.path, modern.path);
      expect(advancements.dataVersion, 2);
    });

    test('corrupt modern duplicate does not fall back to legacy', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 1,
        },
      );
      final File modern = _advancementsFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
      );
      await modern.parent.create(recursive: true);
      await modern.writeAsString('{broken');

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.storageLayout,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
      );
      expect(
        advancements.state,
        MtnMinecraftInfoPlayerAdvancementsState.invalid,
      );
      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidJson,
      );
    });

    test('invalid JSON is isolated as invalidJson', () async {
      final File file = _advancementsFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('{');

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.state,
        MtnMinecraftInfoPlayerAdvancementsState.invalid,
      );
      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidJson,
      );
    });

    test('non-object root is invalidData', () async {
      await _writeRawAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        value: <Object?>[],
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('non-integer DataVersion is invalidData', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': '3465',
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('advancement progress must be an object', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': true,
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('done must be a boolean', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{},
            'done': 1,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('criteria must be an object', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <Object?>[],
            'done': false,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('criterion timestamp must be a string', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{
              'criterion': 1,
            },
            'done': false,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('malformed criterion timestamp is invalidData', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{
              'criterion': '2026-99-99 25:61:61 +9999',
            },
            'done': false,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        advancements.error,
        MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    });

    test('advancement and criteria maps are deeply immutable', () async {
      await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{
          'minecraft:story/root': <String, Object?>{
            'criteria': <String, Object?>{
              'criterion': '2026-10-04 10:15:30 +0300',
            },
            'done': true,
          },
        },
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(
        () => advancements.advancements['example:test'] =
            MtnMinecraftInfoPlayerAdvancement(
          id: 'example:test',
          done: false,
          criteria: const <String, DateTime>{},
        ),
        throwsUnsupportedError,
      );
      expect(
        () => advancements
            .advancements['minecraft:story/root']!
            .criteria['criterion'] = DateTime.utc(2026),
        throwsUnsupportedError,
      );
    });

    test('uppercase filename is matched by canonical UUID', () async {
      final File file = await _writeAdvancements(
        worldDirectory,
        uuid: _uuidA.toUpperCase(),
        layout: MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
        data: <String, Object?>{},
      );

      final MtnMinecraftInfoPlayerAdvancements advancements =
          (await provider.readPlayerAdvancements(world, player))!;

      expect(advancements.uuid, _uuidA);
      expect(advancements.file.path, file.path);
    });

    test('player from another world is rejected', () async {
      final Directory otherWorld = Directory(
        p.join(gameDirectory.path, 'saves', 'Other World'),
      );
      await otherWorld.create(recursive: true);
      final MtnMinecraftInfoPlayer foreignPlayer =
          MtnMinecraftInfoPlayer.available(
        uuid: _uuidB,
        dataFile: File(
          p.join(otherWorld.path, 'playerdata', '$_uuidB.dat'),
        ),
        storageLayout: MtnMinecraftInfoPlayerStorageLayout.legacy,
      );

      expect(
        provider.readPlayerAdvancements(world, foreignPlayer),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('foreign world is rejected', () async {
      final Directory foreignDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-advancements-foreign-',
      );
      addTearDown(() async {
        if (await foreignDirectory.exists()) {
          await foreignDirectory.delete(recursive: true);
        }
      });
      final MtnMinecraftInfoWorld foreignWorld =
          MtnMinecraftInfoWorld.available(
        directory: foreignDirectory,
        directoryName: p.basename(foreignDirectory.path),
      );

      expect(
        provider.readPlayerAdvancements(foreignWorld, player),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('non-directory advancements storage fails at provider level',
        () async {
      await File(
        p.join(worldDirectory.path, 'advancements'),
      ).writeAsString('x');

      expect(
        provider.readPlayerAdvancements(world, player),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });
  });
}

Future<File> _writeAdvancements(
  Directory worldDirectory, {
  required String uuid,
  required MtnMinecraftInfoPlayerAdvancementsStorageLayout layout,
  required Map<String, Object?> data,
}) =>
    _writeRawAdvancements(
      worldDirectory,
      uuid: uuid,
      layout: layout,
      value: data,
    );

Future<File> _writeRawAdvancements(
  Directory worldDirectory, {
  required String uuid,
  required MtnMinecraftInfoPlayerAdvancementsStorageLayout layout,
  required Object? value,
}) async {
  final File file = _advancementsFile(worldDirectory, uuid, layout);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(value), flush: true);
  return file;
}

File _advancementsFile(
  Directory worldDirectory,
  String uuid,
  MtnMinecraftInfoPlayerAdvancementsStorageLayout layout,
) {
  final List<String> parts = switch (layout) {
    MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy => <String>[
        worldDirectory.path,
        'advancements',
        '$uuid.json',
      ],
    MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern => <String>[
        worldDirectory.path,
        'players',
        'advancements',
        '$uuid.json',
      ],
  };
  return File(p.joinAll(parts));
}
