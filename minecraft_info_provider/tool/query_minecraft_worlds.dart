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

      stdout.writeln(
        'PLAYER_GAMEPLAY world=${world.directoryName} '
        'uuid=${player.uuid} '
        'rotation=${_rotation(player.rotation)} '
        'gameMode=${player.gameMode?.name} '
        'previousGameMode=${player.previousGameMode?.name} '
        'health=${player.health} '
        'absorption=${player.absorptionAmount} '
        'selectedItemSlot=${player.selectedItemSlot}',
      );

      stdout.writeln(
        'PLAYER_FOOD world=${world.directoryName} '
        'uuid=${player.uuid} '
        'level=${player.food?.level} '
        'saturation=${player.food?.saturation} '
        'exhaustion=${player.food?.exhaustion} '
        'tickTimer=${player.food?.tickTimer}',
      );

      stdout.writeln(
        'PLAYER_XP world=${world.directoryName} '
        'uuid=${player.uuid} '
        'level=${player.experience?.level} '
        'progress=${player.experience?.progress} '
        'total=${player.experience?.total} '
        'seed=${player.experience?.seed}',
      );

      stdout.writeln(
        'PLAYER_ABILITIES world=${world.directoryName} '
        'uuid=${player.uuid} '
        'flying=${player.abilities?.flying} '
        'mayFly=${player.abilities?.mayFly} '
        'instantBuild=${player.abilities?.instantBuild} '
        'invulnerable=${player.abilities?.invulnerable} '
        'mayBuild=${player.abilities?.mayBuild} '
        'flySpeed=${player.abilities?.flySpeed} '
        'walkSpeed=${player.abilities?.walkSpeed}',
      );

      stdout.writeln(
        'PLAYER_RESPAWN world=${world.directoryName} '
        'uuid=${player.uuid} '
        'value=${_respawn(player.respawn)}',
      );

      stdout.writeln(
        'PLAYER_LAST_DEATH world=${world.directoryName} '
        'uuid=${player.uuid} '
        'value=${_lastDeath(player.lastDeath)}',
      );

      final MtnMinecraftInfoPlayerStats? stats =
          await provider.readPlayerStats(world, player);
      if (stats == null) {
        stdout.writeln(
          'STATS world=${world.directoryName} '
          'uuid=${player.uuid} missing=true',
        );
      } else {
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

      final MtnMinecraftInfoPlayerAdvancements? advancements =
          await provider.readPlayerAdvancements(world, player);
      if (advancements == null) {
        stdout.writeln(
          'ADVANCEMENTS world=${world.directoryName} '
          'uuid=${player.uuid} missing=true',
        );
        continue;
      }

      stdout.writeln(
        'ADVANCEMENTS world=${world.directoryName} '
        'uuid=${player.uuid} '
        'state=${advancements.state.name} '
        'error=${advancements.error?.name} '
        'layout=${advancements.storageLayout.name} '
        'dataVersion=${advancements.dataVersion} '
        'advancements=${advancements.advancements.length} '
        'completed=${_completedAdvancementCount(advancements)} '
        'criteria=${_advancementCriterionCount(advancements)} '
        'file=${advancements.file.path}',
      );

      final List<String> advancementIds =
          advancements.advancements.keys.toList()..sort();
      const int advancementPreviewLimit = 10;
      for (final String id in advancementIds.take(advancementPreviewLimit)) {
        final MtnMinecraftInfoPlayerAdvancement advancement =
            advancements.advancements[id]!;
        stdout.writeln(
          'ADVANCEMENT world=${world.directoryName} '
          'uuid=${player.uuid} '
          'id=$id '
          'done=${advancement.done} '
          'criteria=${advancement.criteria.length}',
        );
      }
      if (advancementIds.length > advancementPreviewLimit) {
        stdout.writeln(
          'ADVANCEMENT_MORE world=${world.directoryName} '
          'uuid=${player.uuid} '
          'count=${advancementIds.length - advancementPreviewLimit}',
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

String _rotation(MtnMinecraftInfoPlayerRotation? rotation) {
  if (rotation == null) return 'null';
  return '${rotation.yaw},${rotation.pitch}';
}

String _blockPosition(MtnMinecraftInfoPlayerBlockPosition position) =>
    '${position.x},${position.y},${position.z}';

String _respawn(MtnMinecraftInfoPlayerRespawn? respawn) {
  if (respawn == null) return 'null';
  return 'position=${_blockPosition(respawn.position)},'
      'dimension=${respawn.dimension},'
      'yaw=${respawn.yaw},'
      'pitch=${respawn.pitch},'
      'forced=${respawn.forced}';
}

String _lastDeath(MtnMinecraftInfoPlayerLastDeath? lastDeath) {
  if (lastDeath == null) return 'null';
  return 'position=${_blockPosition(lastDeath.position)},'
      'dimension=${lastDeath.dimension}';
}

int _statsCounterCount(MtnMinecraftInfoPlayerStats stats) {
  var count = 0;
  for (final Map<String, int> values in stats.values.values) {
    count += values.length;
  }
  return count;
}

int _completedAdvancementCount(
  MtnMinecraftInfoPlayerAdvancements advancements,
) {
  var count = 0;
  for (final MtnMinecraftInfoPlayerAdvancement advancement
      in advancements.advancements.values) {
    if (advancement.done) count++;
  }
  return count;
}

int _advancementCriterionCount(
  MtnMinecraftInfoPlayerAdvancements advancements,
) {
  var count = 0;
  for (final MtnMinecraftInfoPlayerAdvancement advancement
      in advancements.advancements.values) {
    count += advancement.criteria.length;
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
