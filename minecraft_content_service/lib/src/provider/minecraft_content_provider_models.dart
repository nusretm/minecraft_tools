import '../model/minecraft_content_models.dart';

class MtnMinecraftContentSearchRequest {
  MtnMinecraftContentSearchRequest({
    this.query,
    List<MtnMinecraftContentType>? types,
    List<String>? gameVersions,
    List<MtnMinecraftModLoaderType>? modLoaders,
    this.offset = 0,
    this.limit = 50,
  }) : types = List<MtnMinecraftContentType>.unmodifiable(types ?? <MtnMinecraftContentType>[]),
       gameVersions = List<String>.unmodifiable(gameVersions ?? <String>[]),
       modLoaders = List<MtnMinecraftModLoaderType>.unmodifiable(modLoaders ?? <MtnMinecraftModLoaderType>[]) {
    _validatePage(offset, limit);
  }

  final String? query;
  final List<MtnMinecraftContentType> types;
  final List<String> gameVersions;
  final List<MtnMinecraftModLoaderType> modLoaders;
  final int offset;
  final int limit;
}

class MtnMinecraftContentSearchResult {
  MtnMinecraftContentSearchResult({
    required this.provider,
    required List<MtnMinecraftContent> contents,
    required this.offset,
    required this.limit,
    required this.hasMore,
    this.total,
  }) : contents = List<MtnMinecraftContent>.unmodifiable(contents) {
    if (provider.isEmpty) throw ArgumentError.value(provider, 'provider', 'Provider name cannot be empty.');
    if (provider.trim() != provider) throw ArgumentError.value(provider, 'provider', 'Provider name cannot contain leading or trailing whitespace.');
    _validatePage(offset, limit);
    if (total != null && total! < 0) throw ArgumentError.value(total, 'total', 'Total cannot be negative.');
  }

  final String provider;
  final List<MtnMinecraftContent> contents;
  final int offset;
  final int limit;
  final int? total;
  final bool hasMore;
}

class MtnMinecraftContentDependencyResolution {
  MtnMinecraftContentDependencyResolution({
    required this.dependency,
    MtnMinecraftContent? content,
    this.version,
  }) : content = version?.content ?? content {
    if (version != null && content != null && !identical(version!.content, content)) throw ArgumentError.value(content, 'content', 'Resolved dependency content must match the resolved version content.');
  }

  final MtnMinecraftContentDependency dependency;
  final MtnMinecraftContent? content;
  final MtnMinecraftContentVersion? version;

  bool get contentResolved => content != null;

  bool get versionResolved => version != null;
}

class MtnMinecraftContentVersionSelectionRequest {
  MtnMinecraftContentVersionSelectionRequest({
    List<String>? gameVersions,
    List<MtnMinecraftModLoaderType>? modLoaders,
    List<MtnMinecraftContentVersionReleaseType>? releaseTypes,
  }) : gameVersions = List<String>.unmodifiable(gameVersions ?? <String>[]),
       modLoaders = List<MtnMinecraftModLoaderType>.unmodifiable(modLoaders ?? <MtnMinecraftModLoaderType>[]),
       releaseTypes = List<MtnMinecraftContentVersionReleaseType>.unmodifiable(releaseTypes ?? <MtnMinecraftContentVersionReleaseType>[]);

  final List<String> gameVersions;
  final List<MtnMinecraftModLoaderType> modLoaders;
  final List<MtnMinecraftContentVersionReleaseType> releaseTypes;
}

class MtnMinecraftContentVersionListRequest {
  MtnMinecraftContentVersionListRequest({
    List<String>? gameVersions,
    List<MtnMinecraftModLoaderType>? modLoaders,
    List<MtnMinecraftContentVersionReleaseType>? releaseTypes,
    this.offset = 0,
    this.limit = 50,
  }) : gameVersions = List<String>.unmodifiable(gameVersions ?? <String>[]),
       modLoaders = List<MtnMinecraftModLoaderType>.unmodifiable(modLoaders ?? <MtnMinecraftModLoaderType>[]),
       releaseTypes = List<MtnMinecraftContentVersionReleaseType>.unmodifiable(releaseTypes ?? <MtnMinecraftContentVersionReleaseType>[]) {
    _validatePage(offset, limit);
  }

  final List<String> gameVersions;
  final List<MtnMinecraftModLoaderType> modLoaders;
  final List<MtnMinecraftContentVersionReleaseType> releaseTypes;
  final int offset;
  final int limit;
}

class MtnMinecraftContentVersionListResult {
  MtnMinecraftContentVersionListResult({
    required List<MtnMinecraftContentVersion> versions,
    required this.offset,
    required this.limit,
    required this.hasMore,
    this.total,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions) {
    _validatePage(offset, limit);
    if (total != null && total! < 0) throw ArgumentError.value(total, 'total', 'Total cannot be negative.');
  }

  final List<MtnMinecraftContentVersion> versions;
  final int offset;
  final int limit;
  final int? total;
  final bool hasMore;
}

void _validatePage(int offset, int limit) {
  if (offset < 0) throw ArgumentError.value(offset, 'offset', 'Offset cannot be negative.');
  if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50.');
}
