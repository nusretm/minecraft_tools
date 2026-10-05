import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft item display text', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-display-',
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

    test('normalizes legacy display Name and Lore JSON components', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'display': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'Name': MtnMinecraftNbtValue.string(
                  '{"text":"Blade","color":"red","bold":true,'
                  '"extra":[{"text":"!","color":"gold"}]}',
                ),
                'Lore': _stringList(
                  <String>[
                    '{"text":"First line","italic":true}',
                    '{"text":"Second","color":"#12ABEF"}',
                  ],
                ),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.customName?.plainText, 'Blade!');
      expect(components.customName?.items, hasLength(2));
      expect(
        components.customName?.items[0].color,
        MtnMinecraftTextColor.red,
      );
      expect(components.customName?.items[0].bold, isTrue);
      expect(
        components.customName?.items[1].color,
        MtnMinecraftTextColor.gold,
      );

      expect(components.itemName, isNull);
      expect(components.lore, hasLength(2));
      expect(components.lore?[0].plainText, 'First line');
      expect(components.lore?[0].items.single.italic, isTrue);
      expect(components.lore?[1].items.single.color.hex, '#12ABEF');
    });

    test('normalizes 1.20.5 JSON-string display components', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_name': MtnMinecraftNbtValue.string(
              '{"text":"Renamed","color":"yellow"}',
            ),
            'minecraft:item_name': MtnMinecraftNbtValue.string(
              '{"text":"Base name","color":"aqua"}',
            ),
            'minecraft:lore': _stringList(
              <String>[
                '{"text":"Lore A","color":"gray"}',
                '{"text":"Lore B","underlined":true}',
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.customName?.plainText, 'Renamed');
      expect(
        components.customName?.items.single.color,
        MtnMinecraftTextColor.yellow,
      );
      expect(components.itemName?.plainText, 'Base name');
      expect(
        components.itemName?.items.single.color,
        MtnMinecraftTextColor.aqua,
      );
      expect(
        components.lore
            ?.map((MtnMinecraftText line) => line.plainText)
            .toList(growable: false),
        <String>['Lore A', 'Lore B'],
      );
      expect(components.lore?[1].items.single.underlined, isTrue);
    });

    test('normalizes 1.21.5 inline NBT display components', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_name': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'text': MtnMinecraftNbtValue.string('Inline'),
                'color': MtnMinecraftNbtValue.string('light_purple'),
                'italic': MtnMinecraftNbtValue.byte(1),
                'extra': _compoundList(
                  <Map<String, MtnMinecraftNbtValue>>[
                    <String, MtnMinecraftNbtValue>{
                      'text': MtnMinecraftNbtValue.string(' child'),
                      'bold': MtnMinecraftNbtValue.byte(1),
                    },
                  ],
                ),
              },
            ),
            'minecraft:item_name': MtnMinecraftNbtValue.string(
              'Simple inline string',
            ),
            'minecraft:lore': _compoundList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'text': MtnMinecraftNbtValue.string('NBT lore'),
                  'color': MtnMinecraftNbtValue.string('#55FF55'),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.customName?.plainText, 'Inline child');
      expect(components.customName?.items, hasLength(2));
      expect(
        components.customName?.items[0].color,
        MtnMinecraftTextColor.lightPurple,
      );
      expect(components.customName?.items[0].italic, isTrue);
      expect(components.customName?.items[1].italic, isTrue);
      expect(components.customName?.items[1].bold, isTrue);

      expect(components.itemName?.plainText, 'Simple inline string');
      expect(components.lore?.single.plainText, 'NBT lore');
      expect(components.lore?.single.items.single.color.hex, '#55FF55');
    });

    test('modern display components remain authoritative over legacy display',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        <String, MtnMinecraftNbtValue>{
          ..._modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:custom_name':
                  MtnMinecraftNbtValue.string('{"text":"Modern"}'),
            },
          ),
          'tag': MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'display': MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{
                  'Name':
                      MtnMinecraftNbtValue.string('{"text":"Legacy"}'),
                },
              ),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.customName?.plainText, 'Modern');
    });

    test('explicit empty lore remains distinct from absent lore', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:lore': _emptyList(),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components?.lore, isEmpty);

      await _writeInventoryItem(worldDirectory, _modernItem());
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('display lore list and removed-component set are immutable',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:lore': _stringList(<String>['{"text":"Line"}']),
          },
        ),
      );

      final List<MtnMinecraftText> lore =
          (await _readItem(provider, world)).components!.lore!;
      expect(
        () => lore.add(MtnMinecraftText(text: 'Other')),
        throwsUnsupportedError,
      );
    });

    test('malformed recognized display data invalidates player', () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'display': MtnMinecraftNbtValue.string('bad'),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:lore': MtnMinecraftNbtValue.string('bad'),
          },
        ),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_name': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'text': MtnMinecraftNbtValue.string('Bad style'),
                'bold': MtnMinecraftNbtValue.intValue(2),
              },
            ),
          },
        ),
      );
    });

    test('recognized display component cannot be set and removed together',
        () async {
      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:custom_name':
                MtnMinecraftNbtValue.string('{"text":"Name"}'),
            '!minecraft:custom_name':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
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

MtnMinecraftNbtValue _stringList(List<String> values) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: values.isEmpty
            ? MtnMinecraftNbtType.end
            : MtnMinecraftNbtType.string,
        values: values
            .map(MtnMinecraftNbtValue.string)
            .toList(growable: false),
      ),
    );

MtnMinecraftNbtValue _compoundList(
  List<Map<String, MtnMinecraftNbtValue>> values,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: values.isEmpty
            ? MtnMinecraftNbtType.end
            : MtnMinecraftNbtType.compound,
        values: values
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
