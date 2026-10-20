import 'dart:typed_data';

/// Source-level access to Minecraft client resources.
///
/// [namespaces] is a sorted, immutable inventory of exposed namespaces.
/// Source ordering and effective resource selection belong to
/// MtnMinecraftResourceLoader, not to individual sources.
abstract class MtnMinecraftResourceSourceAbs {
  MtnMinecraftResourceSourceAbs({
    Iterable<String> namespaces = const <String>[],
  }) : namespaces = List<String>.unmodifiable(
          _normalizeNamespaces(namespaces),
        );

  final List<String> namespaces;

  bool containsNamespace(String namespace) => namespaces.contains(namespace);

  /// Reads one resource relative to `assets/<namespace>/`.
  ///
  /// Missing resources return null. Malformed paths and storage failures
  /// propagate instead of silently selecting another source.
  Future<Uint8List?> read(String namespace, String path) async {
    validateResource(namespace, path);
    if (!containsNamespace(namespace)) return null;

    final Uint8List? bytes = await readAsset(namespace, path);
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  /// Storage-specific read hook. Called only after public read validation.
  ///
  /// Subclasses should not apply source-stack precedence or model semantics.
  Future<Uint8List?> readAsset(String namespace, String path);

  /// Validates a Minecraft resource namespace and namespace-relative path.
  ///
  /// Kept public so the loader rejects invalid requests even with no sources.
  static void validateResource(String namespace, String path) {
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

final RegExp _namespacePattern = RegExp(r'^[a-z0-9_.-]+$');
final RegExp _assetPathPattern = RegExp(r'^[a-z0-9/._-]+$');
