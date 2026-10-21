import 'package:minecraft_models/minecraft_models.dart';

import '../mtn_minecraft_resource_item_entry.dart';
import 'mtn_minecraft_resource_helper_abs.dart';

/// Modern Minecraft 1.21.4+ entry under items/*.json.
final class MtnMinecraftResourceHelperModern extends MtnMinecraftResourceHelperAbs {
  MtnMinecraftResourceHelperModern()
      : super(
          name: 'modern',
          title: 'Modern Item Definitions',
          versionMin: MtnMinecraftVersion.parse(
            '1.21.4',
            type: MtnMinecraftGameVersionType.release,
          ),
        );

  @override
  String get entryDirectory => 'items';

  @override
  bool get usesEffectiveItemModel => true;

  @override
  MtnMinecraftResourceItemEntryKind get entryKind =>
      MtnMinecraftResourceItemEntryKind.itemDefinition;
}
