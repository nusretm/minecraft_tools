import 'nbt_type.dart';
import 'nbt_value.dart';

final class MtnMinecraftNbtDocument {
  MtnMinecraftNbtDocument({
    required this.name,
    required this.root,
  }) {
    if (root.type == MtnMinecraftNbtType.end) {
      throw ArgumentError.value(
        root.type,
        'root',
        'TAG_End cannot be the root tag of an NBT document',
      );
    }
  }

  final String name;
  final MtnMinecraftNbtValue root;
}
