import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider player inventory and equipment', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-player-inventory-',
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

    test('reads legacy inventory, ender chest and equipment slots', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'SelectedItemSlot': MtnMinecraftNbtValue.intValue(2),
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 2, id: 'minecraft:diamond_sword', count: 1),
            _legacyItem(slot: 9, id: 'minecraft:stone', count: 64),
            _legacyItem(slot: 103, id: 'minecraft:diamond_helmet', count: 1),
            _legacyItem(slot: 102, id: 'minecraft:diamond_chestplate', count: 1),
            _legacyItem(slot: 101, id: 'minecraft:diamond_leggings', count: 1),
            _legacyItem(slot: 100, id: 'minecraft:diamond_boots', count: 1),
            _legacyItem(slot: -106, id: 'minecraft:shield', count: 1),
          ]),
          'EnderItems': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 0, id: 'minecraft:ender_pearl', count: 16),
            _legacyItem(slot: 26, id: 'minecraft:diamond', count: 3),
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.inventory, hasLength(36));
      expect(player.inventory![2]?.id, 'minecraft:diamond_sword');
      expect(player.inventory![2]?.count, 1);
      expect(player.inventory![9]?.id, 'minecraft:stone');
      expect(player.inventory![9]?.count, 64);
      expect(player.inventory!.whereType<MtnMinecraftInfoItemStack>(), hasLength(2));
      expect(player.selectedItem?.id, 'minecraft:diamond_sword');

      expect(player.enderChest, hasLength(27));
      expect(player.enderChest![0]?.id, 'minecraft:ender_pearl');
      expect(player.enderChest![26]?.id, 'minecraft:diamond');

      expect(player.equipment?.head?.id, 'minecraft:diamond_helmet');
      expect(player.equipment?.chest?.id, 'minecraft:diamond_chestplate');
      expect(player.equipment?.legs?.id, 'minecraft:diamond_leggings');
      expect(player.equipment?.feet?.id, 'minecraft:diamond_boots');
      expect(player.equipment?.offHand?.id, 'minecraft:shield');
    });

    test('reads modern count and defaults missing count to one', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _modernItem(
              slot: 0,
              id: 'minecraft:apple',
              count: 5,
              extra: <String, MtnMinecraftNbtValue>{
                'Count': MtnMinecraftNbtValue.string('ignored legacy count'),
                'components': MtnMinecraftNbtValue.string('ignored'),
              },
            ),
            _modernItem(
              slot: 1,
              id: 'minecraft:stick',
              count: null,
            ),
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.inventory![0]?.count, 5);
      expect(player.inventory![1]?.count, 1);
    });

    test('legacy tag metadata is ignored by the foundation', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(
              slot: 0,
              id: 'minecraft:diamond_sword',
              count: 1,
              extra: <String, MtnMinecraftNbtValue>{
                'tag': MtnMinecraftNbtValue.string('not parsed here'),
              },
            ),
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.available);
      expect(player.inventory![0]?.id, 'minecraft:diamond_sword');
    });

    test('modern equipment overrides matching legacy slots per slot', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 103, id: 'minecraft:iron_helmet', count: 1),
            _legacyItem(slot: 102, id: 'minecraft:iron_chestplate', count: 1),
            _legacyItem(slot: -106, id: 'minecraft:shield', count: 1),
          ]),
          'equipment': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'head': MtnMinecraftNbtValue.compound(
                _modernStack(id: 'minecraft:diamond_helmet', count: 1),
              ),
              'offhand': MtnMinecraftNbtValue.compound(
                _modernStack(id: 'minecraft:totem_of_undying', count: 1),
              ),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayerEquipment equipment =
          (await provider.readPlayers(world)).single.equipment!;

      expect(equipment.head?.id, 'minecraft:diamond_helmet');
      expect(equipment.chest?.id, 'minecraft:iron_chestplate');
      expect(equipment.offHand?.id, 'minecraft:totem_of_undying');
    });

    test('explicit empty modern equipment slot suppresses legacy fallback',
        () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 103, id: 'minecraft:iron_helmet', count: 1),
          ]),
          'equipment': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'head': MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{},
              ),
            },
          ),
        },
      );

      final MtnMinecraftInfoPlayerEquipment equipment =
          (await provider.readPlayers(world)).single.equipment!;

      expect(equipment.head, isNull);
    });

    test('missing and empty storage remain distinguishable', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{},
      );
      MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;
      expect(player.inventory, isNull);
      expect(player.enderChest, isNull);
      expect(player.equipment, isNull);

      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _emptyList(),
          'EnderItems': _emptyList(),
          'equipment': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{},
          ),
        },
      );
      player = (await provider.readPlayers(world)).single;

      expect(player.inventory, hasLength(36));
      expect(player.inventory!.whereType<MtnMinecraftInfoItemStack>(), isEmpty);
      expect(player.enderChest, hasLength(27));
      expect(player.enderChest!.whereType<MtnMinecraftInfoItemStack>(), isEmpty);
      expect(player.equipment, isNotNull);
      expect(player.equipment?.head, isNull);
      expect(player.equipment?.offHand, isNull);
    });

    test('unknown inventory and ender slots are ignored', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              'Slot': MtnMinecraftNbtValue.byte(42),
              'id': MtnMinecraftNbtValue.intValue(123),
            },
            _legacyItem(slot: 0, id: 'minecraft:stone', count: 2),
          ]),
          'EnderItems': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              'Slot': MtnMinecraftNbtValue.byte(30),
              'id': MtnMinecraftNbtValue.intValue(123),
            },
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.state, MtnMinecraftInfoPlayerState.available);
      expect(player.inventory![0]?.id, 'minecraft:stone');
      expect(player.enderChest!.whereType<MtnMinecraftInfoItemStack>(), isEmpty);
    });

    test('duplicate recognized inventory slot is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 3, id: 'minecraft:stone', count: 1),
            _legacyItem(slot: 3, id: 'minecraft:dirt', count: 1),
          ]),
        },
      );
    });

    test('duplicate recognized legacy equipment slot is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 103, id: 'minecraft:iron_helmet', count: 1),
            _legacyItem(slot: 103, id: 'minecraft:diamond_helmet', count: 1),
          ]),
        },
      );
    });

    test('duplicate recognized ender slot is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'EnderItems': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 4, id: 'minecraft:stone', count: 1),
            _legacyItem(slot: 4, id: 'minecraft:dirt', count: 1),
          ]),
        },
      );
    });

    test('wrong recognized item id or count type is invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              'Slot': MtnMinecraftNbtValue.byte(0),
              'id': MtnMinecraftNbtValue.intValue(1),
              'Count': MtnMinecraftNbtValue.byte(1),
            },
          ]),
        },
      );

      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              'Slot': MtnMinecraftNbtValue.byte(0),
              'id': MtnMinecraftNbtValue.string('minecraft:stone'),
              'count': MtnMinecraftNbtValue.byte(1),
            },
          ]),
        },
      );
    });

    test('legacy signed Count byte is normalized as unsigned count', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 0, id: 'example:large_stack', count: -1),
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.inventory![0]?.count, 255);
    });

    test('air and zero-count stacks normalize to empty slots', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _compoundList(<Map<String, MtnMinecraftNbtValue>>[
            _legacyItem(slot: 0, id: 'minecraft:air', count: 1),
            _modernItem(slot: 1, id: 'minecraft:stone', count: 0),
          ]),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(player.inventory![0], isNull);
      expect(player.inventory![1], isNull);
    });

    test('inventory and ender chest lists are immutable', () async {
      await _writePlayer(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': _emptyList(),
          'EnderItems': _emptyList(),
        },
      );

      final MtnMinecraftInfoPlayer player =
          (await provider.readPlayers(world)).single;

      expect(
        () => player.inventory![0] =
            const MtnMinecraftInfoItemStack(id: 'minecraft:stone', count: 1),
        throwsUnsupportedError,
      );
      expect(
        () => player.enderChest![0] =
            const MtnMinecraftInfoItemStack(id: 'minecraft:stone', count: 1),
        throwsUnsupportedError,
      );
    });

    test('storage list and equipment shape errors are invalidData', () async {
      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'Inventory': MtnMinecraftNbtValue.string('not a list'),
        },
      );

      await _expectInvalidData(
        provider,
        world,
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          'equipment': MtnMinecraftNbtValue.string('not a compound'),
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

Map<String, MtnMinecraftNbtValue> _legacyItem({
  required int slot,
  required String id,
  required int count,
  Map<String, MtnMinecraftNbtValue>? extra,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(slot),
      'id': MtnMinecraftNbtValue.string(id),
      'Count': MtnMinecraftNbtValue.byte(count),
      ...?extra,
    };

Map<String, MtnMinecraftNbtValue> _modernItem({
  required int slot,
  required String id,
  required int? count,
  Map<String, MtnMinecraftNbtValue>? extra,
}) =>
    <String, MtnMinecraftNbtValue>{
      'Slot': MtnMinecraftNbtValue.byte(slot),
      ..._modernStack(id: id, count: count),
      ...?extra,
    };

Map<String, MtnMinecraftNbtValue> _modernStack({
  required String id,
  required int? count,
}) =>
    <String, MtnMinecraftNbtValue>{
      'id': MtnMinecraftNbtValue.string(id),
      if (count != null) 'count': MtnMinecraftNbtValue.intValue(count),
    };

MtnMinecraftNbtValue _compoundList(
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
