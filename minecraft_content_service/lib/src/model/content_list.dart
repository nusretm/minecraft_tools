part of 'minecraft_content_models.dart';

class MtnMinecraftContentList extends MtnMinecraftContentModel {
  MtnMinecraftContentList();

  factory MtnMinecraftContentList.fromMap(Map<String, dynamic> map) {
    final schemaVersion = MtnMinecraftContentModel.intFromMap(map['schemaVersion']);
    if (schemaVersion != currentSchemaVersion) throw FormatException('Unsupported minecraft content schema version: $schemaVersion');

    final result = MtnMinecraftContentList();
    final selectedVersionKeys = <String, String?>{};

    for (final contentMap in MtnMinecraftContentModel.mapListFromMap(map['contents'])) {
      final content = MtnMinecraftContent.fromMap(contentMap);
      result.addContent(content);
      selectedVersionKeys[content.key] = MtnMinecraftContentModel.nullableStringFromMap(contentMap['version']);
    }

    final contentsByKey = <String, MtnMinecraftContent>{
      for (final content in result._contents) content.key: content,
    };

    for (final versionMap in MtnMinecraftContentModel.mapListFromMap(map['versions'])) {
      final contentKey = MtnMinecraftContentModel.stringFromMap(versionMap['content']);
      final content = contentsByKey[contentKey];
      if (content == null) throw FormatException('Version references unknown content: $contentKey');
      result.addVersion(MtnMinecraftContentVersion.fromMap(versionMap, content));
    }

    final versionsByKey = <String, MtnMinecraftContentVersion>{
      for (final version in result.versions) version.key: version,
    };

    for (final version in result.versions) {
      for (final dependency in version.dependencies) {
        dependency._resolve(contentsByKey, versionsByKey);
      }
    }

    for (final relationMap in MtnMinecraftContentModel.mapListFromMap(map['relations'])) {
      result.addRelation(MtnMinecraftContentRelation.fromMap(relationMap, versionsByKey));
    }

    for (final content in result._contents) {
      final selectedVersionKey = selectedVersionKeys[content.key];
      if (selectedVersionKey == null) continue;
      final selectedVersion = versionsByKey[selectedVersionKey];
      if (selectedVersion == null) throw FormatException('Content ${content.key} selects unknown version: $selectedVersionKey');
      if (!identical(selectedVersion.content, content)) throw FormatException('Content ${content.key} selects a version owned by another content: $selectedVersionKey');
      content.version = selectedVersion;
    }

    return result;
  }

  factory MtnMinecraftContentList.fromJson(String value) => MtnMinecraftContentList.fromMap(MtnMinecraftContentModel.jsonDecode(value));

  factory MtnMinecraftContentList.decode(Uint8List value) => MtnMinecraftContentList.fromMap(MtnMinecraftContentModel.decode(value));

  static const int currentSchemaVersion = 1;

  final List<MtnMinecraftContent> _contents = <MtnMinecraftContent>[];
  final List<MtnMinecraftContentRelation> _relations = <MtnMinecraftContentRelation>[];

  List<MtnMinecraftContent> get contents => List<MtnMinecraftContent>.unmodifiable(_contents);

  List<MtnMinecraftContentVersion> get versions => List<MtnMinecraftContentVersion>.unmodifiable(_contents.expand((content) => content._versions));

  List<MtnMinecraftContentRelation> get relations => List<MtnMinecraftContentRelation>.unmodifiable(_relations);

  void addContent(MtnMinecraftContent content) {
    if (_contents.any((item) => item.key == content.key)) throw StateError('Duplicate content key: ${content.key}');

    for (final provider in content.providers) {
      if (provider.id == null) continue;
      final duplicate = _contents.any((item) => item.providers.any((other) => other.provider == provider.provider && other.id == provider.id));
      if (duplicate) throw StateError('Duplicate provider content identity: ${provider.provider}:${provider.id}');
    }

    _contents.add(content);
  }

  void addVersion(MtnMinecraftContentVersion version) {
    if (!_contents.any((content) => identical(content, version.content))) throw StateError('Version content is not registered in this list: ${version.content.key}');
    if (versions.any((item) => item.key == version.key)) throw StateError('Duplicate version key: ${version.key}');

    for (final provider in version.providers) {
      if (provider.id == null) continue;
      final duplicate = version.content._versions.any((item) => item.providers.any((other) => other.provider == provider.provider && other.id == provider.id));
      if (duplicate) throw StateError('Duplicate provider version identity: ${provider.provider}:${provider.id}');
    }

    version.content._addVersion(version);
  }

  void addRelation(MtnMinecraftContentRelation relation) {
    final registeredVersions = versions;
    if (!registeredVersions.contains(relation.source)) throw StateError('Relation source is not registered: ${relation.source.key}');
    if (!registeredVersions.contains(relation.owner)) throw StateError('Relation owner is not registered: ${relation.owner.key}');

    final duplicate = _relations.any((item) => identical(item.source, relation.source) && identical(item.owner, relation.owner) && item.type == relation.type);
    if (duplicate) throw StateError('Duplicate content relation: ${relation.source.key} -> ${relation.owner.key} (${relation.type.name})');

    _relations.add(relation);
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'schemaVersion': currentSchemaVersion,
    'contents': _contents,
    'versions': versions,
    'relations': _relations,
  };
}
