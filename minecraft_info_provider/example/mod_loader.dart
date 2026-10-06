import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/mod_loader.dart <game-directory>',
    );
    exitCode = 64;
    return;
  }

  final Directory gameDirectory = Directory(args.single);
  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: gameDirectory,
  );

  final MtnMinecraftInfoModLoader? loader = await provider.readModLoader();
  if (loader == null) {
    print('Mod loader: not found');
    return;
  }

  print('Mod loader: ${loader.type.name}');
  print('Loader version: ${loader.version}');
  print('Minecraft version: ${loader.minecraftVersion}');
}
