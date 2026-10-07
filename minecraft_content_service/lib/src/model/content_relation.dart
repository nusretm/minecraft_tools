part of 'minecraft_content_models.dart';

class MtnMinecraftContentRelation extends MtnMinecraftContentModel {
  MtnMinecraftContentRelation({
    required this.source,
    required this.owner,
    required this.type,
  }) {
    if (identical(source, owner)) throw ArgumentError('A content relation cannot reference the same version as source and owner.');
  }

  factory MtnMinecraftContentRelation.fromMap(Map<String, dynamic> map, Map<String, MtnMinecraftContentVersion> versions) {
    final sourceKey = MtnMinecraftContentModel.stringFromMap(map['source']);
    final ownerKey = MtnMinecraftContentModel.stringFromMap(map['owner']);
    final source = versions[sourceKey];
    final owner = versions[ownerKey];
    if (source == null) throw FormatException('Relation references unknown source version: $sourceKey');
    if (owner == null) throw FormatException('Relation references unknown owner version: $ownerKey');

    return MtnMinecraftContentRelation(
      source: source,
      owner: owner,
      type: MtnMinecraftContentModel.enumFromMap(MtnMinecraftContentRelationType.values, map['type']),
    );
  }

  final MtnMinecraftContentVersion source;
  final MtnMinecraftContentVersion owner;
  final MtnMinecraftContentRelationType type;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'source': source.key,
    'owner': owner.key,
    'type': type,
  };
}
