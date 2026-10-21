import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

/// CP6 real client-JAR smoke: inspect a texture's first logical frame.
///
/// dart run example/texture_animation.dart CLIENT_JAR minecraft:block/lava_still
///
/// The client JAR must already exist. No downloads, PNG decode or image
/// rendering are performed.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart run example/texture_animation.dart CLIENT_JAR TEXTURE_ID');
    exitCode = 64;
    return;
  }

  final MtnMinecraftResourceSourceVanilla vanilla =
      await MtnMinecraftResourceSourceVanilla.open(clientJar: File(arguments[0]));
  final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
    sources: <MtnMinecraftResourceSourceAbs>[vanilla],
  );
  final MtnMinecraftResourceLocation location =
      MtnMinecraftResourceLocation.parse(arguments[1]);
  final MtnMinecraftResourceImage? image =
      await MtnMinecraftResourceHelperLegacy().loadTexture(loader, location);
  if (image == null) {
    stderr.writeln('Texture is missing from the client JAR.');
    exitCode = 2;
    return;
  }

  stdout.writeln('Source: ${vanilla.clientJar.path}');
  stdout.writeln('Sprite: ${image.location}');
  stdout.writeln('PNG bytes: ${image.png.length}');
  final MtnMinecraftResourceImageRegion? region = image.region;
  if (region == null) {
    stdout.writeln('Frame region: null (static/whole PNG)');
  } else {
    stdout.writeln('Frame region: x=${region.x}, y=${region.y}, width=${region.width}, height=${region.height}');
  }
}
