import 'dart:io';

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
  });

  factory MtnMinecraftInfoPlayer.available({
    required String uuid,
    required File dataFile,
    required MtnMinecraftInfoPlayerStorageLayout storageLayout,
    int? dataVersion,
    String? dimension,
    MtnMinecraftInfoPlayerPosition? position,
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
}
