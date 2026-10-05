import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider item custom model data', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-custom-model-data-',
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

    test('reads legacy CustomModelData integer', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'CustomModelData': MtnMinecraftNbtValue.intValue(42),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;

      expect(data.legacyValue, 42);
      expect(data.floats, isEmpty);
      expect(data.flags, isEmpty);
      expect(data.strings, isEmpty);
      expect(data.colors, isEmpty);
    });

    test('reads 1.20.5 through 1.21.3 numeric component including zero',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.intValue(0),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;

      expect(data.legacyValue, 0);
      expect(data.floats, isEmpty);
    });

    test('reads current floats flags strings and packed colors', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'floats': _list(
                  MtnMinecraftNbtType.float,
                  <MtnMinecraftNbtValue>[
                    MtnMinecraftNbtValue.float(1),
                    MtnMinecraftNbtValue.float(2.5),
                  ],
                ),
                'flags': _list(
                  MtnMinecraftNbtType.byte,
                  <MtnMinecraftNbtValue>[
                    MtnMinecraftNbtValue.byte(1),
                    MtnMinecraftNbtValue.byte(0),
                  ],
                ),
                'strings': _list(
                  MtnMinecraftNbtType.string,
                  <MtnMinecraftNbtValue>[
                    MtnMinecraftNbtValue.string('examplemod:blade'),
                    MtnMinecraftNbtValue.string(''),
                  ],
                ),
                'colors': _list(
                  MtnMinecraftNbtType.intValue,
                  <MtnMinecraftNbtValue>[
                    MtnMinecraftNbtValue.intValue(0x112233),
                    MtnMinecraftNbtValue.intValue(-1),
                  ],
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;

      expect(data.legacyValue, isNull);
      expect(data.floats, <double>[1, 2.5]);
      expect(data.flags, <bool>[true, false]);
      expect(data.strings, <String>['examplemod:blade', '']);
      expect(data.colors, <int>[0x112233, -1]);
    });

    test('current empty compound stays distinct from absent component',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{},
            ),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.customModelData, isNotNull);
      expect(item.components!.customModelData!.legacyValue, isNull);
      expect(item.components!.customModelData!.floats, isEmpty);
      expect(item.components!.customModelData!.flags, isEmpty);
      expect(item.components!.customModelData!.strings, isEmpty);
      expect(item.components!.customModelData!.colors, isEmpty);

      await _writeInventoryItem(worldDirectory, _legacyItem());
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('explicit empty current lists are accepted', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'floats': _emptyList(),
                'flags': _emptyList(),
                'strings': _emptyList(),
                'colors': _emptyList(),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;
      expect(data.floats, isEmpty);
      expect(data.flags, isEmpty);
      expect(data.strings, isEmpty);
      expect(data.colors, isEmpty);
    });

    test('custom model data lists are immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'floats': _list(
                  MtnMinecraftNbtType.float,
                  <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.float(1)],
                ),
                'flags': _list(
                  MtnMinecraftNbtType.byte,
                  <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.byte(1)],
                ),
                'strings': _list(
                  MtnMinecraftNbtType.string,
                  <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.string('x')],
                ),
                'colors': _list(
                  MtnMinecraftNbtType.intValue,
                  <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.intValue(1)],
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;

      expect(() => data.floats.add(2), throwsUnsupportedError);
      expect(() => data.flags.add(false), throwsUnsupportedError);
      expect(() => data.strings.add('y'), throwsUnsupportedError);
      expect(() => data.colors.add(2), throwsUnsupportedError);
    });

    test('modern components remain authoritative over legacy custom model data',
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
              'CustomModelData': MtnMinecraftNbtValue.intValue(77),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.damage, 1);
      expect(components.customModelData, isNull);
    });

    test('custom model data removal is preserved and conflicts are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:custom_model_data':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.customModelData, isNull);
      expect(
        components.removedComponentIds,
        contains('minecraft:custom_model_data'),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.intValue(1),
            '!minecraft:custom_model_data':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );
    });

    test('unknown current custom model metadata remains tolerated', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_model_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'strings': _list(
                  MtnMinecraftNbtType.string,
                  <MtnMinecraftNbtValue>[
                    MtnMinecraftNbtValue.string('future'),
                  ],
                ),
                'examplemod:future_field':
                    MtnMinecraftNbtValue.long(123),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemCustomModelData data =
          (await _readItem(provider, world)).components!.customModelData!;
      expect(data.strings, <String>['future']);
    });

    test('malformed legacy custom model data invalidates player', () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'CustomModelData': MtnMinecraftNbtValue.string('42'),
          },
        ),
      );
    });

    test('malformed modern custom model data invalidates player', () async {
      final List<MtnMinecraftNbtValue> invalidValues =
          <MtnMinecraftNbtValue>[
        MtnMinecraftNbtValue.float(1),
        MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'floats': _list(
              MtnMinecraftNbtType.doubleValue,
              <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.doubleValue(1)],
            ),
          },
        ),
        MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'flags': _list(
              MtnMinecraftNbtType.byte,
              <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.byte(2)],
            ),
          },
        ),
        MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'strings': _list(
              MtnMinecraftNbtType.intValue,
              <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.intValue(1)],
            ),
          },
        ),
        MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'colors': _list(
              MtnMinecraftNbtType.long,
              <MtnMinecraftNbtValue>[MtnMinecraftNbtValue.long(1)],
            ),
          },
        ),
      ];

      for (final MtnMinecraftNbtValue invalid in invalidValues) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:custom_model_data': invalid,
            },
          ),
        );
      }
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
      'id': MtnMinecraftNbtValue.string('minecraft:stick'),
      'Count': MtnMinecraftNbtValue.byte(1),
      if (tag != null) 'tag': MtnMinecraftNbtValue.compound(tag),
    };

Map<String, MtnMinecraftNbtValue> _modernItem({
  Map<String, MtnMinecraftNbtValue>? components,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string('minecraft:stick'),
      'count': MtnMinecraftNbtValue.intValue(1),
      if (components != null)
        'components': MtnMinecraftNbtValue.compound(components),
    };

MtnMinecraftNbtValue _list(
  MtnMinecraftNbtType elementType,
  List<MtnMinecraftNbtValue> values,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: elementType,
        values: values,
      ),
    );

MtnMinecraftNbtValue _emptyList() => MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.end,
        values: const <MtnMinecraftNbtValue>[],
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
