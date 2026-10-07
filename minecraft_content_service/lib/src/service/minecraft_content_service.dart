import '../model/minecraft_content_models.dart';
import '../provider/minecraft_content_provider.dart';
import '../provider/minecraft_content_provider_list.dart';
import '../provider/minecraft_content_provider_models.dart';

class MtnMinecraftContentService {
  MtnMinecraftContentService({
    Iterable<MtnMinecraftContentProvider> providers = const <MtnMinecraftContentProvider>[],
  }) : providers = MtnMinecraftContentProviderList(providers);

  final MtnMinecraftContentProviderList providers;

  Future<MtnMinecraftContentSearchResult> search(String providerName, MtnMinecraftContentSearchRequest request) {
    return providers.requireReadyFromName(providerName).search(request);
  }

  Future<List<MtnMinecraftContentSearchResult>> searchAll(MtnMinecraftContentSearchRequest request) {
    return Future.wait(
      providers.readyItems.map((provider) => provider.search(request)),
    );
  }

  Future<MtnMinecraftContent> getContent(String providerName, String id) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Content id cannot be empty.');
    return providers.requireReadyFromName(providerName).getContent(id);
  }

  Future<MtnMinecraftContentVersion> getVersion(String providerName, String id) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Version id cannot be empty.');
    return providers.requireReadyFromName(providerName).getVersion(id);
  }

  Future<MtnMinecraftContentVersionListResult> getVersions(String providerName, MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) {
    return providers.requireReadyFromName(providerName).getVersions(content, request);
  }

  Future<MtnMinecraftContentDependencyResolution> resolveDependency(MtnMinecraftContentDependency dependency) async {
    final resolvedVersion = dependency.version;
    if (resolvedVersion != null) return MtnMinecraftContentDependencyResolution(dependency: dependency, version: resolvedVersion);

    final providerName = dependency.provider;
    final resolvedContent = dependency.content;
    if (providerName == null) return MtnMinecraftContentDependencyResolution(dependency: dependency, content: resolvedContent);

    if (resolvedContent != null) _requireDependencyContentIdentity(dependency, providerName, resolvedContent);

    final providerVersionId = dependency.providerVersionId;
    if (providerVersionId != null && providerVersionId.isNotEmpty) {
      final version = await getVersion(providerName, providerVersionId);
      _requireDependencyContentIdentity(dependency, providerName, version.content);

      if (resolvedContent != null) {
        final resolvedContentId = _providerContentId(providerName, resolvedContent);
        final versionContentId = _providerContentId(providerName, version.content);
        if (resolvedContentId != null && versionContentId != null && resolvedContentId != versionContentId) {
          throw FormatException('Resolved dependency content $resolvedContentId does not match version owner $versionContentId for provider $providerName.');
        }
      }

      return MtnMinecraftContentDependencyResolution(dependency: dependency, version: version);
    }

    if (resolvedContent != null) return MtnMinecraftContentDependencyResolution(dependency: dependency, content: resolvedContent);

    final providerContentId = dependency.providerContentId;
    if (providerContentId == null || providerContentId.isEmpty) return MtnMinecraftContentDependencyResolution(dependency: dependency);

    final content = await getContent(providerName, providerContentId);
    _requireDependencyContentIdentity(dependency, providerName, content);
    return MtnMinecraftContentDependencyResolution(dependency: dependency, content: content);
  }

  void _requireDependencyContentIdentity(MtnMinecraftContentDependency dependency, String providerName, MtnMinecraftContent content) {
    final expected = dependency.providerContentId;
    if (expected == null || expected.isEmpty) return;

    final actual = _providerContentId(providerName, content);
    if (actual != expected) throw FormatException('Resolved dependency content id $actual does not match expected $providerName content id $expected.');
  }

  String? _providerContentId(String providerName, MtnMinecraftContent content) {
    for (final metadata in content.providers) {
      if (metadata.provider == providerName) return metadata.id;
    }
    return null;
  }
}
