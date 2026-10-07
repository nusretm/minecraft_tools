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
    return providers.requireFromName(providerName).search(request);
  }

  Future<MtnMinecraftContent> getContent(String providerName, String id) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Content id cannot be empty.');
    return providers.requireFromName(providerName).getContent(id);
  }

  Future<MtnMinecraftContentVersionListResult> getVersions(String providerName, String contentId, MtnMinecraftContentVersionListRequest request) {
    if (contentId.isEmpty) throw ArgumentError.value(contentId, 'contentId', 'Content id cannot be empty.');
    return providers.requireFromName(providerName).getVersions(contentId, request);
  }
}
