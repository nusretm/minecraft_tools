import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuidA = '00112233-4455-6677-8899-aabbccddeeff';
const String _uuidB = '11112222-3333-4444-aaaa-bbbbccccdddd';
const String _uuidC = 'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb';

void main() {
  group('Minecraft Info Provider player discovery', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-info-',
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
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('missing player directories read as an empty immutable list',
        () async {
      final List<MtnMinecraftInfoPlayer> players =
          await provider.readPlayers(world);

      expect(players, isEmpty);
      expect(
        () => players.add(
          MtnMinecraftInfoPlayer.invalid(
            uuid: _uuidA,
            dataFile: File('unused'),
            storageLayout: MtnMinecraftInfoPlayerStorageLayout.legacy,
            error: MtnMinecraftInfoPlayerError.invalidData,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('reads legacy playerdata core metadata', () async {
      final File file = await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(
          dataVersion: 4321,
          dimension: 'minecraft:overworld',
          position: const <double>[12.5, 64.0, -20.25],
        ),
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.uuid, _uuidA);
      expect(player.dataFile.path, file.path);
      expect(
        player.storageLayout,
        MtnMinecraftInfoPlayerStorageLayout.legacy,
      );
      expect(player.state, MtnMinecraftInfoPlayerState.available);
      expect(player.error, isNull);
      expect(player.dataVersion, 4321);
      expect(player.dimension, 'minecraft:overworld');
      expect(player.position?.x, 12.5);
      expect(player.position?.y, 64.0);
      expect(player.position?.z, -20.25);
    });

    test('reads modern players/data core metadata', () async {
      final File file = await _writePlayer(
        worldDirectory,
        uuid: _uuidB,
        layout: MtnMinecraftInfoPlayerStorageLayout.modern,
        data: _playerData(
          dataVersion: 5000,
          dimension: 'minecraft:the_nether',
          position: const <double>[1.0, 72.0, 3.0],
        ),
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.uuid, _uuidB);
      expect(player.dataFile.path, file.path);
      expect(
        player.storageLayout,
        MtnMinecraftInfoPlayerStorageLayout.modern,
      );
      expect(player.dataVersion, 5000);
      expect(player.dimension, 'minecraft:the_nether');
      expect(player.position?.x, 1.0);
      expect(player.position?.y, 72.0);
      expect(player.position?.z, 3.0);
    });

    test('modern layout wins when the same UUID exists in both layouts',
        () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(dataVersion: 1),
      );
      final File modern = await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.modern,
        data: _playerData(dataVersion: 2),
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(
        player.storageLayout,
        MtnMinecraftInfoPlayerStorageLayout.modern,
      );
      expect(player.dataFile.path, modern.path);
      expect(player.dataVersion, 2);
    });

    test('corrupt modern duplicate does not fall back to legacy', () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(dataVersion: 1),
      );
      final File modern = _playerFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerStorageLayout.modern,
      );
      await modern.parent.create(recursive: true);
      await modern.writeAsBytes(<int>[1, 2, 3, 4], flush: true);

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(
        player.storageLayout,
        MtnMinecraftInfoPlayerStorageLayout.modern,
      );
      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(
        player.error,
        MtnMinecraftInfoPlayerError.invalidCompression,
      );
    });

    test('player ordering is deterministic and invalid names are ignored',
        () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidC,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(),
      );
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(),
      );
      final Directory playerData = Directory(
        p.join(worldDirectory.path, 'playerdata'),
      );
      await File(p.join(playerData.path, 'not-a-uuid.dat')).writeAsBytes(
        gzip.encode(<int>[1]),
      );
      await Directory(
        p.join(playerData.path, '22222222-3333-4444-5555-666666666666.dat'),
      ).create();

      final List<MtnMinecraftInfoPlayer> players =
          await provider.readPlayers(world);

      expect(
        players.map((MtnMinecraftInfoPlayer player) => player.uuid),
        <String>[_uuidA, _uuidC],
      );
    });

    test('uppercase UUID filenames are normalized to lowercase', () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA.toUpperCase(),
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(),
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.uuid, _uuidA);
      expect(p.basename(player.dataFile.path), '${_uuidA.toUpperCase()}.dat');
    });

    test('missing optional metadata still produces an available player',
        () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: <String, MtnMinecraftNbtValue>{},
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.available);
      expect(player.dataVersion, isNull);
      expect(player.dimension, isNull);
      expect(player.position, isNull);
    });

    test('corrupt player is isolated from valid siblings', () async {
      final File corrupt = _playerFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerStorageLayout.legacy,
      );
      await corrupt.parent.create(recursive: true);
      await corrupt.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      await _writePlayer(
        worldDirectory,
        uuid: _uuidB,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: _playerData(dataVersion: 9),
      );

      final List<MtnMinecraftInfoPlayer> players =
          await provider.readPlayers(world);

      expect(players, hasLength(2));
      expect(players.first.uuid, _uuidA);
      expect(players.first.state, MtnMinecraftInfoPlayerState.invalid);
      expect(
        players.first.error,
        MtnMinecraftInfoPlayerError.invalidCompression,
      );
      expect(players.last.uuid, _uuidB);
      expect(players.last.state, MtnMinecraftInfoPlayerState.available);
      expect(players.last.dataVersion, 9);
    });

    test('gzip payload containing malformed NBT is invalidNbt', () async {
      final File file = _playerFile(
        worldDirectory,
        _uuidA,
        MtnMinecraftInfoPlayerStorageLayout.legacy,
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        gzip.encode(<int>[MtnMinecraftNbtType.compound.id]),
        flush: true,
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(player.error, MtnMinecraftInfoPlayerError.invalidNbt);
    });

    test('non-compound player root is invalidData', () async {
      await _writePlayerDocument(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        document: MtnMinecraftNbtDocument(
          name: '',
          root: MtnMinecraftNbtValue.string('not-a-compound'),
        ),
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
    });

    test('wrong metadata type is invalidData', () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.legacy,
        data: <String, MtnMinecraftNbtValue>{
          'DataVersion': MtnMinecraftNbtValue.string('new'),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
    });

    test('Pos must be a three-double list', () async {
      await _writePlayer(
        worldDirectory,
        uuid: _uuidA,
        layout: MtnMinecraftInfoPlayerStorageLayout.modern,
        data: <String, MtnMinecraftNbtValue>{
          'Pos': MtnMinecraftNbtValue.list(
            MtnMinecraftNbtList(
              elementType: MtnMinecraftNbtType.doubleValue,
              values: <MtnMinecraftNbtValue>[
                MtnMinecraftNbtValue.doubleValue(1.0),
                MtnMinecraftNbtValue.doubleValue(2.0),
              ],
            ),
          ),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
    });

    test('world outside provider saves directory is rejected', () async {
      final Directory foreign = await Directory.systemTemp.createTemp(
        'mtn-minecraft-foreign-world-',
      );
      addTearDown(() async {
        if (await foreign.exists()) await foreign.delete(recursive: true);
      });
      final MtnMinecraftInfoWorld foreignWorld =
          MtnMinecraftInfoWorld.available(
        directory: foreign,
        directoryName: p.basename(foreign.path),
      );

      expect(
        provider.readPlayers(foreignWorld),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('non-directory player storage path fails at provider level', () async {
      await File(p.join(worldDirectory.path, 'playerdata')).writeAsString('x');

      expect(
        provider.readPlayers(world),
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

Map<String, MtnMinecraftNbtValue> _playerData({
  int? dataVersion,
  String? dimension,
  List<double>? position,
}) =>
    <String, MtnMinecraftNbtValue>{
      if (dataVersion != null)
        'DataVersion': MtnMinecraftNbtValue.intValue(dataVersion),
      if (dimension != null)
        'Dimension': MtnMinecraftNbtValue.string(dimension),
      if (position != null)
        'Pos': MtnMinecraftNbtValue.list(
          MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.doubleValue,
            values: position
                .map(MtnMinecraftNbtValue.doubleValue)
                .toList(growable: false),
          ),
        ),
    };

Future<File> _writePlayer(
  Directory worldDirectory, {
  required String uuid,
  required MtnMinecraftInfoPlayerStorageLayout layout,
  required Map<String, MtnMinecraftNbtValue> data,
}) =>
    _writePlayerDocument(
      worldDirectory,
      uuid: uuid,
      layout: layout,
      document: MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(data),
      ),
    );

Future<File> _writePlayerDocument(
  Directory worldDirectory, {
  required String uuid,
  required MtnMinecraftInfoPlayerStorageLayout layout,
  required MtnMinecraftNbtDocument document,
}) async {
  final File file = _playerFile(worldDirectory, uuid, layout);
  await file.parent.create(recursive: true);
  final List<int> encoded = const MtnMinecraftNbtCodec().encode(document);
  await file.writeAsBytes(gzip.encode(encoded), flush: true);
  return file;
}

File _playerFile(
  Directory worldDirectory,
  String uuid,
  MtnMinecraftInfoPlayerStorageLayout layout,
) {
  final List<String> parts = switch (layout) {
    MtnMinecraftInfoPlayerStorageLayout.legacy => <String>[
        worldDirectory.path,
        'playerdata',
        '$uuid.dat',
      ],
    MtnMinecraftInfoPlayerStorageLayout.modern => <String>[
        worldDirectory.path,
        'players',
        'data',
        '$uuid.dat',
      ],
  };
  return File(p.joinAll(parts));
}
