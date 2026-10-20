import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../resource/mtn_minecraft_resource_source_abs.dart';

typedef MtnMinecraftInfoModAssetLoader = Future<Uint8List?> Function(
  String path,
);

/// One archive-level Minecraft client-asset source associated with a mod.
///
/// A source may expose namespaces that do not match any logical mod ID in the
/// same JAR. Callers must not treat namespace presence as authoritative mod
/// ownership.
final class MtnMinecraftInfoModAssetSource extends MtnMinecraftResourceSourceAbs {
  MtnMinecraftInfoModAssetSource({
    required File? rootFile,
    Iterable<String> embeddedArchivePaths = const <String>[],
    Iterable<String> namespaces = const <String>[],
    required MtnMinecraftInfoModAssetLoader loader,
  })  : rootFile = rootFile == null
            ? null
            : File(p.normalize(p.absolute(rootFile.path))),
        embeddedArchivePaths =
            List<String>.unmodifiable(embeddedArchivePaths),
        _loader = loader,
        super(namespaces: namespaces);

  final File? rootFile;

  /// Archive entry path chain followed from [rootFile] to this source.
  final List<String> embeddedArchivePaths;

  final MtnMinecraftInfoModAssetLoader _loader;

  /// Lazy source-specific read; public read() validates and copies the bytes.
  @override
  Future<Uint8List?> readAsset(String namespace, String path) =>
      _loader('assets/$namespace/$path');

  bool sameArchive(MtnMinecraftInfoModAssetSource other) {
    final File? leftRoot = rootFile;
    final File? rightRoot = other.rootFile;
    if (leftRoot == null || rightRoot == null) {
      return identical(this, other);
    }
    if (!p.equals(leftRoot.path, rightRoot.path) ||
        embeddedArchivePaths.length != other.embeddedArchivePaths.length) {
      return false;
    }

    for (int index = 0; index < embeddedArchivePaths.length; index++) {
      if (embeddedArchivePaths[index] != other.embeddedArchivePaths[index]) {
        return false;
      }
    }
    return true;
  }
}
