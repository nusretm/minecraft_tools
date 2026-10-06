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
  final MtnMinecraftModList modList = MtnMinecraftModList(
    providers: const <MtnMinecraftModInfoProvider>[
      MtnMinecraftModInfoProviderFabric(),
    ],
  );
  final List<MtnMinecraftInfoMod> mods = await provider.readMods(modList);

  print('Mods: ${mods.length}');
  for (final MtnMinecraftInfoMod mod in mods) {
    final String installed = mod.installedFiles.isEmpty
        ? '-'
        : mod.installedFiles.map((File file) => file.path).join(', ');
    final String parents = mod.parentMods.isEmpty
        ? '-'
        : mod.parentMods
            .map((MtnMinecraftInfoMod parent) => parent.id)
            .join(', ');

    print(
      'id=${mod.id} '
      'name=${mod.name} '
      'version=${mod.version} '
      'types=${mod.modTypes.join(',')} '
      'installed=$installed '
      'parents=$parents',
    );
  }
}
