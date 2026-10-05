import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider player gameplay core', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-gameplay-',
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

    test('reads gameplay core and legacy respawn fields', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Rotation': _floatList(<double>[90.5, -12.25]),
          'Health': MtnMinecraftNbtValue.float(17.5),
          'AbsorptionAmount': MtnMinecraftNbtValue.float(4.0),
          'foodLevel': MtnMinecraftNbtValue.intValue(18),
          'foodSaturationLevel': MtnMinecraftNbtValue.float(6.5),
          'foodExhaustionLevel': MtnMinecraftNbtValue.float(2.25),
          'foodTickTimer': MtnMinecraftNbtValue.intValue(7),
          'XpLevel': MtnMinecraftNbtValue.intValue(12),
          'XpP': MtnMinecraftNbtValue.float(0.75),
          'XpTotal': MtnMinecraftNbtValue.intValue(345),
          'XpSeed': MtnMinecraftNbtValue.intValue(987654),
          'playerGameType': MtnMinecraftNbtValue.intValue(1),
          'previousPlayerGameType': MtnMinecraftNbtValue.intValue(0),
          'SelectedItemSlot': MtnMinecraftNbtValue.intValue(5),
          'abilities': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'flying': MtnMinecraftNbtValue.byte(1),
              'mayfly': MtnMinecraftNbtValue.byte(1),
              'instabuild': MtnMinecraftNbtValue.byte(1),
              'invulnerable': MtnMinecraftNbtValue.byte(0),
              'mayBuild': MtnMinecraftNbtValue.byte(1),
              'flySpeed': MtnMinecraftNbtValue.float(0.05),
              'walkSpeed': MtnMinecraftNbtValue.float(0.1),
            },
          ),
          'SpawnX': MtnMinecraftNbtValue.intValue(10),
          'SpawnY': MtnMinecraftNbtValue.intValue(64),
          'SpawnZ': MtnMinecraftNbtValue.intValue(-20),
          'SpawnAngle': MtnMinecraftNbtValue.float(45.0),
          'SpawnDimension':
              MtnMinecraftNbtValue.string('minecraft:overworld'),
          'SpawnForced': MtnMinecraftNbtValue.byte(1),
          'LastDeathLocation': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'dimension': MtnMinecraftNbtValue.string('minecraft:the_nether'),
              'pos': MtnMinecraftNbtValue.intArray(<int>[4, 70, -9]),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.rotation?.yaw, 90.5);
      expect(player.rotation?.pitch, -12.25);
      expect(player.health, 17.5);
      expect(player.absorptionAmount, 4.0);
      expect(player.food?.level, 18);
      expect(player.food?.saturation, 6.5);
      expect(player.food?.exhaustion, 2.25);
      expect(player.food?.tickTimer, 7);
      expect(player.experience?.level, 12);
      expect(player.experience?.progress, 0.75);
      expect(player.experience?.total, 345);
      expect(player.experience?.seed, 987654);
      expect(player.gameMode, MtnMinecraftInfoPlayerGameMode.creative);
      expect(
        player.previousGameMode,
        MtnMinecraftInfoPlayerGameMode.survival,
      );
      expect(player.selectedItemSlot, 5);
      expect(player.abilities?.flying, isTrue);
      expect(player.abilities?.mayFly, isTrue);
      expect(player.abilities?.instantBuild, isTrue);
      expect(player.abilities?.invulnerable, isFalse);
      expect(player.abilities?.mayBuild, isTrue);
      expect(player.abilities?.flySpeed, closeTo(0.05, 0.000001));
      expect(player.abilities?.walkSpeed, closeTo(0.1, 0.000001));
      expect(player.respawn?.position.x, 10);
      expect(player.respawn?.position.y, 64);
      expect(player.respawn?.position.z, -20);
      expect(player.respawn?.dimension, 'minecraft:overworld');
      expect(player.respawn?.yaw, 45.0);
      expect(player.respawn?.pitch, isNull);
      expect(player.respawn?.forced, isTrue);
      expect(player.lastDeath?.dimension, 'minecraft:the_nether');
      expect(player.lastDeath?.position.x, 4);
      expect(player.lastDeath?.position.y, 70);
      expect(player.lastDeath?.position.z, -9);
    });

    test('reads 1.21.5 respawn angle compound', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'respawn': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'pos': MtnMinecraftNbtValue.intArray(<int>[1, 65, 2]),
              'angle': MtnMinecraftNbtValue.float(33.0),
              'dimension':
                  MtnMinecraftNbtValue.string('minecraft:the_end'),
              'forced': MtnMinecraftNbtValue.byte(0),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayerRespawn respawn =
          (await provider.readPlayers(world)).single.respawn!;

      expect(respawn.position.x, 1);
      expect(respawn.position.y, 65);
      expect(respawn.position.z, 2);
      expect(respawn.yaw, 33.0);
      expect(respawn.pitch, isNull);
      expect(respawn.dimension, 'minecraft:the_end');
      expect(respawn.forced, isFalse);
    });

    test('reads 1.21.9+ respawn yaw and pitch compound', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'respawn': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'pos': MtnMinecraftNbtValue.intArray(<int>[7, 80, -3]),
              'yaw': MtnMinecraftNbtValue.float(120.0),
              'pitch': MtnMinecraftNbtValue.float(-15.0),
              'dimension':
                  MtnMinecraftNbtValue.string('minecraft:overworld'),
              'forced': MtnMinecraftNbtValue.byte(1),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayerRespawn respawn =
          (await provider.readPlayers(world)).single.respawn!;

      expect(respawn.position.x, 7);
      expect(respawn.position.y, 80);
      expect(respawn.position.z, -3);
      expect(respawn.yaw, 120.0);
      expect(respawn.pitch, -15.0);
      expect(respawn.dimension, 'minecraft:overworld');
      expect(respawn.forced, isTrue);
    });

    test('modern respawn compound is authoritative over legacy fields',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'respawn': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'pos': MtnMinecraftNbtValue.intArray(<int>[1, 2, 3]),
              'yaw': MtnMinecraftNbtValue.float(4.0),
            },
          ),
          'SpawnX': MtnMinecraftNbtValue.intValue(10),
          'SpawnY': MtnMinecraftNbtValue.intValue(20),
          'SpawnZ': MtnMinecraftNbtValue.intValue(30),
          'SpawnAngle': MtnMinecraftNbtValue.float(40.0),
        },
      );

      final MtnMinecraftInfoPlayerRespawn respawn =
          (await provider.readPlayers(world)).single.respawn!;

      expect(respawn.position.x, 1);
      expect(respawn.position.y, 2);
      expect(respawn.position.z, 3);
      expect(respawn.yaw, 4.0);
    });

    test('missing gameplay metadata remains null', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{},
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.rotation, isNull);
      expect(player.gameMode, isNull);
      expect(player.previousGameMode, isNull);
      expect(player.health, isNull);
      expect(player.absorptionAmount, isNull);
      expect(player.food, isNull);
      expect(player.experience, isNull);
      expect(player.abilities, isNull);
      expect(player.selectedItemSlot, isNull);
      expect(player.respawn, isNull);
      expect(player.lastDeath, isNull);
    });

    test('previous game mode -1 is normalized to null', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'previousPlayerGameType': MtnMinecraftNbtValue.intValue(-1),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.available);
      expect(player.previousGameMode, isNull);
    });

    test('partial food and experience groups preserve missing values',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'foodLevel': MtnMinecraftNbtValue.intValue(9),
          'XpP': MtnMinecraftNbtValue.float(0.25),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.food?.level, 9);
      expect(player.food?.saturation, isNull);
      expect(player.food?.exhaustion, isNull);
      expect(player.food?.tickTimer, isNull);
      expect(player.experience?.level, isNull);
      expect(player.experience?.progress, 0.25);
      expect(player.experience?.total, isNull);
      expect(player.experience?.seed, isNull);
    });

    test('partial abilities preserve missing values', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'abilities': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'flying': MtnMinecraftNbtValue.byte(0),
              'walkSpeed': MtnMinecraftNbtValue.float(0.2),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayerAbilities abilities =
          (await provider.readPlayers(world)).single.abilities!;

      expect(abilities.flying, isFalse);
      expect(abilities.walkSpeed, closeTo(0.2, 0.000001));
      expect(abilities.mayFly, isNull);
      expect(abilities.instantBuild, isNull);
      expect(abilities.invulnerable, isNull);
      expect(abilities.mayBuild, isNull);
      expect(abilities.flySpeed, isNull);
    });

    test('invalid game mode is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'playerGameType': MtnMinecraftNbtValue.intValue(4),
        },
      );
    });

    test('selected hotbar slot outside 0 through 8 is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'SelectedItemSlot': MtnMinecraftNbtValue.intValue(9),
        },
      );
    });

    test('ability boolean must be byte 0 or 1', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'abilities': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'flying': MtnMinecraftNbtValue.byte(2),
            },
          ),
        },
      );
    });

    test('Rotation must be a two-float list', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Rotation': _floatList(<double>[1.0]),
        },
      );
    });

    test('legacy respawn requires all three coordinates', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'SpawnX': MtnMinecraftNbtValue.intValue(1),
          'SpawnY': MtnMinecraftNbtValue.intValue(2),
        },
      );
    });

    test('malformed modern respawn does not fall back to legacy fields',
        () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'respawn': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'yaw': MtnMinecraftNbtValue.float(1.0),
            },
          ),
          'SpawnX': MtnMinecraftNbtValue.intValue(10),
          'SpawnY': MtnMinecraftNbtValue.intValue(20),
          'SpawnZ': MtnMinecraftNbtValue.intValue(30),
        },
      );
    });

    test('LastDeathLocation requires dimension and three-int position',
        () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'LastDeathLocation': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'dimension':
                  MtnMinecraftNbtValue.string('minecraft:overworld'),
              'pos': MtnMinecraftNbtValue.intArray(<int>[1, 2]),
            },
          ),
        },
      );
    });

    test('wrong scalar gameplay type is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Health': MtnMinecraftNbtValue.intValue(20),
        },
      );
    });
  });
}

Future<void> _expectInvalidData(
  MtnMinecraftInfoProvider provider,
  MtnMinecraftInfoWorld world,
  Directory worldDirectory,
  Map<String, MtnMinecraftNbtValue> data,
) async {
  await _writePlayer(worldDirectory, data);
  final MtnMinecraftInfoPlayer player =
      (await provider.readPlayers(world)).single;
  expect(player.state, MtnMinecraftInfoPlayerState.invalid);
  expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
}

MtnMinecraftNbtValue _floatList(List<double> values) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.float,
        values: values
            .map(MtnMinecraftNbtValue.float)
            .toList(growable: false),
      ),
    );

Future<File> _writePlayer(
  Directory worldDirectory,
  Map<String, MtnMinecraftNbtValue> data,
) async {
  final File file = File(
    p.join(
      worldDirectory.path,
      'playerdata',
      '$_uuid.dat',
    ),
  );
  await file.parent.create(recursive: true);
  final Uint8List bytes = const MtnMinecraftNbtCodec().encode(
    MtnMinecraftNbtDocument(
      name: '',
      root: MtnMinecraftNbtValue.compound(data),
    ),
  );
  await file.writeAsBytes(gzip.encode(bytes), flush: true);
  return file;
}
