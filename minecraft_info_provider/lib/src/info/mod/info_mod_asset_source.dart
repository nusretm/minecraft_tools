import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

typedef MtnMinecraftInfoModAssetLoader = Future<Uint8List?> Function(
  String path,
);

/// One archive-level Minecraft client-asset source associated with a mod.
///
/// A source may expose namespaces that do not match any logical mod ID in the
/// same JAR. Callers must not treat namespace presence as authoritative mod
/// ownership.
final class MtnMinecraftInfoModAssetSource {
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
        namespaces = List<String>.unmodifiable(
          _normalizeNamespaces(namespaces),
        ),
        _loader = loader;

  final File? rootFile;

  /// Archive entry path chain followed from [rootFile] to this source.
  final List<String> embeddedArchivePaths;

  /// Client resource namespaces found under `assets/<namespace>/...`.
  final List<String> namespaces;

  final MtnMinecraftInfoModAssetLoader _loader;

  bool containsNamespace(String namespace) => namespaces.contains(namespace);

  /// Reads one client asset relative to `assets/<namespace>/`.
  ///
  /// Returns null when the asset is absent from this source.
  Future<Uint8List?> read(
    String namespace,
    String path,
  ) async {
    if (!_namespacePattern.hasMatch(namespace)) {
      throw ArgumentError.value(
        namespace,
        'namespace',
        'must be a valid Minecraft resource namespace',
      );
    }
    if (!_assetPathPattern.hasMatch(path) ||
        path.startsWith('/') ||
        path.endsWith('/') ||
        path.split('/').contains('..')) {
      throw ArgumentError.value(
        path,
        'path',
        'must be a relative Minecraft resource path',
      );
    }

    if (!containsNamespace(namespace)) return null;

    final Uint8List? bytes = await _loader(
      'assets/$namespace/$path',
    );
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

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

List<String> _normalizeNamespaces(Iterable<String> namespaces) {
  final Set<String> result = <String>{};
  for (final String namespace in namespaces) {
    if (!_namespacePattern.hasMatch(namespace)) {
      throw ArgumentError.value(
        namespace,
        'namespaces',
        'contains an invalid Minecraft resource namespace',
      );
    }
    result.add(namespace);
  }
  final List<String> sorted = result.toList()..sort();
  return sorted;
}

final RegExp _namespacePattern = RegExp(r'^[a-z0-9_.-]+
);
final RegExp _assetPathPattern = RegExp(r'^[a-z0-9/._-]+
);
