import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'mtn_minecraft_resource_source_abs.dart';
import 'src/mtn_minecraft_resource_archive_reader.dart';

/// Read-only client JAR asset source. No downloads, installation discovery or
/// item-model logic: the caller registers this source with the resource loader.
///
/// Paths are inventoried once when opened. Construct a new instance if the
/// underlying JAR changes; do not mutate a JAR during active resource reads.
final class MtnMinecraftResourceSourceVanilla extends MtnMinecraftResourceSourceAbs {
  MtnMinecraftResourceSourceVanilla._({
    required this.clientJar,
    required Set<String> assetPaths,
    required super.namespaces,
  }) : _assetPaths = Set<String>.unmodifiable(assetPaths);

  /// Opens an existing, already-downloaded Minecraft client JAR.
  ///
  /// Invalid ZIP data and unreadable files throw rather than silently
  /// falling back to a lower-precedence resource source.
  static Future<MtnMinecraftResourceSourceVanilla> open({
    required File clientJar,
  }) async {
    final File jar = File(p.normalize(p.absolute(clientJar.path)));
    final Set<String> paths =
        await MtnMinecraftResourceArchiveReader.scanAssetPaths(jar);
    final Set<String> namespaces = <String>{
      for (final String path in paths) path.split('/')[1],
    };
    return MtnMinecraftResourceSourceVanilla._(
      clientJar: jar,
      assetPaths: paths,
      namespaces: namespaces,
    );
  }

  /// Normalized absolute path of the actual client JAR.
  final File clientJar;
  final Set<String> _assetPaths;

  /// Reads only a known archive entry, decompressing just its requested data.
  @override
  Future<Uint8List?> readAsset(String namespace, String path) async {
    final String assetPath = 'assets/$namespace/$path';
    if (!_assetPaths.contains(assetPath)) return null;
    final Uint8List? bytes =
        await MtnMinecraftResourceArchiveReader.readEntry(file: clientJar, path: assetPath);
    if (bytes == null) {
      // The indexed file disappeared: this is an inconsistent/broken JAR,
      // not a legitimate absent resource that may fall back to another source.
      throw StateError('Indexed Vanilla resource disappeared: $assetPath');
    }
    return bytes;
  }
}
