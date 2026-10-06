import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1 && args.length != 3) {
    stderr.writeln(
      'Usage: dart run example/mod_assets.dart '
      '<mod-jar> [namespace asset-path]',
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

  print('Asset namespaces: ${modList.assetNamespaces.join(', ')}');
  for (final MtnMinecraftInfoMod mod in modList.mods) {
    print(
      '${mod.id}@${mod.version}: '
      '${mod.assetNamespaces.isEmpty ? '-' : mod.assetNamespaces.join(', ')}',
    );
    for (final MtnMinecraftInfoModAssetSource source in mod.assetSources) {
      final String root = source.rootFile?.path ?? '<memory>';
      final String embedded = source.embeddedArchivePaths.isEmpty
          ? ''
          : '!/${source.embeddedArchivePaths.join('!/')}';
      print('  $root$embedded');
    }
  }

  if (args.length != 3) return;

  final String namespace = args[1];
  final String assetPath = args[2];
  final List<MtnMinecraftInfoModAssetSource> sources =
      modList.getAssetSources(namespace);

  if (sources.isEmpty) {
    print('No asset source contains namespace: $namespace');
    return;
  }

  for (int index = 0; index < sources.length; index++) {
    final MtnMinecraftInfoModAssetSource source = sources[index];
    final Uint8List? bytes = await source.read(
      namespace,
      assetPath,
    );
    if (bytes == null) {
      print('source[$index]: missing');
    } else {
      print('source[$index]: ${bytes.length} bytes');
    }
  }
}
