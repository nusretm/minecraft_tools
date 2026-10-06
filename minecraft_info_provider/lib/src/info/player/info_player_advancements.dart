import 'dart:io';

/// On-disk Java Edition advancement-progress layout used by the discovered file.
enum MtnMinecraftInfoPlayerAdvancementsStorageLayout {
  /// `<world>/advancements/<uuid>.json`, used before the 26.1 layout move.
  legacy,

  /// `<world>/players/advancements/<uuid>.json`, used by 26.1 and later.
  modern,
}

/// Read state for one Java Edition player advancements file.
enum MtnMinecraftInfoPlayerAdvancementsState {
  available,
  invalid,
}

/// Player-advancements-local failure reported while reading one JSON file.
enum MtnMinecraftInfoPlayerAdvancementsError {
  readFailed,
  invalidJson,
  invalidData,
}

/// Immutable progress snapshot for one advancement resource ID.
final class MtnMinecraftInfoPlayerAdvancement {
  MtnMinecraftInfoPlayerAdvancement({
    required this.id,
    required this.done,
    required Map<String, DateTime> criteria,
  }) : criteria = Map<String, DateTime>.unmodifiable(criteria);

  /// External advancement resource ID, for example `minecraft:story/root`.
  final String id;

  /// Authoritative completion flag stored in the player progress file.
  final bool done;

  /// Completed criterion names and their UTC completion timestamps.
  final Map<String, DateTime> criteria;
}

/// Immutable snapshot of one Java Edition player advancements JSON file.
final class MtnMinecraftInfoPlayerAdvancements {
  MtnMinecraftInfoPlayerAdvancements._({
    required this.uuid,
    required this.file,
    required this.storageLayout,
    required this.state,
    required this.error,
    required Map<String, MtnMinecraftInfoPlayerAdvancement> advancements,
    this.dataVersion,
  }) : advancements =
            Map<String, MtnMinecraftInfoPlayerAdvancement>.unmodifiable(
          advancements,
        );

  factory MtnMinecraftInfoPlayerAdvancements.available({
    required String uuid,
    required File file,
    required MtnMinecraftInfoPlayerAdvancementsStorageLayout storageLayout,
    int? dataVersion,
    required Map<String, MtnMinecraftInfoPlayerAdvancement> advancements,
  }) =>
      MtnMinecraftInfoPlayerAdvancements._(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerAdvancementsState.available,
        error: null,
        dataVersion: dataVersion,
        advancements: advancements,
      );

  factory MtnMinecraftInfoPlayerAdvancements.invalid({
    required String uuid,
    required File file,
    required MtnMinecraftInfoPlayerAdvancementsStorageLayout storageLayout,
    required MtnMinecraftInfoPlayerAdvancementsError error,
  }) =>
      MtnMinecraftInfoPlayerAdvancements._(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        state: MtnMinecraftInfoPlayerAdvancementsState.invalid,
        error: error,
        advancements:
            const <String, MtnMinecraftInfoPlayerAdvancement>{},
      );

  /// Canonical lowercase UUID of the owning player.
  final String uuid;

  /// Exact discovered advancements file.
  final File file;

  final MtnMinecraftInfoPlayerAdvancementsStorageLayout storageLayout;

  final MtnMinecraftInfoPlayerAdvancementsState state;

  /// Advancements-local read error. Null when [state] is `available`.
  final MtnMinecraftInfoPlayerAdvancementsError? error;

  /// Root `DataVersion`, when present.
  final int? dataVersion;

  /// Progress entries keyed by external advancement resource ID.
  final Map<String, MtnMinecraftInfoPlayerAdvancement> advancements;
}
