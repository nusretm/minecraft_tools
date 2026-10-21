/// Pixel rectangle inside the original PNG, not model-face UV coordinates.
///
/// Coordinates are in source image pixels. The PNG is never cropped or decoded
/// by the resource layer.
final class MtnMinecraftResourceImageRegion {
  MtnMinecraftResourceImageRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) {
    if (x < 0 || y < 0 || width <= 0 || height <= 0) {
      throw ArgumentError('Image region must have non-negative coordinates and positive dimensions.');
    }
  }

  final int x;
  final int y;
  final int width;
  final int height;
}
