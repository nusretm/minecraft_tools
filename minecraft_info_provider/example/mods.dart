import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/mods.dart <game-directory>',
    );
    exitCode = 64;
    return;
  }

  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: Directory(args.single),
  );
  final List<MtnMinecraftInfoMod> mods = await provider.readMods();

  print('Mods: ${mods.length}');
  for (final MtnMinecraftInfoMod mod in mods) {
    print(mod.fileName);
  }
}
