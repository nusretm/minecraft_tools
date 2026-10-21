import 'dart:typed_data';

import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_location.dart';

/// Raw PNG resource, not a decoded bitmap or rendered item icon.
final class MtnMinecraftResourceImage {
  const MtnMinecraftResourceImage({
    required this.location,
    required this.resource,
  });

  /// Sprite ID, relative to textures/.
  final MtnMinecraftResourceLocation location;
  final MtnMinecraftResourceData resource;

  /// A defensive copy: caller mutations never modify the backing resource.
  Uint8List get png => Uint8List.fromList(resource.bytes);
}
