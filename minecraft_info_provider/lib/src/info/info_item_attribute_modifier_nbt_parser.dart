import '../nbt/minecraft_nbt.dart';
import '../text/minecraft_text.dart';
import 'info_item_attribute_modifier.dart';
import 'info_nbt_uuid_parser.dart';

/// Internal cross-version parser for explicitly persisted item attribute
/// modifiers.
final class MtnMinecraftInfoItemAttributeModifierNbtParser {
  const MtnMinecraftInfoItemAttributeModifierNbtParser();

  List<MtnMinecraftInfoItemAttributeModifier>? parseLegacy(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? value = tag['AttributeModifiers'];
    if (value == null) return null;
    return _parseList(value, _parseLegacyEntry);
  }

  List<MtnMinecraftInfoItemAttributeModifier> parseModern(
    MtnMinecraftNbtValue value,
  ) {
    if (value.type == MtnMinecraftNbtType.list) {
      return _parseList(value, _parseModernEntry);
    }
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> component = value.asCompound;
    final MtnMinecraftNbtValue? modifiers = component['modifiers'];
    if (modifiers == null) {
      return const <MtnMinecraftInfoItemAttributeModifier>[];
    }
    return _parseList(modifiers, _parseModernEntry);
  }

  List<MtnMinecraftInfoItemAttributeModifier> _parseList(
    MtnMinecraftNbtValue value,
    MtnMinecraftInfoItemAttributeModifier Function(
      Map<String, MtnMinecraftNbtValue> data,
    ) parseEntry,
  ) {
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.values.isEmpty) {
      if (list.elementType != MtnMinecraftNbtType.end &&
          list.elementType != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
      }
      return const <MtnMinecraftInfoItemAttributeModifier>[];
    }
    if (list.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    return List<MtnMinecraftInfoItemAttributeModifier>.unmodifiable(
      list.values.map(
        (MtnMinecraftNbtValue entry) => parseEntry(entry.asCompound),
      ),
    );
  }

  MtnMinecraftInfoItemAttributeModifier _parseLegacyEntry(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final String attributeId = _requiredString(data, 'AttributeName');
    final String legacyName = _requiredString(
      data,
      'Name',
      allowEmpty: true,
    );
    final MtnMinecraftNbtValue? uuidValue = data['UUID'];
    if (uuidValue == null) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    final String legacyUuid;
    try {
      legacyUuid = const MtnMinecraftInfoNbtUuidParser().parse(uuidValue);
    } on MtnMinecraftInfoNbtUuidParserException {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    return MtnMinecraftInfoItemAttributeModifier(
      attributeId: attributeId,
      legacyUuid: legacyUuid,
      legacyName: legacyName,
      amount: _requiredDouble(data, 'Amount'),
      operation: _legacyOperation(data, 'Operation'),
      slot: _slot(data, 'Slot'),
    );
  }

  MtnMinecraftInfoItemAttributeModifier _parseModernEntry(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final String attributeId = _requiredString(data, 'type');

    final String? id;
    final String? legacyUuid;
    final String? legacyName;
    if (data.containsKey('id')) {
      id = _requiredString(data, 'id');
      legacyUuid = null;
      legacyName = null;
    } else {
      final MtnMinecraftNbtValue? uuidValue = data['uuid'];
      if (uuidValue == null) {
        throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
      }
      try {
        legacyUuid = const MtnMinecraftInfoNbtUuidParser().parse(uuidValue);
      } on MtnMinecraftInfoNbtUuidParserException {
        throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
      }
      legacyName = _requiredString(
        data,
        'name',
        allowEmpty: true,
      );
      id = null;
    }

    return MtnMinecraftInfoItemAttributeModifier(
      attributeId: attributeId,
      id: id,
      legacyUuid: legacyUuid,
      legacyName: legacyName,
      amount: _requiredDouble(data, 'amount'),
      operation: _modernOperation(data, 'operation'),
      slot: _slot(data, 'slot'),
      display: _optionalDisplay(data),
    );
  }

  String _requiredString(
    Map<String, MtnMinecraftNbtValue> data,
    String name, {
    bool allowEmpty = false,
  }) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value?.type != MtnMinecraftNbtType.string ||
        (!allowEmpty && value!.asString.isEmpty)) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }
    return value!.asString;
  }

  double _requiredDouble(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value?.type != MtnMinecraftNbtType.doubleValue) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }
    return value!.asDouble;
  }

  MtnMinecraftInfoAttributeModifierOperation _legacyOperation(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    final int operation = switch (value.type) {
      MtnMinecraftNbtType.byte => value.asByte,
      MtnMinecraftNbtType.intValue => value.asInt,
      _ => throw const MtnMinecraftInfoItemAttributeModifierNbtParserException(),
    };

    return switch (operation) {
      0 => MtnMinecraftInfoAttributeModifierOperation.addValue,
      1 => MtnMinecraftInfoAttributeModifierOperation.addMultipliedBase,
      2 => MtnMinecraftInfoAttributeModifierOperation.addMultipliedTotal,
      _ => throw const MtnMinecraftInfoItemAttributeModifierNbtParserException(),
    };
  }

  MtnMinecraftInfoAttributeModifierOperation _modernOperation(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final String operation = _requiredString(data, name);
    return switch (operation) {
      'add_value' => MtnMinecraftInfoAttributeModifierOperation.addValue,
      'add_multiplied_base' =>
        MtnMinecraftInfoAttributeModifierOperation.addMultipliedBase,
      'add_multiplied_total' =>
        MtnMinecraftInfoAttributeModifierOperation.addMultipliedTotal,
      _ => throw const MtnMinecraftInfoItemAttributeModifierNbtParserException(),
    };
  }

  MtnMinecraftInfoItemAttributeModifierSlot _slot(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return MtnMinecraftInfoItemAttributeModifierSlot.any;
    if (value.type != MtnMinecraftNbtType.string) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    return switch (value.asString) {
      'any' => MtnMinecraftInfoItemAttributeModifierSlot.any,
      'hand' => MtnMinecraftInfoItemAttributeModifierSlot.hand,
      'armor' => MtnMinecraftInfoItemAttributeModifierSlot.armor,
      'mainhand' => MtnMinecraftInfoItemAttributeModifierSlot.mainHand,
      'offhand' => MtnMinecraftInfoItemAttributeModifierSlot.offHand,
      'head' => MtnMinecraftInfoItemAttributeModifierSlot.head,
      'chest' => MtnMinecraftInfoItemAttributeModifierSlot.chest,
      'legs' => MtnMinecraftInfoItemAttributeModifierSlot.legs,
      'feet' => MtnMinecraftInfoItemAttributeModifierSlot.feet,
      'body' => MtnMinecraftInfoItemAttributeModifierSlot.body,
      'saddle' => MtnMinecraftInfoItemAttributeModifierSlot.saddle,
      _ => throw const MtnMinecraftInfoItemAttributeModifierNbtParserException(),
    };
  }

  MtnMinecraftInfoItemAttributeModifierDisplay? _optionalDisplay(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['display'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> display = value.asCompound;
    final String type = _requiredString(display, 'type');
    switch (type) {
      case 'default':
        return const MtnMinecraftInfoItemAttributeModifierDisplay(
          type: MtnMinecraftInfoItemAttributeModifierDisplayType.defaultDisplay,
        );
      case 'hidden':
        return const MtnMinecraftInfoItemAttributeModifierDisplay(
          type: MtnMinecraftInfoItemAttributeModifierDisplayType.hidden,
        );
      case 'override':
        final MtnMinecraftNbtValue? textValue = display['value'];
        if (textValue == null) {
          throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
        }
        final MtnMinecraftText text;
        try {
          text = MtnMinecraftText.fromNbt(textValue);
        } on FormatException {
          throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
        }
        return MtnMinecraftInfoItemAttributeModifierDisplay(
          type: MtnMinecraftInfoItemAttributeModifierDisplayType.override,
          value: text,
        );
      default:
        throw const MtnMinecraftInfoItemAttributeModifierNbtParserException();
    }
  }
}

final class MtnMinecraftInfoItemAttributeModifierNbtParserException
    implements Exception {
  const MtnMinecraftInfoItemAttributeModifierNbtParserException();
}
