part of 'minecraft_content_models.dart';

abstract class MtnMinecraftContent extends MtnMinecraftContentModel {
  MtnMinecraftContent({
    required this.key,
    required this.type,
    required this.name,
    this.slug,
    this.summary,
    this.description,
    List<MtnMinecraftContentProviderMetadata>? providers,
    List<MtnMinecraftContentAuthor>? authors,
    List<MtnMinecraftContentCategory>? categories,
    this.links,
    this.icon,
    List<MtnMinecraftContentImage>? gallery,
    this.license,
    this.createdAt,
    this.updatedAt,
    this.releasedAt,
  }) : providers = List<MtnMinecraftContentProviderMetadata>.unmodifiable(providers ?? <MtnMinecraftContentProviderMetadata>[]),
       authors = List<MtnMinecraftContentAuthor>.unmodifiable(authors ?? <MtnMinecraftContentAuthor>[]),
       categories = List<MtnMinecraftContentCategory>.unmodifiable(categories ?? <MtnMinecraftContentCategory>[]),
       gallery = List<MtnMinecraftContentImage>.unmodifiable(gallery ?? <MtnMinecraftContentImage>[]) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', 'Content key cannot be empty.');
    if (name.isEmpty) throw ArgumentError.value(name, 'name', 'Content name cannot be empty.');

    final providerNames = <String>{};
    for (final provider in this.providers) {
      if (provider.provider.isEmpty) throw ArgumentError.value(provider.provider, 'providers', 'Provider name cannot be empty.');
      if (!providerNames.add(provider.provider)) throw ArgumentError.value(provider.provider, 'providers', 'A content can contain only one metadata entry per provider.');
    }
  }

  factory MtnMinecraftContent.fromMap(Map<String, dynamic> map) {
    final type = MtnMinecraftContentModel.enumFromMap(MtnMinecraftContentType.values, map['type']);
    final providers = MtnMinecraftContentModel.mapListFromMap(map['providers']).map(MtnMinecraftContentProviderMetadata.fromMap).toList(growable: false);
    final authors = MtnMinecraftContentModel.mapListFromMap(map['authors']).map(MtnMinecraftContentAuthor.fromMap).toList(growable: false);
    final categories = MtnMinecraftContentModel.mapListFromMap(map['categories']).map(MtnMinecraftContentCategory.fromMap).toList(growable: false);
    final gallery = MtnMinecraftContentModel.mapListFromMap(map['gallery']).map(MtnMinecraftContentImage.fromMap).toList(growable: false);
    final linksMap = map['links'];
    final iconMap = map['icon'];
    final licenseMap = map['license'];

    final key = MtnMinecraftContentModel.stringFromMap(map['key']);
    final name = MtnMinecraftContentModel.stringFromMap(map['name']);
    final slug = MtnMinecraftContentModel.nullableStringFromMap(map['slug']);
    final summary = MtnMinecraftContentModel.nullableStringFromMap(map['summary']);
    final description = MtnMinecraftContentModel.nullableStringFromMap(map['description']);
    final links = linksMap == null ? null : MtnMinecraftContentLinks.fromMap(MtnMinecraftContentModel.mapFromMap(linksMap));
    final icon = iconMap == null ? null : MtnMinecraftContentImage.fromMap(MtnMinecraftContentModel.mapFromMap(iconMap));
    final license = licenseMap == null ? null : MtnMinecraftContentLicense.fromMap(MtnMinecraftContentModel.mapFromMap(licenseMap));
    final createdAt = MtnMinecraftContentModel.nullableDateTimeFromMap(map['createdAt']);
    final updatedAt = MtnMinecraftContentModel.nullableDateTimeFromMap(map['updatedAt']);
    final releasedAt = MtnMinecraftContentModel.nullableDateTimeFromMap(map['releasedAt']);

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

  final String key;
  final MtnMinecraftContentType type;
  final String name;
  final String? slug;
  final String? summary;
  final String? description;
  final List<MtnMinecraftContentProviderMetadata> providers;
  final List<MtnMinecraftContentAuthor> authors;
  final List<MtnMinecraftContentCategory> categories;
  final MtnMinecraftContentLinks? links;
  final MtnMinecraftContentImage? icon;
  final List<MtnMinecraftContentImage> gallery;
  final MtnMinecraftContentLicense? license;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? releasedAt;

  final List<MtnMinecraftContentVersion> _versions = <MtnMinecraftContentVersion>[];
  MtnMinecraftContentVersion? _version;

  List<MtnMinecraftContentVersion> get versions => List<MtnMinecraftContentVersion>.unmodifiable(_versions);

  MtnMinecraftContentVersion get version {
    final selected = _version;
    if (selected != null) return selected;
    if (_versions.isEmpty) throw StateError('$runtimeType($key) has no versions.');
    return _versions.last;
  }

  set version(MtnMinecraftContentVersion? value) {
    if (value != null && (!_versions.contains(value) || !identical(value.content, this))) throw ArgumentError.value(value, 'version', 'Version must belong to this content and be registered in versions.');
    _version = value;
  }

  void _addVersion(MtnMinecraftContentVersion value) {
    if (!identical(value.content, this)) throw ArgumentError.value(value, 'value', 'Version content does not match this content.');
    if (_versions.any((item) => item.key == value.key)) throw StateError('Duplicate version key: ${value.key}');
    _versions.add(value);
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    'type': type,
    'name': name,
    'slug': slug,
    'summary': summary,
    'description': description,
    'providers': providers,
    'authors': authors,
    'categories': categories,
    'links': links,
    'icon': icon,
    'gallery': gallery,
    'license': license,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'releasedAt': releasedAt,
    'version': _version?.key,
  };
}

class MtnMinecraftContentMod extends MtnMinecraftContent {
  MtnMinecraftContentMod({
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
  }) : super(key: key, type: MtnMinecraftContentType.mod, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
}

class MtnMinecraftContentModPack extends MtnMinecraftContent {
  MtnMinecraftContentModPack({
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
  }) : super(key: key, type: MtnMinecraftContentType.modPack, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
}

class MtnMinecraftContentResourcePack extends MtnMinecraftContent {
  MtnMinecraftContentResourcePack({
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
  }) : super(key: key, type: MtnMinecraftContentType.resourcePack, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
}

class MtnMinecraftContentShaderPack extends MtnMinecraftContent {
  MtnMinecraftContentShaderPack({
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
  }) : super(key: key, type: MtnMinecraftContentType.shaderPack, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
}

class MtnMinecraftContentDataPack extends MtnMinecraftContent {
  MtnMinecraftContentDataPack({
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
  }) : super(key: key, type: MtnMinecraftContentType.dataPack, name: name, slug: slug, summary: summary, description: description, providers: providers, authors: authors, categories: categories, links: links, icon: icon, gallery: gallery, license: license, createdAt: createdAt, updatedAt: updatedAt, releasedAt: releasedAt);
}
