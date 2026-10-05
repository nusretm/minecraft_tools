import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _uuid = '00112233-4455-6677-8899-aabbccddeeff';
const List<int> _modifierUuid = <int>[
  0x00112233,
  0x44556677,
  -2003195205,
  -857870593,
];

void main() {
  group('Minecraft Info Provider item attribute modifiers', () {
    late Directory gameDirectory;
    late Directory worldDirectory;
    late MtnMinecraftInfoProvider provider;
    late MtnMinecraftInfoWorld world;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-attributes-',
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

    test('reads legacy item attribute modifier identity and values', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'AttributeModifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'AttributeName':
                      MtnMinecraftNbtValue.string('generic.attack_damage'),
                  'Name': MtnMinecraftNbtValue.string('Weapon modifier'),
                  'UUID': MtnMinecraftNbtValue.intArray(_modifierUuid),
                  'Amount': MtnMinecraftNbtValue.doubleValue(7),
                  'Operation': MtnMinecraftNbtValue.intValue(0),
                  'Slot': MtnMinecraftNbtValue.string('mainhand'),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemAttributeModifier modifier =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!
              .single;

      expect(modifier.attributeId, 'generic.attack_damage');
      expect(modifier.id, isNull);
      expect(modifier.legacyUuid, _uuid);
      expect(modifier.legacyName, 'Weapon modifier');
      expect(modifier.amount, 7);
      expect(
        modifier.operation,
        MtnMinecraftInfoAttributeModifierOperation.addValue,
      );
      expect(
        modifier.slot,
        MtnMinecraftInfoItemAttributeModifierSlot.mainHand,
      );
      expect(modifier.display, isNull);
    });

    test('normalizes legacy operation forms and missing slot', () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'AttributeModifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                _legacyModifier(
                  name: 'One',
                  operation: MtnMinecraftNbtValue.byte(0),
                ),
                _legacyModifier(
                  name: 'Two',
                  operation: MtnMinecraftNbtValue.intValue(1),
                  slot: 'offhand',
                ),
                _legacyModifier(
                  name: 'Three',
                  operation: MtnMinecraftNbtValue.intValue(2),
                  slot: 'chest',
                ),
              ],
            ),
          },
        ),
      );

      final List<MtnMinecraftInfoItemAttributeModifier> modifiers =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!;

      expect(modifiers[0].operation,
          MtnMinecraftInfoAttributeModifierOperation.addValue);
      expect(modifiers[0].slot,
          MtnMinecraftInfoItemAttributeModifierSlot.any);
      expect(modifiers[1].operation,
          MtnMinecraftInfoAttributeModifierOperation.addMultipliedBase);
      expect(modifiers[1].slot,
          MtnMinecraftInfoItemAttributeModifierSlot.offHand);
      expect(modifiers[2].operation,
          MtnMinecraftInfoAttributeModifierOperation.addMultipliedTotal);
      expect(modifiers[2].slot,
          MtnMinecraftInfoItemAttributeModifierSlot.chest);
    });

    test('reads 1.20.5 full component with legacy modifier identity', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'modifiers': _modifierList(
                  <Map<String, MtnMinecraftNbtValue>>[
                    <String, MtnMinecraftNbtValue>{
                      'type':
                          MtnMinecraftNbtValue.string('minecraft:generic.scale'),
                      'uuid': MtnMinecraftNbtValue.intArray(_modifierUuid),
                      'name': MtnMinecraftNbtValue.string('Big!'),
                      'amount': MtnMinecraftNbtValue.doubleValue(1),
                      'operation':
                          MtnMinecraftNbtValue.string('add_multiplied_base'),
                      'slot': MtnMinecraftNbtValue.string('body'),
                    },
                  ],
                ),
                'show_in_tooltip': MtnMinecraftNbtValue.byte(0),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemAttributeModifier modifier =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!
              .single;

      expect(modifier.attributeId, 'minecraft:generic.scale');
      expect(modifier.id, isNull);
      expect(modifier.legacyUuid, _uuid);
      expect(modifier.legacyName, 'Big!');
      expect(modifier.amount, 1);
      expect(
        modifier.operation,
        MtnMinecraftInfoAttributeModifierOperation.addMultipliedBase,
      );
      expect(
        modifier.slot,
        MtnMinecraftInfoItemAttributeModifierSlot.body,
      );
    });

    test('reads 1.20.5 direct list component form', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  'type':
                      MtnMinecraftNbtValue.string('examplemod:reach'),
                  'uuid': MtnMinecraftNbtValue.intArray(_modifierUuid),
                  'name': MtnMinecraftNbtValue.string('Extended reach'),
                  'amount': MtnMinecraftNbtValue.doubleValue(2.5),
                  'operation': MtnMinecraftNbtValue.string('add_value'),
                  'slot': MtnMinecraftNbtValue.string('hand'),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemAttributeModifier modifier =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!
              .single;

      expect(modifier.attributeId, 'examplemod:reach');
      expect(modifier.legacyUuid, _uuid);
      expect(modifier.legacyName, 'Extended reach');
      expect(modifier.amount, 2.5);
      expect(modifier.slot, MtnMinecraftInfoItemAttributeModifierSlot.hand);
    });

    test('reads current modifier ids and modern slot groups', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                _modernModifier(
                  attributeId: 'minecraft:attack_damage',
                  id: 'minecraft:base_attack_damage',
                  slot: 'armor',
                ),
                _modernModifier(
                  attributeId: 'examplemod:mount_speed',
                  id: 'examplemod:saddle_speed',
                  slot: 'saddle',
                ),
              ],
            ),
          },
        ),
      );

      final List<MtnMinecraftInfoItemAttributeModifier> modifiers =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!;

      expect(modifiers[0].id, 'minecraft:base_attack_damage');
      expect(modifiers[0].legacyUuid, isNull);
      expect(modifiers[0].legacyName, isNull);
      expect(modifiers[0].slot,
          MtnMinecraftInfoItemAttributeModifierSlot.armor);
      expect(modifiers[1].attributeId, 'examplemod:mount_speed');
      expect(modifiers[1].id, 'examplemod:saddle_speed');
      expect(modifiers[1].slot,
          MtnMinecraftInfoItemAttributeModifierSlot.saddle);
    });

    test('current id is authoritative over legacy identity fields', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  ..._modernModifier(
                    attributeId: 'minecraft:attack_speed',
                    id: 'examplemod:current',
                  ),
                  'uuid': MtnMinecraftNbtValue.string('ignored old data'),
                  'name': MtnMinecraftNbtValue.intValue(12),
                },
              ],
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemAttributeModifier modifier =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!
              .single;

      expect(modifier.id, 'examplemod:current');
      expect(modifier.legacyUuid, isNull);
      expect(modifier.legacyName, isNull);
    });

    test('reads 1.21.6 modifier display metadata', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                <String, MtnMinecraftNbtValue>{
                  ..._modernModifier(id: 'examplemod:default'),
                  'display': MtnMinecraftNbtValue.compound(
                    <String, MtnMinecraftNbtValue>{
                      'type': MtnMinecraftNbtValue.string('default'),
                    },
                  ),
                },
                <String, MtnMinecraftNbtValue>{
                  ..._modernModifier(id: 'examplemod:hidden'),
                  'display': MtnMinecraftNbtValue.compound(
                    <String, MtnMinecraftNbtValue>{
                      'type': MtnMinecraftNbtValue.string('hidden'),
                    },
                  ),
                },
                <String, MtnMinecraftNbtValue>{
                  ..._modernModifier(id: 'examplemod:override'),
                  'display': MtnMinecraftNbtValue.compound(
                    <String, MtnMinecraftNbtValue>{
                      'type': MtnMinecraftNbtValue.string('override'),
                      'value': MtnMinecraftNbtValue.string('Custom power'),
                    },
                  ),
                },
              ],
            ),
          },
        ),
      );

      final List<MtnMinecraftInfoItemAttributeModifier> modifiers =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!;

      expect(
        modifiers[0].display?.type,
        MtnMinecraftInfoItemAttributeModifierDisplayType.defaultDisplay,
      );
      expect(modifiers[0].display?.value, isNull);
      expect(
        modifiers[1].display?.type,
        MtnMinecraftInfoItemAttributeModifierDisplayType.hidden,
      );
      expect(modifiers[1].display?.value, isNull);
      expect(
        modifiers[2].display?.type,
        MtnMinecraftInfoItemAttributeModifierDisplayType.override,
      );
      expect(modifiers[2].display?.value?.plainText, 'Custom power');
    });

    test('explicit empty modifiers remain distinct from absent metadata',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _legacyItem(
          tag: <String, MtnMinecraftNbtValue>{
            'AttributeModifiers': _emptyList(),
          },
        ),
      );

      MtnMinecraftInfoItemStack item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.attributeModifiers, isEmpty);

      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _emptyList(),
          },
        ),
      );
      item = await _readItem(provider, world);
      expect(item.components, isNotNull);
      expect(item.components!.attributeModifiers, isEmpty);

      await _writeInventoryItem(worldDirectory, _legacyItem());
      item = await _readItem(provider, world);
      expect(item.components, isNull);
    });

    test('attribute modifier list is immutable', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _modifierList(
              <Map<String, MtnMinecraftNbtValue>>[
                _modernModifier(),
              ],
            ),
          },
        ),
      );

      final List<MtnMinecraftInfoItemAttributeModifier> modifiers =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!;

      expect(
        () => modifiers.add(
          const MtnMinecraftInfoItemAttributeModifier(
            attributeId: 'minecraft:attack_damage',
            id: 'examplemod:new',
            amount: 1,
            operation: MtnMinecraftInfoAttributeModifierOperation.addValue,
            slot: MtnMinecraftInfoItemAttributeModifierSlot.any,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('modern components remain authoritative over legacy modifiers',
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
              'AttributeModifiers': _modifierList(
                <Map<String, MtnMinecraftNbtValue>>[
                  _legacyModifier(name: 'Ignored'),
                ],
              ),
            },
          ),
        },
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;

      expect(components.damage, 1);
      expect(components.attributeModifiers, isNull);
    });

    test('attribute component removals are preserved and conflicts are invalid',
        () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            '!minecraft:attribute_modifiers':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );

      final MtnMinecraftInfoItemStackComponents components =
          (await _readItem(provider, world)).components!;
      expect(components.attributeModifiers, isNull);
      expect(
        components.removedComponentIds,
        contains('minecraft:attribute_modifiers'),
      );

      await _expectInvalid(
        provider,
        world,
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': _emptyList(),
            '!minecraft:attribute_modifiers':
                MtnMinecraftNbtValue.compound(<String, MtnMinecraftNbtValue>{}),
          },
        ),
      );
    });

    test('unknown modifier metadata remains tolerated', () async {
      await _writeInventoryItem(
        worldDirectory,
        _modernItem(
          components: <String, MtnMinecraftNbtValue>{
            'minecraft:attribute_modifiers': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'modifiers': _modifierList(
                  <Map<String, MtnMinecraftNbtValue>>[
                    <String, MtnMinecraftNbtValue>{
                      ..._modernModifier(id: 'examplemod:future'),
                      'examplemod:entry_data':
                          MtnMinecraftNbtValue.string('value'),
                    },
                  ],
                ),
                'show_in_tooltip': MtnMinecraftNbtValue.string(
                  'ignored historical presentation data',
                ),
                'examplemod:wrapper_data':
                    MtnMinecraftNbtValue.intValue(123),
              },
            ),
          },
        ),
      );

      final MtnMinecraftInfoItemAttributeModifier modifier =
          (await _readItem(provider, world))
              .components!
              .attributeModifiers!
              .single;

      expect(modifier.id, 'examplemod:future');
    });

    test('malformed legacy recognized modifier data invalidates player',
        () async {
      final List<MtnMinecraftNbtValue> invalidLists =
          <MtnMinecraftNbtValue>[
        MtnMinecraftNbtValue.string('bad'),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._legacyModifier(),
              'AttributeName': MtnMinecraftNbtValue.string(''),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._legacyModifier(),
              'UUID': MtnMinecraftNbtValue.intArray(<int>[1, 2, 3]),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._legacyModifier(),
              'Operation': MtnMinecraftNbtValue.intValue(3),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._legacyModifier(),
              'Slot': MtnMinecraftNbtValue.string('future_slot'),
            },
          ],
        ),
      ];

      for (final MtnMinecraftNbtValue invalid in invalidLists) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _legacyItem(
            tag: <String, MtnMinecraftNbtValue>{
              'AttributeModifiers': invalid,
            },
          ),
        );
      }
    });

    test('malformed modern recognized modifier data invalidates player',
        () async {
      final List<MtnMinecraftNbtValue> invalidComponents =
          <MtnMinecraftNbtValue>[
        MtnMinecraftNbtValue.intValue(1),
        MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'modifiers': MtnMinecraftNbtValue.string('bad'),
          },
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              'type': MtnMinecraftNbtValue.string('minecraft:attack_damage'),
              'amount': MtnMinecraftNbtValue.doubleValue(1),
              'operation': MtnMinecraftNbtValue.string('add_value'),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._modernModifier(),
              'id': MtnMinecraftNbtValue.string(''),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._modernModifier(),
              'amount': MtnMinecraftNbtValue.float(1),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._modernModifier(),
              'operation': MtnMinecraftNbtValue.string('multiply'),
            },
          ],
        ),
        _modifierList(
          <Map<String, MtnMinecraftNbtValue>>[
            <String, MtnMinecraftNbtValue>{
              ..._modernModifier(),
              'display': MtnMinecraftNbtValue.compound(
                <String, MtnMinecraftNbtValue>{
                  'type': MtnMinecraftNbtValue.string('override'),
                },
              ),
            },
          ],
        ),
      ];

      for (final MtnMinecraftNbtValue invalid in invalidComponents) {
        await _expectInvalid(
          provider,
          world,
          worldDirectory,
          _modernItem(
            components: <String, MtnMinecraftNbtValue>{
              'minecraft:attribute_modifiers': invalid,
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

Map<String, MtnMinecraftNbtValue> _legacyModifier({
  String attributeId = 'generic.attack_speed',
  String name = 'Modifier',
  MtnMinecraftNbtValue? operation,
  String? slot,
}) =>
    <String, MtnMinecraftNbtValue>{
      'AttributeName': MtnMinecraftNbtValue.string(attributeId),
      'Name': MtnMinecraftNbtValue.string(name),
      'UUID': MtnMinecraftNbtValue.intArray(_modifierUuid),
      'Amount': MtnMinecraftNbtValue.doubleValue(1),
      'Operation': operation ?? MtnMinecraftNbtValue.intValue(0),
      if (slot != null) 'Slot': MtnMinecraftNbtValue.string(slot),
    };

Map<String, MtnMinecraftNbtValue> _modernModifier({
  String attributeId = 'minecraft:attack_damage',
  String id = 'examplemod:modifier',
  String operation = 'add_value',
  String? slot,
}) =>
    <String, MtnMinecraftNbtValue>{
      'type': MtnMinecraftNbtValue.string(attributeId),
      'id': MtnMinecraftNbtValue.string(id),
      'amount': MtnMinecraftNbtValue.doubleValue(1),
      'operation': MtnMinecraftNbtValue.string(operation),
      if (slot != null) 'slot': MtnMinecraftNbtValue.string(slot),
    };

MtnMinecraftNbtValue _modifierList(
  List<Map<String, MtnMinecraftNbtValue>> modifiers,
) =>
    MtnMinecraftNbtValue.list(
      MtnMinecraftNbtList(
        elementType: MtnMinecraftNbtType.compound,
        values: modifiers
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
