import 'package:minecraft_models/minecraft_models.dart';

import 'mtn_minecraft_resource_helper_abs.dart';

/// Item-registry entry for Minecraft releases through 1.21.1 inclusive.
final class MtnMinecraftResourceHelperLegacy extends MtnMinecraftResourceHelperAbs {
  MtnMinecraftResourceHelperLegacy()
      : super(
          name: 'legacy',
          title: 'Legacy Item Models',
          versionMax: MtnMinecraftVersion.parse(
            '1.21.1',
            type: MtnMinecraftGameVersionType.release,
          ),
        );

  @override
  String get entryDirectory => 'models/item';
}
