import '../nbt/minecraft_nbt.dart';
import '../text/minecraft_text.dart';
import 'info_item_attribute_modifier.dart';
import 'info_item_attribute_modifier_nbt_parser.dart';
import 'info_item_custom_model_data.dart';
import 'info_item_custom_model_data_nbt_parser.dart';
import 'info_item_stack.dart';
import 'info_potion_contents.dart';
import 'info_potion_contents_nbt_parser.dart';

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
    final MtnMinecraftInfoPotionContents? potionContents =
        _optionalLegacyPotionContents(tag);
    final List<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers =
        _optionalLegacyAttributeModifiers(tag);
    final MtnMinecraftInfoItemCustomModelData? customModelData =
        _optionalLegacyCustomModelData(tag);

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null &&
        display.customName == null &&
        display.lore == null &&
        potionContents == null &&
        attributeModifiers == null &&
        customModelData == null) {
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
      potionContents: potionContents,
      attributeModifiers: attributeModifiers,
      customModelData: customModelData,
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
      'minecraft:potion_contents',
      'minecraft:potion_duration_scale',
      'minecraft:attribute_modifiers',
      'minecraft:custom_model_data',
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
    final MtnMinecraftInfoPotionContents? potionContents =
        _optionalModernPotionContents(
      components,
      'minecraft:potion_contents',
    );
    final double? potionDurationScale = _optionalNonNegativeFloat(
      components,
      'minecraft:potion_duration_scale',
    );
    final List<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers =
        _optionalModernAttributeModifiers(
      components,
      'minecraft:attribute_modifiers',
    );
    final MtnMinecraftInfoItemCustomModelData? customModelData =
        _optionalModernCustomModelData(
      components,
      'minecraft:custom_model_data',
    );

    if (damage == null &&
        repairCost == null &&
        unbreakable == null &&
        enchantments == null &&
        storedEnchantments == null &&
        customName == null &&
        itemName == null &&
        lore == null &&
        potionContents == null &&
        potionDurationScale == null &&
        attributeModifiers == null &&
        customModelData == null &&
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
      potionContents: potionContents,
      potionDurationScale: potionDurationScale,
      attributeModifiers: attributeModifiers,
      customModelData: customModelData,
      removedComponentIds: removedComponentIds,
    );
  }

  MtnMinecraftInfoItemCustomModelData? _optionalLegacyCustomModelData(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    try {
      return const MtnMinecraftInfoItemCustomModelDataNbtParser()
          .parseLegacy(tag);
    } on MtnMinecraftInfoItemCustomModelDataNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  MtnMinecraftInfoItemCustomModelData? _optionalModernCustomModelData(
    Map<String, MtnMinecraftNbtValue> components,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = components[name];
    if (value == null) return null;
    try {
      return const MtnMinecraftInfoItemCustomModelDataNbtParser()
          .parseModern(value);
    } on MtnMinecraftInfoItemCustomModelDataNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  List<MtnMinecraftInfoItemAttributeModifier>?
      _optionalLegacyAttributeModifiers(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    try {
      return const MtnMinecraftInfoItemAttributeModifierNbtParser()
          .parseLegacy(tag);
    } on MtnMinecraftInfoItemAttributeModifierNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  List<MtnMinecraftInfoItemAttributeModifier>?
      _optionalModernAttributeModifiers(
    Map<String, MtnMinecraftNbtValue> components,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = components[name];
    if (value == null) return null;
    try {
      return const MtnMinecraftInfoItemAttributeModifierNbtParser()
          .parseModern(value);
    } on MtnMinecraftInfoItemAttributeModifierNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  MtnMinecraftInfoPotionContents? _optionalLegacyPotionContents(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    try {
      return const MtnMinecraftInfoPotionContentsNbtParser().parseLegacy(tag);
    } on MtnMinecraftInfoPotionContentsNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  MtnMinecraftInfoPotionContents? _optionalModernPotionContents(
    Map<String, MtnMinecraftNbtValue> components,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = components[name];
    if (value == null) return null;
    try {
      return const MtnMinecraftInfoPotionContentsNbtParser().parseModern(value);
    } on MtnMinecraftInfoPotionContentsNbtParserException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  double? _optionalNonNegativeFloat(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.float || value.asFloat < 0) {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
    return value.asFloat;
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
      return MtnMinecraftText.fromJson(source);
    } on FormatException {
      throw const MtnMinecraftInfoItemStackComponentsNbtParserException();
    }
  }

  MtnMinecraftText _parseNbtText(MtnMinecraftNbtValue value) {
    try {
      return MtnMinecraftText.fromNbt(value);
    } on FormatException {
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
