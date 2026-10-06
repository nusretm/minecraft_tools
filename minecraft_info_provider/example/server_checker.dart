import 'dart:async';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/server_checker.dart <servers.dat>',
    );
    exitCode = 64;
    return;
  }

  final File serversFile = File(p.normalize(p.absolute(args.single)));
  if (p.basename(serversFile.path).toLowerCase() != 'servers.dat') {
    stderr.writeln('Expected a servers.dat file path');
    exitCode = 64;
    return;
  }

  final MtnMinecraftInfoProvider provider = MtnMinecraftInfoProvider(
    gameDirectory: serversFile.parent,
  );
  final List<MtnMinecraftInfoServer> servers = await provider.readServers();

  final MtnMinecraftInfoServerHealthCheck checker =
      MtnMinecraftInfoServerHealthCheck(
    intervalSec: 15,
    onAdd: (
      MtnMinecraftInfoServerHealthCheck checker,
      MtnMinecraftInfoServer server,
    ) {
      print('[ADD] ${_serverSummary(server)}');
    },
    onChange: (
      MtnMinecraftInfoServerHealthCheck checker,
      MtnMinecraftInfoServer server,
    ) {
      print('[CHANGE] ${_serverSummary(server)} ${_statusSummary(server)}');
    },
    onRemove: (
      MtnMinecraftInfoServerHealthCheck checker,
      MtnMinecraftInfoServer server,
    ) {
      print('[REMOVE] ${_serverSummary(server)}');
    },
  );

  print('servers.dat=${provider.serversFile.path}');
  print('servers=${servers.length}');
  print('intervalSec=${checker.intervalSec}');

  for (final MtnMinecraftInfoServer server in servers) {
    checker.add(server);
  }

  checker.start();

  print('Checking server status until Ctrl+C...');

  await ProcessSignal.sigint.watch().first;

  print('');
  print('Stopping...');
  checker.dispose();
}

String _serverSummary(MtnMinecraftInfoServer server) {
  return 'name=${server.name} '
      'address=${server.address} '
      'resourcePacks=${_resourcePackPolicy(server.acceptServerResourcePacks)} '
      'hidden=${server.hidden}';
}

String _statusSummary(MtnMinecraftInfoServer server) {
  final MtnMinecraftInfoServerStatus? status = server.status;
  if (status == null) return 'status=unknown';

  return 'status=${status.state.name} '
      'version=${status.versionName ?? '-'} '
      'players=${status.onlinePlayers ?? '-'}/${status.maxPlayers ?? '-'} '
      'latencyMs=${status.latency?.inMilliseconds ?? '-'} '
      'stale=${status.isStale} '
      'reason=${status.unavailableReason?.name ?? '-'} '
      'motd=${status.motd?.plainText ?? '-'}';
}

String _resourcePackPolicy(bool? value) {
  if (value == true) return 'enabled';
  if (value == false) return 'disabled';
  return 'prompt';
}
