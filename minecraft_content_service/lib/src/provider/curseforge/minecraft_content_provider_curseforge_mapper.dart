import 'dart:convert';

import '../../model/minecraft_content_models.dart';
import '../minecraft_content_provider_models.dart';

class MtnMinecraftContentProviderCurseForgeMapper {
  const MtnMinecraftContentProviderCurseForgeMapper._();

  static (Map<MtnMinecraftContentType, int>, Map<int, MtnMinecraftContentType>) contentClassMaps(List<Map<String, dynamic>> classes) {
    final byType = <MtnMinecraftContentType, int>{};
    final byId = <int, MtnMinecraftContentType>{};

    for (final item in classes) {
      if (!MtnMinecraftContentModel.boolFromMap(item['isClass'])) continue;

      final id = MtnMinecraftContentModel.intFromMap(item['id'], fallback: -1);
      if (id <= 0) continue;

      final type = _contentTypeFromClass(
        MtnMinecraftContentModel.nullableStringFromMap(item['name']),
        MtnMinecraftContentModel.nullableStringFromMap(item['slug']),
      );
      if (type == null) continue;

      byType[type] = id;
      byId[id] = type;
    }

    return (Map<MtnMinecraftContentType, int>.unmodifiable(byType), Map<int, MtnMinecraftContentType>.unmodifiable(byId));
  }

  static void validateSearchRequest(MtnMinecraftContentSearchRequest request) {
    if (request.types.length != 1) throw ArgumentError.value(request.types, 'request.types', 'CurseForge search requires exactly one content type.');
    if (request.offset + request.limit > 10000) throw ArgumentError.value(request.offset, 'request.offset', 'CurseForge requires offset + limit to be at most 10000.');
    if (request.gameVersions.length > 4) throw ArgumentError.value(request.gameVersions, 'request.gameVersions', 'CurseForge search accepts at most four game versions.');
    if (request.modLoaders.length > 1) throw ArgumentError.value(request.modLoaders, 'request.modLoaders', 'CurseForge search currently supports one mod loader filter at a time.');
    if (request.modLoaders.isEmpty) return;

    final contentType = request.types.single;
    final loader = request.modLoaders.single;
    if (contentType != MtnMinecraftContentType.mod) {
      if (loader != MtnMinecraftModLoaderType.vanilla) throw ArgumentError.value(loader, 'request.modLoaders', 'Non-mod content can only use the generic vanilla loader.');
      return;
    }

    if (request.gameVersions.isEmpty) throw ArgumentError.value(request.modLoaders, 'request.modLoaders', 'CurseForge loader search requires at least one game version.');
    _loaderWireValue(loader);
  }

  static Map<String, String> searchQuery(MtnMinecraftContentSearchRequest request, int gameId, int classId) {
    validateSearchRequest(request);

    final query = <String, String>{
      'gameId': gameId.toString(),
      'classId': classId.toString(),
      'index': request.offset.toString(),
      'pageSize': request.limit.toString(),
    };

    final text = request.query?.trim();
    if (text != null && text.isNotEmpty) query['searchFilter'] = text;

    if (request.gameVersions.length == 1) {
      query['gameVersion'] = request.gameVersions.single;
    } else if (request.gameVersions.length > 1) {
      query['gameVersions'] = jsonEncode(request.gameVersions);
    }

    if (request.modLoaders.length == 1 && request.types.single == MtnMinecraftContentType.mod) {
      query['modLoaderType'] = _loaderWireValue(request.modLoaders.single).toString();
    }

    return query;
  }

  static MtnMinecraftContentSearchResult searchResult(
    String providerName,
    MtnMinecraftContentType contentType,
    MtnMinecraftContentSearchRequest request,
    Map<String, dynamic> envelope,
  ) {
    final items = dataList(envelope);
    final pagination = MtnMinecraftContentModel.mapFromMap(envelope['pagination']);
    final offset = MtnMinecraftContentModel.intFromMap(pagination['index'], fallback: request.offset);
    final pageSize = MtnMinecraftContentModel.intFromMap(pagination['pageSize'], fallback: request.limit);
    final resultCount = MtnMinecraftContentModel.intFromMap(pagination['resultCount'], fallback: items.length);
    final total = MtnMinecraftContentModel.intFromMap(pagination['totalCount'], fallback: offset + resultCount);
    final contents = items.map((item) => content(providerName, contentType, item)).toList(growable: false);

    return MtnMinecraftContentSearchResult(
      contents: contents,
      offset: offset,
      limit: pageSize < 1 ? request.limit : pageSize,
      total: total,
      hasMore: offset + resultCount < total,
    );
  }

  static Map<String, dynamic> dataMap(Map<String, dynamic> envelope, String label) {
    final value = envelope['data'];
    if (value is! Map<Object?, Object?>) throw FormatException('Expected $label data object.');
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Map<String, dynamic>> dataList(Map<String, dynamic> envelope) {
    final value = envelope['data'];
    if (value is! Iterable<Object?>) throw const FormatException('Expected CurseForge data list.');
    return value.map(MtnMinecraftContentModel.mapFromMap).toList(growable: false);
  }

  static String? dataString(Map<String, dynamic> envelope) {
    return MtnMinecraftContentModel.nullableStringFromMap(envelope['data']);
  }

  static int providerId(String providerName, MtnMinecraftContent content) {
    for (final metadata in content.providers) {
      if (metadata.provider != providerName) continue;
      final value = int.tryParse(metadata.id ?? '');
      if (value != null && value > 0) return value;
    }
    throw StateError('Content ${content.key} does not contain a canonical $providerName project id.');
  }

  static MtnMinecraftContent content(
    String providerName,
    MtnMinecraftContentType type,
    Map<String, dynamic> map, {
    String? description,
  }) {
    final id = MtnMinecraftContentModel.intFromMap(map['id'], fallback: -1);
    if (id <= 0) throw const FormatException('CurseForge content id must be positive.');

    final primaryCategoryId = MtnMinecraftContentModel.nullableIntFromMap(map['primaryCategoryId']);
    final categories = MtnMinecraftContentModel.mapListFromMap(map['categories']).map((item) {
      final categoryId = MtnMinecraftContentModel.intFromMap(item['id'], fallback: -1);
      return MtnMinecraftContentCategory(
        id: categoryId > 0 ? categoryId.toString() : null,
        name: MtnMinecraftContentModel.stringFromMap(item['name']),
        slug: MtnMinecraftContentModel.nullableStringFromMap(item['slug']),
        url: MtnMinecraftContentModel.nullableStringFromMap(item['url']),
        iconUrl: MtnMinecraftContentModel.nullableStringFromMap(item['iconUrl']),
        parentId: MtnMinecraftContentModel.nullableIntFromMap(item['parentCategoryId'])?.toString(),
        primary: primaryCategoryId != null && categoryId == primaryCategoryId,
        provider: providerName,
        providerMetadata: item,
      );
    }).toList(growable: false);

    final authors = MtnMinecraftContentModel.mapListFromMap(map['authors']).map((item) {
      final authorId = MtnMinecraftContentModel.intFromMap(item['id'], fallback: -1);
      final name = MtnMinecraftContentModel.stringFromMap(item['name']);
      return MtnMinecraftContentAuthor(
        id: authorId > 0 ? authorId.toString() : null,
        name: name,
        username: name,
        url: MtnMinecraftContentModel.nullableStringFromMap(item['url']),
        provider: providerName,
        providerMetadata: item,
      );
    }).toList(growable: false);

    final linksMap = MtnMinecraftContentModel.mapFromMap(map['links']);
    final links = MtnMinecraftContentLinks(
      website: MtnMinecraftContentModel.nullableStringFromMap(linksMap['websiteUrl']),
      source: MtnMinecraftContentModel.nullableStringFromMap(linksMap['sourceUrl']),
      issues: MtnMinecraftContentModel.nullableStringFromMap(linksMap['issuesUrl']),
      wiki: MtnMinecraftContentModel.nullableStringFromMap(linksMap['wikiUrl']),
    );

    final logoMap = MtnMinecraftContentModel.mapFromMap(map['logo']);
    final logoUrl = MtnMinecraftContentModel.nullableStringFromMap(logoMap['url']);
    final icon = logoUrl == null
        ? null
        : MtnMinecraftContentImage(
            id: MtnMinecraftContentModel.nullableIntFromMap(logoMap['id'])?.toString(),
            url: logoUrl,
            thumbnailUrl: MtnMinecraftContentModel.nullableStringFromMap(logoMap['thumbnailUrl']),
            title: MtnMinecraftContentModel.nullableStringFromMap(logoMap['title']),
            description: MtnMinecraftContentModel.nullableStringFromMap(logoMap['description']),
            provider: providerName,
            providerMetadata: logoMap,
          );

    final screenshots = MtnMinecraftContentModel.mapListFromMap(map['screenshots']).map((item) {
      return MtnMinecraftContentImage(
        id: MtnMinecraftContentModel.nullableIntFromMap(item['id'])?.toString(),
        url: MtnMinecraftContentModel.stringFromMap(item['url']),
        thumbnailUrl: MtnMinecraftContentModel.nullableStringFromMap(item['thumbnailUrl']),
        title: MtnMinecraftContentModel.nullableStringFromMap(item['title']),
        description: MtnMinecraftContentModel.nullableStringFromMap(item['description']),
        provider: providerName,
        providerMetadata: item,
      );
    }).toList(growable: false);

    final arguments = (
      key: '$providerName:$id',
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      slug: MtnMinecraftContentModel.nullableStringFromMap(map['slug']),
      summary: MtnMinecraftContentModel.nullableStringFromMap(map['summary']),
      description: description,
      providers: <MtnMinecraftContentProviderMetadata>[
        MtnMinecraftContentProviderMetadata(provider: providerName, id: id.toString(), metadata: map),
      ],
      authors: authors,
      categories: categories,
      links: links,
      icon: icon,
      gallery: screenshots,
      createdAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['dateCreated']),
      updatedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['dateModified']),
      releasedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['dateReleased']),
    );

    switch (type) {
      case MtnMinecraftContentType.mod:
        return MtnMinecraftContentMod(key: arguments.key, name: arguments.name, slug: arguments.slug, summary: arguments.summary, description: arguments.description, providers: arguments.providers, authors: arguments.authors, categories: arguments.categories, links: arguments.links, icon: arguments.icon, gallery: arguments.gallery, createdAt: arguments.createdAt, updatedAt: arguments.updatedAt, releasedAt: arguments.releasedAt);
      case MtnMinecraftContentType.modPack:
        return MtnMinecraftContentModPack(key: arguments.key, name: arguments.name, slug: arguments.slug, summary: arguments.summary, description: arguments.description, providers: arguments.providers, authors: arguments.authors, categories: arguments.categories, links: arguments.links, icon: arguments.icon, gallery: arguments.gallery, createdAt: arguments.createdAt, updatedAt: arguments.updatedAt, releasedAt: arguments.releasedAt);
      case MtnMinecraftContentType.resourcePack:
        return MtnMinecraftContentResourcePack(key: arguments.key, name: arguments.name, slug: arguments.slug, summary: arguments.summary, description: arguments.description, providers: arguments.providers, authors: arguments.authors, categories: arguments.categories, links: arguments.links, icon: arguments.icon, gallery: arguments.gallery, createdAt: arguments.createdAt, updatedAt: arguments.updatedAt, releasedAt: arguments.releasedAt);
      case MtnMinecraftContentType.shaderPack:
        return MtnMinecraftContentShaderPack(key: arguments.key, name: arguments.name, slug: arguments.slug, summary: arguments.summary, description: arguments.description, providers: arguments.providers, authors: arguments.authors, categories: arguments.categories, links: arguments.links, icon: arguments.icon, gallery: arguments.gallery, createdAt: arguments.createdAt, updatedAt: arguments.updatedAt, releasedAt: arguments.releasedAt);
      case MtnMinecraftContentType.dataPack:
        return MtnMinecraftContentDataPack(key: arguments.key, name: arguments.name, slug: arguments.slug, summary: arguments.summary, description: arguments.description, providers: arguments.providers, authors: arguments.authors, categories: arguments.categories, links: arguments.links, icon: arguments.icon, gallery: arguments.gallery, createdAt: arguments.createdAt, updatedAt: arguments.updatedAt, releasedAt: arguments.releasedAt);
    }
  }

  static void validateVersionRequest(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) {
    if (request.offset + request.limit > 10000) throw ArgumentError.value(request.offset, 'request.offset', 'CurseForge requires offset + limit to be at most 10000.');
    if (request.gameVersions.length > 1) throw ArgumentError.value(request.gameVersions, 'request.gameVersions', 'CurseForge file listing accepts at most one game version.');
    if (request.modLoaders.length > 1) throw ArgumentError.value(request.modLoaders, 'request.modLoaders', 'CurseForge file listing accepts at most one mod loader.');
    if (request.modLoaders.isEmpty) return;

    final loader = request.modLoaders.single;
    if (content is! MtnMinecraftContentMod) {
      if (loader != MtnMinecraftModLoaderType.vanilla) throw ArgumentError.value(loader, 'request.modLoaders', 'Non-mod content can only use the generic vanilla loader.');
      return;
    }

    _loaderWireValue(loader);
  }

  static Map<String, String> versionQuery(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request, {required int index, required int pageSize}) {
    final loader = request.modLoaders.isEmpty ? null : request.modLoaders.single;
    final shouldSendLoader = loader != null && !(content is! MtnMinecraftContentMod && loader == MtnMinecraftModLoaderType.vanilla);

    return <String, String>{
      if (request.gameVersions.isNotEmpty) 'gameVersion': request.gameVersions.single,
      if (shouldSendLoader) 'modLoaderType': _loaderWireValue(loader).toString(),
      'index': index.toString(),
      'pageSize': pageSize.toString(),
    };
  }

  static MtnMinecraftContentVersionListResult versionResult(
    String providerName,
    MtnMinecraftContent content,
    MtnMinecraftContentVersionListRequest request,
    List<Map<String, dynamic>> files,
  ) {
    final expectedModId = providerId(providerName, content);
    final versions = <MtnMinecraftContentVersion>[];

    for (final file in files) {
      final modId = MtnMinecraftContentModel.intFromMap(file['modId'], fallback: -1);
      if (modId != expectedModId) throw FormatException('CurseForge file belongs to project $modId instead of $expectedModId.');

      final releaseType = _releaseType(MtnMinecraftContentModel.intFromMap(file['releaseType'], fallback: -1));
      if (request.releaseTypes.isNotEmpty && !request.releaseTypes.contains(releaseType)) continue;

      versions.add(_version(providerName, content, request, file, releaseType));
    }

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

    return MtnMinecraftContentVersionListResult(
      versions: versions.sublist(start, end),
      offset: request.offset,
      limit: request.limit,
      total: total,
      hasMore: end < total,
    );
  }

  static MtnMinecraftContentVersion _version(
    String providerName,
    MtnMinecraftContent content,
    MtnMinecraftContentVersionListRequest request,
    Map<String, dynamic> file,
    MtnMinecraftContentVersionReleaseType releaseType,
  ) {
    final fileId = MtnMinecraftContentModel.intFromMap(file['id'], fallback: -1);
    if (fileId <= 0) throw const FormatException('CurseForge file id must be positive.');

    final fileName = MtnMinecraftContentModel.stringFromMap(file['fileName']);
    final displayName = MtnMinecraftContentModel.nullableStringFromMap(file['displayName']);
    final versionName = displayName ?? fileName;

    final hashes = MtnMinecraftContentModel.mapListFromMap(file['hashes']).map((item) {
      final algorithmId = MtnMinecraftContentModel.intFromMap(item['algo'], fallback: -1);
      if (algorithmId <= 0) throw FormatException('Invalid CurseForge hash algorithm: $algorithmId');

      final algorithm = switch (algorithmId) {
        1 => 'sha1',
        2 => 'md5',
        _ => 'curseforge:$algorithmId',
      };
      return MtnMinecraftContentFileHash(
        algorithm: algorithm,
        value: MtnMinecraftContentModel.stringFromMap(item['value']),
      );
    }).toList(growable: false);

    final modules = MtnMinecraftContentModel.mapListFromMap(file['modules']).map((item) {
      return MtnMinecraftContentFileModule(
        name: MtnMinecraftContentModel.stringFromMap(item['name']),
        fingerprint: MtnMinecraftContentModel.intFromMap(item['fingerprint']),
      );
    }).toList(growable: false);

    final dependencies = MtnMinecraftContentModel.mapListFromMap(file['dependencies']).map((item) {
      final dependencyModId = MtnMinecraftContentModel.intFromMap(item['modId'], fallback: -1);
      if (dependencyModId <= 0) throw FormatException('Invalid CurseForge dependency mod id: $dependencyModId');

      return MtnMinecraftContentDependency(
        type: _dependencyType(MtnMinecraftContentModel.intFromMap(item['relationType'], fallback: -1)),
        provider: providerName,
        providerContentId: dependencyModId.toString(),
        providerMetadata: item,
      );
    }).toList(growable: false);

    final contentFile = MtnMinecraftContentFile(
      providers: <MtnMinecraftContentProviderMetadata>[
        MtnMinecraftContentProviderMetadata(provider: providerName, id: fileId.toString(), metadata: file),
      ],
      fileName: fileName,
      displayName: displayName,
      downloadUrl: MtnMinecraftContentModel.nullableStringFromMap(file['downloadUrl']),
      size: MtnMinecraftContentModel.nullableIntFromMap(file['fileLength']),
      sizeOnDisk: MtnMinecraftContentModel.nullableIntFromMap(file['fileSizeOnDisk']),
      primary: true,
      available: MtnMinecraftContentModel.nullableBoolFromMap(file['isAvailable']),
      hashes: hashes,
      fingerprint: MtnMinecraftContentModel.nullableIntFromMap(file['fileFingerprint']),
      modules: modules,
    );

    return MtnMinecraftContentVersion(
      key: '$providerName:$fileId',
      content: content,
      providers: <MtnMinecraftContentProviderMetadata>[
        MtnMinecraftContentProviderMetadata(provider: providerName, id: fileId.toString(), metadata: file),
      ],
      name: versionName,
      version: versionName,
      releaseType: releaseType,
      gameVersions: _gameVersions(file),
      modLoaders: _versionLoaders(content, request, file),
      publishedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(file['fileDate']),
      files: <MtnMinecraftContentFile>[contentFile],
      dependencies: dependencies,
    );
  }

  static List<String> _gameVersions(Map<String, dynamic> file) {
    final sortable = MtnMinecraftContentModel.mapListFromMap(file['sortableGameVersions']);
    final result = <String>[];

    for (final item in sortable) {
      final value = MtnMinecraftContentModel.nullableStringFromMap(item['gameVersionName']) ?? MtnMinecraftContentModel.nullableStringFromMap(item['gameVersion']);
      if (value == null || _isNonMinecraftVersionTag(value)) continue;
      if (!result.contains(value)) result.add(value);
    }

    if (result.isNotEmpty) return result;

    for (final value in MtnMinecraftContentModel.stringListFromMap(file['gameVersions'])) {
      if (_isNonMinecraftVersionTag(value)) continue;
      if (!result.contains(value)) result.add(value);
    }

    return result;
  }

  static List<MtnMinecraftModLoaderType> _versionLoaders(
    MtnMinecraftContent content,
    MtnMinecraftContentVersionListRequest request,
    Map<String, dynamic> file,
  ) {
    if (content is! MtnMinecraftContentMod) return const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla];
    if (request.modLoaders.isNotEmpty) return <MtnMinecraftModLoaderType>[request.modLoaders.single];

    final result = <MtnMinecraftModLoaderType>[];
    for (final value in MtnMinecraftContentModel.stringListFromMap(file['gameVersions'])) {
      final loader = _loaderFromWireName(value);
      if (loader != null && !result.contains(loader)) result.add(loader);
    }

    return result.isEmpty ? const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.unknown] : result;
  }

  static int _loaderWireValue(MtnMinecraftModLoaderType loader) {
    return switch (loader) {
      MtnMinecraftModLoaderType.forge => 1,
      MtnMinecraftModLoaderType.cauldron => 2,
      MtnMinecraftModLoaderType.liteLoader => 3,
      MtnMinecraftModLoaderType.fabric => 4,
      MtnMinecraftModLoaderType.quilt => 5,
      MtnMinecraftModLoaderType.neoForge => 6,
      MtnMinecraftModLoaderType.vanilla => throw ArgumentError.value(loader, 'loader', 'CurseForge does not expose a Vanilla loader filter; Any is not equivalent to Vanilla.'),
      MtnMinecraftModLoaderType.unknown => throw ArgumentError.value(loader, 'loader', 'Unknown mod loader cannot be used as a CurseForge API filter.'),
    };
  }

  static MtnMinecraftModLoaderType? _loaderFromWireName(String value) {
    return switch (_normalize(value)) {
      'forge' => MtnMinecraftModLoaderType.forge,
      'cauldron' => MtnMinecraftModLoaderType.cauldron,
      'liteloader' => MtnMinecraftModLoaderType.liteLoader,
      'fabric' => MtnMinecraftModLoaderType.fabric,
      'quilt' => MtnMinecraftModLoaderType.quilt,
      'neoforge' => MtnMinecraftModLoaderType.neoForge,
      _ => null,
    };
  }

  static MtnMinecraftContentVersionReleaseType _releaseType(int value) {
    return switch (value) {
      1 => MtnMinecraftContentVersionReleaseType.release,
      2 => MtnMinecraftContentVersionReleaseType.beta,
      3 => MtnMinecraftContentVersionReleaseType.alpha,
      _ => throw FormatException('Unsupported CurseForge release type: $value'),
    };
  }

  static MtnMinecraftContentDependencyType _dependencyType(int value) {
    return switch (value) {
      1 => MtnMinecraftContentDependencyType.embedded,
      2 => MtnMinecraftContentDependencyType.optional,
      3 => MtnMinecraftContentDependencyType.required,
      4 => MtnMinecraftContentDependencyType.tool,
      5 => MtnMinecraftContentDependencyType.incompatible,
      6 => MtnMinecraftContentDependencyType.included,
      _ => throw FormatException('Unsupported CurseForge dependency relation type: $value'),
    };
  }

  static MtnMinecraftContentType? _contentTypeFromClass(String? name, String? slug) {
    final values = <String>{
      if (name != null) _normalize(name),
      if (slug != null) _normalize(slug),
    };

    if (values.contains('mods') || values.contains('mcmods')) return MtnMinecraftContentType.mod;
    if (values.contains('modpacks')) return MtnMinecraftContentType.modPack;
    if (values.contains('resourcepacks') || values.contains('texturepacks')) return MtnMinecraftContentType.resourcePack;
    if (values.contains('shaders') || values.contains('shaderpacks')) return MtnMinecraftContentType.shaderPack;
    if (values.contains('datapacks')) return MtnMinecraftContentType.dataPack;
    return null;
  }

  static bool _isNonMinecraftVersionTag(String value) {
    if (_loaderFromWireName(value) != null) return true;
    final normalized = _normalize(value);
    return normalized == 'client' || normalized == 'server';
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
