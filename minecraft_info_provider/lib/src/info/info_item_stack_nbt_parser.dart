import '../nbt/minecraft_nbt.dart';
import 'info_item_stack.dart';

/// Internal parser for serialized Minecraft item stacks.
///
/// Supports both the pre-1.20.5 `Count` byte representation and the 1.20.5+
/// `count` integer representation. Legacy `tag` and modern `components`
/// are deliberately ignored by this foundation.
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

    return MtnMinecraftInfoItemStack(
      id: id,
      count: count,
    );
  }
}

final class MtnMinecraftInfoItemStackNbtParserException implements Exception {
  const MtnMinecraftInfoItemStackNbtParserException();
}
