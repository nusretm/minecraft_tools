import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 && args.length != 3) {
    stderr.writeln(
      'Usage: dart run example/item_names.dart '
      '<game-directory> <item-id> [locale]',
    );
    exitCode = 64;
    return;
  }

  final Directory gameDirectory = Directory(args[0]);
  if (!await gameDirectory.exists()) {
    stderr.writeln(
      'Game directory does not exist: ${gameDirectory.path}',
    );
    exitCode = 66;
    return;
  }

  final String itemId = args[1];
  final String locale = args.length == 3 ? args[2] : 'en_us';

  final MtnMinecraftModList modList = MtnMinecraftModList(
    providers: const <MtnMinecraftModInfoProvider>[
      MtnMinecraftModInfoProviderFabric(),
      MtnMinecraftModInfoProviderForge(),
      MtnMinecraftModInfoProviderNeoForge(),
    ],
  );
  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: gameDirectory,
  );
  await provider.readMods(modList);

  final MtnMinecraftInfoItemIdentity identity =
      MtnMinecraftInfoItemIdentity.parse(itemId);
  print('Item: ${identity.id}');
  print('Conventional item key: ${identity.itemTranslationKey}');
  print('Conventional block key: ${identity.blockTranslationKey}');

  final List<MtnMinecraftInfoItemName> names =
      await MtnMinecraftInfoItemNameResolver(
    modList: modList,
  ).resolve(
    itemId,
    locale: locale,
  );

  if (names.isEmpty) {
    print('No conventional localized name candidate found.');
    return;
  }

  for (int index = 0; index < names.length; index++) {
    final MtnMinecraftInfoItemName name = names[index];
    print(
      'name[$index]: ${name.value} '
      '[${name.kind.name}] '
      'key=${name.translationKey} '
      'langNamespace=${name.languageNamespace} '
      'source=${_sourceLabel(name.source)}',
    );
  }
}

String _sourceLabel(MtnMinecraftInfoModAssetSource source) {
  final String root = source.rootFile?.path ?? '<memory>';
  if (source.embeddedArchivePaths.isEmpty) return root;
  return '$root!/${source.embeddedArchivePaths.join('!/')}';
}
