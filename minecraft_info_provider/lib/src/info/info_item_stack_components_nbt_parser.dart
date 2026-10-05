import '../nbt/minecraft_nbt.dart';
import '../text/minecraft_text.dart';
import '../text/minecraft_text_component_parser.dart';
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
    final ({
      MtnMinecraftText? customName,
      List<MtnMinecraftText>? lore,
    }) display = _optionalLegacyDisplay(tag);

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null &&
        display.customName == null &&
        display.lore == null) {
      return null;
    }

    return MtnMinecraftInfoItemStackComponents(
      damage: damage,
      repairCost: repairCost,
      unbreakable: unbreakable,
      enchantments: enchantments,
      storedEnchantments: storedEnchantments,
      customName: display.customName,
      lore: display.lore,
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
      'minecraft:custom_name',
      'minecraft:item_name',
      'minecraft:lore',
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
    final MtnMinecraftText? customName =
        _optionalModernText(components, 'minecraft:custom_name');
    final MtnMinecraftText? itemName =
        _optionalModernText(components, 'minecraft:item_name');
    final List<MtnMinecraftText>? lore =
        _optionalModernLore(components, 'minecraft:lore');

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null &&
        customName == null &&
        itemName == null &&
        lore == null &&
        removedComponentIds.isEmpty) {
      return null;
    }

    return MtnMinecraftInfoItemStackComponents(
      damage: damage,
      repairCost: repairCost,
      unbreakable: unbreakable,
      enchantments: enchantments,
      storedEnchantments: storedEnchantments,
      customName: customName,
      itemName: itemName,
      lore: lore,
      removedComponentIds: removedComponentIds,
    );
  }

  ({
    MtnMinecraftText? customName,
    List<MtnMinecraftText>? lore,
  }) _optionalLegacyDisplay(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? value = tag['display'];
    if (value == null) {
      return (customName: null, lore: null);
    }
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> display = value.asCompound;
    final MtnMinecraftText? customName;
    final MtnMinecraftNbtValue? nameValue = display['Name'];
    if (nameValue == null) {
      customName = null;
    } else {
      if (nameValue.type != MtnMinecraftNbtType.string) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      customName = _parseJsonText(nameValue.asString);
    }

    final List<MtnMinecraftText>? lore;
    final MtnMinecraftNbtValue? loreValue = display['Lore'];
    if (loreValue == null) {
      lore = null;
    } else {
      if (loreValue.type != MtnMinecraftNbtType.list) {
        throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
      }
      final MtnMinecraftNbtList list = loreValue.asList;
      if (list.values.isEmpty) {
        if (list.elementType != MtnMinecraftNbtType.end &&
            list.elementType != MtnMinecraftNbtType.string) {
          throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
        }
        lore = const <MtnMinecraftText>[];
      } else {
        if (list.elementType != MtnMinecraftNbtType.string) {
          throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
        }
        lore = List<MtnMinecraftText>.unmodifiable(
          list.values.map(
            (MtnMinecraftNbtValue line) => _parseJsonText(line.asString),
          ),
        );
      }
    }

    return (customName: customName, lore: lore);
  }

  MtnMinecraftText? _optionalModernText(
    Map<String, MtnMinecraftNbtValue> components,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = components[name];
    if (value == null) return null;
    return _parseNbtText(value);
  }

  List<MtnMinecraftText>? _optionalModernLore(
    Map<String, MtnMinecraftNbtValue> components,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = components[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }

    return List<MtnMinecraftText>.unmodifiable(
      value.asList.values.map(_parseNbtText),
    );
  }

  MtnMinecraftText _parseJsonText(String source) {
    try {
      return const MtnMinecraftTextComponentParser().parseJsonSource(source);
    } on MtnMinecraftTextComponentParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  MtnMinecraftText _parseNbtText(MtnMinecraftNbtValue value) {
    try {
      return const MtnMinecraftTextComponentParser().parseNbtValue(value);
    } on MtnMinecraftTextComponentParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
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
