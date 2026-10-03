import 'dart:io';

/// On-disk Java Edition statistics layout used by the discovered file.
enum MtnMinecraftInfoPlayerStatsStorageLayout {
  /// `<world>/stats/<uuid>.json`, used before the 26.1 layout move.
  legacy,

  /// `<world>/players/stats/<uuid>.json`, used by 26.1 and later.
  modern,
}

/// Read state for one Java Edition player statistics file.
enum MtnMinecraftInfoPlayerStatsState {
  available,
  invalid,
}

/// Player-statistics-local failure reported while reading one JSON file.
enum MtnMinecraftInfoPlayerStatsError {
  readFailed,
  invalidJson,
  invalidData,
}

/// Immutable snapshot of one Java Edition player statistics JSON file.
final class MtnMinecraftInfoPlayerStats {
  MtnMinecraftInfoPlayerStats._({
    required this.uuid,
    required this.file,
    required this.storageLayout,
    required this.state,
    required this.error,
    required Map<String, Map<String, int>> values,
    this.dataVersion,
  }) : values = Map<String, Map<String, int>>.unmodifiable(
          values.map(
            (String category, Map<String, int> entries) =>
                MapEntry<String, Map<String, int>>(
              category,
              Map<String, int>.unmodifiable(entries),
            ),
          ),
        );

  factory MtnMinecraftInfoPlayerStats.available({
    required String uuid,
    required File file,
    required MtnMinecraftInfoPlayerStatsStorageLayout storageLayout,
    int? dataVersion,
    required Map<String, Map<String, int>> values,
  }) =>
      MtnMinecraftInfoPlayerStats._(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerStatsState.available,
        error: null,
        dataVersion: dataVersion,
        values: values,
      );

  factory MtnMinecraftInfoPlayerStats.invalid({
    required String uuid,
    required File file,
    required MtnMinecraftInfoPlayerStatsStorageLayout storageLayout,
    required MtnMinecraftInfoPlayerStatsError error,
  }) =>
      MtnMinecraftInfoPlayerStats._(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerStatsState.invalid,
        error: error,
        values: const <String, Map<String, int>>{},
      );

  /// Canonical lowercase UUID of the owning player.
  final String uuid;

  /// Exact discovered statistics file.
  final File file;

  final MtnMinecraftInfoPlayerStatsStorageLayout storageLayout;

  final MtnMinecraftInfoPlayerStatsState state;

  /// Statistics-local read error. Null when [state] is `available`.
  final MtnMinecraftInfoPlayerStatsError? error;

  /// Root `DataVersion`, when present.
  final int? dataVersion;

  /// Statistics grouped by external Minecraft category and statistic keys.
  ///
  /// Both map levels are immutable. Unknown vanilla, future or modded keys are
  /// preserved rather than mapped to a closed enum.
  final Map<String, Map<String, int>> values;
}
