import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> arguments) async {
  final Directory gameDirectory = Directory(
    _requiredValue(arguments, '--game-directory'),
  ).absolute;
  final String? selectedWorld = _value(arguments, '--world');
  final String? iconPath = _value(arguments, '--set-icon');

  if (!await gameDirectory.exists()) {
    throw ArgumentError.value(
      gameDirectory.path,
      '--game-directory',
      'Directory does not exist',
    );
  }
  if (iconPath != null && selectedWorld == null) {
    throw ArgumentError('--set-icon requires --world');
  }

  final MtnMinecraftInfoProvider provider =
      MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
  final List<MtnMinecraftInfoWorld> worlds = await provider.readWorlds();

  stdout.writeln(
    'WORLDS_RESULT gameDirectory=${gameDirectory.path} '
    'count=${worlds.length}',
  );

  for (final MtnMinecraftInfoWorld world in worlds) {
    stdout.writeln(
      'WORLD directory=${world.directoryName} '
      'name=${world.name} '
      'state=${world.state.name} '
      'error=${world.error?.name} '
      'dataVersion=${world.dataVersion} '
      'version=${world.version?.name} '
      'lastPlayed=${world.lastPlayed?.toIso8601String()} '
      'playersState=${world.playersState.name} '
      'playersError=${world.playersError?.name} '
      'players=${world.players.length} '
      'iconBytes=${world.icon?.length}',
    );

    for (final MtnMinecraftInfoPlayer player in world.players) {
      stdout.writeln(
        'PLAYER world=${world.directoryName} '
        'uuid=${player.uuid} '
        'state=${player.state.name} '
        'error=${player.error?.name} '
        'layout=${player.storageLayout.name} '
        'dataVersion=${player.dataVersion} '
        'dimension=${player.dimension} '
        'position=${_position(player.position)}',
      );

      final MtnMinecraftInfoPlayerStats? stats =
          await provider.readPlayerStats(world, player);
      if (stats == null) {
        stdout.writeln(
          'STATS world=${world.directoryName} '
          'uuid=${player.uuid} missing=true',
        );
        continue;
      }

      stdout.writeln(
        'STATS world=${world.directoryName} '
        'uuid=${player.uuid} '
        'state=${stats.state.name} '
        'error=${stats.error?.name} '
        'layout=${stats.storageLayout.name} '
        'dataVersion=${stats.dataVersion} '
        'categories=${stats.values.length} '
        'counters=${_statsCounterCount(stats)} '
        'file=${stats.file.path}',
      );

      final List<String> categories = stats.values.keys.toList()..sort();
      for (final String category in categories) {
        stdout.writeln(
          'STATS_CATEGORY world=${world.directoryName} '
          'uuid=${player.uuid} '
          'category=$category '
          'counters=${stats.values[category]!.length}',
        );
      }
    }
  }

  if (selectedWorld == null) return;

  final MtnMinecraftInfoWorld world = _worldByDirectoryName(
    worlds,
    selectedWorld,
  );
  if (iconPath == null) {
    stdout.writeln(
      'WORLD_SELECTED directory=${world.directoryName} '
      'iconFile=${world.iconFile.path} '
      'iconBytes=${world.icon?.length}',
    );
    return;
  }

  final File sourceIcon = File(iconPath).absolute;
  if (!await sourceIcon.exists()) {
    throw ArgumentError.value(
      sourceIcon.path,
      '--set-icon',
      'File does not exist',
    );
  }

  final Uint8List sourceBytes = await sourceIcon.readAsBytes();
  await provider.writeWorldIcon(world, sourceBytes);

  final MtnMinecraftInfoWorld refreshed = _worldByDirectoryName(
    await provider.readWorlds(),
    selectedWorld,
  );
  final List<int>? persisted = refreshed.icon;
  if (persisted == null || !_sameBytes(sourceBytes, persisted)) {
    throw StateError('World icon verification failed');
  }

  stdout.writeln(
    'ICON_WRITE_RESULT PASS '
    'world=${refreshed.directoryName} '
    'source=${sourceIcon.path} '
    'bytes=${persisted.length}',
  );
}

MtnMinecraftInfoWorld _worldByDirectoryName(
  List<MtnMinecraftInfoWorld> worlds,
  String directoryName,
) {
  for (final MtnMinecraftInfoWorld world in worlds) {
    if (world.directoryName == directoryName) return world;
  }
  throw ArgumentError.value(
    directoryName,
    '--world',
    'World directory was not found',
  );
}

String _position(MtnMinecraftInfoPlayerPosition? position) {
  if (position == null) return 'null';
  return '${position.x},${position.y},${position.z}';
}

int _statsCounterCount(MtnMinecraftInfoPlayerStats stats) {
  var count = 0;
  for (final Map<String, int> values in stats.values.values) {
    count += values.length;
  }
  return count;
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

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
