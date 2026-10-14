import 'minecraft_content_package.dart';
import 'minecraft_content_package_source.dart';

/// Local metadata is encrypted at rest by MtnMinecraftContentPackageRecordCodec.
///
/// A local publisher may retain an editable draft while previously published
/// revisions remain immutable remote snapshots. Origin is not proof of ownership.
class MtnMinecraftContentPackageRecord {
  MtnMinecraftContentPackageRecord({
    required this.package,
    required this.source,
    this.remoteId,
    this.publishedRevision,
  }) {
    if (remoteId != null && remoteId!.trim().isEmpty) throw ArgumentError.value(remoteId, 'remoteId', 'Remote ID cannot be blank.');
    if (publishedRevision != null && publishedRevision! < 1) throw ArgumentError.value(publishedRevision, 'publishedRevision', 'Published revision must be positive.');
  }

  factory MtnMinecraftContentPackageRecord.fromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != currentSchemaVersion) throw FormatException('Unsupported local Content Package Record schema: ${map['schemaVersion']}');
    final rawSource = map['source'];
    final rawPackage = map['package'];
    if (rawPackage is! Map) throw const FormatException('Local record must contain a package.');
    final source = MtnMinecraftContentPackageSource.values.where((value) => value.name == rawSource).firstOrNull;
    if (source == null) throw FormatException('Unknown local package origin: $rawSource');
    if (map['remoteId'] != null && map['remoteId'] is! String) throw const FormatException('Invalid local record remoteId.');
    if (map['publishedRevision'] != null && map['publishedRevision'] is! int) throw const FormatException('Invalid local record publishedRevision.');
    return MtnMinecraftContentPackageRecord(
      package: MtnMinecraftContentPackage.fromLocalMap(Map<String, dynamic>.from(rawPackage)),
      source: source,
      remoteId: map['remoteId'] as String?,
      publishedRevision: map['publishedRevision'] as int?,
    );
  }

  static const int currentSchemaVersion = 2;

  final MtnMinecraftContentPackage package;
  final MtnMinecraftContentPackageSource source;
  final String? remoteId;
  final int? publishedRevision;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'schemaVersion': currentSchemaVersion,
    'package': package.toLocalMap(),
    'source': source.name,
    if (remoteId != null) 'remoteId': remoteId,
    if (publishedRevision != null) 'publishedRevision': publishedRevision,
  };
}
