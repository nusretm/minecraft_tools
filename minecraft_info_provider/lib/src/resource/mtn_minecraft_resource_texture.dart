import 'mtn_minecraft_resource_image.dart';
import 'mtn_minecraft_resource_location.dart';

/// A texture-symbol binding in the effective model.
final class MtnMinecraftResourceTexture {
  const MtnMinecraftResourceTexture({
    required this.symbol,
    required this.reference,
    required this.location,
    required this.image,
    this.forceTranslucent = false,
  });

  /// Effective model symbol, e.g. layer0 or particle.
  final String symbol;
  /// Raw effective value, potentially a #symbol indirection.
  final String reference;
  /// Concrete texture resource location when available.
  final MtnMinecraftResourceLocation? location;
  /// Backing PNG and source provenance, if found.
  final MtnMinecraftResourceImage? image;
  /// 26.1 block-model texture hint; no blending is performed in Pure Dart.
  final bool forceTranslucent;
}
