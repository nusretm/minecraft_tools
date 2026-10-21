import 'dart:typed_data';

import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_image_region.dart';
import 'mtn_minecraft_resource_location.dart';

/// Raw PNG resource, not a decoded bitmap or rendered item icon.
final class MtnMinecraftResourceImage {
  const MtnMinecraftResourceImage({
    required this.location,
    required this.resource,
    this.region,
  });

  /// Sprite ID, relative to textures/.
  final MtnMinecraftResourceLocation location;
  final MtnMinecraftResourceData resource;

  /// First logical animation frame in backing PNG pixels, if animated.
  /// Null uses the full PNG. This is not model UV or a cropped image.
  final MtnMinecraftResourceImageRegion? region;

  /// A defensive copy: caller mutations never modify the backing resource.
  Uint8List get png => Uint8List.fromList(resource.bytes);
}
