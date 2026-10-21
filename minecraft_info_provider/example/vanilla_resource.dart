import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> args) async {
  final MtnMinecraftResourceSourceVanilla vanilla =
      await MtnMinecraftResourceSourceVanilla.open(clientJar: File(args[0]));
  stdout.writeln(vanilla.clientJar.path);
  stdout.writeln(vanilla.namespaces);
}
