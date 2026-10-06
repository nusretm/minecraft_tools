import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;

const String _provanasAddress = 'oyna.provanas.com';

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run example/servers_dat.dart [minecraft-game-directory]',
    );
    exitCode = 64;
    return;
  }

  final Directory gameDirectory =
      args.isEmpty ? _defaultGameDirectory() : Directory(args.single);
  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: gameDirectory,
  );

  final List<MtnMinecraftInfoServer> servers = await provider.readServers();

  print('servers.dat=${provider.serversFile.path}');
  print('servers=${servers.length}');

  for (var index = 0; index < servers.length; index++) {
    final MtnMinecraftInfoServer server = servers[index];
    print(
      '[$index] '
      'name=${server.name} '
      'address=${server.address} '
      'resourcePacks=${_resourcePackPolicy(server.acceptServerResourcePacks)} '
      'hidden=${server.hidden}',
    );
  }

  final MtnMinecraftInfoServerAddress provanasAddress =
      MtnMinecraftInfoServerAddress.parse(_provanasAddress);

  final bool hasProvanas = servers.any(
    (MtnMinecraftInfoServer server) {
      try {
        return server.parsedAddress.sameIdentity(provanasAddress);
      } on ArgumentError {
        return false;
      }
    },
  );

  if (hasProvanas) {
    print('Provanas already exists: $_provanasAddress');
    return;
  }

  await provider.addServer(
    MtnMinecraftInfoServer(
      name: 'Provanas',
      address: _provanasAddress,
      acceptServerResourcePacks: true,
    ),
    first: true,
  );

  print(
    'Added Provanas at first position: '
    'address=$_provanasAddress '
    'resourcePacks=enabled',
  );
}

Directory _defaultGameDirectory() {
  if (Platform.isWindows) {
    final String? appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw StateError('APPDATA is not available');
    }
    return Directory(p.join(appData, '.minecraft'));
  }

  final String? home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw StateError('HOME is not available');
  }

  if (Platform.isMacOS) {
    return Directory(
      p.join(home, 'Library', 'Application Support', 'minecraft'),
    );
  }

  return Directory(p.join(home, '.minecraft'));
}

String _resourcePackPolicy(bool? value) {
  if (value == true) return 'enabled';
  if (value == false) return 'disabled';
  return 'prompt';
}
