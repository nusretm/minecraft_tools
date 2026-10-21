import 'package:minecraft_models/minecraft_models.dart';

import 'mtn_minecraft_resource_helper_abs.dart';

/// Item-model component entry under models/item for 1.21.2–1.21.3.
final class MtnMinecraftResourceHelperItemModelComponent extends MtnMinecraftResourceHelperAbs {
  MtnMinecraftResourceHelperItemModelComponent()
      : super(
          name: 'item-model-component',
          title: 'Item Model Component',
          versionMin: MtnMinecraftVersion.parse(
            '1.21.2',
            type: MtnMinecraftGameVersionType.release,
          ),
          versionMax: MtnMinecraftVersion.parse(
            '1.21.3',
            type: MtnMinecraftGameVersionType.release,
          ),
        );

  @override
  String get entryDirectory => 'models/item';

  @override
  bool get usesEffectiveItemModel => true;
}
