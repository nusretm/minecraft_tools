import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';

void main() {
  group('Minecraft Info Provider nested item stacks', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-nested-stacks-',
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

    test('reads legacy BlockEntityTag Items as sparse container contents',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          id: 'minecraft:shulker_box',
          tag: <String, MtnMinecraftNbtValue>{
            'BlockEntityTag': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'Items': _compoundList(<MtnMinecraftNbtValue>[
                  _legacyNestedItem(
                    slot: 0,
                    id: 'minecraft:diamond_pickaxe',
                  ),
                  _legacyNestedItem(
                    slot: 5,
                    id: 'minecraft:apple',
                    count: 3,
                  ),
                ]),
              },
            ),
          },
        ),
      );

      final Map<int, MtnMinecraftInfoItemStack> contents =
          (await _readItem(provider, world))
              .components!
              .containerContents!;

      expect(contents.keys, <int>[0, 5]);
      expect(contents[0]!.id, 'minecraft:diamond_pickaxe');
      expect(contents[0]!.count, 1);
      expect(contents[5]!.id, 'minecraft:apple');
      expect(contents[5]!.count, 3);
    });

    test('reads modern container slots including 0 and 255', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          id: 'minecraft:chest',
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:container': _compoundList(<MtnMinecraftNbtValue>[
              _modernContainerEntry(
                slot: 0,
                item: _modernNestedItem(id: 'minecraft:stone'),
              ),
              _modernContainerEntry(
                slot: 255,
                item: _modernNestedItem(
                  id: 'minecraft:apple',
                  count: 2,
                ),
              ),
            ]),
          },
        ),
      );

      final Map<int, MtnMinecraftInfoItemStack> contents =
          (await _readItem(provider, world))
              .components!
              .containerContents!;

      expect(contents.keys, <int>[0, 255]);
      expect(contents[0]!.id, 'minecraft:stone');
      expect(contents[255]!.count, 2);
    });

    test('rejects duplicate and out-of-range modern container slots',
        () async {
      final List<MtnMinecraftNbtValue> invalidContainers =
          <MtnMinecraftNbtValue>[
        _compoundList(<MtnMinecraftNbtValue>[
          _modernContainerEntry(
            slot: 4,
            item: _modernNestedItem(id: 'minecraft:stone'),
          ),
          _modernContainerEntry(
            slot: 4,
            item: _modernNestedItem(id: 'minecraft:apple'),
          ),
        ]),
        _compoundList(<MtnMinecraftNbtValue>[
          _modernContainerEntry(
            slot: 256,
            item: _modernNestedItem(id: 'minecraft:stone'),
          ),
        ]),
      ];

      for (final MtnMinecraftNbtValue container in invalidContainers) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:container': container,
            },
          ),
        );
      }
    });

    test('keeps explicit empty container distinct from absent property',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:container': _emptyList(),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components!.containerContents, isEmpty);

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:damage': MtnMinecraftNbtValue.intValue(1),
          },
        ),
      );
      item = await _readItem(provider, world);
      expect(item.components!.containerContents, isNull);
    });

    test('reads legacy Bundle Items and ChargedProjectiles', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          id: 'minecraft:bundle',
          tag: <String, MtnMinecraftNbtValue>{
            'Items': _compoundList(<MtnMinecraftNbtValue>[
              _legacyNestedItem(id: 'minecraft:stone', count: 32),
              _legacyNestedItem(id: 'minecraft:apple', count: 2),
            ]),
            'ChargedProjectiles': _compoundList(<MtnMinecraftNbtValue>[
              _legacyNestedItem(id: 'minecraft:arrow'),
            ]),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(
        components.bundleContents!.map((MtnMinecraftInfoItemStack item) => item.id),
        <String>['minecraft:stone', 'minecraft:apple'],
      );
      expect(components.bundleContents![0].count, 32);
      expect(components.chargedProjectiles!.single.id, 'minecraft:arrow');
    });

    test('reads modern bundle contents and charged projectiles', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:bundle_contents': _compoundList(
              <MtnMinecraftNbtValue>[
                _modernNestedItem(id: 'minecraft:stone', count: 12),
              ],
            ),
            'minecraft:charged_projectiles': _compoundList(
              <MtnMinecraftNbtValue>[
                _modernNestedItem(id: 'minecraft:firework_rocket'),
                _modernNestedItem(id: 'minecraft:arrow'),
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.bundleContents!.single.count, 12);
      expect(components.chargedProjectiles!.length, 2);
      expect(
        components.chargedProjectiles![0].id,
        'minecraft:firework_rocket',
      );
    });

    test('reads modern use remainder as one nested item stack', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:use_remainder':
                _modernNestedItem(id: 'minecraft:bowl'),
          },
        ),
      );

      final MtnMinecraftInfoItemStack remainder =
          (await _readItem(provider, world)).components!.useRemainder!;
      expect(remainder.id, 'minecraft:bowl');
      expect(remainder.count, 1);
    });

    test('recursively parses nested item components through one item parser',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          id: 'minecraft:shulker_box',
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:container': _compoundList(<MtnMinecraftNbtValue>[
              _modernContainerEntry(
                slot: 7,
                item: _modernNestedItem(
                  id: 'minecraft:bundle',
                  components: <String, MtnMinecraftNbtValue>{
                    'minecraft:bundle_contents': _compoundList(
                      <MtnMinecraftNbtValue>[
                        _modernNestedItem(
                          id: 'minecraft:stick',
                          count: 2,
                          components: <String, MtnMinecraftNbtValue>{
                            'minecraft:custom_model_data':
                                MtnMinecraftNbtValue.intValue(91),
                          },
                        ),
                      ],
                    ),
                  },
                ),
              ),
            ]),
          },
        ),
      );

      final MtnMinecraftInfoItemStack bundle =
          (await _readItem(provider, world))
              .components!
              .containerContents![7]!;
      final MtnMinecraftInfoItemStack stick =
          bundle.components!.bundleContents!.single;

      expect(bundle.id, 'minecraft:bundle');
      expect(stick.id, 'minecraft:stick');
      expect(stick.count, 2);
      expect(stick.components!.customModelData!.legacyValue, 91);
    });

    test('nested maps and lists are immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:container': _compoundList(<MtnMinecraftNbtValue>[
              _modernContainerEntry(
                slot: 1,
                item: _modernNestedItem(id: 'minecraft:stone'),
              ),
            ]),
            'minecraft:bundle_contents': _compoundList(
              <MtnMinecraftNbtValue>[
                _modernNestedItem(id: 'minecraft:apple'),
              ],
            ),
            'minecraft:charged_projectiles': _compoundList(
              <MtnMinecraftNbtValue>[
                _modernNestedItem(id: 'minecraft:arrow'),
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(
        () => components.containerContents![2] =
            const MtnMinecraftInfoItemStack(id: 'minecraft:dirt', count: 1),
        throwsUnsupportedError,
      );
      expect(
        () => components.bundleContents!.add(
          const MtnMinecraftInfoItemStack(id: 'minecraft:dirt', count: 1),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => components.chargedProjectiles!.clear(),
        throwsUnsupportedError,
      );
    });

    test('modern components remain authoritative over legacy nested contents',
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
              'Items': _compoundList(<MtnMinecraftNbtValue>[
                _legacyNestedItem(id: 'minecraft:stone'),
              ]),
              'ChargedProjectiles': _compoundList(<MtnMinecraftNbtValue>[
                _legacyNestedItem(id: 'minecraft:arrow'),
              ]),
              'BlockEntityTag': MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{
                  'Items': _compoundList(<MtnMinecraftNbtValue>[
                    _legacyNestedItem(
                      slot: 0,
                      id: 'minecraft:apple',
                    ),
                  ]),
                },
              ),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.damage, 1);
      expect(components.containerContents, isNull);
      expect(components.bundleContents, isNull);
      expect(components.chargedProjectiles, isNull);
    });

    test('nested component removals are preserved and conflicts are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:container': _emptyCompound(),
            '!minecraft:bundle_contents': _emptyCompound(),
            '!minecraft:charged_projectiles': _emptyCompound(),
            '!minecraft:use_remainder': _emptyCompound(),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.containerContents, isNull);
      expect(components.bundleContents, isNull);
      expect(components.chargedProjectiles, isNull);
      expect(components.useRemainder, isNull);
      expect(
        components.removedComponentIds,
        containsAll(<String>[
          'minecraft:container',
          'minecraft:bundle_contents',
          'minecraft:charged_projectiles',
          'minecraft:use_remainder',
        ]),
      );

      final Map<String, MtnMinecraftNbtValue> validValues =
          <String, MtnMinecraftNbtValue>{
        'minecraft:container': _emptyList(),
        'minecraft:bundle_contents': _emptyList(),
        'minecraft:charged_projectiles': _emptyList(),
        'minecraft:use_remainder':
            _modernNestedItem(id: 'minecraft:bowl'),
      };
      for (final MapEntry<String, MtnMinecraftNbtValue> entry
          in validValues.entries) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(
            components: <String, MtnMinecraftNbtValue>{
              entry.key: entry.value,
              '!${entry.key}': _emptyCompound(),
            },
          ),
        );
      }
    });

    test('unknown nested entry metadata remains tolerated', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:container': _compoundList(<MtnMinecraftNbtValue>[
              MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{
                  'slot': MtnMinecraftNbtValue.intValue(3),
                  'item': _modernNestedItem(id: 'minecraft:stone'),
                  'examplemod:future': MtnMinecraftNbtValue.long(123),
                },
              ),
            ]),
          },
        ),
      );

      final Map<int, MtnMinecraftInfoItemStack> contents =
          (await _readItem(provider, world))
              .components!
              .containerContents!;
      expect(contents[3]!.id, 'minecraft:stone');
    });

    test('malformed recognized nested items invalidate player data',
        () async {
      final List<Map<String, MtnMinecraftNbtValue>> invalidItems =
          <Map<String, MtnMinecraftNbtValue>>[
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:bundle_contents': _compoundList(
              <MtnMinecraftNbtValue>[
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
              ],
            ),
          },
        ),
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:charged_projectiles': _compoundList(
              <MtnMinecraftNbtValue>[
                _modernNestedItem(id: 'minecraft:air'),
              ],
            ),
          },
        ),
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:use_remainder':
                _modernNestedItem(id: 'minecraft:bowl', count: 0),
          },
        ),
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'BlockEntityTag': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'Items': MtnMinecraftNbtValue.string('bad'),
              },
            ),
          },
        ),
      ];

      for (final Map<String, MtnMinecraftNbtValue> item in invalidItems) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          item,
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

MtnMinecraftNbtValue _legacyNestedItem({
  int? slot,
  required String id,
  int count = 1,
}) =>
    MtnMinecraftNbtValue.compound(
      <String, MtnMinecraftNbtValue>{
        if (slot != null) 'Slot': MtnMinecraftNbtValue.byte(slot),
        'id': MtnMinecraftNbtValue.string(id),
        'Count': MtnMinecraftNbtValue.byte(count),
      },
    );

MtnMinecraftNbtValue _modernNestedItem({
  required String id,
  int count = 1,
  Map<String, MtnMinecraftNbtValue>? components,
}) =>
    MtnMinecraftNbtValue.compound(
      <String, MtnMinecraftNbtValue>{
        'id': MtnMinecraftNbtValue.string(id),
        'count': MtnMinecraftNbtValue.intValue(count),
        if (components != null)
          'components': MtnMinecraftNbtValue.compound(components),
      },
    );

MtnMinecraftNbtValue _modernContainerEntry({
  required int slot,
  required MtnMinecraftNbtValue item,
}) =>
    MtnMinecraftNbtValue.compound(
      <String, MtnMinecraftNbtValue>{
        'slot': MtnMinecraftNbtValue.intValue(slot),
        'item': item,
      },
    );

MtnMinecraftNbtValue _compoundList(
  List<MtnMinecraftNbtValue> values,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.compound,
        values: values,
      ),
    );

MtnMinecraftNbtValue _emptyList() => MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.end,
        values: const <MtnMinecraftNbtValue>[],
      ),
    );

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
