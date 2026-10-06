import 'dart:io';

/// One directly installed mod file discovered under the profile's `mods` directory.
final class MtnMinecraftInfoMod {
  const MtnMinecraftInfoMod({
    required this.file,
    required this.fileName,
  });

  final File file;
  final String fileName;
}
