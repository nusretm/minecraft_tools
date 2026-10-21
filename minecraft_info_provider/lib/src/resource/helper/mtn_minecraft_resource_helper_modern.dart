import 'package:minecraft_models/minecraft_models.dart';

import '../mtn_minecraft_resource_environment.dart';
import '../mtn_minecraft_resource_item.dart';
import '../mtn_minecraft_resource_item_entry.dart';
import '../mtn_minecraft_resource_item_model_resolver.dart';
import '../mtn_minecraft_resource_item_request.dart';
import '../mtn_minecraft_resource_loader.dart';
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

  /// Resolve modern item graph only; the shared helper remains authoritative
  /// for entry selection, normal model inheritance and raw texture reads.
  @override
  Future<MtnMinecraftResourceItem?> loadItem(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceItemRequest request, {
    MtnMinecraftResourceEnvironment? environment,
  }) async {
    final MtnMinecraftResourceItemEntry? entry = await loadItemEntry(loader, request);
    if (entry == null) return null;
    final bool allowTextureObjects = environment != null &&
        environment.version >= MtnMinecraftVersion.parse(
          '26.1', type: MtnMinecraftGameVersionType.release,
        );
    return const MtnMinecraftResourceItemModelResolver().resolve(
      loader, this, entry, allowTextureObjects: allowTextureObjects,
    );
  }
}
