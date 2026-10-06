import 'dart:io';

import '../../nbt/minecraft_nbt.dart';
import '../effect/info_mob_effect.dart';
import '../effect/info_mob_effect_nbt_parser.dart';
import 'info_player.dart';
import 'info_player_inventory_nbt_parser.dart';

/// Internal schema parser for one decoded Java Edition player NBT document.
///
/// Filesystem discovery, compression and raw NBT decoding remain provider
/// responsibilities. This parser owns only the semantic player-data schema.
final class MtnMinecraftInfoPlayerNbtParser {
  const MtnMinecraftInfoPlayerNbtParser();

  MtnMinecraftInfoPlayer parse({
    required String uuid,
    required File dataFile,
    required MtnMinecraftInfoPlayerStorageLayout storageLayout,
    required MtnMinecraftNbtDocument document,
  }) {
    if (document.root.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> data = document.root.asCompound;
    late final MtnMinecraftInfoPlayerInventoryData inventoryData;
    late final List<MtnMinecraftInfoMobEffect>? activeEffects;
    try {
      inventoryData =
          const MtnMinecraftInfoPlayerInventoryNbtParser().parse(data);

      final MtnMinecraftNbtValue? modernEffects = data['active_effects'];
      final MtnMinecraftNbtValue? legacyEffects = data['ActiveEffects'];
      if (modernEffects != null) {
        activeEffects = const MtnMinecraftInfoMobEffectNbtParser().parseList(
          modernEffects,
          modern: true,
        );
      } else if (legacyEffects != null) {
        activeEffects = const MtnMinecraftInfoMobEffectNbtParser().parseList(
          legacyEffects,
          modern: false,
        );
      } else {
        activeEffects = null;
      }
    } on MtnMinecraftInfoPlayerInventoryNbtParserException {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    } on MtnMinecraftInfoMobEffectNbtParserException {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    return MtnMinecraftInfoPlayer.available(
      uuid: uuid,
      dataFile: dataFile,
      storageLayout: storageLayout,
      dataVersion: _optionalInt(data, 'DataVersion'),
      dimension: _optionalString(data, 'Dimension'),
      position: _optionalPosition(data),
      rotation: _optionalRotation(data),
      gameMode: _optionalGameMode(data, 'playerGameType'),
      previousGameMode: _optionalGameMode(
        data,
        'previousPlayerGameType',
        allowUnset: true,
      ),
      health: _optionalFloat(data, 'Health'),
      absorptionAmount: _optionalFloat(data, 'AbsorptionAmount'),
      food: _optionalFood(data),
      experience: _optionalExperience(data),
      abilities: _optionalAbilities(data),
      selectedItemSlot: _optionalSelectedItemSlot(data),
      respawn: _optionalRespawn(data),
      lastDeath: _optionalLastDeath(data),
      activeEffects: activeEffects,
      inventory: inventoryData.inventory,
      enderChest: inventoryData.enderChest,
      equipment: inventoryData.equipment,
    );
  }

  String? _optionalString(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.string) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }
    return value.asString;
  }

  int? _optionalInt(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.intValue) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }
    return value.asInt;
  }

  double? _optionalFloat(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.float) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }
    return value.asFloat;
  }

  bool? _optionalBoolean(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.byte ||
        (value.asByte != 0 && value.asByte != 1)) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }
    return value.asByte == 1;
  }

  MtnMinecraftInfoPlayerPosition? _optionalPosition(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['Pos'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.elementType != MtnMinecraftNbtType.doubleValue ||
        list.values.length != 3) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    return MtnMinecraftInfoPlayerPosition(
      x: list.values[0].asDouble,
      y: list.values[1].asDouble,
      z: list.values[2].asDouble,
    );
  }

  MtnMinecraftInfoPlayerRotation? _optionalRotation(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['Rotation'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.elementType != MtnMinecraftNbtType.float ||
        list.values.length != 2) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    return MtnMinecraftInfoPlayerRotation(
      yaw: list.values[0].asFloat,
      pitch: list.values[1].asFloat,
    );
  }

  MtnMinecraftInfoPlayerGameMode? _optionalGameMode(
    Map<String, MtnMinecraftNbtValue> data,
    String name, {
    bool allowUnset = false,
  }) {
    final int? value = _optionalInt(data, name);
    if (value == null || (allowUnset && value == -1)) return null;
    return switch (value) {
      0 => MtnMinecraftInfoPlayerGameMode.survival,
      1 => MtnMinecraftInfoPlayerGameMode.creative,
      2 => MtnMinecraftInfoPlayerGameMode.adventure,
      3 => MtnMinecraftInfoPlayerGameMode.spectator,
      _ => throw const MtnMinecraftInfoPlayerNbtParserException(),
    };
  }

  MtnMinecraftInfoPlayerFood? _optionalFood(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    const List<String> names = <String>[
      'foodLevel',
      'foodSaturationLevel',
      'foodExhaustionLevel',
      'foodTickTimer',
    ];
    if (!names.any(data.containsKey)) return null;
    return MtnMinecraftInfoPlayerFood(
      level: _optionalInt(data, 'foodLevel'),
      saturation: _optionalFloat(data, 'foodSaturationLevel'),
      exhaustion: _optionalFloat(data, 'foodExhaustionLevel'),
      tickTimer: _optionalInt(data, 'foodTickTimer'),
    );
  }

  MtnMinecraftInfoPlayerExperience? _optionalExperience(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    const List<String> names = <String>[
      'XpLevel',
      'XpP',
      'XpTotal',
      'XpSeed',
    ];
    if (!names.any(data.containsKey)) return null;
    return MtnMinecraftInfoPlayerExperience(
      level: _optionalInt(data, 'XpLevel'),
      progress: _optionalFloat(data, 'XpP'),
      total: _optionalInt(data, 'XpTotal'),
      seed: _optionalInt(data, 'XpSeed'),
    );
  }

  MtnMinecraftInfoPlayerAbilities? _optionalAbilities(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['abilities'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> abilities = value.asCompound;
    return MtnMinecraftInfoPlayerAbilities(
      flying: _optionalBoolean(abilities, 'flying'),
      mayFly: _optionalBoolean(abilities, 'mayfly'),
      instantBuild: _optionalBoolean(abilities, 'instabuild'),
      invulnerable: _optionalBoolean(abilities, 'invulnerable'),
      mayBuild: _optionalBoolean(abilities, 'mayBuild'),
      flySpeed: _optionalFloat(abilities, 'flySpeed'),
      walkSpeed: _optionalFloat(abilities, 'walkSpeed'),
    );
  }

  int? _optionalSelectedItemSlot(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final int? value = _optionalInt(data, 'SelectedItemSlot');
    if (value == null) return null;
    if (value < 0 || value > 8) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }
    return value;
  }

  MtnMinecraftInfoPlayerRespawn? _optionalRespawn(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? modern = data['respawn'];
    if (modern != null) {
      if (modern.type != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoPlayerNbtParserException();
      }

      final Map<String, MtnMinecraftNbtValue> respawn = modern.asCompound;
      return MtnMinecraftInfoPlayerRespawn(
        position: _requiredBlockPosition(respawn, 'pos'),
        dimension: _optionalString(respawn, 'dimension'),
        yaw: respawn.containsKey('yaw')
            ? _optionalFloat(respawn, 'yaw')
            : _optionalFloat(respawn, 'angle'),
        pitch: _optionalFloat(respawn, 'pitch'),
        forced: _optionalBoolean(respawn, 'forced'),
      );
    }

    const List<String> legacyNames = <String>[
      'SpawnX',
      'SpawnY',
      'SpawnZ',
      'SpawnAngle',
      'SpawnDimension',
      'SpawnForced',
    ];
    if (!legacyNames.any(data.containsKey)) return null;

    final int? x = _optionalInt(data, 'SpawnX');
    final int? y = _optionalInt(data, 'SpawnY');
    final int? z = _optionalInt(data, 'SpawnZ');
    if (x == null || y == null || z == null) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    return MtnMinecraftInfoPlayerRespawn(
      position: MtnMinecraftInfoPlayerBlockPosition(x: x, y: y, z: z),
      dimension: _optionalString(data, 'SpawnDimension'),
      yaw: _optionalFloat(data, 'SpawnAngle'),
      forced: _optionalBoolean(data, 'SpawnForced'),
    );
  }

  MtnMinecraftInfoPlayerLastDeath? _optionalLastDeath(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['LastDeathLocation'];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> location = value.asCompound;
    final String? dimension = _optionalString(location, 'dimension');
    if (dimension == null) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    return MtnMinecraftInfoPlayerLastDeath(
      position: _requiredBlockPosition(location, 'pos'),
      dimension: dimension,
    );
  }

  MtnMinecraftInfoPlayerBlockPosition _requiredBlockPosition(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null ||
        value.type != MtnMinecraftNbtType.intArray ||
        value.asIntArray.length != 3) {
      throw const MtnMinecraftInfoPlayerNbtParserException();
    }

    final List<int> position = value.asIntArray;
    return MtnMinecraftInfoPlayerBlockPosition(
      x: position[0],
      y: position[1],
      z: position[2],
    );
  }
}

final class MtnMinecraftInfoPlayerNbtParserException implements Exception {
  const MtnMinecraftInfoPlayerNbtParserException();
}
