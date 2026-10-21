import 'dart:convert';
import 'dart:typed_data';

import 'mtn_minecraft_resource_image_region.dart';

/// Computes the first logical animated frame from PNG IHDR and .png.mcmeta.
///
/// The input PNG remains opaque: this parser reads dimensions only. Animation
/// timing/interpolation are validated as metadata, never evaluated or rendered.
final class MtnMinecraftResourceImageAnimationParser {
  const MtnMinecraftResourceImageAnimationParser();

  /// Returns null when metadata contains no animation section.
  ///
  /// Invalid animation metadata, PNG headers, frame geometry and frame
  /// references fail with FormatException instead of silently using a wrong
  /// frame or borrowing metadata from another resource source.
  MtnMinecraftResourceImageRegion? parse({
    required Uint8List png,
    required Uint8List metadata,
  }) {
    final Object? decoded = jsonDecode(utf8.decode(metadata));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('PNG metadata must be a JSON object.');
    }
    if (!decoded.containsKey('animation')) return null;

    final Object? animationValue = decoded['animation'];
    if (animationValue is! Map<String, dynamic>) {
      throw const FormatException('PNG animation must be a JSON object.');
    }
    final Map<String, dynamic> animation = animationValue;
    final (int imageWidth, int imageHeight) = _readPngDimensions(png);

    final int? explicitWidth = _positiveInt(animation, 'width');
    final int? explicitHeight = _positiveInt(animation, 'height');
    _positiveInt(animation, 'frametime');
    if (animation.containsKey('interpolate') && animation['interpolate'] is! bool) {
      throw const FormatException('PNG animation.interpolate must be a boolean.');
    }

    // Vanilla default is a square frame with the smaller image dimension.
    // If one dimension is explicitly supplied, the other uses the full image
    // dimension, not the square default.
    final int defaultSide = imageWidth < imageHeight ? imageWidth : imageHeight;
    final int frameWidth = explicitWidth ?? (explicitHeight == null ? defaultSide : imageWidth);
    final int frameHeight = explicitHeight ?? (explicitWidth == null ? defaultSide : imageHeight);
    if (imageWidth % frameWidth != 0 || imageHeight % frameHeight != 0) {
      throw const FormatException('PNG animation frame dimensions must divide image dimensions.');
    }

    final int columns = imageWidth ~/ frameWidth;
    final int rows = imageHeight ~/ frameHeight;
    int firstFrame = 0;
    if (animation.containsKey('frames')) {
      final Object? framesValue = animation['frames'];
      if (framesValue is! List<dynamic> || framesValue.isEmpty) {
        throw const FormatException('PNG animation.frames must be a non-empty list.');
      }
      for (int position = 0; position < framesValue.length; position++) {
        final Object? entry = framesValue[position];
        final int index;
        if (entry is int) {
          index = entry;
        } else if (entry is Map<String, dynamic>) {
          final Object? rawIndex = entry['index'];
          if (rawIndex is! int) {
            throw const FormatException('PNG animation frame.index must be an integer.');
          }
          _positiveInt(entry, 'time');
          index = rawIndex;
        } else {
          throw const FormatException('PNG animation frame must be an integer or indexed object.');
        }
        if (index < 0 || index ~/ columns >= rows) {
          throw FormatException('PNG animation frame index $index is outside the source image.');
        }
        if (position == 0) firstFrame = index;
      }
    }

    return MtnMinecraftResourceImageRegion(
      x: (firstFrame % columns) * frameWidth,
      y: (firstFrame ~/ columns) * frameHeight,
      width: frameWidth,
      height: frameHeight,
    );
  }

  static int? _positiveInt(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) return null;
    final Object? value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('PNG animation.$key must be a positive integer.');
    }
    return value;
  }

  static (int, int) _readPngDimensions(Uint8List png) {
    if (png.length < 33 ||
        png[0] != 0x89 || png[1] != 0x50 || png[2] != 0x4e || png[3] != 0x47 ||
        png[4] != 0x0d || png[5] != 0x0a || png[6] != 0x1a || png[7] != 0x0a ||
        png[8] != 0 || png[9] != 0 || png[10] != 0 || png[11] != 13 ||
        png[12] != 0x49 || png[13] != 0x48 || png[14] != 0x44 || png[15] != 0x52) {
      throw const FormatException('Animated texture has an invalid PNG IHDR header.');
    }
    final ByteData header = ByteData.sublistView(png);
    final int width = header.getUint32(16, Endian.big);
    final int height = header.getUint32(20, Endian.big);
    if (width <= 0 || height <= 0) {
      throw const FormatException('Animated PNG has non-positive dimensions.');
    }
    return (width, height);
  }
}
