import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_source_abs.dart';

/// Ordered authority for effective and candidate Minecraft resource reads.
///
/// Sources are registered from lowest to highest precedence. No Minecraft
/// mod-discovery or resource-pack policy is inferred from registration order.
final class MtnMinecraftResourceLoader {
  MtnMinecraftResourceLoader({
    Iterable<MtnMinecraftResourceSourceAbs> sources =
        const <MtnMinecraftResourceSourceAbs>[],
  }) {
    for (final MtnMinecraftResourceSourceAbs source in sources) {
      registerSource(source);
    }
  }

  final List<MtnMinecraftResourceSourceAbs> _sources =
      <MtnMinecraftResourceSourceAbs>[];

  /// Snapshot ordered from lowest to highest precedence.
  List<MtnMinecraftResourceSourceAbs> get sources =>
      List<MtnMinecraftResourceSourceAbs>.unmodifiable(_sources);

  /// Adds a source at the highest precedence position.
  ///
  /// Duplicate registration of the same source instance is rejected.
  void registerSource(MtnMinecraftResourceSourceAbs source) {
    if (_sources.any(
      (MtnMinecraftResourceSourceAbs current) => identical(current, source),
    )) {
      throw StateError('This resource source is already registered.');
    }
    _sources.add(source);
  }

  /// Removes exactly the registered source instance.
  bool unregisterSource(MtnMinecraftResourceSourceAbs source) {
    final int index = _sources.indexWhere(
      (MtnMinecraftResourceSourceAbs current) => identical(current, source),
    );
    if (index < 0) return false;
    _sources.removeAt(index);
    return true;
  }

  void clearSources() => _sources.clear();

  /// Returns the highest-precedence match, preserving source provenance.
  ///
  /// A source failure is propagated; lower-precedence resources are never
  /// treated as a silent fallback for a broken higher-precedence source.
  Future<MtnMinecraftResourceData?> read(
    String namespace,
    String path,
  ) async {
    MtnMinecraftResourceSourceAbs.validateResource(namespace, path);

    for (final MtnMinecraftResourceSourceAbs source in _sources.reversed) {
      final bytes = await source.read(namespace, path);
      if (bytes == null) continue;
      return MtnMinecraftResourceData(
        source: source,
        namespace: namespace,
        path: path,
        bytes: bytes,
      );
    }
    return null;
  }

  /// Returns every matching candidate, highest precedence first.
  ///
  /// Missing entries are skipped; source errors are not swallowed.
  Future<List<MtnMinecraftResourceData>> readAll(
    String namespace,
    String path,
  ) async {
    MtnMinecraftResourceSourceAbs.validateResource(namespace, path);

    final List<MtnMinecraftResourceData> result =
        <MtnMinecraftResourceData>[];
    for (final MtnMinecraftResourceSourceAbs source in _sources.reversed) {
      final bytes = await source.read(namespace, path);
      if (bytes == null) continue;
      result.add(
        MtnMinecraftResourceData(
          source: source,
          namespace: namespace,
          path: path,
          bytes: bytes,
        ),
      );
    }
    return List<MtnMinecraftResourceData>.unmodifiable(result);
  }
}
