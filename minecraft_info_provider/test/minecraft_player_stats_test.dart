import 'dart:convert';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuidA = '00112233-4455-6677-8899-aabbccddeeff';
const String _uuidB = '11112222-3333-4444-aaaa-bbbbccccdddd';

void main() {
  group('Minecraft Info Provider player stats', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;
    late MtnMinecraftInfoPlayer player;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-stats-',
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

    test('missing stats file returns null', () async {
      expect(await provider.readPlayerStats(world, player), isNull);
    });

    test('reads legacy stats with generic unknown keys', () async {
      final File file = await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 3465,
          'stats': <String, Object?>{
            'minecraft:mined': <String, Object?>{
              'minecraft:stone': 123,
            },
            'example:future_category': <String, Object?>{
              'example:future_stat': 456,
            },
          },
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.uuid, _uuidA);
      expect(stats.file.path, file.path);
      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
      );
      expect(stats.state, MtnMinecraftInfoPlayerStatsState.available);
      expect(stats.error, isNull);
      expect(stats.dataVersion, 3465);
      expect(stats.values['minecraft:mined']?['minecraft:stone'], 123);
      expect(
        stats.values['example:future_category']?['example:future_stat'],
        456,
      );
    });

    test('reads modern players/stats layout', () async {
      final File file = await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.modern,
        data: <String, Object?>{
          'stats': <String, Object?>{
            'minecraft:custom': <String, Object?>{
              'minecraft:jump': 9,
            },
          },
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.file.path, file.path);
      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
      );
      expect(stats.dataVersion, isNull);
      expect(stats.values['minecraft:custom']?['minecraft:jump'], 9);
    });

    test('stats layout is independent from player-data layout', () async {
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
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'stats': <String, Object?>{
            'minecraft:custom': <String, Object?>{
              'minecraft:jump': 7,
            },
          },
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, modernPlayer))!;

      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
      );
      expect(stats.values['minecraft:custom']?['minecraft:jump'], 7);
    });

    test('valid modern stats do not depend on legacy storage shape', () async {
      await File(p.join(worldDirectory.path, 'stats')).writeAsString('x');
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.modern,
        data: <String, Object?>{
          'DataVersion': 5000,
          'stats': <String, Object?>{},
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
      );
      expect(stats.dataVersion, 5000);
    });

    test('modern stats win when the same UUID exists in both layouts',
        () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 1,
          'stats': <String, Object?>{},
        },
      );
      final File modern = await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.modern,
        data: <String, Object?>{
          'DataVersion': 2,
          'stats': <String, Object?>{},
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
      );
      expect(stats.file.path, modern.path);
      expect(stats.dataVersion, 2);
    });

    test('corrupt modern duplicate does not fall back to legacy', () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 1,
          'stats': <String, Object?>{},
        },
      );
      final File modern = _statsFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
      );
      await modern.parent.create(recursive: true);
      await modern.writeAsString('{broken');

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(
        stats.storageLayout,
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
      );
      expect(stats.state, MtnMinecraftInfoPlayerStatsState.invalid);
      expect(stats.error, MtnMinecraftInfoPlayerStatsError.invalidJson);
    });

    test('invalid JSON is isolated as invalidJson', () async {
      final File file = _statsFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('{');

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.state, MtnMinecraftInfoPlayerStatsState.invalid);
      expect(stats.error, MtnMinecraftInfoPlayerStatsError.invalidJson);
    });

    test('missing stats object is invalidData', () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': 3465,
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.state, MtnMinecraftInfoPlayerStatsState.invalid);
      expect(stats.error, MtnMinecraftInfoPlayerStatsError.invalidData);
    });

    test('non-integer DataVersion is invalidData', () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'DataVersion': '3465',
          'stats': <String, Object?>{},
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.state, MtnMinecraftInfoPlayerStatsState.invalid);
      expect(stats.error, MtnMinecraftInfoPlayerStatsError.invalidData);
    });

    test('non-integer counter is invalidData', () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'stats': <String, Object?>{
            'minecraft:custom': <String, Object?>{
              'minecraft:jump': 1.5,
            },
          },
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.state, MtnMinecraftInfoPlayerStatsState.invalid);
      expect(stats.error, MtnMinecraftInfoPlayerStatsError.invalidData);
    });

    test('stats maps are deeply immutable', () async {
      await _writeStats(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'stats': <String, Object?>{
            'minecraft:mined': <String, Object?>{
              'minecraft:stone': 1,
            },
          },
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(
        () => stats.values['minecraft:custom'] = <String, int>{},
        throwsUnsupportedError,
      );
      expect(
        () => stats.values['minecraft:mined']!['minecraft:stone'] = 2,
        throwsUnsupportedError,
      );
    });

    test('uppercase stats filename is matched by canonical UUID', () async {
      final File file = await _writeStats(
        worldDirectory,
        uuid: _uuidA.toUpperCase(),
        layout: MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
        data: <String, Object?>{
          'stats': <String, Object?>{},
        },
      );

      final MtnMinecraftInfoPlayerStats stats =
          (await provider.readPlayerStats(world, player))!;

      expect(stats.uuid, _uuidA);
      expect(stats.file.path, file.path);
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
        provider.readPlayerStats(world, foreignPlayer),
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
        'mtn-minecraft-player-stats-foreign-',
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
        provider.readPlayerStats(foreignWorld, player),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('non-directory stats storage path fails at provider level', () async {
      await File(p.join(worldDirectory.path, 'stats')).writeAsString('x');

      expect(
        provider.readPlayerStats(world, player),
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

Future<File> _writeStats(
  Directory worldDirectory, {
  required String uuid,
  required MtnMinecraftInfoPlayerStatsStorageLayout layout,
  required Map<String, Object?> data,
}) async {
  final File file = _statsFile(worldDirectory, uuid, layout);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(data), flush: true);
  return file;
}

File _statsFile(
  Directory worldDirectory,
  String uuid,
  MtnMinecraftInfoPlayerStatsStorageLayout layout,
) {
  final List<String> parts = switch (layout) {
    MtnMinecraftInfoPlayerStatsStorageLayout.legacy => <String>[
        worldDirectory.path,
        'stats',
        '$uuid.json',
      ],
    MtnMinecraftInfoPlayerStatsStorageLayout.modern => <String>[
        worldDirectory.path,
        'players',
        'stats',
        '$uuid.json',
      ],
  };
  return File(p.joinAll(parts));
}
