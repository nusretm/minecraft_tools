part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemPlatform {
  windows,
  posix,
}

class MtnMinecraftContentMaterializationFileSystemPolicy {
  const MtnMinecraftContentMaterializationFileSystemPolicy({
    required this.platform,
    required this.caseSensitive,
  });

  factory MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    if (Platform.isWindows) {
      return const MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.windows,
        caseSensitive: false,
      );
    }
    if (Platform.isMacOS) {
      return const MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
        caseSensitive: false,
      );
    }
    return const MtnMinecraftContentMaterializationFileSystemPolicy(
      platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
      caseSensitive: true,
    );
  }

  final MtnMinecraftContentMaterializationFileSystemPlatform platform;
  final bool caseSensitive;
}
