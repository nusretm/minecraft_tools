import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_service.dart';

/// Explicit, service-scoped in-memory metadata cache for portable package hydration.
///
/// Cache keys are provider name plus canonical provider ID, not display titles,
/// Minecraft versions, or a provider-independent project key.
/// Successes are retained until invalidated; failures are never cached.
/// An invalidated in-flight response cannot repopulate the cache.
class MtnMinecraftContentPackageMetadataCache {
  MtnMinecraftContentPackageMetadataCache(this.service);

  final MtnMinecraftContentService service;
  final Map<String, MtnMinecraftContent> _contents = <String, MtnMinecraftContent>{};
  final Map<String, MtnMinecraftContentVersion> _versions = <String, MtnMinecraftContentVersion>{};
  final Map<String, Future<MtnMinecraftContent>> _pendingContents = <String, Future<MtnMinecraftContent>>{};
  final Map<String, Future<MtnMinecraftContentVersion>> _pendingVersions = <String, Future<MtnMinecraftContentVersion>>{};

  int get cachedContentCount => _contents.length;
  int get cachedVersionCount => _versions.length;

  Future<MtnMinecraftContent> getContent(String provider, String projectId, {bool refresh = false}) {
    final key = _key(provider, projectId);
    return _load(
      key: key,
      values: _contents,
      pending: _pendingContents,
      refresh: refresh,
      fetch: () async {
        final content = await service.getContent(provider, projectId);
        if (!content.providers.any((entry) => entry.provider == provider && entry.id == projectId)) {
          throw FormatException('Provider returned a different project identity for $key.');
        }
        return content;
      },
    );
  }

  Future<MtnMinecraftContentVersion> getVersion(String provider, String versionId, {bool refresh = false}) {
    final key = _key(provider, versionId);
    return _load(
      key: key,
      values: _versions,
      pending: _pendingVersions,
      refresh: refresh,
      fetch: () async {
        final version = await service.getVersion(provider, versionId);
        if (!version.providers.any((entry) => entry.provider == provider && entry.id == versionId)) {
          throw FormatException('Provider returned a different version identity for $key.');
        }
        return version;
      },
    );
  }

  void invalidateContent(String provider, String projectId) {
    final key = _key(provider, projectId);
    _contents.remove(key);
    _pendingContents.remove(key);
  }

  void invalidateVersion(String provider, String versionId) {
    final key = _key(provider, versionId);
    _versions.remove(key);
    _pendingVersions.remove(key);
  }

  void clear() {
    _contents.clear();
    _versions.clear();
    _pendingContents.clear();
    _pendingVersions.clear();
  }

  Future<T> _load<T>({
    required String key,
    required Map<String, T> values,
    required Map<String, Future<T>> pending,
    required Future<T> Function() fetch,
    required bool refresh,
  }) {
    final existing = pending[key];
    if (existing != null) return existing;
    if (!refresh && values.containsKey(key)) return Future<T>.value(values[key] as T);

    late final Future<T> request;
    request = Future<T>.sync(fetch).then((value) {
      if (identical(pending[key], request)) values[key] = value;
      return value;
    }).whenComplete(() {
      if (identical(pending[key], request)) pending.remove(key);
    });
    pending[key] = request;
    return request;
  }

  static String _key(String provider, String id) {
    if (provider.trim().isEmpty || provider.trim() != provider || id.trim().isEmpty || id.trim() != id) {
      throw ArgumentError('Provider and ID must be nonempty, canonical identities.');
    }
    return '$provider:$id';
  }
}
