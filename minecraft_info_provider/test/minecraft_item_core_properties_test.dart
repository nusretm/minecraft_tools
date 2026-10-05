import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider item core properties', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-components-',
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

    test('normalizes legacy core item properties', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Damage': MtnMinecraftNbtValue.intValue(12),
            'RepairCost': MtnMinecraftNbtValue.intValue(7),
            'Unbreakable': MtnMinecraftNbtValue.byte(1),
            'Enchantments': _legacyEnchantments(
              <String, int>{
                'minecraft:sharpness': 5,
                'example:lifesteal': 2,
              },
            ),
            'StoredEnchantments': _legacyEnchantments(
              <String, int>{
                'minecraft:mending': 1,
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      final MtnMinecraftInfoItemStackComponents components = item.components!;

      expect(components.damage, 12);
      expect(components.repairCost, 7);
      expect(components.unbreakable, isTrue);
      expect(
        components.enchantments,
        <String, int>{
          'minecraft:sharpness': 5,
          'example:lifesteal': 2,
        },
      );
      expect(
        components.storedEnchantments,
        <String, int>{'minecraft:mending': 1},
      );
    });

    test('normalizes 1.20.5-style modern core components', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:damage': MtnMinecraftNbtValue.intValue(21),
            'minecraft:repair_cost': MtnMinecraftNbtValue.intValue(4),
            'minecraft:unbreakable': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'show_in_tooltip': MtnMinecraftNbtValue.byte(0),
              },
            ),
            'minecraft:enchantments': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'levels': MtnMinecraftNbtValue.compound(
                  <String, MtnMinecraftNbtValue>{
                    'minecraft:efficiency': MtnMinecraftNbtValue.intValue(5),
                    'example:vein_miner': MtnMinecraftNbtValue.intValue(3),
                  },
                ),
                'show_in_tooltip': MtnMinecraftNbtValue.byte(0),
              },
            ),
            'minecraft:stored_enchantments': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'levels': MtnMinecraftNbtValue.compound(
                  <String, MtnMinecraftNbtValue>{
                    'minecraft:fortune': MtnMinecraftNbtValue.intValue(3),
                  },
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.damage, 21);
      expect(components.repairCost, 4);
      expect(components.unbreakable, isTrue);
      expect(
        components.enchantments,
        <String, int>{
          'minecraft:efficiency': 5,
          'example:vein_miner': 3,
        },
      );
      expect(
        components.storedEnchantments,
        <String, int>{'minecraft:fortune': 3},
      );
    });

    test('normalizes 1.21.5-style simplified enchantment components',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:enchantments': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'minecraft:sharpness': MtnMinecraftNbtValue.intValue(4),
                'example:frost': MtnMinecraftNbtValue.intValue(2),
              },
            ),
            'minecraft:stored_enchantments': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'minecraft:protection': MtnMinecraftNbtValue.intValue(3),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(
        components.enchantments,
        <String, int>{
          'minecraft:sharpness': 4,
          'example:frost': 2,
        },
      );
      expect(
        components.storedEnchantments,
        <String, int>{'minecraft:protection': 3},
      );
    });

    test('modern components are authoritative over legacy tag', () async {
      await _writeInventoryItem(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:damage': MtnMinecraftNbtValue.intValue(8),
            },
          ),
          'tag': MtnMinecraftNbtValue.string('ignored legacy payload'),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.damage, 8);
      expect(components.repairCost, isNull);
    });

    test('unknown legacy and modern metadata do not invalidate item',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'ExampleModData': MtnMinecraftNbtValue.string('value'),
          },
        ),
      );
      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNull);

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'example:custom_component': MtnMinecraftNbtValue.string('value'),
            '!example:removed_component':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );
      item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(
        item.components?.removedComponentIds,
        <String>{'example:removed_component'},
      );
    });

    test('modern component removals are preserved and conflicting core patches are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:damage':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
            '!minecraft:enchantments':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.damage, isNull);
      expect(components.enchantments, isNull);
      expect(
        components.removedComponentIds,
        <String>{'minecraft:damage', 'minecraft:enchantments'},
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:damage': MtnMinecraftNbtValue.intValue(2),
            '!minecraft:damage':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );
    });

    test('component removal set is immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!example:custom':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );

      final Set<String> removed =
          (await _readItem(provider, world)).components!.removedComponentIds;
      expect(
        () => removed.add('minecraft:damage'),
        throwsUnsupportedError,
      );
    });

    test('explicit empty enchantments remain distinct from absent properties',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Enchantments': _emptyList(),
          },
        ),
      );
      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components?.enchantments, isEmpty);

      await _writeInventoryItem(worldDirectory, _legacyItem());
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('legacy false unbreakable remains explicit false', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Unbreakable': MtnMinecraftNbtValue.byte(0),
          },
        ),
      );

      expect(
        (await _readItem(provider, world)).components?.unbreakable,
        isFalse,
      );
    });

    test('enchantment maps are immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Enchantments': _legacyEnchantments(
              <String, int>{'minecraft:sharpness': 3},
            ),
          },
        ),
      );

      final Map<String, int> enchantments =
          (await _readItem(provider, world)).components!.enchantments!;

      expect(
        () => enchantments['minecraft:mending'] = 1,
        throwsUnsupportedError,
      );
    });

    test('malformed legacy recognized properties invalidate player',
        () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Damage': MtnMinecraftNbtValue.string('bad'),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Unbreakable': MtnMinecraftNbtValue.byte(2),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Enchantments': _legacyEnchantmentEntries(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'id': MtnMinecraftNbtValue.string('minecraft:sharpness'),
                  'lvl': MtnMinecraftNbtValue.intValue(3),
                },
              ],
            ),
          },
        ),
      );
    });

    test('duplicate legacy enchantment id invalidates player', () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'Enchantments': _legacyEnchantmentEntries(
              <Map<String, MtnMinecraftNbtValue>>[
                _legacyEnchantment('minecraft:sharpness', 2),
                _legacyEnchantment('minecraft:sharpness', 3),
              ],
            ),
          },
        ),
      );
    });

    test('malformed modern recognized components invalidate player',
        () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:damage': MtnMinecraftNbtValue.intValue(-1),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:unbreakable': MtnMinecraftNbtValue.byte(1),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:enchantments': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'minecraft:sharpness': MtnMinecraftNbtValue.short(3),
              },
            ),
          },
        ),
      );
    });

    test('legacy tag and modern components containers must be compounds',
        () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._legacyItem(),
          'tag': MtnMinecraftNbtValue.string('bad'),
        },
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._modernItem(),
          'components': MtnMinecraftNbtValue.string('bad'),
        },
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
      'id': MtnMinecraftNbtValue.string('minecraft:diamond_sword'),
      'Count': MtnMinecraftNbtValue.byte(1),
      if (tag != null) 'tag': MtnMinecraftNbtValue.compound(tag),
    };

Map<String, MtnMinecraftNbtValue> _modernItem({
  Map<String, MtnMinecraftNbtValue>? components,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(0),
      'id': MtnMinecraftNbtValue.string('minecraft:diamond_sword'),
      'count': MtnMinecraftNbtValue.intValue(1),
      if (components != null)
        'components': MtnMinecraftNbtValue.compound(components),
    };

MtnMinecraftNbtValue _legacyEnchantments(
  Map<String, int> enchantments,
) =>
    _legacyEnchantmentEntries(
      enchantments.entries
          .map(
            (MapEntry<String, int> entry) =>
                _legacyEnchantment(entry.key, entry.value),
          )
          .toList(growable: false),
    );

Map<String, MtnMinecraftNbtValue> _legacyEnchantment(
  String id,
  int level,
) =>
    <String, MtnMinecraftNbtValue>{
      'id': MtnMinecraftNbtValue.string(id),
      'lvl': MtnMinecraftNbtValue.short(level),
    };

MtnMinecraftNbtValue _legacyEnchantmentEntries(
  List<Map<String, MtnMinecraftNbtValue>> entries,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.compound,
        values: entries
            .map(MtnMinecraftNbtValue.compound)
            .toList(growable: false),
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
