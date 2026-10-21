import '../info/item/info_item_name.dart';
import 'mtn_minecraft_resource_location.dart';

/// Item registry identity and optionally known effective minecraft:item_model.
///
/// An absent effective identity is unknown, not a known registry default.
final class MtnMinecraftResourceItemRequest {
  MtnMinecraftResourceItemRequest({
    required this.item,
    this.effectiveItemModel,
  }) {
    MtnMinecraftResourceLocation.parse(item.id);
  }

  final MtnMinecraftInfoItemIdentity item;
  final MtnMinecraftResourceLocation? effectiveItemModel;

  String get itemId => item.id;
}
