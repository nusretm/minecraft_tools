import '../nbt/minecraft_nbt.dart';
import 'info_item_stack.dart';

/// Internal cross-version parser for persisted item-stack properties.
///
/// Pre-1.20.5 item `tag` data and 1.20.5+ `components` data are normalized
/// into the same semantic public model. If the modern `components` compound
/// exists it is authoritative and legacy `tag` is not consulted.
final class MtnMinecraftInfoItemStackComponentsNbtParser {
  const MtnMinecraftInfoItemStackComponentsNbtParser();

  MtnMinecraftInfoItemStackComponents? parse(
    Map<String, MtnMinecraftNbtValue> item,
  ) {
    final MtnMinecraftNbtValue? modernValue = item['components'];
    if (modernValue != null) {
      if (modernValue.type != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      return _parseModern(modernValue.asCompound);
    }

    final MtnMinecraftNbtValue? legacyValue = item['tag'];
    if (legacyValue == null) return null;
    if (legacyValue.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
    return _parseLegacy(legacyValue.asCompound);
  }

  MtnMinecraftInfoItemStackComponents? _parseLegacy(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final int? damage = _optionalNonNegativeInt(tag, 'Damage');
    final int? repairCost = _optionalNonNegativeInt(tag, 'RepairCost');
    final bool? unbreakable = _optionalLegacyBoolean(tag, 'Unbreakable');
    final Map<String, int>? enchantments =
        _optionalLegacyEnchantments(tag, 'Enchantments');
    final Map<String, int>? storedEnchantments =
        _optionalLegacyEnchantments(tag, 'StoredEnchantments');

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null) {
      return null;
    }

    return MtnMinecraftInfoItemStackComponents(
      damage: damage,
      repairCost: repairCost,
      unbreakable: unbreakable,
      enchantments: enchantments,
      storedEnchantments: storedEnchantments,
    );
  }

  MtnMinecraftInfoItemStackComponents? _parseModern(
    Map<String, MtnMinecraftNbtValue> components,
  ) {
    final Set<String> removedComponentIds = <String>{};
    for (final String key in components.keys) {
      if (!key.startsWith('!')) continue;
      final String id = key.substring(1);
      if (id.isEmpty) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      removedComponentIds.add(id);
    }

    const List<String> recognizedIds = <String>[
      'minecraft:damage',
      'minecraft:repair_cost',
      'minecraft:unbreakable',
      'minecraft:enchantments',
      'minecraft:stored_enchantments',
    ];
    for (final String id in recognizedIds) {
      if (components.containsKey(id) && removedComponentIds.contains(id)) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
    }

    final int? damage =
        _optionalNonNegativeInt(components, 'minecraft:damage');
    final int? repairCost =
        _optionalNonNegativeInt(components, 'minecraft:repair_cost');
    final bool? unbreakable =
        _optionalModernUnbreakable(components, 'minecraft:unbreakable');
    final Map<String, int>? enchantments =
        _optionalModernEnchantments(components, 'minecraft:enchantments');
    final Map<String, int>? storedEnchantments =
        _optionalModernEnchantments(
      components,
      'minecraft:stored_enchantments',
    );

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null &&
        removedComponentIds.isEmpty) {
      return null;
    }

    return MtnMinecraftInfoItemStackComponents(
      damage: damage,
      repairCost: repairCost,
      unbreakable: unbreakable,
      enchantments: enchantments,
      storedEnchantments: storedEnchantments,
      removedComponentIds: removedComponentIds,
    );
  }

  int? _optionalNonNegativeInt(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.intValue || value.asInt < 0) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
    return value.asInt;
  }

  bool? _optionalLegacyBoolean(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.byte ||
        (value.asByte != 0 && value.asByte != 1)) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
    return value.asByte == 1;
  }

  bool? _optionalModernUnbreakable(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
    return true;
  }

  Map<String, int>? _optionalLegacyEnchantments(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.values.isEmpty) {
      if (list.elementType != MtnMinecraftNbtType.end &&
          list.elementType != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      return const <String, int>{};
    }
    if (list.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }

    final Map<String, int> result = <String, int>{};
    for (final MtnMinecraftNbtValue entryValue in list.values) {
      final Map<String, MtnMinecraftNbtValue> entry = entryValue.asCompound;
      final MtnMinecraftNbtValue? id = entry['id'];
      final MtnMinecraftNbtValue? level = entry['lvl'];
      if (id?.type != MtnMinecraftNbtType.string ||
          id!.asString.isEmpty ||
          level?.type != MtnMinecraftNbtType.short) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }

      final int normalizedLevel = level!.asShort;
      if (normalizedLevel < 0 ||
          normalizedLevel > 255 ||
          result.containsKey(id.asString)) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      result[id.asString] = normalizedLevel;
    }
    return Map<String, int>.unmodifiable(result);
  }

  Map<String, int>? _optionalModernEnchantments(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> component = value.asCompound;
    final MtnMinecraftNbtValue? levelsValue = component['levels'];
    final Map<String, MtnMinecraftNbtValue> levels;
    if (levelsValue != null) {
      if (levelsValue.type != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      levels = levelsValue.asCompound;
    } else {
      levels = <String, MtnMinecraftNbtValue>{
        for (final MapEntry<String, MtnMinecraftNbtValue> entry
            in component.entries)
          if (entry.key != 'show_in_tooltip') entry.key: entry.value,
      };
    }

    final Map<String, int> result = <String, int>{};
    for (final MapEntry<String, MtnMinecraftNbtValue> entry
        in levels.entries) {
      if (entry.key.isEmpty ||
          entry.value.type != MtnMinecraftNbtType.intValue ||
          entry.value.asInt < 0 ||
          entry.value.asInt > 255) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      result[entry.key] = entry.value.asInt;
    }
    return Map<String, int>.unmodifiable(result);
  }
}

final class MtnMinecraftInfoItemStackComponentsNbtParserException
    implements Exception {
  const MtnMinecraftInfoItemStackComponentsNbtParserException();
}
