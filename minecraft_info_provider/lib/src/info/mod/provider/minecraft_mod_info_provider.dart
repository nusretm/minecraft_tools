import 'dart:io';
import 'dart:typed_data';

import '../info_mod.dart';

enum MtnMinecraftModInfoProviderError {
  readFailed,
  invalidData,
}

final class MtnMinecraftModInfoProviderException implements Exception {
  const MtnMinecraftModInfoProviderException(this.error);

  final MtnMinecraftModInfoProviderError error;

  @override
  String toString() => 'MtnMinecraftModInfoProviderException(${error.name})';
}

/// Parses one mod metadata format into normalized Minecraft mod information.
abstract class MtnMinecraftModInfoProvider {
  const MtnMinecraftModInfoProvider();

  /// Stable registry identity for this provider.
  String get name;

  /// Parses one root JAR from disk.
  ///
  /// Returns null when the JAR does not belong to this provider.
  Future<List<MtnMinecraftInfoMod>?> parse(File jarFile);

  /// Parses one JAR already available in memory.
  ///
  /// [parentMod] identifies the mod that embeds this JAR, when applicable.
  /// Returns null when the JAR does not belong to this provider.
  Future<List<MtnMinecraftInfoMod>?> parseJarContent(
    Uint8List content, {
    MtnMinecraftInfoMod? parentMod,
  });
}
