import 'dart:io';

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
