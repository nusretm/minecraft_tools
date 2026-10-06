import 'dart:io';

import 'package:path/path.dart' as p;

/// One directly installed mod file discovered under the profile's `mods` directory.
final class MtnMinecraftInfoMod {
  const MtnMinecraftInfoMod({
    required this.file,
  });

  final File file;

  String get fileName => p.basename(file.path);
}
