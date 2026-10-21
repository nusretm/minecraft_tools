import 'helper/mtn_minecraft_resource_helper_abs.dart';
import 'helper/mtn_minecraft_resource_helper_item_model_component.dart';
import 'helper/mtn_minecraft_resource_helper_legacy.dart';
import 'helper/mtn_minecraft_resource_helper_modern.dart';
import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_environment.dart';
import 'mtn_minecraft_resource_item.dart';
import 'mtn_minecraft_resource_item_entry.dart';
import 'mtn_minecraft_resource_item_request.dart';
import 'mtn_minecraft_resource_source_abs.dart';

/// Ordered authority for effective and candidate Minecraft resource reads.
///
/// Sources are registered from lowest to highest precedence. No Minecraft
/// mod-discovery or resource-pack policy is inferred from registration order.
final class MtnMinecraftResourceLoader {
  MtnMinecraftResourceLoader({
    Iterable<MtnMinecraftResourceSourceAbs> sources =
        const <MtnMinecraftResourceSourceAbs>[],
    Iterable<MtnMinecraftResourceHelperAbs> helpers =
        const <MtnMinecraftResourceHelperAbs>[],
    bool registerBuiltInHelpers = true,
  }) {
    for (final MtnMinecraftResourceSourceAbs source in sources) {
      registerSource(source);
    }
    if (registerBuiltInHelpers) {
      registerHelper(MtnMinecraftResourceHelperLegacy());
      registerHelper(MtnMinecraftResourceHelperItemModelComponent());
      registerHelper(MtnMinecraftResourceHelperModern());
    }
    for (final MtnMinecraftResourceHelperAbs helper in helpers) {
      registerHelper(helper);
    }
  }

  final List<MtnMinecraftResourceSourceAbs> _sources =
      <MtnMinecraftResourceSourceAbs>[];

  final List<MtnMinecraftResourceHelperAbs> _helpers =
      <MtnMinecraftResourceHelperAbs>[];

  /// Snapshot of helpers in registration order (last has highest priority).
  List<MtnMinecraftResourceHelperAbs> get helpers =>
      List<MtnMinecraftResourceHelperAbs>.unmodifiable(_helpers);

  /// Registers at highest dispatch priority; duplicate names are invalid.
  void registerHelper(MtnMinecraftResourceHelperAbs helper) {
    if (_helpers.any((MtnMinecraftResourceHelperAbs current) => current.name == helper.name)) {
      throw StateError('Resource helper "${helper.name}" is already registered.');
    }
    _helpers.add(helper);
  }

  /// Unregisters the same instance only, not another helper with similar data.
  bool unregisterHelper(MtnMinecraftResourceHelperAbs helper) {
    final int index = _helpers.indexWhere((MtnMinecraftResourceHelperAbs current) => identical(current, helper));
    if (index < 0) return false;
    _helpers.removeAt(index);
    return true;
  }

  void clearHelpers() => _helpers.clear();

  /// Resolves item-entry and normal-model resources using one helper.
  ///
  /// A missing entry permits the next compatible helper; a partial graph
  /// remains a non-null result with explicit unresolved issues.
  Future<MtnMinecraftResourceItem?> loadItem({
    required MtnMinecraftResourceEnvironment environment,
    required MtnMinecraftResourceItemRequest request,
  }) async {
    for (final MtnMinecraftResourceHelperAbs helper in _helpers.reversed) {
      if (!helper.supports(environment)) continue;
      final MtnMinecraftResourceItem? result = await helper.loadItem(this, request, environment: environment);
      if (result != null) return result;
    }
    return null;
  }

  /// Selects a matching helper in descending registration priority.
  ///
  /// Null results allow the next compatible helper to be tried.
  /// Source failures propagate and do not silently select a lower source.
  Future<MtnMinecraftResourceItemEntry?> loadItemEntry({
    required MtnMinecraftResourceEnvironment environment,
    required MtnMinecraftResourceItemRequest request,
  }) async {
    for (final MtnMinecraftResourceHelperAbs helper in _helpers.reversed) {
      if (!helper.supports(environment)) continue;
      final MtnMinecraftResourceItemEntry? result = await helper.loadItemEntry(this, request);
      if (result != null) return result;
    }
    return null;
  }

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
