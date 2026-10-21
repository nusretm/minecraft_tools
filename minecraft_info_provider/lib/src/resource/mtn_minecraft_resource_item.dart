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
  List<Uint8List> get pngList => List<Uint8List>.unmodifiable(
        textures.where((MtnMinecraftResourceTexture texture) => texture.image != null)
            .map((MtnMinecraftResourceTexture texture) => texture.image!.png),
      );
}
