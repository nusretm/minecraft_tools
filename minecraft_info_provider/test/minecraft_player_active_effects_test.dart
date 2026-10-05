import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider player active effects', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-effects-',
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

    test('missing effect list remains null', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{},
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.activeEffects, isNull);
    });

    test('reads modern effects and recursive hidden effect', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'id': MtnMinecraftNbtValue.string('minecraft:speed'),
                'amplifier': MtnMinecraftNbtValue.byte(1),
                'duration': MtnMinecraftNbtValue.intValue(2400),
                'ambient': MtnMinecraftNbtValue.byte(1),
                'show_particles': MtnMinecraftNbtValue.byte(0),
                'show_icon': MtnMinecraftNbtValue.byte(1),
                'hidden_effect': MtnMinecraftNbtValue.compound(
                  <String, MtnMinecraftNbtValue>{
                    'id': MtnMinecraftNbtValue.string('minecraft:speed'),
                    'duration': MtnMinecraftNbtValue.intValue(600),
                  },
                ),
              },
              <String, MtnMinecraftNbtValue>{
                'id': MtnMinecraftNbtValue.string('examplemod:radiation'),
                'duration': MtnMinecraftNbtValue.intValue(-1),
              },
            ],
          ),
        },
      );

      final List<MtnMinecraftInfoMobEffect> effects =
          (await provider.readPlayers(world)).single.activeEffects!;

      expect(effects, hasLength(2));

      final MtnMinecraftInfoMobEffect speed = effects[0];
      expect(speed.id.resourceLocation, 'minecraft:speed');
      expect(speed.id.legacyNumeric, isNull);
      expect(speed.id.isResourceLocation, isTrue);
      expect(speed.id.toString(), 'minecraft:speed');
      expect(speed.amplifier, 1);
      expect(speed.duration, 2400);
      expect(speed.ambient, isTrue);
      expect(speed.showParticles, isFalse);
      expect(speed.showIcon, isTrue);

      final MtnMinecraftInfoMobEffect hidden = speed.hiddenEffect!;
      expect(hidden.id.resourceLocation, 'minecraft:speed');
      expect(hidden.amplifier, 0);
      expect(hidden.duration, 600);
      expect(hidden.ambient, isFalse);
      expect(hidden.showParticles, isTrue);
      expect(hidden.showIcon, isTrue);
      expect(hidden.hiddenEffect, isNull);

      final MtnMinecraftInfoMobEffect modded = effects[1];
      expect(modded.id.resourceLocation, 'examplemod:radiation');
      expect(modded.duration, -1);
    });

    test('modern omitted values normalize to Minecraft defaults', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'id': MtnMinecraftNbtValue.string('minecraft:regeneration'),
              },
            ],
          ),
        },
      );

      final MtnMinecraftInfoMobEffect effect =
          (await provider.readPlayers(world)).single.activeEffects!.single;

      expect(effect.amplifier, 0);
      expect(effect.duration, 0);
      expect(effect.ambient, isFalse);
      expect(effect.showParticles, isTrue);
      expect(effect.showIcon, isTrue);
    });

    test('explicit empty effect list remains immutable and distinct from null',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': MtnMinecraftNbtValue.list(
            MtnMinecraftNbtList(
              elementType: MtnMinecraftNbtType.end,
              values: const <MtnMinecraftNbtValue>[],
            ),
          ),
        },
      );

      final List<MtnMinecraftInfoMobEffect> effects =
          (await provider.readPlayers(world)).single.activeEffects!;

      expect(effects, isEmpty);
      expect(
        () => effects.add(
          MtnMinecraftInfoMobEffect(
            id: MtnMinecraftInfoMobEffectId.resourceLocation(
              'minecraft:speed',
            ),
            amplifier: 0,
            duration: 0,
            ambient: false,
            showParticles: true,
            showIcon: true,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('reads legacy integer and byte effect IDs without registry guessing',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'ActiveEffects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'Id': MtnMinecraftNbtValue.intValue(19),
                'Amplifier': MtnMinecraftNbtValue.byte(2),
                'Duration': MtnMinecraftNbtValue.intValue(120),
                'Ambient': MtnMinecraftNbtValue.byte(0),
                'ShowParticles': MtnMinecraftNbtValue.byte(1),
                'ShowIcon': MtnMinecraftNbtValue.byte(0),
              },
              <String, MtnMinecraftNbtValue>{
                'Id': MtnMinecraftNbtValue.byte(1),
                'Duration': MtnMinecraftNbtValue.intValue(40),
              },
            ],
          ),
        },
      );

      final List<MtnMinecraftInfoMobEffect> effects =
          (await provider.readPlayers(world)).single.activeEffects!;

      expect(effects, hasLength(2));
      expect(effects[0].id.legacyNumeric, 19);
      expect(effects[0].id.resourceLocation, isNull);
      expect(effects[0].id.isLegacyNumeric, isTrue);
      expect(effects[0].id.toString(), '19');
      expect(effects[0].amplifier, 2);
      expect(effects[0].duration, 120);
      expect(effects[0].ambient, isFalse);
      expect(effects[0].showParticles, isTrue);
      expect(effects[0].showIcon, isFalse);

      expect(effects[1].id.legacyNumeric, 1);
      expect(effects[1].amplifier, 0);
      expect(effects[1].duration, 40);
      expect(effects[1].ambient, isFalse);
      expect(effects[1].showParticles, isTrue);
      expect(effects[1].showIcon, isTrue);
    });

    test('modern effect list is authoritative over legacy list', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': MtnMinecraftNbtValue.list(
            MtnMinecraftNbtList(
              elementType: MtnMinecraftNbtType.end,
              values: const <MtnMinecraftNbtValue>[],
            ),
          ),
          'ActiveEffects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'Id': MtnMinecraftNbtValue.intValue(1),
              },
            ],
          ),
        },
      );

      final List<MtnMinecraftInfoMobEffect> effects =
          (await provider.readPlayers(world)).single.activeEffects!;

      expect(effects, isEmpty);
    });

    test('malformed modern list does not fall back to valid legacy data',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': MtnMinecraftNbtValue.string('invalid'),
          'ActiveEffects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'Id': MtnMinecraftNbtValue.intValue(1),
              },
            ],
          ),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.invalid);
      expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
    });

    test('malformed recognized effect fields are invalid data', () async {
      final List<Map<String, MtnMinecraftNbtValue>> invalidEffects =
          <Map<String, MtnMinecraftNbtValue>>[
        <String, MtnMinecraftNbtValue>{
          'id': MtnMinecraftNbtValue.string(''),
        },
        <String, MtnMinecraftNbtValue>{
          'id': MtnMinecraftNbtValue.string('minecraft:speed'),
          'amplifier': MtnMinecraftNbtValue.intValue(1),
        },
        <String, MtnMinecraftNbtValue>{
          'id': MtnMinecraftNbtValue.string('minecraft:speed'),
          'show_particles': MtnMinecraftNbtValue.byte(2),
        },
        <String, MtnMinecraftNbtValue>{
          'id': MtnMinecraftNbtValue.string('minecraft:speed'),
          'hidden_effect': MtnMinecraftNbtValue.string('invalid'),
        },
      ];

      for (final Map<String, MtnMinecraftNbtValue> effect in invalidEffects) {
        await _writePlayer(
          worldDirectory,
          <String, MtnMinecraftNbtValue>{
            'active_effects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[effect],
            ),
          },
        );

        final MtnMinecraftInfoPlayer player =
            (await provider.readPlayers(world)).single;

        expect(player.state, MtnMinecraftInfoPlayerState.invalid);
        expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
      }
    });

    test('unknown effect metadata remains tolerated', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'active_effects': _effectList(
            <Map<String, MtnMinecraftNbtValue>>[
              <String, MtnMinecraftNbtValue>{
                'id': MtnMinecraftNbtValue.string('examplemod:future'),
                'factor_calculation_data': MtnMinecraftNbtValue.compound(
                  <String, MtnMinecraftNbtValue>{
                    'padding_duration':
                        MtnMinecraftNbtValue.intValue(10),
                  },
                ),
                'examplemod:custom':
                    MtnMinecraftNbtValue.string('preserved externally'),
              },
            ],
          ),
        },
      );

      final MtnMinecraftInfoMobEffect effect =
          (await provider.readPlayers(world)).single.activeEffects!.single;

      expect(effect.id.resourceLocation, 'examplemod:future');
      expect(effect.amplifier, 0);
      expect(effect.duration, 0);
    });
  });
}

MtnMinecraftNbtValue _effectList(
  List<Map<String, MtnMinecraftNbtValue>> effects,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.compound,
        values: effects
            .map(MtnMinecraftNbtValue.compound)
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
