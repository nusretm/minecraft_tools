import '../nbt/minecraft_nbt.dart';

/// Internal parser for Minecraft's four-int UUID NBT representation.
final class MtnMinecraftInfoNbtUuidParser {
  const MtnMinecraftInfoNbtUuidParser();

  String parse(MtnMinecraftNbtValue value) {
    if (value.type != MtnMinecraftNbtType.intArray ||
        value.asIntArray.length != 4) {
      throw const MtnMinecraftInfoNbtUuidParserException();
    }

    final String digits = value.asIntArray
        .map(
          (int part) =>
              (part & 0xffffffff).toRadixString(16).padLeft(8, '0'),
        )
        .join();

    return '${digits.substring(0, 8)}-'
        '${digits.substring(8, 12)}-'
        '${digits.substring(12, 16)}-'
        '${digits.substring(16, 20)}-'
        '${digits.substring(20)}';
  }
}

final class MtnMinecraftInfoNbtUuidParserException implements Exception {
  const MtnMinecraftInfoNbtUuidParserException();
}
