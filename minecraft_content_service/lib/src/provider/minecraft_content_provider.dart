import '../model/minecraft_content_models.dart';

abstract class MtnMinecraftContentProvider {
  MtnMinecraftContentProvider({
    required this.name,
  }) {
    if (name.isEmpty) throw ArgumentError.value(name, 'name', 'Provider name cannot be empty.');
    if (name.trim() != name) throw ArgumentError.value(name, 'name', 'Provider name cannot contain leading or trailing whitespace.');
  }

  final String name;

  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request);

  Future<MtnMinecraftContent> getContent(String id);

  Future<MtnMinecraftContentVersionListResult> getVersions(String contentId, MtnMinecraftContentVersionListRequest request);
}
