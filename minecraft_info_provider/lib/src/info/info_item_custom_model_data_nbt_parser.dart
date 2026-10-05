import '../nbt/minecraft_nbt.dart';
import 'info_item_custom_model_data.dart';

/// Internal cross-version parser for explicitly persisted item custom-model
/// data.
final class MtnMinecraftInfoItemCustomModelDataNbtParser {
  const MtnMinecraftInfoItemCustomModelDataNbtParser();

  MtnMinecraftInfoItemCustomModelData? parseLegacy(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? value = tag['CustomModelData'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.intValue) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }
    return MtnMinecraftInfoItemCustomModelData(
      legacyValue: value.asInt,
    );
  }

  MtnMinecraftInfoItemCustomModelData parseModern(
    MtnMinecraftNbtValue value,
  ) {
    if (value.type == MtnMinecraftNbtType.intValue) {
      return MtnMinecraftInfoItemCustomModelData(
        legacyValue: value.asInt,
      );
    }
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> data = value.asCompound;
    return MtnMinecraftInfoItemCustomModelData(
      floats: _optionalFloatList(data, 'floats'),
      flags: _optionalBooleanList(data, 'flags'),
      strings: _optionalStringList(data, 'strings'),
      colors: _optionalIntList(data, 'colors'),
    );
  }

  List<double> _optionalFloatList(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return const <double>[];
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (!_validListType(list, MtnMinecraftNbtType.float)) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }
    return List<double>.unmodifiable(
      list.values.map((MtnMinecraftNbtValue item) => item.asFloat),
    );
  }

  List<bool> _optionalBooleanList(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return const <bool>[];
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (!_validListType(list, MtnMinecraftNbtType.byte)) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final List<bool> result = <bool>[];
    for (final MtnMinecraftNbtValue item in list.values) {
      final int raw = item.asByte;
      if (raw != 0 && raw != 1) {
        throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
      }
      result.add(raw == 1);
    }
    return List<bool>.unmodifiable(result);
  }

  List<String> _optionalStringList(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return const <String>[];
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (!_validListType(list, MtnMinecraftNbtType.string)) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }
    return List<String>.unmodifiable(
      list.values.map((MtnMinecraftNbtValue item) => item.asString),
    );
  }

  List<int> _optionalIntList(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return const <int>[];
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (!_validListType(list, MtnMinecraftNbtType.intValue)) {
      throw const MtnMinecraftInfoItemCustomModelDataNbtParserException();
    }
    return List<int>.unmodifiable(
      list.values.map((MtnMinecraftNbtValue item) => item.asInt),
    );
  }

  bool _validListType(
    MtnMinecraftNbtList list,
    MtnMinecraftNbtType expected,
  ) =>
      list.values.isEmpty
          ? list.elementType == MtnMinecraftNbtType.end ||
              list.elementType == expected
          : list.elementType == expected;
}

final class MtnMinecraftInfoItemCustomModelDataNbtParserException
    implements Exception {
  const MtnMinecraftInfoItemCustomModelDataNbtParserException();
}
