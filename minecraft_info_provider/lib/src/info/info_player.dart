import 'dart:io';

import 'info_item_stack.dart';

/// On-disk Java Edition player-data layout used by the discovered file.
enum MtnMinecraftInfoPlayerStorageLayout {
  /// `<world>/playerdata/<uuid>.dat`, used before the 26.1 layout move.
  legacy,

  /// `<world>/players/data/<uuid>.dat`, used by 26.1 and later.
  modern,
}

/// Discovery state for one Java Edition player-data file.
enum MtnMinecraftInfoPlayerState {
  available,
  invalid,
}

/// Player-local failure reported while decoding one `.dat` file.
///
/// These errors do not fail discovery of sibling players.
enum MtnMinecraftInfoPlayerError {
  readFailed,
  invalidCompression,
  invalidNbt,
  invalidData,
}

/// Immutable last-known player position from the player NBT `Pos` tag.
final class MtnMinecraftInfoPlayerPosition {
  const MtnMinecraftInfoPlayerPosition({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;
}

/// Java Edition player game mode.
enum MtnMinecraftInfoPlayerGameMode {
  survival,
  creative,
  adventure,
  spectator,
}

/// Immutable player look rotation.
final class MtnMinecraftInfoPlayerRotation {
  const MtnMinecraftInfoPlayerRotation({
    required this.yaw,
    required this.pitch,
  });

  final double yaw;
  final double pitch;
}

/// Immutable block position used by player-owned location metadata.
final class MtnMinecraftInfoPlayerBlockPosition {
  const MtnMinecraftInfoPlayerBlockPosition({
    required this.x,
    required this.y,
    required this.z,
  });

  final int x;
  final int y;
  final int z;
}

/// Immutable player food-state snapshot.
final class MtnMinecraftInfoPlayerFood {
  const MtnMinecraftInfoPlayerFood({
    this.level,
    this.saturation,
    this.exhaustion,
    this.tickTimer,
  });

  final int? level;
  final double? saturation;
  final double? exhaustion;
  final int? tickTimer;
}

/// Immutable player experience-state snapshot.
final class MtnMinecraftInfoPlayerExperience {
  const MtnMinecraftInfoPlayerExperience({
    this.level,
    this.progress,
    this.total,
    this.seed,
  });

  final int? level;
  final double? progress;
  final int? total;
  final int? seed;
}

/// Immutable player abilities snapshot.
final class MtnMinecraftInfoPlayerAbilities {
  const MtnMinecraftInfoPlayerAbilities({
    this.flying,
    this.mayFly,
    this.instantBuild,
    this.invulnerable,
    this.mayBuild,
    this.flySpeed,
    this.walkSpeed,
  });

  final bool? flying;
  final bool? mayFly;
  final bool? instantBuild;
  final bool? invulnerable;
  final bool? mayBuild;
  final double? flySpeed;
  final double? walkSpeed;
}

/// Immutable player respawn-point snapshot normalized across storage versions.
final class MtnMinecraftInfoPlayerRespawn {
  const MtnMinecraftInfoPlayerRespawn({
    required this.position,
    this.dimension,
    this.yaw,
    this.pitch,
    this.forced,
  });

  final MtnMinecraftInfoPlayerBlockPosition position;
  final String? dimension;
  final double? yaw;
  final double? pitch;
  final bool? forced;
}

/// Immutable player last-death location.
final class MtnMinecraftInfoPlayerLastDeath {
  const MtnMinecraftInfoPlayerLastDeath({
    required this.position,
    required this.dimension,
  });

  final MtnMinecraftInfoPlayerBlockPosition position;
  final String dimension;
}

/// Immutable normalized player equipment snapshot.
final class MtnMinecraftInfoPlayerEquipment {
  const MtnMinecraftInfoPlayerEquipment({
    this.head,
    this.chest,
    this.legs,
    this.feet,
    this.offHand,
  });

  final MtnMinecraftInfoItemStack? head;
  final MtnMinecraftInfoItemStack? chest;
  final MtnMinecraftInfoItemStack? legs;
  final MtnMinecraftInfoItemStack? feet;
  final MtnMinecraftInfoItemStack? offHand;
}

/// Immutable snapshot of one Java Edition player-data file.
final class MtnMinecraftInfoPlayer {
  MtnMinecraftInfoPlayer._({
    required this.uuid,
    required this.dataFile,
    required this.storageLayout,
    required this.state,
    required this.error,
    this.dataVersion,
    this.dimension,
    this.position,
    this.rotation,
    this.gameMode,
    this.previousGameMode,
    this.health,
    this.absorptionAmount,
    this.food,
    this.experience,
    this.abilities,
    this.selectedItemSlot,
    this.respawn,
    this.lastDeath,
    this.inventory,
    this.enderChest,
    this.equipment,
  });

  factory MtnMinecraftInfoPlayer.available({
    required String uuid,
    required File dataFile,
    required MtnMinecraftInfoPlayerStorageLayout storageLayout,
    int? dataVersion,
    String? dimension,
    MtnMinecraftInfoPlayerPosition? position,
    MtnMinecraftInfoPlayerRotation? rotation,
    MtnMinecraftInfoPlayerGameMode? gameMode,
    MtnMinecraftInfoPlayerGameMode? previousGameMode,
    double? health,
    double? absorptionAmount,
    MtnMinecraftInfoPlayerFood? food,
    MtnMinecraftInfoPlayerExperience? experience,
    MtnMinecraftInfoPlayerAbilities? abilities,
    int? selectedItemSlot,
    MtnMinecraftInfoPlayerRespawn? respawn,
    MtnMinecraftInfoPlayerLastDeath? lastDeath,
    List<MtnMinecraftInfoItemStack?>? inventory,
    List<MtnMinecraftInfoItemStack?>? enderChest,
    MtnMinecraftInfoPlayerEquipment? equipment,
  }) =>
      MtnMinecraftInfoPlayer._(
        uuid: uuid,
        dataFile: dataFile,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerState.available,
        error: null,
        dataVersion: dataVersion,
        dimension: dimension,
        position: position,
        rotation: rotation,
        gameMode: gameMode,
        previousGameMode: previousGameMode,
        health: health,
        absorptionAmount: absorptionAmount,
        food: food,
        experience: experience,
        abilities: abilities,
        selectedItemSlot: selectedItemSlot,
        respawn: respawn,
        lastDeath: lastDeath,
        inventory: inventory == null
            ? null
            : List<MtnMinecraftInfoItemStack?>.unmodifiable(inventory),
        enderChest: enderChest == null
            ? null
            : List<MtnMinecraftInfoItemStack?>.unmodifiable(enderChest),
        equipment: equipment,
      );

  factory MtnMinecraftInfoPlayer.invalid({
    required String uuid,
    required File dataFile,
    required MtnMinecraftInfoPlayerStorageLayout storageLayout,
    required MtnMinecraftInfoPlayerError error,
  }) =>
      MtnMinecraftInfoPlayer._(
        uuid: uuid,
        dataFile: dataFile,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerState.invalid,
        error: error,
      );

  /// Canonical lowercase UUID derived from the `.dat` filename.
  final String uuid;

  /// Exact discovered player-data file.
  final File dataFile;

  final MtnMinecraftInfoPlayerStorageLayout storageLayout;

  final MtnMinecraftInfoPlayerState state;

  /// Player-local discovery error. Null when [state] is `available`.
  final MtnMinecraftInfoPlayerError? error;

  /// Root `DataVersion`, when present.
  final int? dataVersion;

  /// Root `Dimension` resource location, when present.
  final String? dimension;

  /// Root `Pos` coordinates, when present.
  final MtnMinecraftInfoPlayerPosition? position;

  /// Root `Rotation` yaw/pitch, when present.
  final MtnMinecraftInfoPlayerRotation? rotation;

  /// Current player game mode, when persisted.
  final MtnMinecraftInfoPlayerGameMode? gameMode;

  /// Previous player game mode, when persisted and set.
  final MtnMinecraftInfoPlayerGameMode? previousGameMode;

  /// Current health points from root `Health`, when present.
  final double? health;

  /// Current absorption amount from root `AbsorptionAmount`, when present.
  final double? absorptionAmount;

  /// Food-state fields, when at least one is persisted.
  final MtnMinecraftInfoPlayerFood? food;

  /// Experience-state fields, when at least one is persisted.
  final MtnMinecraftInfoPlayerExperience? experience;

  /// Root `abilities` compound, when present.
  final MtnMinecraftInfoPlayerAbilities? abilities;

  /// Selected hotbar slot, when present.
  final int? selectedItemSlot;

  /// Semantic respawn point normalized from legacy `Spawn*` or modern
  /// `respawn` storage.
  final MtnMinecraftInfoPlayerRespawn? respawn;

  /// Root `LastDeathLocation`, when present.
  final MtnMinecraftInfoPlayerLastDeath? lastDeath;

  /// Semantic 36-slot player inventory, or null when `Inventory` is absent.
  ///
  /// Hotbar slots are 0 through 8 and main storage slots are 9 through 35.
  final List<MtnMinecraftInfoItemStack?>? inventory;

  /// Semantic 27-slot ender chest, or null when `EnderItems` is absent.
  final List<MtnMinecraftInfoItemStack?>? enderChest;

  /// Armor/off-hand equipment normalized across legacy inventory slots and
  /// the modern `equipment` compound.
  final MtnMinecraftInfoPlayerEquipment? equipment;

  /// Item in [selectedItemSlot], when both slot and inventory are available.
  MtnMinecraftInfoItemStack? get selectedItem {
    final List<MtnMinecraftInfoItemStack?>? inventory = this.inventory;
    final int? slot = selectedItemSlot;
    if (inventory == null || slot == null) return null;
    return inventory[slot];
  }
}
