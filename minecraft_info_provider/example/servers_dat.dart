import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;

const String _provanasAddress = 'oyna.provanas.com';
const String _provanasAddName = 'Provanas';
const String _provanasUpdatedName = 'Provanas Network';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final String action = args.first;
  if (action != '--add' && action != '--update' && action != '--remove') {
    _printUsage();
    exitCode = 64;
    return;
  }

  final Directory gameDirectory =
      args.length == 1 ? _defaultGameDirectory() : Directory(args[1]);
  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: gameDirectory,
  );

  final List<MtnMinecraftInfoServer> servers = await provider.readServers();

  print('servers.dat=${provider.serversFile.path}');
  print('servers=${servers.length}');
  _printServers(servers);

  final MtnMinecraftInfoServerAddress provanasAddress =
      MtnMinecraftInfoServerAddress.parse(_provanasAddress);
  final MtnMinecraftInfoServer? existing =
      _findServer(servers, provanasAddress);

  switch (action) {
    case '--add':
      if (existing != null) {
        print('Provanas already exists: $_provanasAddress');
        return;
      }

      await provider.addServer(
        MtnMinecraftInfoServer(
          name: _provanasAddName,
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

    case '--update':
      if (existing == null) {
        print('Provanas not found: $_provanasAddress');
        return;
      }

      final bool updated = await provider.updateServer(
        MtnMinecraftInfoServer(
          name: _provanasUpdatedName,
          address: existing.address,
          icon: existing.icon,
          hidden: existing.hidden,
          acceptServerResourcePacks: true,
        ),
      );

      print(
        updated
            ? 'Updated Provanas: '
                'name=$_provanasUpdatedName '
                'address=${existing.address} '
                'resourcePacks=enabled'
            : 'Provanas not found: $_provanasAddress',
      );

    case '--remove':
      final bool removed = await provider.removeServer(_provanasAddress);
      print(
        removed
            ? 'Removed Provanas: $_provanasAddress'
            : 'Provanas not found: $_provanasAddress',
      );
  }
}

MtnMinecraftInfoServer? _findServer(
  List<MtnMinecraftInfoServer> servers,
  MtnMinecraftInfoServerAddress target,
) {
  for (final MtnMinecraftInfoServer server in servers) {
    try {
      if (server.parsedAddress.sameIdentity(target)) {
        return server;
      }
    } on ArgumentError {
      // Ignore malformed unrelated addresses.
    }
  }
  return null;
}

void _printServers(List<MtnMinecraftInfoServer> servers) {
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
}

void _printUsage() {
  stderr.writeln(
    'Usage: dart run example/servers_dat.dart '
    '<--add|--update|--remove> [minecraft-game-directory]',
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
