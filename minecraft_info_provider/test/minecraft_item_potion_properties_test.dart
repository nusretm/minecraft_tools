import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider potion item properties', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-potions-',
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

    test('reads pre-1.20.2 legacy potion metadata', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Potion': MtnMinecraftNbtValue.string('minecraft:strong_healing'),
            'CustomPotionColor': MtnMinecraftNbtValue.intValue(0x336699),
            'CustomPotionEffects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'Id': MtnMinecraftNbtValue.byte(1),
                  'Amplifier': MtnMinecraftNbtValue.byte(2),
                  'Duration': MtnMinecraftNbtValue.intValue(600),
                  'Ambient': MtnMinecraftNbtValue.byte(0),
                  'ShowParticles': MtnMinecraftNbtValue.byte(1),
                  'ShowIcon': MtnMinecraftNbtValue.byte(0),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoPotionContents contents =
          (await _readItem(provider, world)).components!.potionContents!;

      expect(contents.potion, 'minecraft:strong_healing');
      expect(contents.customColor, 0x336699);
      expect(contents.customName, isNull);
      expect(contents.customEffects, hasLength(1));
      expect(contents.customEffects.single.id.legacyNumeric, 1);
      expect(contents.customEffects.single.amplifier, 2);
      expect(contents.customEffects.single.duration, 600);
      expect(contents.customEffects.single.showIcon, isFalse);
    });

    test('reads 1.20.2 through 1.20.4 custom potion effects', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Potion': MtnMinecraftNbtValue.string('examplemod:base'),
            'custom_potion_effects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'id': MtnMinecraftNbtValue.string(
                    'examplemod:radiation',
                  ),
                  'amplifier': MtnMinecraftNbtValue.byte(3),
                  'duration': MtnMinecraftNbtValue.intValue(1200),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoPotionContents contents =
          (await _readItem(provider, world)).components!.potionContents!;

      expect(contents.potion, 'examplemod:base');
      expect(
        contents.customEffects.single.id.resourceLocation,
        'examplemod:radiation',
      );
      expect(contents.customEffects.single.amplifier, 3);
      expect(contents.customEffects.single.duration, 1200);
    });

    test('reads modern potion contents compound and integer amplifier',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'potion':
                    MtnMinecraftNbtValue.string('minecraft:long_swiftness'),
                'custom_color': MtnMinecraftNbtValue.intValue(0x112233),
                'custom_name': MtnMinecraftNbtValue.string('rapid'),
                'custom_effects': _effectList(
                  <Map<String, MtnMinecraftNbtValue>>[
                    <String, MtnMinecraftNbtValue>{
                      'id': MtnMinecraftNbtValue.string(
                        'minecraft:regeneration',
                      ),
                      'amplifier': MtnMinecraftNbtValue.intValue(4),
                      'duration': MtnMinecraftNbtValue.intValue(200),
                    },
                  ],
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoPotionContents contents =
          (await _readItem(provider, world)).components!.potionContents!;

      expect(contents.potion, 'minecraft:long_swiftness');
      expect(contents.customColor, 0x112233);
      expect(contents.customName, 'rapid');
      expect(contents.customEffects.single.amplifier, 4);
      expect(
        contents.customEffects.single.id.resourceLocation,
        'minecraft:regeneration',
      );
    });

    test('reads modern potion contents string shorthand', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_contents':
                MtnMinecraftNbtValue.string('examplemod:instant_focus'),
          },
        ),
      );

      final MtnMinecraftInfoPotionContents contents =
          (await _readItem(provider, world)).components!.potionContents!;

      expect(contents.potion, 'examplemod:instant_focus');
      expect(contents.customColor, isNull);
      expect(contents.customName, isNull);
      expect(contents.customEffects, isEmpty);
    });

    test('explicit empty potion contents stays distinct from absent metadata',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{},
            ),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.potionContents, isNotNull);
      expect(item.components!.potionContents!.potion, isNull);
      expect(item.components!.potionContents!.customEffects, isEmpty);

      await _writeInventoryItem(worldDirectory, _legacyItem());
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('custom effect list is immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'custom_effects': _effectList(
                  <Map<String, MtnMinecraftNbtValue>>[
                    <String, MtnMinecraftNbtValue>{
                      'id': MtnMinecraftNbtValue.string('minecraft:speed'),
                    },
                  ],
                ),
              },
            ),
          },
        ),
      );

      final List<MtnMinecraftInfoMobEffect> effects =
          (await _readItem(provider, world))
              .components!
              .potionContents!
              .customEffects;

      expect(
        () => effects.add(
          MtnMinecraftInfoMobEffect(
            id: MtnMinecraftInfoMobEffectId.resourceLocation(
              'minecraft:strength',
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

    test('modern components remain authoritative over legacy potion tag',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:damage': MtnMinecraftNbtValue.intValue(1),
            },
          ),
          'tag': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'Potion': MtnMinecraftNbtValue.string('minecraft:healing'),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.damage, 1);
      expect(components.potionContents, isNull);
    });

    test('snake case custom effects are authoritative over legacy effects',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'custom_potion_effects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'id': MtnMinecraftNbtValue.string('minecraft:strength'),
                },
              ],
            ),
            'CustomPotionEffects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'Id': MtnMinecraftNbtValue.byte(1),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoPotionContents contents =
          (await _readItem(provider, world)).components!.potionContents!;
      expect(
        contents.customEffects.single.id.resourceLocation,
        'minecraft:strength',
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'custom_potion_effects': MtnMinecraftNbtValue.string('bad'),
            'CustomPotionEffects': _effectList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'Id': MtnMinecraftNbtValue.byte(1),
                },
              ],
            ),
          },
        ),
      );
    });

    test('potion component removals are preserved and conflicts are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:potion_contents':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
            '!minecraft:potion_duration_scale':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.potionContents, isNull);
      expect(components.potionDurationScale, isNull);
      expect(
        components.removedComponentIds,
        containsAll(
          <String>[
            'minecraft:potion_contents',
            'minecraft:potion_duration_scale',
          ],
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{},
            ),
            '!minecraft:potion_contents':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );
    });

    test('reads non-negative potion duration scale', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_duration_scale':
                MtnMinecraftNbtValue.float(0.25),
          },
        ),
      );

      expect(
        (await _readItem(provider, world)).components!.potionDurationScale,
        closeTo(0.25, 0.000001),
      );

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:potion_duration_scale':
                MtnMinecraftNbtValue.float(0),
          },
        ),
      );
      expect(
        (await _readItem(provider, world)).components!.potionDurationScale,
        0,
      );
    });

    test('malformed recognized potion properties invalidate player', () async {
      final List<Map<String, MtnMinecraftNbtValue>> invalidComponents =
          <Map<String, MtnMinecraftNbtValue>>[
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_contents': MtnMinecraftNbtValue.intValue(1),
        },
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_contents': MtnMinecraftNbtValue.string(''),
        },
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'potion': MtnMinecraftNbtValue.intValue(1),
            },
          ),
        },
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_contents': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'custom_effects': _effectList(
                <Map<String, MtnMinecraftNbtValue>>[
                  <String, MtnMinecraftNbtValue>{
                    'id': MtnMinecraftNbtValue.string('minecraft:speed'),
                    'amplifier': MtnMinecraftNbtValue.intValue(128),
                  },
                ],
              ),
            },
          ),
        },
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_duration_scale':
              MtnMinecraftNbtValue.float(-0.1),
        },
        <String, MtnMinecraftNbtValue>{
          'minecraft:potion_duration_scale':
              MtnMinecraftNbtValue.intValue(1),
        },
      ];

      for (final Map<String, MtnMinecraftNbtValue> components
          in invalidComponents) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(components: components),
        );
      }
    });

    test('legacy malformed recognized potion properties invalidate player',
        () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Potion': MtnMinecraftNbtValue.intValue(1),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'CustomPotionColor': MtnMinecraftNbtValue.string('red'),
          },
        ),
      );
    });
  });
}

Future<MtnMinecraftInfoItemStack> _readItem(
  MtnMinecraftInfoProvider provider,
  MtnMinecraftInfoWorld world,
) async {
  final MtnMinecraftInfoPlayer player =
      (await provider.readPlayers(world)).single;
  expect(player.state, MtnMinecraftInfoPlayerState.available);
  return player.inventory![0]!;
}

Future<void> _expectInvalid(
  MtnMinecraftInfoProvider provider,
  MtnMinecraftInfoWorld world,
  Directory worldDirectory,
  Map<String, MtnMinecraftNbtValue> item,
) async {
  await _writeInventoryItem(worldDirectory, item);
  final MtnMinecraftInfoPlayer player =
      (await provider.readPlayers(world)).single;
  expect(player.state, MtnMinecraftInfoPlayerState.invalid);
  expect(player.error, MtnMinecraftInfoPlayerError.invalidData);
}

Map<String, MtnMinecraftNbtValue> _legacyItem({
  Map<String, MtnMinecraftNbtValue>? tag,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string('minecraft:potion'),
      'Count': MtnMinecraftNbtValue.byte(1),
      if (tag != null) 'tag': MtnMinecraftNbtValue.compound(tag),
    };

Map<String, MtnMinecraftNbtValue> _modernItem({
  Map<String, MtnMinecraftNbtValue>? components,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string('minecraft:potion'),
      'count': MtnMinecraftNbtValue.intValue(1),
      if (components != null)
        'components': MtnMinecraftNbtValue.compound(components),
    };

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

Future<void> _writeInventoryItem(
  Directory worldDirectory,
  Map<String, MtnMinecraftNbtValue> item,
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
      root: MtnMinecraftNbtValue.compound(
        <String, MtnMinecraftNbtValue>{
          'Inventory': MtnMinecraftNbtValue.list(
            MtnMinecraftNbtList(
              elementType: MtnMinecraftNbtType.compound,
              values: <MtnMinecraftNbtValue>[
                MtnMinecraftNbtValue.compound(item),
              ],
            ),
          ),
        },
      ),
    ),
  );
  await file.writeAsBytes(gzip.encode(bytes), flush: true);
}
