import 'mtn_launcher_game_version_type.dart';

/// A concrete loader build for an exact Minecraft game-version family.
class MtnLauncherGameLoaderVersion {
  const MtnLauncherGameLoaderVersion({
    required this.mcVersion,
    required this.version,
    required this.url,
    required this.type,
  });

  final String mcVersion;
  /// The full upstream loader version; never trim or reconstruct this for downloads.
  final String version;
  /// URL supplied by the loader callback, cached without regeneration.
  final String url;
  /// Type of the Minecraft game version, NOT the loader's stable/beta channel.
  final MtnLauncherGameVersionType type;

  String get text => version.replaceAll('$mcVersion-', '').replaceAll('-$mcVersion', '');

  Map<String, dynamic> toJson() => {
    'mcVersion': mcVersion,
    'version': version,
    'url': url,
    'type': type.name,
  };

  factory MtnLauncherGameLoaderVersion.fromJson(Map<String, dynamic> json) {
    return MtnLauncherGameLoaderVersion(
      mcVersion: json['mcVersion'] as String,
      version: json['version'] as String,
      url: json['url'] as String,
      type: MtnLauncherGameVersionType.values.byName(json['type'] as String),
    );
  }

  @override
  String toString() => '$runtimeType(mcVersion: $mcVersion, version: $version, type: ${type.name}, url: $url)';
}
