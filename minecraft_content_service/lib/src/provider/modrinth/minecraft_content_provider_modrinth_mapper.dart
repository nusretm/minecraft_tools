import '../../model/minecraft_content_models.dart';
import '../minecraft_content_provider_models.dart';

class MtnMinecraftContentProviderModrinthMapper {
  const MtnMinecraftContentProviderModrinthMapper._();

  static List<List<String>> searchFacets(MtnMinecraftContentSearchRequest request) {
    final result = <List<String>>[];

    if (request.types.isNotEmpty) {
      result.add(request.types.map(_contentTypeFacet).toList(growable: false));
    }

    if (request.gameVersions.isNotEmpty) {
      result.add(request.gameVersions.map((version) => 'versions:$version').toList(growable: false));
    }

    if (request.modLoaders.isNotEmpty) {
      result.add(request.modLoaders.map((loader) => 'categories:${_loaderWireName(loader)}').toList(growable: false));
    }

    return result;
  }

  static Map<String, String> versionQuery(MtnMinecraftContentVersionListRequest request) {
    return <String, String>{
      if (request.modLoaders.isNotEmpty) 'loaders': MtnMinecraftContentModel.jsonEncode(<String, dynamic>{'value': request.modLoaders.map(_loaderWireName).toList(growable: false)}).replaceFirst('{"value":', '').replaceFirst(RegExp(r'}$'), ''),
      if (request.gameVersions.isNotEmpty) 'game_versions': MtnMinecraftContentModel.jsonEncode(<String, dynamic>{'value': request.gameVersions}).replaceFirst('{"value":', '').replaceFirst(RegExp(r'}$'), ''),
      'include_changelog': 'true',
    };
  }

  static String providerId(String providerName, MtnMinecraftContent content) {
    for (final metadata in content.providers) {
      if (metadata.provider == providerName && metadata.id != null && metadata.id!.isNotEmpty) return metadata.id!;
    }
    throw StateError('Content ${content.key} does not contain a canonical $providerName project id.');
  }

  static MtnMinecraftContentSearchResult searchResult(String providerName, Map<String, dynamic> map) {
    final hits = MtnMinecraftContentModel.mapListFromMap(map['hits']);
    final contents = hits.map((hit) => _searchContent(providerName, hit)).toList(growable: false);
    final offset = MtnMinecraftContentModel.intFromMap(map['offset']);
    final limit = MtnMinecraftContentModel.intFromMap(map['limit'], fallback: contents.length);
    final total = MtnMinecraftContentModel.intFromMap(map['total_hits']);

    return MtnMinecraftContentSearchResult(
      contents: contents,
      offset: offset,
      limit: limit == 0 ? 1 : limit,
      total: total,
      hasMore: offset + contents.length < total,
    );
  }

  static MtnMinecraftContent project(String providerName, Map<String, dynamic> map) {
    final id = MtnMinecraftContentModel.stringFromMap(map['id']);
    final type = _contentType(MtnMinecraftContentModel.stringFromMap(map['project_type']));
    final categories = <MtnMinecraftContentCategory>[];
    final primaryCategories = MtnMinecraftContentModel.stringListFromMap(map['categories']);
    final additionalCategories = MtnMinecraftContentModel.stringListFromMap(map['additional_categories']);

    for (final category in primaryCategories) {
      categories.add(MtnMinecraftContentCategory(name: category, slug: category, primary: true, provider: providerName));
    }
    for (final category in additionalCategories) {
      if (primaryCategories.contains(category)) continue;
      categories.add(MtnMinecraftContentCategory(name: category, slug: category, provider: providerName));
    }

    final gallery = MtnMinecraftContentModel.mapListFromMap(map['gallery']).map((item) {
      return MtnMinecraftContentImage(
        url: MtnMinecraftContentModel.stringFromMap(item['url']),
        title: MtnMinecraftContentModel.nullableStringFromMap(item['title']),
        description: MtnMinecraftContentModel.nullableStringFromMap(item['description']),
        featured: MtnMinecraftContentModel.boolFromMap(item['featured']),
        ordering: MtnMinecraftContentModel.nullableIntFromMap(item['ordering']),
        createdAt: MtnMinecraftContentModel.nullableDateTimeFromMap(item['created']),
        provider: providerName,
        providerMetadata: item,
      );
    }).toList(growable: false);

    final donationUrls = MtnMinecraftContentModel.mapListFromMap(map['donation_urls']).map((item) {
      return MtnMinecraftContentDonation(
        id: MtnMinecraftContentModel.nullableStringFromMap(item['id']),
        platform: MtnMinecraftContentModel.nullableStringFromMap(item['platform']),
        url: MtnMinecraftContentModel.stringFromMap(item['url']),
      );
    }).toList(growable: false);

    final links = MtnMinecraftContentLinks(
      source: MtnMinecraftContentModel.nullableStringFromMap(map['source_url']),
      issues: MtnMinecraftContentModel.nullableStringFromMap(map['issues_url']),
      wiki: MtnMinecraftContentModel.nullableStringFromMap(map['wiki_url']),
      discord: MtnMinecraftContentModel.nullableStringFromMap(map['discord_url']),
      donations: donationUrls,
    );

    final iconUrl = MtnMinecraftContentModel.nullableStringFromMap(map['icon_url']);
    final licenseMap = MtnMinecraftContentModel.mapFromMap(map['license']);
    final license = licenseMap.isEmpty
        ? null
        : MtnMinecraftContentLicense(
            id: MtnMinecraftContentModel.nullableStringFromMap(licenseMap['id']),
            name: MtnMinecraftContentModel.nullableStringFromMap(licenseMap['name']),
            url: MtnMinecraftContentModel.nullableStringFromMap(licenseMap['url']),
            providerMetadata: licenseMap,
          );

    return _content(
      type,
      key: '$providerName:$id',
      name: MtnMinecraftContentModel.stringFromMap(map['title']),
      slug: MtnMinecraftContentModel.nullableStringFromMap(map['slug']),
      summary: MtnMinecraftContentModel.nullableStringFromMap(map['description']),
      description: MtnMinecraftContentModel.nullableStringFromMap(map['body']),
      providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: providerName, id: id, metadata: map)],
      categories: categories,
      links: links,
      icon: iconUrl == null ? null : MtnMinecraftContentImage(url: iconUrl, provider: providerName),
      gallery: gallery,
      license: license,
      createdAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['published']),
      updatedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['updated']),
      releasedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['approved']),
    );
  }

  static MtnMinecraftContentVersionListResult versionResult(
    String providerName,
    MtnMinecraftContent content,
    MtnMinecraftContentVersionListRequest request,
    List<Object?> values,
  ) {
    final versions = values.map(MtnMinecraftContentModel.mapFromMap).map((map) => _version(providerName, content, map)).where((version) {
      return request.releaseTypes.isEmpty || request.releaseTypes.contains(version.releaseType);
    }).toList(growable: true);

    versions.sort((a, b) {
      final aDate = a.publishedAt;
      final bDate = b.publishedAt;
      if (aDate == null && bDate == null) return a.key.compareTo(b.key);
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      final compare = aDate.compareTo(bDate);
      return compare == 0 ? a.key.compareTo(b.key) : compare;
    });

    final total = versions.length;
    final start = request.offset > total ? total : request.offset;
    final end = start + request.limit > total ? total : start + request.limit;
    final page = versions.sublist(start, end);

    return MtnMinecraftContentVersionListResult(
      versions: page,
      offset: request.offset,
      limit: request.limit,
      total: total,
      hasMore: end < total,
    );
  }

  static MtnMinecraftContent _searchContent(String providerName, Map<String, dynamic> map) {
    final id = MtnMinecraftContentModel.stringFromMap(map['project_id']);
    final type = _contentType(MtnMinecraftContentModel.stringFromMap(map['project_type']));
    final iconUrl = MtnMinecraftContentModel.nullableStringFromMap(map['icon_url']);
    final author = MtnMinecraftContentModel.nullableStringFromMap(map['author']);
    final licenseId = MtnMinecraftContentModel.nullableStringFromMap(map['license']);

    return _content(
      type,
      key: '$providerName:$id',
      name: MtnMinecraftContentModel.stringFromMap(map['title']),
      summary: MtnMinecraftContentModel.nullableStringFromMap(map['description']),
      providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: providerName, id: id, metadata: map)],
      authors: author == null ? const <MtnMinecraftContentAuthor>[] : <MtnMinecraftContentAuthor>[MtnMinecraftContentAuthor(name: author, username: author, provider: providerName)],
      categories: MtnMinecraftContentModel.stringListFromMap(map['categories']).map((category) => MtnMinecraftContentCategory(name: category, slug: category, primary: true, provider: providerName)).toList(growable: false),
      icon: iconUrl == null ? null : MtnMinecraftContentImage(url: iconUrl, provider: providerName),
      license: licenseId == null ? null : MtnMinecraftContentLicense(id: licenseId),
      createdAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['date_created']),
      updatedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['date_modified']),
    );
  }

  static MtnMinecraftContentVersion _version(String providerName, MtnMinecraftContent content, Map<String, dynamic> map) {
    final id = MtnMinecraftContentModel.stringFromMap(map['id']);
    final dependencies = MtnMinecraftContentModel.mapListFromMap(map['dependencies']).map((dependency) {
      return MtnMinecraftContentDependency(
        type: _dependencyType(MtnMinecraftContentModel.stringFromMap(dependency['dependency_type'])),
        provider: providerName,
        providerContentId: MtnMinecraftContentModel.nullableStringFromMap(dependency['project_id']),
        providerVersionId: MtnMinecraftContentModel.nullableStringFromMap(dependency['version_id']),
        fileName: MtnMinecraftContentModel.nullableStringFromMap(dependency['file_name']),
        providerMetadata: dependency,
      );
    }).toList(growable: false);

    final files = MtnMinecraftContentModel.mapListFromMap(map['files']).map((file) {
      final hashMap = MtnMinecraftContentModel.mapFromMap(file['hashes']);
      final hashes = hashMap.entries.map((entry) => MtnMinecraftContentFileHash(algorithm: entry.key, value: entry.value.toString())).toList(growable: false);
      return MtnMinecraftContentFile(
        fileName: MtnMinecraftContentModel.stringFromMap(file['filename']),
        downloadUrl: MtnMinecraftContentModel.nullableStringFromMap(file['url']),
        size: MtnMinecraftContentModel.nullableIntFromMap(file['size']),
        primary: MtnMinecraftContentModel.boolFromMap(file['primary']),
        available: true,
        type: MtnMinecraftContentModel.nullableStringFromMap(file['file_type']),
        hashes: hashes,
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: providerName, metadata: file)],
      );
    }).toList(growable: false);

    return MtnMinecraftContentVersion(
      key: '$providerName:$id',
      content: content,
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      version: MtnMinecraftContentModel.stringFromMap(map['version_number']),
      releaseType: _releaseType(MtnMinecraftContentModel.stringFromMap(map['version_type'])),
      modLoaders: _loaders(content, MtnMinecraftContentModel.stringListFromMap(map['loaders'])),
      providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: providerName, id: id, metadata: map)],
      gameVersions: MtnMinecraftContentModel.stringListFromMap(map['game_versions']),
      environment: _environment(MtnMinecraftContentModel.nullableStringFromMap(map['environment'])),
      publishedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['date_published']),
      changelog: MtnMinecraftContentModel.nullableStringFromMap(map['changelog']),
      featured: MtnMinecraftContentModel.boolFromMap(map['featured']),
      files: files,
      dependencies: dependencies,
    );
  }

  static MtnMinecraftContent _content(
    MtnMinecraftContentType type, {
    required String key,
    required String name,
    String? slug,
    String? summary,
    String? description,
    List<MtnMinecraftContentProviderMetadata>? providers,
    List<MtnMinecraftContentAuthor>? authors,
    List<MtnMinecraftContentCategory>? categories,
    MtnMinecraftContentLinks? links,
    MtnMinecraftContentImage? icon,
    List<MtnMinecraftContentImage>? gallery,
    MtnMinecraftContentLicense? license,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? releasedAt,
  }) {
    switch (type) {
      case MtnMinecraftContentType.mod:
        return MtnMinecraftContentMod(key: key, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
      case MtnMinecraftContentType.modPack:
        return MtnMinecraftContentModPack(key: key, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
      case MtnMinecraftContentType.resourcePack:
        return MtnMinecraftContentResourcePack(key: key, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
      case MtnMinecraftContentType.shaderPack:
        return MtnMinecraftContentShaderPack(key: key, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
      case MtnMinecraftContentType.dataPack:
        return MtnMinecraftContentDataPack(key: key, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
    }
  }

  static MtnMinecraftContentType _contentType(String value) {
    switch (value) {
      case 'mod':
        return MtnMinecraftContentType.mod;
      case 'modpack':
        return MtnMinecraftContentType.modPack;
      case 'resourcepack':
        return MtnMinecraftContentType.resourcePack;
      case 'shader':
        return MtnMinecraftContentType.shaderPack;
      case 'datapack':
        return MtnMinecraftContentType.dataPack;
      default:
        throw FormatException('Unsupported Modrinth project type: $value');
    }
  }

  static String _contentTypeFacet(MtnMinecraftContentType type) {
    switch (type) {
      case MtnMinecraftContentType.mod:
        return 'project_type:mod';
      case MtnMinecraftContentType.modPack:
        return 'project_type:modpack';
      case MtnMinecraftContentType.resourcePack:
        return 'project_type:resourcepack';
      case MtnMinecraftContentType.shaderPack:
        return 'project_type:shader';
      case MtnMinecraftContentType.dataPack:
        return 'all_project_types:datapack';
    }
  }

  static String _loaderWireName(MtnMinecraftModLoaderType loader) {
    switch (loader) {
      case MtnMinecraftModLoaderType.vanilla:
        return 'minecraft';
      case MtnMinecraftModLoaderType.fabric:
        return 'fabric';
      case MtnMinecraftModLoaderType.quilt:
        return 'quilt';
      case MtnMinecraftModLoaderType.forge:
        return 'forge';
      case MtnMinecraftModLoaderType.neoForge:
        return 'neoforge';
      case MtnMinecraftModLoaderType.cauldron:
        return 'cauldron';
      case MtnMinecraftModLoaderType.liteLoader:
        return 'liteloader';
      case MtnMinecraftModLoaderType.unknown:
        return 'unknown';
    }
  }

  static List<MtnMinecraftModLoaderType> _loaders(MtnMinecraftContent content, List<String> values) {
    if (content is! MtnMinecraftContentMod) return const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla];

    final result = <MtnMinecraftModLoaderType>[];
    for (final value in values) {
      final loader = switch (value) {
        'minecraft' => MtnMinecraftModLoaderType.vanilla,
        'fabric' => MtnMinecraftModLoaderType.fabric,
        'quilt' => MtnMinecraftModLoaderType.quilt,
        'forge' => MtnMinecraftModLoaderType.forge,
        'neoforge' => MtnMinecraftModLoaderType.neoForge,
        'cauldron' => MtnMinecraftModLoaderType.cauldron,
        'liteloader' => MtnMinecraftModLoaderType.liteLoader,
        _ => MtnMinecraftModLoaderType.unknown,
      };
      if (!result.contains(loader)) result.add(loader);
    }

    if (result.isEmpty) result.add(MtnMinecraftModLoaderType.unknown);
    if (result.contains(MtnMinecraftModLoaderType.vanilla) && result.length > 1) result.remove(MtnMinecraftModLoaderType.vanilla);
    return result;
  }

  static MtnMinecraftContentVersionReleaseType _releaseType(String value) {
    switch (value) {
      case 'release':
        return MtnMinecraftContentVersionReleaseType.release;
      case 'beta':
        return MtnMinecraftContentVersionReleaseType.beta;
      case 'alpha':
        return MtnMinecraftContentVersionReleaseType.alpha;
      default:
        throw FormatException('Unsupported Modrinth version type: $value');
    }
  }

  static MtnMinecraftContentDependencyType _dependencyType(String value) {
    switch (value) {
      case 'required':
        return MtnMinecraftContentDependencyType.required;
      case 'optional':
        return MtnMinecraftContentDependencyType.optional;
      case 'incompatible':
        return MtnMinecraftContentDependencyType.incompatible;
      case 'embedded':
        return MtnMinecraftContentDependencyType.embedded;
      default:
        throw FormatException('Unsupported Modrinth dependency type: $value');
    }
  }

  static MtnMinecraftContentEnvironment? _environment(String? value) {
    if (value == null) return null;
    return switch (value) {
      'client_and_server' => MtnMinecraftContentEnvironment.clientAndServer,
      'client_only' => MtnMinecraftContentEnvironment.clientOnly,
      'client_only_server_optional' => MtnMinecraftContentEnvironment.clientOnlyServerOptional,
      'singleplayer_only' => MtnMinecraftContentEnvironment.singleplayerOnly,
      'server_only' => MtnMinecraftContentEnvironment.serverOnly,
      'server_only_client_optional' => MtnMinecraftContentEnvironment.serverOnlyClientOptional,
      'dedicated_server_only' => MtnMinecraftContentEnvironment.dedicatedServerOnly,
      'client_or_server' => MtnMinecraftContentEnvironment.clientOrServer,
      'client_or_server_prefers_both' => MtnMinecraftContentEnvironment.clientOrServerPrefersBoth,
      _ => MtnMinecraftContentEnvironment.unknown,
    };
  }
}
