import '../nbt/minecraft_nbt.dart';
import 'info_item_stack.dart';
import 'info_item_stack_nbt_parser.dart';
import 'info_player.dart';

final class MtnMinecraftInfoPlayerInventoryData {
  const MtnMinecraftInfoPlayerInventoryData({
    required this.inventory,
    required this.enderChest,
    required this.equipment,
  });

  final List<MtnMinecraftInfoItemStack?>? inventory;
  final List<MtnMinecraftInfoItemStack?>? enderChest;
  final MtnMinecraftInfoPlayerEquipment? equipment;
}

/// Internal parser for player inventory, ender chest and equipment storage.
///
/// Legacy armor/off-hand inventory slots are normalized into the same semantic
/// equipment model as the 1.21.5+ `equipment` compound.
final class MtnMinecraftInfoPlayerInventoryNbtParser {
  const MtnMinecraftInfoPlayerInventoryNbtParser();

  static const int inventorySize = 36;
  static const int enderChestSize = 27;

  MtnMinecraftInfoPlayerInventoryData parse(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final _MtnMinecraftInfoLegacyInventoryData legacy =
        _parseLegacyInventory(data['Inventory']);
    final List<MtnMinecraftInfoItemStack?>? enderChest =
        _parseSlottedStorage(
      data['EnderItems'],
      size: enderChestSize,
    );
    final MtnMinecraftInfoPlayerEquipment? equipment =
        _parseEquipment(
      data['equipment'],
      legacy.equipment,
    );

    return MtnMinecraftInfoPlayerInventoryData(
      inventory: legacy.inventory,
      enderChest: enderChest,
      equipment: equipment,
    );
  }

  _MtnMinecraftInfoLegacyInventoryData _parseLegacyInventory(
    MtnMinecraftNbtValue? value,
  ) {
    if (value == null) {
      return const _MtnMinecraftInfoLegacyInventoryData(
        inventory: null,
        equipment: null,
      );
    }

    final MtnMinecraftNbtList list = _requiredCompoundList(value);
    final List<MtnMinecraftInfoItemStack?> inventory =
        List<MtnMinecraftInfoItemStack?>.filled(
      inventorySize,
      null,
      growable: false,
    );
    final Set<int> seenSlots = <int>{};

    MtnMinecraftInfoItemStack? head;
    MtnMinecraftInfoItemStack? chest;
    MtnMinecraftInfoItemStack? legs;
    MtnMinecraftInfoItemStack? feet;
    MtnMinecraftInfoItemStack? offHand;
    var hasLegacyEquipment = false;

    for (final MtnMinecraftNbtValue entry in list.values) {
      final Map<String, MtnMinecraftNbtValue> item = entry.asCompound;
      final int slot = _requiredSlot(item);

      if (slot >= 0 && slot < inventorySize) {
        if (!seenSlots.add(slot)) {
          throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
        }
        inventory[slot] = _parseItem(item);
        continue;
      }

      switch (slot) {
        case 100:
          if (!seenSlots.add(slot)) {
            throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
          }
          feet = _parseItem(item);
          hasLegacyEquipment = true;
          break;
        case 101:
          if (!seenSlots.add(slot)) {
            throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
          }
          legs = _parseItem(item);
          hasLegacyEquipment = true;
          break;
        case 102:
          if (!seenSlots.add(slot)) {
            throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
          }
          chest = _parseItem(item);
          hasLegacyEquipment = true;
          break;
        case 103:
          if (!seenSlots.add(slot)) {
            throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
          }
          head = _parseItem(item);
          hasLegacyEquipment = true;
          break;
        case -106:
          if (!seenSlots.add(slot)) {
            throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
          }
          offHand = _parseItem(item);
          hasLegacyEquipment = true;
          break;
        default:
          // Unknown/future/modded inventory slots are outside this foundation.
          continue;
      }
    }

    return _MtnMinecraftInfoLegacyInventoryData(
      inventory: List<MtnMinecraftInfoItemStack?>.unmodifiable(inventory),
      equipment: hasLegacyEquipment
          ? MtnMinecraftInfoPlayerEquipment(
              head: head,
              chest: chest,
              legs: legs,
              feet: feet,
              offHand: offHand,
            )
          : null,
    );
  }

  List<MtnMinecraftInfoItemStack?>? _parseSlottedStorage(
    MtnMinecraftNbtValue? value, {
    required int size,
  }) {
    if (value == null) return null;

    final MtnMinecraftNbtList list = _requiredCompoundList(value);
    final List<MtnMinecraftInfoItemStack?> result =
        List<MtnMinecraftInfoItemStack?>.filled(
      size,
      null,
      growable: false,
    );
    final Set<int> seenSlots = <int>{};

    for (final MtnMinecraftNbtValue entry in list.values) {
      final Map<String, MtnMinecraftNbtValue> item = entry.asCompound;
      final int slot = _requiredSlot(item);
      if (slot < 0 || slot >= size) {
        // Unknown/future/modded slots are outside this foundation.
        continue;
      }
      if (!seenSlots.add(slot)) {
        throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
      }
      result[slot] = _parseItem(item);
    }

    return List<MtnMinecraftInfoItemStack?>.unmodifiable(result);
  }

  MtnMinecraftInfoPlayerEquipment? _parseEquipment(
    MtnMinecraftNbtValue? value,
    MtnMinecraftInfoPlayerEquipment? legacy,
  ) {
    if (value == null) return legacy;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> equipment = value.asCompound;
    return MtnMinecraftInfoPlayerEquipment(
      head: _equipmentSlot(equipment, 'head', legacy?.head),
      chest: _equipmentSlot(equipment, 'chest', legacy?.chest),
      legs: _equipmentSlot(equipment, 'legs', legacy?.legs),
      feet: _equipmentSlot(equipment, 'feet', legacy?.feet),
      offHand: _equipmentSlot(equipment, 'offhand', legacy?.offHand),
    );
  }

  MtnMinecraftInfoItemStack? _equipmentSlot(
    Map<String, MtnMinecraftNbtValue> equipment,
    String name,
    MtnMinecraftInfoItemStack? legacy,
  ) {
    if (!equipment.containsKey(name)) return legacy;
    return _parseItemValue(equipment[name]!);
  }

  MtnMinecraftNbtList _requiredCompoundList(
    MtnMinecraftNbtValue value,
  ) {
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.values.isEmpty) {
      if (list.elementType != MtnMinecraftNbtType.end &&
          list.elementType != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
      }
      return list;
    }
    if (list.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }
    return list;
  }

  int _requiredSlot(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['Slot'];
    if (value?.type != MtnMinecraftNbtType.byte) {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }
    return value!.asByte;
  }

  MtnMinecraftInfoItemStack? _parseItem(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    try {
      return const MtnMinecraftInfoItemStackNbtParser().parseCompound(data);
    } on MtnMinecraftInfoItemStackNbtParserException {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }
  }

  MtnMinecraftInfoItemStack? _parseItemValue(
    MtnMinecraftNbtValue value,
  ) {
    try {
      return const MtnMinecraftInfoItemStackNbtParser().parse(value);
    } on MtnMinecraftInfoItemStackNbtParserException {
      throw const MtnMinecraftInfoPlayerInventoryNbtParserException();
    }
  }
}

final class _MtnMinecraftInfoLegacyInventoryData {
  const _MtnMinecraftInfoLegacyInventoryData({
    required this.inventory,
    required this.equipment,
  });

  final List<MtnMinecraftInfoItemStack?>? inventory;
  final MtnMinecraftInfoPlayerEquipment? equipment;
}

final class MtnMinecraftInfoPlayerInventoryNbtParserException
    implements Exception {
  const MtnMinecraftInfoPlayerInventoryNbtParserException();
}
