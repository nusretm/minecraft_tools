part of 'minecraft_content_models.dart';

enum MtnMinecraftContentType {
  mod,
  modPack,
  resourcePack,
  shaderPack,
  dataPack,
}

enum MtnMinecraftModLoaderType {
  vanilla,
  fabric,
  quilt,
  forge,
  neoForge,
  cauldron,
  liteLoader,
  unknown,
}

enum MtnMinecraftContentVersionReleaseType {
  release,
  beta,
  alpha,
}

enum MtnMinecraftContentEnvironment {
  clientAndServer,
  clientOnly,
  clientOnlyServerOptional,
  singleplayerOnly,
  serverOnly,
  serverOnlyClientOptional,
  dedicatedServerOnly,
  clientOrServer,
  clientOrServerPrefersBoth,
  unknown,
}

enum MtnMinecraftContentDependencyType {
  required,
  optional,
  incompatible,
  embedded,
  included,
  tool,
}

enum MtnMinecraftContentRelationType {
  included,
  embedded,
}

class MtnMinecraftContentProviderMetadata extends MtnMinecraftContentModel {
  MtnMinecraftContentProviderMetadata({
    required this.provider,
    this.id,
    Map<String, dynamic>? metadata,
  }) : metadata = Map<String, dynamic>.unmodifiable(metadata ?? <String, dynamic>{});

  factory MtnMinecraftContentProviderMetadata.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentProviderMetadata(
      provider: MtnMinecraftContentModel.stringFromMap(map['provider']),
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      metadata: MtnMinecraftContentModel.mapFromMap(map['metadata']),
    );
  }

  final String provider;
  final String? id;
  final Map<String, dynamic> metadata;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'provider': provider,
    'id': id,
    'metadata': metadata,
  };
}

class MtnMinecraftContentAuthor extends MtnMinecraftContentModel {
  MtnMinecraftContentAuthor({
    required this.name,
    this.id,
    this.username,
    this.role,
    this.url,
    this.avatarUrl,
    this.provider,
    Map<String, dynamic>? providerMetadata,
  }) : providerMetadata = Map<String, dynamic>.unmodifiable(providerMetadata ?? <String, dynamic>{});

  factory MtnMinecraftContentAuthor.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentAuthor(
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      username: MtnMinecraftContentModel.nullableStringFromMap(map['username']),
      role: MtnMinecraftContentModel.nullableStringFromMap(map['role']),
      url: MtnMinecraftContentModel.nullableStringFromMap(map['url']),
      avatarUrl: MtnMinecraftContentModel.nullableStringFromMap(map['avatarUrl']),
      provider: MtnMinecraftContentModel.nullableStringFromMap(map['provider']),
      providerMetadata: MtnMinecraftContentModel.mapFromMap(map['providerMetadata']),
    );
  }

  final String? id;
  final String name;
  final String? username;
  final String? role;
  final String? url;
  final String? avatarUrl;
  final String? provider;
  final Map<String, dynamic> providerMetadata;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'username': username,
    'role': role,
    'url': url,
    'avatarUrl': avatarUrl,
    'provider': provider,
    'providerMetadata': providerMetadata,
  };
}

class MtnMinecraftContentCategory extends MtnMinecraftContentModel {
  MtnMinecraftContentCategory({
    required this.name,
    this.id,
    this.slug,
    this.url,
    this.iconUrl,
    this.parentId,
    this.primary = false,
    this.provider,
    Map<String, dynamic>? providerMetadata,
  }) : providerMetadata = Map<String, dynamic>.unmodifiable(providerMetadata ?? <String, dynamic>{});

  factory MtnMinecraftContentCategory.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentCategory(
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      slug: MtnMinecraftContentModel.nullableStringFromMap(map['slug']),
      url: MtnMinecraftContentModel.nullableStringFromMap(map['url']),
      iconUrl: MtnMinecraftContentModel.nullableStringFromMap(map['iconUrl']),
      parentId: MtnMinecraftContentModel.nullableStringFromMap(map['parentId']),
      primary: MtnMinecraftContentModel.boolFromMap(map['primary']),
      provider: MtnMinecraftContentModel.nullableStringFromMap(map['provider']),
      providerMetadata: MtnMinecraftContentModel.mapFromMap(map['providerMetadata']),
    );
  }

  final String? id;
  final String name;
  final String? slug;
  final String? url;
  final String? iconUrl;
  final String? parentId;
  final bool primary;
  final String? provider;
  final Map<String, dynamic> providerMetadata;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'url': url,
    'iconUrl': iconUrl,
    'parentId': parentId,
    'primary': primary,
    'provider': provider,
    'providerMetadata': providerMetadata,
  };
}

class MtnMinecraftContentImage extends MtnMinecraftContentModel {
  MtnMinecraftContentImage({
    required this.url,
    this.id,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.featured = false,
    this.ordering,
    this.createdAt,
    this.provider,
    Map<String, dynamic>? providerMetadata,
  }) : providerMetadata = Map<String, dynamic>.unmodifiable(providerMetadata ?? <String, dynamic>{});

  factory MtnMinecraftContentImage.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentImage(
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      url: MtnMinecraftContentModel.stringFromMap(map['url']),
      thumbnailUrl: MtnMinecraftContentModel.nullableStringFromMap(map['thumbnailUrl']),
      title: MtnMinecraftContentModel.nullableStringFromMap(map['title']),
      description: MtnMinecraftContentModel.nullableStringFromMap(map['description']),
      featured: MtnMinecraftContentModel.boolFromMap(map['featured']),
      ordering: MtnMinecraftContentModel.nullableIntFromMap(map['ordering']),
      createdAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['createdAt']),
      provider: MtnMinecraftContentModel.nullableStringFromMap(map['provider']),
      providerMetadata: MtnMinecraftContentModel.mapFromMap(map['providerMetadata']),
    );
  }

  final String? id;
  final String url;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final bool featured;
  final int? ordering;
  final DateTime? createdAt;
  final String? provider;
  final Map<String, dynamic> providerMetadata;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'title': title,
    'description': description,
    'featured': featured,
    'ordering': ordering,
    'createdAt': createdAt,
    'provider': provider,
    'providerMetadata': providerMetadata,
  };
}

class MtnMinecraftContentDonation extends MtnMinecraftContentModel {
  MtnMinecraftContentDonation({
    required this.url,
    this.id,
    this.platform,
  });

  factory MtnMinecraftContentDonation.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentDonation(
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      platform: MtnMinecraftContentModel.nullableStringFromMap(map['platform']),
      url: MtnMinecraftContentModel.stringFromMap(map['url']),
    );
  }

  final String? id;
  final String? platform;
  final String url;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'platform': platform,
    'url': url,
  };
}

class MtnMinecraftContentLinks extends MtnMinecraftContentModel {
  MtnMinecraftContentLinks({
    this.website,
    this.source,
    this.issues,
    this.wiki,
    this.discord,
    List<MtnMinecraftContentDonation>? donations,
  }) : donations = List<MtnMinecraftContentDonation>.unmodifiable(donations ?? <MtnMinecraftContentDonation>[]);

  factory MtnMinecraftContentLinks.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentLinks(
      website: MtnMinecraftContentModel.nullableStringFromMap(map['website']),
      source: MtnMinecraftContentModel.nullableStringFromMap(map['source']),
      issues: MtnMinecraftContentModel.nullableStringFromMap(map['issues']),
      wiki: MtnMinecraftContentModel.nullableStringFromMap(map['wiki']),
      discord: MtnMinecraftContentModel.nullableStringFromMap(map['discord']),
      donations: MtnMinecraftContentModel.mapListFromMap(map['donations']).map(MtnMinecraftContentDonation.fromMap).toList(growable: false),
    );
  }

  final String? website;
  final String? source;
  final String? issues;
  final String? wiki;
  final String? discord;
  final List<MtnMinecraftContentDonation> donations;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'website': website,
    'source': source,
    'issues': issues,
    'wiki': wiki,
    'discord': discord,
    'donations': donations,
  };
}

class MtnMinecraftContentLicense extends MtnMinecraftContentModel {
  MtnMinecraftContentLicense({
    this.id,
    this.name,
    this.url,
    Map<String, dynamic>? providerMetadata,
  }) : providerMetadata = Map<String, dynamic>.unmodifiable(providerMetadata ?? <String, dynamic>{});

  factory MtnMinecraftContentLicense.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentLicense(
      id: MtnMinecraftContentModel.nullableStringFromMap(map['id']),
      name: MtnMinecraftContentModel.nullableStringFromMap(map['name']),
      url: MtnMinecraftContentModel.nullableStringFromMap(map['url']),
      providerMetadata: MtnMinecraftContentModel.mapFromMap(map['providerMetadata']),
    );
  }

  final String? id;
  final String? name;
  final String? url;
  final Map<String, dynamic> providerMetadata;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    'providerMetadata': providerMetadata,
  };
}
