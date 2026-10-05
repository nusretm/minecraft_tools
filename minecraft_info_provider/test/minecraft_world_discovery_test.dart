import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Minecraft Info Provider world discovery', () {
    late Directory gameDirectory;
    late MtnMinecraftInfoProvider provider;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-world-info-',
      );
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('missing saves directory reads as an empty immutable list', () async {
      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

      expect(worlds, isEmpty);
      expect(
        () => worlds.add(
          MtnMinecraftInfoWorld.invalid(
            directory: Directory('unused'),
            directoryName: 'unused',
            error: MtnMinecraftInfoWorldError.invalidData,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('reads gzip level.dat core metadata', () async {
      final Directory worldDirectory = await _writeWorld(
        gameDirectory,
        directoryName: 'Folder Name',
        data: <String, MtnMinecraftNbtValue>{
          'LevelName': MtnMinecraftNbtValue.string('Displayed World'),
          'DataVersion': MtnMinecraftNbtValue.intValue(4321),
          'LastPlayed': MtnMinecraftNbtValue.long(1790956800123),
          'Version': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'Id': MtnMinecraftNbtValue.intValue(4321),
              'Name': MtnMinecraftNbtValue.string('test-version'),
              'Snapshot': MtnMinecraftNbtValue.byte(0),
              'Series': MtnMinecraftNbtValue.string('main'),
            },
          ),
        },
      );

      final List<int> persisted =
          await File(p.join(worldDirectory.path, 'level.dat')).readAsBytes();
      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();
      final MtnMinecraftInfoWorld world = worlds.single;

      expect(persisted.sublist(0, 2), <int>[0x1f, 0x8b]);
      expect(world.state, MtnMinecraftInfoWorldState.available);
      expect(world.error, isNull);
      expect(world.directory.path, worldDirectory.path);
      expect(world.directoryName, 'Folder Name');
      expect(world.name, 'Displayed World');
      expect(world.dataVersion, 4321);
      expect(world.version?.id, 4321);
      expect(world.version?.name, 'test-version');
      expect(world.version?.snapshot, isFalse);
      expect(world.version?.series, 'main');
      expect(
        world.lastPlayed?.millisecondsSinceEpoch,
        1790956800123,
      );
      expect(world.lastPlayed?.isUtc, isTrue);
      expect(world.levelFile.path, p.join(worldDirectory.path, 'level.dat'));
      expect(world.iconFile.path, p.join(worldDirectory.path, 'icon.png'));
    });

    test('directory name and LevelName remain independent', () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'New World (3)',
        data: <String, MtnMinecraftNbtValue>{
          'LevelName': MtnMinecraftNbtValue.string('Survival 2026'),
        },
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.directoryName, 'New World (3)');
      expect(world.name, 'Survival 2026');
    });

    test('world ordering is deterministic by directory name', () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'z-world',
        data: <String, MtnMinecraftNbtValue>{},
      );
      await _writeWorld(
        gameDirectory,
        directoryName: 'A-world',
        data: <String, MtnMinecraftNbtValue>{},
      );
      await Directory(
        p.join(gameDirectory.path, 'saves', 'not-a-world'),
      ).create(recursive: true);

      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

      expect(
        worlds.map((MtnMinecraftInfoWorld world) => world.directoryName),
        <String>['A-world', 'z-world'],
      );
    });

    test('missing optional metadata still produces an available world',
        () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'Old World',
        data: <String, MtnMinecraftNbtValue>{},
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.state, MtnMinecraftInfoWorldState.available);
      expect(world.name, isNull);
      expect(world.dataVersion, isNull);
      expect(world.version, isNull);
      expect(world.lastPlayed, isNull);
      expect(world.singleplayerUuid, isNull);
      expect(world.singleplayerPlayer, isNull);
    });

    test('corrupt world is isolated from valid siblings', () async {
      final Directory corruptDirectory = Directory(
        p.join(gameDirectory.path, 'saves', 'A-corrupt'),
      );
      await corruptDirectory.create(recursive: true);
      await File(p.join(corruptDirectory.path, 'level.dat')).writeAsBytes(
        <int>[1, 2, 3, 4],
        flush: true,
      );
      await _writeWorld(
        gameDirectory,
        directoryName: 'B-valid',
        data: <String, MtnMinecraftNbtValue>{
          'LevelName': MtnMinecraftNbtValue.string('Valid'),
        },
      );

      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

      expect(worlds, hasLength(2));
      expect(worlds.first.directoryName, 'A-corrupt');
      expect(worlds.first.state, MtnMinecraftInfoWorldState.invalid);
      expect(
        worlds.first.error,
        MtnMinecraftInfoWorldError.invalidCompression,
      );
      expect(worlds.last.directoryName, 'B-valid');
      expect(worlds.last.state, MtnMinecraftInfoWorldState.available);
      expect(worlds.last.name, 'Valid');
    });

    test('gzip payload containing malformed NBT is invalidNbt', () async {
      final Directory directory = Directory(
        p.join(gameDirectory.path, 'saves', 'Broken NBT'),
      );
      await directory.create(recursive: true);
      await File(p.join(directory.path, 'level.dat')).writeAsBytes(
        gzip.encode(<int>[MtnMinecraftNbtType.compound.id]),
        flush: true,
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.state, MtnMinecraftInfoWorldState.invalid);
      expect(world.error, MtnMinecraftInfoWorldError.invalidNbt);
    });

    test('wrong level.dat schema is invalidData', () async {
      await _writeDocument(
        gameDirectory,
        directoryName: 'Wrong Schema',
        document: MtnMinecraftNbtDocument(
          name: '',
          root: MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'Data': MtnMinecraftNbtValue.string('not-a-compound'),
            },
          ),
        ),
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.state, MtnMinecraftInfoWorldState.invalid);
      expect(world.error, MtnMinecraftInfoWorldError.invalidData);
    });

    test('wrong optional metadata type is invalidData', () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'Wrong Field',
        data: <String, MtnMinecraftNbtValue>{
          'LastPlayed': MtnMinecraftNbtValue.string('yesterday'),
        },
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.state, MtnMinecraftInfoWorldState.invalid);
      expect(world.error, MtnMinecraftInfoWorldError.invalidData);
    });

    test('world snapshot includes its discovered players', () async {
      final Directory worldDirectory = await _writeWorld(
        gameDirectory,
        directoryName: 'Players World',
        data: <String, MtnMinecraftNbtValue>{},
      );
      const String uuid = '00112233-4455-6677-8899-aabbccddeeff';
      await _writeWorldPlayer(
        worldDirectory,
        uuid: uuid,
        dataVersion: 5000,
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.playersState, MtnMinecraftInfoWorldPlayersState.available);
      expect(world.playersError, isNull);
      expect(world.players, hasLength(1));
      expect(world.players.single.uuid, uuid);
      expect(world.players.single.dataVersion, 5000);
      expect(
        () => world.players.add(
          MtnMinecraftInfoPlayer.invalid(
            uuid: '11112222-3333-4444-aaaa-bbbbccccdddd',
            dataFile: File('unused'),
            storageLayout: MtnMinecraftInfoPlayerStorageLayout.modern,
            error: MtnMinecraftInfoPlayerError.invalidData,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('reads 26.1 singleplayer UUID and resolves its player snapshot',
        () async {
      const String uuid = '00112233-4455-6677-8899-aabbccddeeff';
      final Directory worldDirectory = await _writeWorld(
        gameDirectory,
        directoryName: 'Singleplayer World',
        data: <String, MtnMinecraftNbtValue>{
          'singleplayer_uuid': MtnMinecraftNbtValue.intArray(
            <int>[1122867, 1146447479, -2003195205, -857870593],
          ),
        },
      );
      await _writeWorldPlayer(
        worldDirectory,
        uuid: uuid,
        dataVersion: 6000,
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.singleplayerUuid, uuid);
      expect(world.singleplayerPlayer, same(world.players.single));
      expect(world.singleplayerPlayer?.uuid, uuid);
      expect(world.singleplayerPlayer?.dataVersion, 6000);
    });

    test('keeps singleplayer UUID when its player snapshot is unavailable',
        () async {
      const String uuid = '00112233-4455-6677-8899-aabbccddeeff';
      await _writeWorld(
        gameDirectory,
        directoryName: 'Missing Singleplayer',
        data: <String, MtnMinecraftNbtValue>{
          'singleplayer_uuid': MtnMinecraftNbtValue.intArray(
            <int>[1122867, 1146447479, -2003195205, -857870593],
          ),
        },
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.singleplayerUuid, uuid);
      expect(world.players, isEmpty);
      expect(world.singleplayerPlayer, isNull);
    });

    test('malformed singleplayer UUID is invalid world data', () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'A-wrong-type',
        data: <String, MtnMinecraftNbtValue>{
          'singleplayer_uuid': MtnMinecraftNbtValue.string(
            '00112233-4455-6677-8899-aabbccddeeff',
          ),
        },
      );
      await _writeWorld(
        gameDirectory,
        directoryName: 'B-wrong-length',
        data: <String, MtnMinecraftNbtValue>{
          'singleplayer_uuid': MtnMinecraftNbtValue.intArray(
            <int>[1, 2, 3],
          ),
        },
      );

      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

      expect(worlds, hasLength(2));
      for (final MtnMinecraftInfoWorld world in worlds) {
        expect(world.state, MtnMinecraftInfoWorldState.invalid);
        expect(world.error, MtnMinecraftInfoWorldError.invalidData);
        expect(world.singleplayerUuid, isNull);
        expect(world.singleplayerPlayer, isNull);
      }
    });

    test('invalid player storage does not fail world discovery', () async {
      final Directory brokenWorld = await _writeWorld(
        gameDirectory,
        directoryName: 'A-broken-players',
        data: <String, MtnMinecraftNbtValue>{
          'LevelName': MtnMinecraftNbtValue.string('Broken Players'),
        },
      );
      final Directory playersDirectory = Directory(
        p.join(brokenWorld.path, 'players'),
      );
      await playersDirectory.create();
      await File(p.join(playersDirectory.path, 'data')).writeAsString('x');

      await _writeWorld(
        gameDirectory,
        directoryName: 'B-valid',
        data: <String, MtnMinecraftNbtValue>{
          'LevelName': MtnMinecraftNbtValue.string('Valid'),
        },
      );

      final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

      expect(worlds, hasLength(2));
      expect(worlds.first.directoryName, 'A-broken-players');
      expect(worlds.first.state, MtnMinecraftInfoWorldState.available);
      expect(worlds.first.error, isNull);
      expect(
        worlds.first.playersState,
        MtnMinecraftInfoWorldPlayersState.invalid,
      );
      expect(
        worlds.first.playersError,
        MtnMinecraftInfoWorldPlayersError.invalidPath,
      );
      expect(worlds.first.players, isEmpty);

      expect(worlds.last.directoryName, 'B-valid');
      expect(worlds.last.state, MtnMinecraftInfoWorldState.available);
      expect(
        worlds.last.playersState,
        MtnMinecraftInfoWorldPlayersState.available,
      );
      expect(worlds.last.playersError, isNull);
    });

    test('world snapshot exposes defensive raw icon bytes', () async {
      final Directory worldDirectory = await _writeWorld(
        gameDirectory,
        directoryName: 'Icon World',
        data: <String, MtnMinecraftNbtValue>{},
      );
      final File iconFile = File(
        p.join(worldDirectory.path, MtnMinecraftInfoWorld.iconFileName),
      );
      await iconFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;
      final Uint8List icon = world.icon!;

      expect(icon, <int>[1, 2, 3, 4]);
      icon[0] = 99;
      expect(world.icon, <int>[1, 2, 3, 4]);
    });

    test('missing world icon is represented as null', () async {
      await _writeWorld(
        gameDirectory,
        directoryName: 'No Icon',
        data: <String, MtnMinecraftNbtValue>{},
      );

      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      expect(world.icon, isNull);
    });

    test('writeWorldIcon atomically replaces icon bytes', () async {
      final Directory worldDirectory = await _writeWorld(
        gameDirectory,
        directoryName: 'Writable Icon',
        data: <String, MtnMinecraftNbtValue>{},
      );
      final File iconFile = File(
        p.join(worldDirectory.path, MtnMinecraftInfoWorld.iconFileName),
      );
      await iconFile.writeAsBytes(<int>[1, 2, 3], flush: true);
      final MtnMinecraftInfoWorld world = (await provider.readWorlds()).single;

      await provider.writeWorldIcon(
        world,
        Uint8List.fromList(<int>[9, 8, 7, 6]),
      );

      expect(await iconFile.readAsBytes(), <int>[9, 8, 7, 6]);
      final List<FileSystemEntity> siblings =
          await worldDirectory.list(followLinks: false).toList();
      expect(
        siblings.where(
          (FileSystemEntity entry) =>
              p.basename(entry.path).startsWith('icon.png.tmp-') ||
              p.basename(entry.path).startsWith('icon.png.old-'),
        ),
        isEmpty,
      );
      expect((await provider.readWorlds()).single.icon, <int>[9, 8, 7, 6]);
    });

    test('writeWorldIcon rejects a world outside provider saves', () async {
      final Directory foreign = await Directory.systemTemp.createTemp(
        'mtn-minecraft-world-icon-foreign-',
      );
      addTearDown(() async {
        if (await foreign.exists()) await foreign.delete(recursive: true);
      });
      final MtnMinecraftInfoWorld world = MtnMinecraftInfoWorld.available(
        directory: foreign,
        directoryName: p.basename(foreign.path),
      );

      expect(
        provider.writeWorldIcon(
          world,
          Uint8List.fromList(<int>[1, 2, 3]),
        ),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('non-directory saves path fails at provider level', () async {
      await File(p.join(gameDirectory.path, 'saves')).writeAsString('x');

      expect(
        provider.readWorlds,
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });

    test('non-file level.dat entries are not followed as worlds', () async {
      final Directory fakeWorld = Directory(
        p.join(gameDirectory.path, 'saves', 'Fake World'),
      );
      await Directory(p.join(fakeWorld.path, 'level.dat')).create(
        recursive: true,
      );

      expect(await provider.readWorlds(), isEmpty);
    });
  });
}

Future<Directory> _writeWorld(
  Directory gameDirectory, {
  required String directoryName,
  required Map<String, MtnMinecraftNbtValue> data,
}) =>
    _writeDocument(
      gameDirectory,
      directoryName: directoryName,
      document: MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'Data': MtnMinecraftNbtValue.compound(data),
          },
        ),
      ),
    );

Future<Directory> _writeDocument(
  Directory gameDirectory, {
  required String directoryName,
  required MtnMinecraftNbtDocument document,
}) async {
  final Directory directory = Directory(
    p.join(gameDirectory.path, 'saves', directoryName),
  );
  await directory.create(recursive: true);
  final List<int> encoded = const MtnMinecraftNbtCodec().encode(document);
  await File(p.join(directory.path, 'level.dat')).writeAsBytes(
    gzip.encode(encoded),
    flush: true,
  );
  return directory;
}


Future<File> _writeWorldPlayer(
  Directory worldDirectory, {
  required String uuid,
  required int dataVersion,
}) async {
  final File file = File(
    p.join(worldDirectory.path, 'players', 'data', '$uuid.dat'),
  );
  await file.parent.create(recursive: true);
  final Uint8List encoded = const MtnMinecraftNbtCodec().encode(
    MtnMinecraftNbtDocument(
      name: '',
      root: MtnMinecraftNbtValue.compound(
        <String, MtnMinecraftNbtValue>{
          'DataVersion': MtnMinecraftNbtValue.intValue(dataVersion),
        },
      ),
    ),
  );
  await file.writeAsBytes(gzip.encode(encoded), flush: true);
  return file;
}
