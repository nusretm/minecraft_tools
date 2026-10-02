import 'dart:convert';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> arguments) async {
  final String host = _requiredValue(arguments, '--host');
  final int port = int.parse(_value(arguments, '--port') ?? '25565');
  final int timeoutMilliseconds =
      int.parse(_value(arguments, '--timeout-ms') ?? '5000');
  final int offlineAfterMilliseconds =
      int.parse(_value(arguments, '--offline-after-ms') ?? '60000');
  final bool measureLatency = !arguments.contains('--no-ping');

  final String address = host.contains(':')
      ? '[$host]:$port'
      : '$host:$port';
  final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
    name: host,
    address: address,
  );
  final MtnMinecraftInfoServerStatus status = await server.queryStatus(
    timeout: Duration(milliseconds: timeoutMilliseconds),
    offlineAfter: Duration(milliseconds: offlineAfterMilliseconds),
    measureLatency: measureLatency,
  );

  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(status.toMap()));
  stdout.writeln(
    'STATUS_RESULT state=${status.state.name} '
    'stale=${status.isStale} '
    'version=${status.versionName} '
    'protocol=${status.protocol} '
    'players=${status.onlinePlayers}/${status.maxPlayers} '
    'modded=${status.advertisesModded} '
    'latencyMs=${status.latency?.inMilliseconds}',
  );

  final MtnMinecraftInfoServerModMetadata? metadata = status.modMetadata;
  if (metadata != null) {
    stdout.writeln(
      'MOD_METADATA loader=${metadata.loader.name} '
      'mods=${metadata.mods.length} '
      'channels=${metadata.channels.length} '
      'complete=${metadata.advertisedListsComplete}',
    );
  }
}

String _requiredValue(List<String> arguments, String name) {
  final String? value = _value(arguments, name);
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('$name is required');
  }
  return value;
}

String? _value(List<String> arguments, String name) {
  final int index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
