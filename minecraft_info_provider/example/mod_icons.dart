import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/mod_icons.dart <game-directory>',
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

  int declared = 0;
  int loaded = 0;

  for (final MtnMinecraftInfoMod mod in mods) {
    if (!mod.hasIcon) continue;
    declared++;

    final Uint8List? icon = await mod.getIcon();
    if (icon != null) loaded++;

    final String source = mod.isInstalled && mod.isEmbedded
        ? 'installed+embedded'
        : mod.isInstalled
            ? 'installed'
            : 'embedded';

    print(
      '${mod.id}@${mod.version} '
      'source=$source '
      'iconBytes=${icon?.length ?? 0}',
    );
  }

  print('Icons: declared=$declared loaded=$loaded');
}
