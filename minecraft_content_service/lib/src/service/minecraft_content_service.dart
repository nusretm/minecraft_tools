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

  Future<MtnMinecraftContentVersionListResult> getVersions(String providerName, MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) {
    return providers.requireReadyFromName(providerName).getVersions(content, request);
  }
}
