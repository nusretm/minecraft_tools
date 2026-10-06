import '../../nbt/minecraft_nbt.dart';
import 'info_item_stack.dart';

/// Internal cross-version parser for item stacks nested inside persisted item
/// metadata.
final class MtnMinecraftInfoItemNestedStackNbtParser {
  MtnMinecraftInfoItemNestedStackNbtParser({
    required this.parseItem,
  });

  final MtnMinecraftInfoItemStack? Function(MtnMinecraftNbtValue value)
      parseItem;

  Map<int, MtnMinecraftInfoItemStack>? parseLegacyContainer(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? blockEntityTag = tag['BlockEntityTag'];
    if (blockEntityTag == null ||
        blockEntityTag.type != MtnMinecraftNbtType.compound) {
      return null;
    }

    final MtnMinecraftNbtValue? items =
        blockEntityTag.asCompound['Items'];
    if (items == null) return null;
    return _parseLegacySlottedItems(items);
  }

  List<MtnMinecraftInfoItemStack>? parseLegacyBundle(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? items = tag['Items'];
    if (items == null) return null;
    return _parseItemList(items);
  }

  List<MtnMinecraftInfoItemStack>? parseLegacyChargedProjectiles(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    final MtnMinecraftNbtValue? items = tag['ChargedProjectiles'];
    if (items == null) return null;
    return _parseItemList(items);
  }

  Map<int, MtnMinecraftInfoItemStack> parseModernContainer(
    MtnMinecraftNbtValue value,
  ) {
    final MtnMinecraftNbtList list = _requiredCompoundList(value);
    final Map<int, MtnMinecraftInfoItemStack> result =
        <int, MtnMinecraftInfoItemStack>{};

    for (final MtnMinecraftNbtValue entryValue in list.values) {
      final Map<String, MtnMinecraftNbtValue> entry =
          entryValue.asCompound;
      final MtnMinecraftNbtValue? slotValue = entry['slot'];
      final MtnMinecraftNbtValue? itemValue = entry['item'];
      if (slotValue?.type != MtnMinecraftNbtType.intValue ||
          itemValue == null) {
        throw const MtnMinecraftInfoItemNestedStackNbtParserException();
      }

      final int slot = slotValue!.asInt;
      if (slot < 0 || slot > 255 || result.containsKey(slot)) {
        throw const MtnMinecraftInfoItemNestedStackNbtParserException();
      }

      final MtnMinecraftInfoItemStack item = _parseRequiredItem(itemValue);
      result[slot] = item;
    }

    return Map<int, MtnMinecraftInfoItemStack>.unmodifiable(result);
  }

  List<MtnMinecraftInfoItemStack> parseModernItemList(
    MtnMinecraftNbtValue value,
  ) =>
      _parseItemList(value);

  MtnMinecraftInfoItemStack parseModernItem(
    MtnMinecraftNbtValue value,
  ) =>
      _parseRequiredItem(value);

  Map<int, MtnMinecraftInfoItemStack> _parseLegacySlottedItems(
    MtnMinecraftNbtValue value,
  ) {
    final MtnMinecraftNbtList list = _requiredCompoundList(value);
    final Map<int, MtnMinecraftInfoItemStack> result =
        <int, MtnMinecraftInfoItemStack>{};

    for (final MtnMinecraftNbtValue entryValue in list.values) {
      final Map<String, MtnMinecraftNbtValue> entry =
          entryValue.asCompound;
      final MtnMinecraftNbtValue? slotValue = entry['Slot'];
      if (slotValue?.type != MtnMinecraftNbtType.byte) {
        throw const MtnMinecraftInfoItemNestedStackNbtParserException();
      }

      final int slot = slotValue!.asByte & 0xff;
      if (result.containsKey(slot)) {
        throw const MtnMinecraftInfoItemNestedStackNbtParserException();
      }

      final MtnMinecraftInfoItemStack item = _parseRequiredItem(entryValue);
      result[slot] = item;
    }

    return Map<int, MtnMinecraftInfoItemStack>.unmodifiable(result);
  }

  List<MtnMinecraftInfoItemStack> _parseItemList(
    MtnMinecraftNbtValue value,
  ) {
    final MtnMinecraftNbtList list = _requiredCompoundList(value);
    return List<MtnMinecraftInfoItemStack>.unmodifiable(
      list.values.map(_parseRequiredItem),
    );
  }

  MtnMinecraftInfoItemStack _parseRequiredItem(
    MtnMinecraftNbtValue value,
  ) {
    final MtnMinecraftInfoItemStack? item = parseItem(value);
    if (item == null) {
      throw const MtnMinecraftInfoItemNestedStackNbtParserException();
    }
    return item;
  }

  MtnMinecraftNbtList _requiredCompoundList(
    MtnMinecraftNbtValue value,
  ) {
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoItemNestedStackNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.values.isEmpty) {
      if (list.elementType != MtnMinecraftNbtType.end &&
          list.elementType != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoItemNestedStackNbtParserException();
      }
      return list;
    }
    if (list.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemNestedStackNbtParserException();
    }
    return list;
  }
}

final class MtnMinecraftInfoItemNestedStackNbtParserException
    implements Exception {
  const MtnMinecraftInfoItemNestedStackNbtParserException();
}
