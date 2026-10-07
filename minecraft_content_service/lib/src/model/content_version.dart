part of 'minecraft_content_models.dart';

class MtnMinecraftContentVersion extends MtnMinecraftContentModel {
  MtnMinecraftContentVersion({
    required this.key,
    required this.content,
    required this.name,
    required this.version,
    required this.releaseType,
    required List<MtnMinecraftModLoaderType> modLoaders,
    List<MtnMinecraftContentProviderMetadata>? providers,
    List<String>? gameVersions,
    this.environment,
    this.publishedAt,
    this.changelog,
    this.featured = false,
    this.direct = false,
    List<MtnMinecraftContentFile>? files,
    List<MtnMinecraftContentDependency>? dependencies,
  }) : providers = List<MtnMinecraftContentProviderMetadata>.unmodifiable(providers ?? <MtnMinecraftContentProviderMetadata>[]),
       gameVersions = List<String>.unmodifiable(gameVersions ?? <String>[]),
       modLoaders = List<MtnMinecraftModLoaderType>.unmodifiable(modLoaders),
       files = List<MtnMinecraftContentFile>.unmodifiable(files ?? <MtnMinecraftContentFile>[]),
       dependencies = List<MtnMinecraftContentDependency>.unmodifiable(dependencies ?? <MtnMinecraftContentDependency>[]) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', 'Version key cannot be empty.');
    if (name.isEmpty) throw ArgumentError.value(name, 'name', 'Version name cannot be empty.');
    if (version.isEmpty) throw ArgumentError.value(version, 'version', 'Version value cannot be empty.');
    if (this.modLoaders.isEmpty) throw ArgumentError.value(this.modLoaders, 'modLoaders', 'modLoaders cannot be empty.');

    final loaderSet = this.modLoaders.toSet();
    if (loaderSet.length != this.modLoaders.length) throw ArgumentError.value(this.modLoaders, 'modLoaders', 'modLoaders cannot contain duplicates.');
    if (loaderSet.contains(MtnMinecraftModLoaderType.vanilla) && loaderSet.length != 1) throw ArgumentError.value(this.modLoaders, 'modLoaders', 'vanilla cannot be combined with another mod loader.');
    if (content is! MtnMinecraftContentMod && (this.modLoaders.length != 1 || this.modLoaders.single != MtnMinecraftModLoaderType.vanilla)) throw ArgumentError.value(this.modLoaders, 'modLoaders', 'Non-mod content versions must use only vanilla.');

    final providerNames = <String>{};
    for (final provider in this.providers) {
      if (!providerNames.add(provider.provider)) throw ArgumentError.value(provider.provider, 'providers', 'A version can contain only one metadata entry per provider.');
    }
  }

  factory MtnMinecraftContentVersion.fromMap(Map<String, dynamic> map, MtnMinecraftContent content) {
    return MtnMinecraftContentVersion(
      key: MtnMinecraftContentModel.stringFromMap(map['key']),
      content: content,
      providers: MtnMinecraftContentModel.mapListFromMap(map['providers']).map(MtnMinecraftContentProviderMetadata.fromMap).toList(growable: false),
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      version: MtnMinecraftContentModel.stringFromMap(map['version']),
      releaseType: MtnMinecraftContentModel.enumFromMap(MtnMinecraftContentVersionReleaseType.values, map['releaseType']),
      gameVersions: MtnMinecraftContentModel.stringListFromMap(map['gameVersions']),
      modLoaders: MtnMinecraftContentModel.enumListFromMap(MtnMinecraftModLoaderType.values, map['modLoaders']),
      environment: map['environment'] == null ? null : MtnMinecraftContentModel.enumFromMap(MtnMinecraftContentEnvironment.values, map['environment']),
      publishedAt: MtnMinecraftContentModel.nullableDateTimeFromMap(map['publishedAt']),
      changelog: MtnMinecraftContentModel.nullableStringFromMap(map['changelog']),
      featured: MtnMinecraftContentModel.boolFromMap(map['featured']),
      direct: MtnMinecraftContentModel.boolFromMap(map['direct']),
      files: MtnMinecraftContentModel.mapListFromMap(map['files']).map(MtnMinecraftContentFile.fromMap).toList(growable: false),
      dependencies: MtnMinecraftContentModel.mapListFromMap(map['dependencies']).map(MtnMinecraftContentDependency.fromMap).toList(growable: false),
    );
  }

  final String key;
  final MtnMinecraftContent content;
  final List<MtnMinecraftContentProviderMetadata> providers;
  final String name;
  final String version;
  final MtnMinecraftContentVersionReleaseType releaseType;
  final List<String> gameVersions;
  final List<MtnMinecraftModLoaderType> modLoaders;
  final MtnMinecraftContentEnvironment? environment;
  final DateTime? publishedAt;
  final String? changelog;
  final bool featured;
  bool direct;
  final List<MtnMinecraftContentFile> files;
  final List<MtnMinecraftContentDependency> dependencies;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    'content': content.key,
    'providers': providers,
    'name': name,
    'version': version,
    'releaseType': releaseType,
    'gameVersions': gameVersions,
    'modLoaders': modLoaders,
    'environment': environment,
    'publishedAt': publishedAt,
    'changelog': changelog,
    'featured': featured,
    'direct': direct,
    'files': files,
    'dependencies': dependencies,
  };
}

class MtnMinecraftContentFile extends MtnMinecraftContentModel {
  MtnMinecraftContentFile({
    required this.fileName,
    List<MtnMinecraftContentProviderMetadata>? providers,
    this.displayName,
    this.downloadUrl,
    this.size,
    this.sizeOnDisk,
    this.primary = false,
    this.available,
    this.type,
    List<MtnMinecraftContentFileHash>? hashes,
    this.fingerprint,
    List<MtnMinecraftContentFileModule>? modules,
  }) : providers = List<MtnMinecraftContentProviderMetadata>.unmodifiable(providers ?? <MtnMinecraftContentProviderMetadata>[]),
       hashes = List<MtnMinecraftContentFileHash>.unmodifiable(hashes ?? <MtnMinecraftContentFileHash>[]),
       modules = List<MtnMinecraftContentFileModule>.unmodifiable(modules ?? <MtnMinecraftContentFileModule>[]) {
    if (fileName.isEmpty) throw ArgumentError.value(fileName, 'fileName', 'File name cannot be empty.');
  }

  factory MtnMinecraftContentFile.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentFile(
      providers: MtnMinecraftContentModel.mapListFromMap(map['providers']).map(MtnMinecraftContentProviderMetadata.fromMap).toList(growable: false),
      fileName: MtnMinecraftContentModel.stringFromMap(map['fileName']),
      displayName: MtnMinecraftContentModel.nullableStringFromMap(map['displayName']),
      downloadUrl: MtnMinecraftContentModel.nullableStringFromMap(map['downloadUrl']),
      size: MtnMinecraftContentModel.nullableIntFromMap(map['size']),
      sizeOnDisk: MtnMinecraftContentModel.nullableIntFromMap(map['sizeOnDisk']),
      primary: MtnMinecraftContentModel.boolFromMap(map['primary']),
      available: MtnMinecraftContentModel.nullableBoolFromMap(map['available']),
      type: MtnMinecraftContentModel.nullableStringFromMap(map['type']),
      hashes: MtnMinecraftContentModel.mapListFromMap(map['hashes']).map(MtnMinecraftContentFileHash.fromMap).toList(growable: false),
      fingerprint: MtnMinecraftContentModel.nullableIntFromMap(map['fingerprint']),
      modules: MtnMinecraftContentModel.mapListFromMap(map['modules']).map(MtnMinecraftContentFileModule.fromMap).toList(growable: false),
    );
  }

  final List<MtnMinecraftContentProviderMetadata> providers;
  final String fileName;
  final String? displayName;
  final String? downloadUrl;
  final int? size;
  final int? sizeOnDisk;
  final bool primary;
  final bool? available;
  final String? type;
  final List<MtnMinecraftContentFileHash> hashes;
  final int? fingerprint;
  final List<MtnMinecraftContentFileModule> modules;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'providers': providers,
    'fileName': fileName,
    'displayName': displayName,
    'downloadUrl': downloadUrl,
    'size': size,
    'sizeOnDisk': sizeOnDisk,
    'primary': primary,
    'available': available,
    'type': type,
    'hashes': hashes,
    'fingerprint': fingerprint,
    'modules': modules,
  };
}

class MtnMinecraftContentFileHash extends MtnMinecraftContentModel {
  MtnMinecraftContentFileHash({
    required this.algorithm,
    required this.value,
  }) {
    if (algorithm.isEmpty) throw ArgumentError.value(algorithm, 'algorithm', 'Hash algorithm cannot be empty.');
    if (value.isEmpty) throw ArgumentError.value(value, 'value', 'Hash value cannot be empty.');
  }

  factory MtnMinecraftContentFileHash.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentFileHash(
      algorithm: MtnMinecraftContentModel.stringFromMap(map['algorithm']),
      value: MtnMinecraftContentModel.stringFromMap(map['value']),
    );
  }

  final String algorithm;
  final String value;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'algorithm': algorithm,
    'value': value,
  };
}

class MtnMinecraftContentFileModule extends MtnMinecraftContentModel {
  MtnMinecraftContentFileModule({
    required this.name,
    required this.fingerprint,
  });

  factory MtnMinecraftContentFileModule.fromMap(Map<String, dynamic> map) {
    return MtnMinecraftContentFileModule(
      name: MtnMinecraftContentModel.stringFromMap(map['name']),
      fingerprint: MtnMinecraftContentModel.intFromMap(map['fingerprint']),
    );
  }

  final String name;
  final int fingerprint;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'fingerprint': fingerprint,
  };
}

class MtnMinecraftContentDependency extends MtnMinecraftContentModel {
  MtnMinecraftContentDependency({
    required this.type,
    this.provider,
    this.providerContentId,
    this.providerVersionId,
    this.fileName,
    this.versionConstraint,
    MtnMinecraftContent? content,
    MtnMinecraftContentVersion? version,
    Map<String, dynamic>? providerMetadata,
  }) : _content = content,
       _version = version,
       providerMetadata = Map<String, dynamic>.unmodifiable(providerMetadata ?? <String, dynamic>{}) {
    if (version != null && content != null && !identical(version.content, content)) throw ArgumentError.value(version, 'version', 'Resolved dependency version must belong to the resolved dependency content.');
  }

  factory MtnMinecraftContentDependency.fromMap(Map<String, dynamic> map) {
    final result = MtnMinecraftContentDependency(
      type: MtnMinecraftContentModel.enumFromMap(MtnMinecraftContentDependencyType.values, map['type']),
      provider: MtnMinecraftContentModel.nullableStringFromMap(map['provider']),
      providerContentId: MtnMinecraftContentModel.nullableStringFromMap(map['providerContentId']),
      providerVersionId: MtnMinecraftContentModel.nullableStringFromMap(map['providerVersionId']),
      fileName: MtnMinecraftContentModel.nullableStringFromMap(map['fileName']),
      versionConstraint: MtnMinecraftContentModel.nullableStringFromMap(map['versionConstraint']),
      providerMetadata: MtnMinecraftContentModel.mapFromMap(map['providerMetadata']),
    );
    result._contentKey = MtnMinecraftContentModel.nullableStringFromMap(map['content']);
    result._versionKey = MtnMinecraftContentModel.nullableStringFromMap(map['version']);
    return result;
  }

  final MtnMinecraftContentDependencyType type;
  final String? provider;
  final String? providerContentId;
  final String? providerVersionId;
  final String? fileName;
  final String? versionConstraint;
  final Map<String, dynamic> providerMetadata;

  MtnMinecraftContent? _content;
  MtnMinecraftContentVersion? _version;
  String? _contentKey;
  String? _versionKey;

  MtnMinecraftContent? get content => _content;
  MtnMinecraftContentVersion? get version => _version;

  void _resolve(Map<String, MtnMinecraftContent> contents, Map<String, MtnMinecraftContentVersion> versions) {
    final contentKey = _contentKey;
    final versionKey = _versionKey;

    if (contentKey != null) {
      _content = contents[contentKey];
      if (_content == null) throw FormatException('Dependency references unknown content: $contentKey');
    }

    if (versionKey != null) {
      _version = versions[versionKey];
      if (_version == null) throw FormatException('Dependency references unknown version: $versionKey');
      if (_content != null && !identical(_version!.content, _content)) throw FormatException('Dependency content/version references do not match: $contentKey / $versionKey');
      _content ??= _version!.content;
    }

    _contentKey = null;
    _versionKey = null;
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type,
    'provider': provider,
    'providerContentId': providerContentId,
    'providerVersionId': providerVersionId,
    'fileName': fileName,
    'versionConstraint': versionConstraint,
    'content': _content?.key ?? _contentKey,
    'version': _version?.key ?? _versionKey,
    'providerMetadata': providerMetadata,
  };
}
