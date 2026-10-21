import 'package:minecraft_models/minecraft_models.dart';

/// Minecraft client environment used for resource-helper selection.
final class MtnMinecraftResourceEnvironment {
  const MtnMinecraftResourceEnvironment({
    required this.version,
    required this.loaderType,
  });

  /// Exact Minecraft game version and its authoritative release type.
  final MtnMinecraftVersion version;

  /// Canonical loader identity, including Vanilla.
  final MtnMinecraftLoaderType loaderType;
}
