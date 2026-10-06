/// Recognized Java Edition mod-loader family.
enum MtnMinecraftInfoModLoaderType {
  fabric,
  forge,
  neoForge,
  quilt,
}

/// Installed mod-loader information needed by launcher-facing discovery.
final class MtnMinecraftInfoModLoader {
  const MtnMinecraftInfoModLoader({
    required this.type,
    required this.version,
    required this.minecraftVersion,
  });

  final MtnMinecraftInfoModLoaderType type;

  /// Loader version, for example `0.19.5` for Fabric Loader.
  final String version;

  /// Minecraft version inherited by the loader profile.
  final String minecraftVersion;
}
