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
      'singleplayerUuid=${world.singleplayerUuid} '
      'singleplayerPlayer=${world.singleplayerPlayer?.uuid} '
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

      _writePlayerInventory(world, player);
      _writePlayerEnderChest(world, player);
      stdout.writeln(
        'PLAYER_EQUIPMENT world=${world.directoryName} '
        'uuid=${player.uuid} '
        'head=${_item(player.equipment?.head)} '
        'chest=${_item(player.equipment?.chest)} '
        'legs=${_item(player.equipment?.legs)} '
        'feet=${_item(player.equipment?.feet)} '
        'offHand=${_item(player.equipment?.offHand)}',
      );
      _writePlayerEquipmentItems(world, player);

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

void _writePlayerInventory(
  MtnMinecraftInfoWorld world,
  MtnMinecraftInfoPlayer player,
) {
  final List<MtnMinecraftInfoItemStack?>? inventory = player.inventory;
  if (inventory == null) {
    stdout.writeln(
      'PLAYER_INVENTORY world=${world.directoryName} '
      'uuid=${player.uuid} missing=true',
    );
    return;
  }

  final List<int> usedSlots = _usedItemSlots(inventory);
  stdout.writeln(
    'PLAYER_INVENTORY world=${world.directoryName} '
    'uuid=${player.uuid} '
    'usedSlots=${usedSlots.length} '
    'selectedSlot=${player.selectedItemSlot} '
    'selectedItem=${_item(player.selectedItem)}',
  );

  _writeItemPreview(
    lineName: 'PLAYER_INVENTORY_ITEM',
    world: world,
    player: player,
    items: inventory,
    usedSlots: usedSlots,
  );
}

void _writePlayerEnderChest(
  MtnMinecraftInfoWorld world,
  MtnMinecraftInfoPlayer player,
) {
  final List<MtnMinecraftInfoItemStack?>? enderChest = player.enderChest;
  if (enderChest == null) {
    stdout.writeln(
      'PLAYER_ENDER_CHEST world=${world.directoryName} '
      'uuid=${player.uuid} missing=true',
    );
    return;
  }

  final List<int> usedSlots = _usedItemSlots(enderChest);
  stdout.writeln(
    'PLAYER_ENDER_CHEST world=${world.directoryName} '
    'uuid=${player.uuid} '
    'usedSlots=${usedSlots.length}',
  );

  _writeItemPreview(
    lineName: 'PLAYER_ENDER_ITEM',
    world: world,
    player: player,
    items: enderChest,
    usedSlots: usedSlots,
  );
}

void _writeItemPreview({
  required String lineName,
  required MtnMinecraftInfoWorld world,
  required MtnMinecraftInfoPlayer player,
  required List<MtnMinecraftInfoItemStack?> items,
  required List<int> usedSlots,
}) {
  const int previewLimit = 10;
  for (final int slot in usedSlots.take(previewLimit)) {
    final MtnMinecraftInfoItemStack item = items[slot]!;
    stdout.writeln(
      '$lineName world=${world.directoryName} '
      'uuid=${player.uuid} '
      'slot=$slot '
      'id=${item.id} '
      'count=${item.count} '
      '${_itemProperties(item)}',
    );
  }
  if (usedSlots.length > previewLimit) {
    stdout.writeln(
      '${lineName}_MORE world=${world.directoryName} '
      'uuid=${player.uuid} '
      'count=${usedSlots.length - previewLimit}',
    );
  }
}

void _writePlayerEquipmentItems(
  MtnMinecraftInfoWorld world,
  MtnMinecraftInfoPlayer player,
) {
  final MtnMinecraftInfoPlayerEquipment? equipment = player.equipment;
  if (equipment == null) return;

  final Map<String, MtnMinecraftInfoItemStack?> items =
      <String, MtnMinecraftInfoItemStack?>{
    'head': equipment.head,
    'chest': equipment.chest,
    'legs': equipment.legs,
    'feet': equipment.feet,
    'offHand': equipment.offHand,
  };

  for (final MapEntry<String, MtnMinecraftInfoItemStack?> entry
      in items.entries) {
    final MtnMinecraftInfoItemStack? item = entry.value;
    if (item == null) continue;
    stdout.writeln(
      'PLAYER_EQUIPMENT_ITEM world=${world.directoryName} '
      'uuid=${player.uuid} '
      'slot=${entry.key} '
      'id=${item.id} '
      'count=${item.count} '
      '${_itemProperties(item)}',
    );
  }
}

List<int> _usedItemSlots(
  List<MtnMinecraftInfoItemStack?> items,
) {
  final List<int> slots = <int>[];
  for (var slot = 0; slot < items.length; slot++) {
    if (items[slot] != null) slots.add(slot);
  }
  return slots;
}

String _item(MtnMinecraftInfoItemStack? item) {
  if (item == null) return 'null';
  return '${item.id}x${item.count}';
}

String _itemProperties(MtnMinecraftInfoItemStack item) {
  final MtnMinecraftInfoItemStackComponents? components = item.components;
  if (components == null) {
    return 'damage=null repairCost=null unbreakable=null '
        'enchantments=null storedEnchantments=null removedComponents=null';
  }

  return 'damage=${components.damage} '
      'repairCost=${components.repairCost} '
      'unbreakable=${components.unbreakable} '
      'enchantments=${_mapPreview(components.enchantments)} '
      'storedEnchantments=${_mapPreview(components.storedEnchantments)} '
      'removedComponents=${_setPreview(components.removedComponentIds)}';
}

String _mapPreview(Map<String, int>? values) {
  if (values == null) return 'null';
  if (values.isEmpty) return '[]';

  const int previewLimit = 5;
  final List<String> keys = values.keys.toList()..sort();
  final List<String> preview = <String>[
    for (final String key in keys.take(previewLimit))
      '$key:${values[key]}',
  ];
  if (keys.length > previewLimit) {
    preview.add('+${keys.length - previewLimit}');
  }
  return '[${preview.join(',')}]';
}

String _setPreview(Set<String> values) {
  if (values.isEmpty) return '[]';

  const int previewLimit = 5;
  final List<String> sorted = values.toList()..sort();
  final List<String> preview =
      sorted.take(previewLimit).toList(growable: true);
  if (sorted.length > previewLimit) {
    preview.add('+${sorted.length - previewLimit}');
  }
  return '[${preview.join(',')}]';
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
