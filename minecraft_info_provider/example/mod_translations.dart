import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3 && args.length != 4) {
    stderr.writeln(
      'Usage: dart run example/mod_translations.dart '
      '<mod-jar> <namespace> <locale> [translation-key]',
    );
    exitCode = 64;
    return;
  }

  final File jarFile = File(args[0]);
  if (!await jarFile.exists()) {
    stderr.writeln('Mod JAR does not exist: ${jarFile.path}');
    exitCode = 66;
    return;
  }

  final String namespace = args[1];
  final String locale = args[2];
  final String? key = args.length == 4 ? args[3] : null;

  final MtnMinecraftModList modList = MtnMinecraftModList(
    providers: const <MtnMinecraftModInfoProvider>[
      MtnMinecraftModInfoProviderFabric(),
      MtnMinecraftModInfoProviderForge(),
      MtnMinecraftModInfoProviderNeoForge(),
    ],
  );
  await modList.add(jarFile);

  if (modList.mods.isEmpty) {
    print('No registered provider recognized this JAR.');
    return;
  }

  final List<MtnMinecraftInfoModLanguage> languages =
      await modList.readLanguages(
    namespace,
    locale: locale,
  );

  print('Language candidates: ${languages.length}');
  for (int index = 0; index < languages.length; index++) {
    final MtnMinecraftInfoModLanguage language = languages[index];
    print(
      'source[$index]: ${language.translations.length} entries '
      '(${_sourceLabel(language.source)})',
    );
  }

  if (key == null) return;

  final List<MtnMinecraftInfoModTranslation> translations =
      await modList.getTranslations(
    namespace,
    key,
    locale: locale,
  );

  if (translations.isEmpty) {
    print('Translation not found: $key');
    return;
  }

  for (int index = 0; index < translations.length; index++) {
    final MtnMinecraftInfoModTranslation translation = translations[index];
    print(
      'translation[$index]: ${translation.value} '
      '(${_sourceLabel(translation.source)})',
    );
  }
}

String _sourceLabel(MtnMinecraftInfoModAssetSource source) {
  final String root = source.rootFile?.path ?? '<memory>';
  if (source.embeddedArchivePaths.isEmpty) return root;
  return '$root!/${source.embeddedArchivePaths.join('!/')}';
}
