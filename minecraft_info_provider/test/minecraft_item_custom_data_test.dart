import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider item custom data', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-custom-data-',
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

    test('reads arbitrary modern custom data with NBT type fidelity',
        () async {
      final Map<String, MtnMinecraftNbtValue> customData =
          <String, MtnMinecraftNbtValue>{
        'byte': MtnMinecraftNbtValue.byte(-7),
        'short': MtnMinecraftNbtValue.short(1234),
        'int': MtnMinecraftNbtValue.intValue(123456),
        'long': MtnMinecraftNbtValue.long(1234567890123),
        'float': MtnMinecraftNbtValue.float(1.25),
        'double': MtnMinecraftNbtValue.doubleValue(2.5),
        'string': MtnMinecraftNbtValue.string('example'),
        'bytes': MtnMinecraftNbtValue.byteArray(<int>[0, 127, 255]),
        'ints': MtnMinecraftNbtValue.intArray(<int>[-1, 2, 3]),
        'longs': MtnMinecraftNbtValue.longArray(<int>[-4, 5, 6]),
        'list': MtnMinecraftNbtValue.list(
          MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.string,
            values: <MtnMinecraftNbtValue>[
              MtnMinecraftNbtValue.string('a'),
              MtnMinecraftNbtValue.string('b'),
            ],
          ),
        ),
        'compound': MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'nested': MtnMinecraftNbtValue.intValue(9),
          },
        ),
      };

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_data':
                MtnMinecraftNbtValue.compound(customData),
          },
        ),
      );

      final Map<String, MtnMinecraftNbtValue> data =
          (await _readItem(provider, world)).components!.customData!;

      expect(data['byte']!.type, MtnMinecraftNbtType.byte);
      expect(data['byte']!.asByte, -7);
      expect(data['short']!.type, MtnMinecraftNbtType.short);
      expect(data['short']!.asShort, 1234);
      expect(data['int']!.type, MtnMinecraftNbtType.intValue);
      expect(data['int']!.asInt, 123456);
      expect(data['long']!.type, MtnMinecraftNbtType.long);
      expect(data['long']!.asLong, 1234567890123);
      expect(data['float']!.type, MtnMinecraftNbtType.float);
      expect(data['float']!.asFloat, 1.25);
      expect(data['double']!.type, MtnMinecraftNbtType.doubleValue);
      expect(data['double']!.asDouble, 2.5);
      expect(data['string']!.asString, 'example');
      expect(data['bytes']!.asByteArray, <int>[0, 127, 255]);
      expect(data['ints']!.asIntArray, <int>[-1, 2, 3]);
      expect(data['longs']!.asLongArray, <int>[-4, 5, 6]);
      expect(
        data['list']!.asList.values.map(
          (MtnMinecraftNbtValue value) => value.asString,
        ),
        <String>['a', 'b'],
      );
      expect(data['compound']!.asCompound['nested']!.asInt, 9);
    });

    test('distinguishes absent and explicit empty modern custom data',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_data': _emptyCompound(),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.customData, isEmpty);

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:damage': MtnMinecraftNbtValue.intValue(1),
          },
        ),
      );
      item = await _readItem(provider, world);
      expect(item.components!.customData, isNull);
    });

    test('preserves raw legacy tag without pretending it is custom data',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Damage': MtnMinecraftNbtValue.intValue(7),
            'examplemod:value': MtnMinecraftNbtValue.intValue(42),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.damage, 7);
      expect(components.customData, isNull);
      expect(components.legacyTag, isNotNull);
      expect(components.legacyTag!['Damage']!.asInt, 7);
      expect(components.legacyTag!['examplemod:value']!.asInt, 42);
    });

    test('distinguishes absent legacy tag from explicit empty tag',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{},
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.legacyTag, isEmpty);
      expect(item.components!.customData, isNull);

      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(),
      );
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('preserves nested legacy tag values alongside semantic parsing',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'RepairCost': MtnMinecraftNbtValue.intValue(3),
            'examplemod:data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'flags': MtnMinecraftNbtValue.list(
                  MtnMinecraftNbtList(
                    elementType: MtnMinecraftNbtType.byte,
                    values: <MtnMinecraftNbtValue>[
                      MtnMinecraftNbtValue.byte(1),
                      MtnMinecraftNbtValue.byte(0),
                    ],
                  ),
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.repairCost, 3);
      final MtnMinecraftNbtList flags = components
          .legacyTag!['examplemod:data']!
          .asCompound['flags']!
          .asList;
      expect(
        flags.values.map((MtnMinecraftNbtValue value) => value.asByte),
        <int>[1, 0],
      );
    });

    test('modern components are authoritative over a legacy tag',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:damage': MtnMinecraftNbtValue.intValue(2),
              'minecraft:custom_data': MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{
                  'examplemod:value': MtnMinecraftNbtValue.intValue(99),
                },
              ),
            },
          ),
          'tag': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'Damage': MtnMinecraftNbtValue.intValue(9),
              'legacy_only': MtnMinecraftNbtValue.string('ignored'),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.damage, 2);
      expect(components.customData!['examplemod:value']!.asInt, 99);
      expect(components.legacyTag, isNull);
    });

    test('custom data and nested NBT collections are immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_data': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'nested': MtnMinecraftNbtValue.compound(
                  <String, MtnMinecraftNbtValue>{
                    'value': MtnMinecraftNbtValue.intValue(1),
                  },
                ),
                'list': MtnMinecraftNbtValue.list(
                  MtnMinecraftNbtList(
                    elementType: MtnMinecraftNbtType.intValue,
                    values: <MtnMinecraftNbtValue>[
                      MtnMinecraftNbtValue.intValue(1),
                    ],
                  ),
                ),
              },
            ),
          },
        ),
      );

      final Map<String, MtnMinecraftNbtValue> data =
          (await _readItem(provider, world)).components!.customData!;
      expect(
        () => data['x'] = MtnMinecraftNbtValue.intValue(2),
        throwsUnsupportedError,
      );
      expect(
        () => data['nested']!.asCompound['x'] =
            MtnMinecraftNbtValue.intValue(2),
        throwsUnsupportedError,
      );
      expect(
        () => data['list']!.asList.values.add(
          MtnMinecraftNbtValue.intValue(2),
        ),
        throwsUnsupportedError,
      );
    });

    test('component constructor snapshots custom and legacy maps', () {
      final Map<String, MtnMinecraftNbtValue> custom =
          <String, MtnMinecraftNbtValue>{
        'a': MtnMinecraftNbtValue.intValue(1),
      };
      final Map<String, MtnMinecraftNbtValue> legacy =
          <String, MtnMinecraftNbtValue>{
        'b': MtnMinecraftNbtValue.intValue(2),
      };

      final MtnMinecraftInfoItemStackComponents components =
          MtnMinecraftInfoItemStackComponents(
        customData: custom,
        legacyTag: legacy,
      );
      custom['a'] = MtnMinecraftNbtValue.intValue(9);
      legacy['b'] = MtnMinecraftNbtValue.intValue(8);

      expect(components.customData!['a']!.asInt, 1);
      expect(components.legacyTag!['b']!.asInt, 2);
    });

    test('custom data removal is preserved and conflicts are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:custom_data': _emptyCompound(),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.customData, isNull);
      expect(
        components.removedComponentIds,
        contains('minecraft:custom_data'),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_data': _emptyCompound(),
            '!minecraft:custom_data': _emptyCompound(),
          },
        ),
      );
    });

    test('rejects malformed modern custom data type', () async {
      for (final MtnMinecraftNbtValue value in <MtnMinecraftNbtValue>[
        MtnMinecraftNbtValue.string('bad'),
        MtnMinecraftNbtValue.intValue(1),
        MtnMinecraftNbtValue.list(
          MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.end,
            values: const <MtnMinecraftNbtValue>[],
          ),
        ),
      ]) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:custom_data': value,
            },
          ),
        );
      }
    });

    test('unknown modern component IDs remain tolerated', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'examplemod:future_component': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'value': MtnMinecraftNbtValue.intValue(3),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStack item =
          await _readItem(provider, world);
      expect(item.components, isNull);
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
  String id = 'minecraft:stick',
  int count = 1,
  Map<String, MtnMinecraftNbtValue>? tag,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string(id),
      'Count': MtnMinecraftNbtValue.byte(count),
      if (tag != null) 'tag': MtnMinecraftNbtValue.compound(tag),
    };

Map<String, MtnMinecraftNbtValue> _modernItem({
  String id = 'minecraft:stick',
  int count = 1,
  Map<String, MtnMinecraftNbtValue>? components,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string(id),
      'count': MtnMinecraftNbtValue.intValue(count),
      if (components != null)
        'components': MtnMinecraftNbtValue.compound(components),
    };

MtnMinecraftNbtValue _emptyCompound() => MtnMinecraftNbtValue.compound(
      <String, MtnMinecraftNbtValue>{},
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
