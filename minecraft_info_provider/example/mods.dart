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
    try {
      final MtnMinecraftInfoModMetadata? metadata =
          await provider.readModMetadata(mod);
      if (metadata == null) {
        print('[metadata=unknown] ${mod.fileName}');
        continue;
      }

      print(
        '[metadata=${metadata.type.name}] '
        'id=${metadata.id} '
        'name=${metadata.name} '
        'version=${metadata.version} '
        'authors=${metadata.authors.join(', ')} '
        'file=${mod.fileName}',
      );
    } on MtnMinecraftInfoProviderException catch (error) {
      print(
        '[metadataError=${error.error.name}] ${mod.fileName}',
      );
    }
  }
}
