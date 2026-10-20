import 'dart:typed_data';

import 'mtn_minecraft_resource_source_abs.dart';

/// One resource read, preserving its exact physical source and identity.
final class MtnMinecraftResourceData {
  MtnMinecraftResourceData({
    required this.source,
    required this.namespace,
    required this.path,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final MtnMinecraftResourceSourceAbs source;
  final String namespace;
  final String path;

  /// A private copy of the bytes supplied to this result constructor.
  ///
  /// Consumers may mutate this result's byte buffer. A separate read creates
  /// a separate result and does not share that mutable buffer.
  final Uint8List bytes;

  String get assetPath => 'assets/$namespace/$path';
}
