import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';

/// Real-profile resource smoke; inputs are already downloaded local JARs.
/// Arguments: CLIENT_JAR FABRIC_MOD_JAR ITEM_ID MC_RELEASE_VERSION.
Future<void> main(List<String> args) async {
  if (args.length != 4) {
    stderr.writeln('Usage: dart run example/vanilla_resource.dart CLIENT_JAR FABRIC_MOD_JAR ITEM_ID MC_RELEASE_VERSION');
    exitCode = 64;
    return;
  }

  final MtnMinecraftResourceSourceVanilla vanilla =
      await MtnMinecraftResourceSourceVanilla.open(clientJar: File(args[0]));
  final MtnMinecraftModList modList = MtnMinecraftModList(
    providers: const <MtnMinecraftModInfoProvider>[
      MtnMinecraftModInfoProviderFabric(),
    ],
  );
  await modList.add(File(args[1]));

  final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
    sources: <MtnMinecraftResourceSourceAbs>[vanilla, ...modList.assetSources],
  );
  final MtnMinecraftResourceItem? item = await loader.loadItem(
    environment: MtnMinecraftResourceEnvironment(
      version: MtnMinecraftVersion.parse(
        args[3], type: MtnMinecraftGameVersionType.release,
      ),
      loaderType: MtnMinecraftLoaderType.fabric,
    ),
    request: MtnMinecraftResourceItemRequest(
      item: MtnMinecraftInfoItemIdentity.parse(args[2]),
    ),
  );
  if (item == null) {
    stderr.writeln('Item resource not found.');
    exitCode = 2;
    return;
  }

  stdout.writeln(vanilla.clientJar.path);
  stdout.writeln(item.entry.entryLocation);
  stdout.writeln(item.entry.resource.source.runtimeType);
  if (item.itemModelGraph != null) {
    for (final MtnMinecraftResourceItemModelBinding binding
        in item.itemModelGraph!.bindings) {
      MtnMinecraftResourceModel? model = binding.model;
      while (model != null) {
        stdout.writeln(model.location);
        stdout.writeln(model.resource.source.runtimeType);
        model = model.parent;
      }
    }
  }
  for (final MtnMinecraftResourceTexture texture in item.textures) {
    stdout.writeln(texture.location);
    stdout.writeln(texture.image?.resource.source.runtimeType);
    stdout.writeln(texture.image?.png.length);
  }
  stdout.writeln(item.isComplete);
  for (final MtnMinecraftResourceIssue issue in item.issues) {
    stderr.writeln(issue);
  }
  if (!item.isComplete) exitCode = 2;
}
