import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/mod_metadata.dart <mod-jar>',
    );
    exitCode = 64;
    return;
  }

  final MtnMinecraftModList modList = MtnMinecraftModList(
    providers: const <MtnMinecraftModInfoProvider>[
      MtnMinecraftModInfoProviderFabric(),
    ],
  );

  await modList.add(File(args.single));

  if (modList.mods.isEmpty) {
    print('No registered provider recognized this JAR.');
    return;
  }

  for (final MtnMinecraftInfoMod mod in modList.mods) {
    print('${mod.id}@${mod.version}');
    print('  name: ${mod.name}');
    print('  description: ${mod.description}');
    print('  authors: ${mod.authors.join(', ')}');
    print('  contributors: ${mod.contributors.join(', ')}');
    print('  licenses: ${mod.licenses.join(', ')}');
    print('  homepage: ${mod.urls.homepage ?? '-'}');
    print('  source: ${mod.urls.source ?? '-'}');
    print('  issues: ${mod.urls.issues ?? '-'}');
    print('  clientSide: ${mod.clientSide}');
    print('  serverSide: ${mod.serverSide}');
    print('  provides: ${mod.providedIds.join(', ')}');
    print('  modTypes: ${mod.modTypes.join(', ')}');

    if (mod.dependencies.isEmpty) {
      print('  dependencies: -');
    } else {
      print('  dependencies:');
      for (final MtnMinecraftInfoModDependency dependency
          in mod.dependencies) {
        print(
          '    ${dependency.type.name}: '
          '${dependency.id} '
          '${dependency.versionConstraints.join(' || ')} '
          'client=${dependency.clientSide} '
          'server=${dependency.serverSide}',
        );
      }
    }
  }
}
