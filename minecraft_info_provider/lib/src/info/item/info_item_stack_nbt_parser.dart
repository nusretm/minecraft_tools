import '../../nbt/minecraft_nbt.dart';
import 'info_item_stack.dart';
import 'info_item_stack_components_nbt_parser.dart';

/// Internal parser for serialized Minecraft item stacks.
///
/// Supports both the pre-1.20.5 `Count` byte representation and the 1.20.5+
/// `count` integer representation, then delegates persisted item properties
/// to the cross-version component parser.
final class MtnMinecraftInfoItemStackNbtParser {
  const MtnMinecraftInfoItemStackNbtParser();

  MtnMinecraftInfoItemStack? parse(MtnMinecraftNbtValue value) {
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoItemStackNbtParserException();
    }
    return parseCompound(value.asCompound);
  }

  MtnMinecraftInfoItemStack? parseCompound(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    if (data.isEmpty) return null;

    final MtnMinecraftNbtValue? idValue = data['id'];
    if (idValue?.type != MtnMinecraftNbtType.string ||
        idValue!.asString.isEmpty) {
      throw const MtnMinecraftInfoItemStackNbtParserException();
    }

    final String id = idValue.asString;
    final int count;
    final MtnMinecraftNbtValue? modernCount = data['count'];
    if (modernCount != null) {
      if (modernCount.type != MtnMinecraftNbtType.intValue) {
        throw const MtnMinecraftInfoItemStackNbtParserException();
      }
      count = modernCount.asInt;
    } else {
      final MtnMinecraftNbtValue? legacyCount = data['Count'];
      if (legacyCount == null) {
        count = 1;
      } else {
        if (legacyCount.type != MtnMinecraftNbtType.byte) {
          throw const MtnMinecraftInfoItemStackNbtParserException();
        }
        count = legacyCount.asByte & 0xff;
      }
    }

    if (count <= 0 || id == 'minecraft:air') return null;

    late final MtnMinecraftInfoItemStackComponents? components;
    try {
      components = MtnMinecraftInfoItemStackComponentsNbtParser(
        parseItem: parse,
      ).parse(data);
    } on MtnMinecraftInfoItemStackComponentsNbtParserException {
      throw const MtnMinecraftInfoItemStackNbtParserException();
    }

    return MtnMinecraftInfoItemStack(
      id: id,
      count: count,
      components: components,
    );
  }
}

final class MtnMinecraftInfoItemStackNbtParserException implements Exception {
  const MtnMinecraftInfoItemStackNbtParserException();
}
