import 'dart:typed_data';

import 'mtn_minecraft_resource_item_entry.dart';
import 'mtn_minecraft_resource_model.dart';
import 'mtn_minecraft_resource_texture.dart';

/// Static resource result, not a rendered PNG or runtime state evaluator.
final class MtnMinecraftResourceItem {
  MtnMinecraftResourceItem({
    required this.entry,
    required this.model,
    required Iterable<MtnMinecraftResourceTexture> textures,
    required Iterable<MtnMinecraftResourceIssue> issues,
  })  : textures = List<MtnMinecraftResourceTexture>.unmodifiable(textures),
        issues = List<MtnMinecraftResourceIssue>.unmodifiable(issues);

  final MtnMinecraftResourceItemEntry entry;
  final MtnMinecraftResourceModel? model;
  final List<MtnMinecraftResourceTexture> textures;
  final List<MtnMinecraftResourceIssue> issues;

  bool get isComplete => issues.isEmpty;

  /// Raw image candidates in layer order; never a flattened final item icon.
  ///
  /// The particle symbol is not another composited image layer when layer
  /// bindings are present. The complete symbol list remains in [textures].
  List<Uint8List> get pngList {
    final RegExp layerPattern = RegExp(r'^layer[0-9]+
}
);
    final bool hasLayers = textures.any(
      (MtnMinecraftResourceTexture texture) => layerPattern.hasMatch(texture.symbol),
    );
    return List<Uint8List>.unmodifiable(
      textures.where(
        (MtnMinecraftResourceTexture texture) =>
            texture.image != null &&
            (!hasLayers || layerPattern.hasMatch(texture.symbol)),
      ).map((MtnMinecraftResourceTexture texture) => texture.image!.png),
    );
  }
}
