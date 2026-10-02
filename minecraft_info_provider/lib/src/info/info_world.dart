import 'dart:io';

import 'package:path/path.dart' as p;

/// Discovery state for one Java Edition world directory.
enum MtnMinecraftInfoWorldState {
  available,
  invalid,
}

/// World-local failure reported during `level.dat` discovery.
///
/// These errors do not fail discovery of sibling worlds.
enum MtnMinecraftInfoWorldError {
  readFailed,
  invalidCompression,
  invalidNbt,
  invalidData,
}

/// Version metadata advertised by a Java Edition world's `level.dat`.
final class MtnMinecraftInfoWorldVersion {
  const MtnMinecraftInfoWorldVersion({
    this.id,
    this.name,
    this.snapshot,
    this.series,
  });

  /// `Data.Version.Id`, when present.
  final int? id;

  /// `Data.Version.Name`, when present.
  final String? name;

  /// `Data.Version.Snapshot`, when present.
  final bool? snapshot;

  /// `Data.Version.Series`, when present.
  final String? series;
}

/// Immutable snapshot of one Java Edition world directory.
final class MtnMinecraftInfoWorld {
  MtnMinecraftInfoWorld._({
    required this.directory,
    required this.directoryName,
    required this.state,
    required this.error,
    this.name,
    this.dataVersion,
    this.version,
    this.lastPlayed,
  });

  factory MtnMinecraftInfoWorld.available({
    required Directory directory,
    required String directoryName,
    String? name,
    int? dataVersion,
    MtnMinecraftInfoWorldVersion? version,
    DateTime? lastPlayed,
  }) =>
      MtnMinecraftInfoWorld._(
        directory: directory,
        directoryName: directoryName,
        state: MtnMinecraftInfoWorldState.available,
        error: null,
        name: name,
        dataVersion: dataVersion,
        version: version,
        lastPlayed: lastPlayed,
      );

  factory MtnMinecraftInfoWorld.invalid({
    required Directory directory,
    required String directoryName,
    required MtnMinecraftInfoWorldError error,
  }) =>
      MtnMinecraftInfoWorld._(
        directory: directory,
        directoryName: directoryName,
        state: MtnMinecraftInfoWorldState.invalid,
        error: error,
      );

  /// Absolute world directory under the provider's `saves` directory.
  final Directory directory;

  /// Filesystem directory name. This is distinct from [name].
  final String directoryName;

  File get levelFile => File(p.join(directory.path, 'level.dat'));

  /// Conventional Java Edition world icon path.
  ///
  /// The foundation does not read or validate the PNG payload.
  File get iconFile => File(p.join(directory.path, 'icon.png'));

  final MtnMinecraftInfoWorldState state;

  /// World-local discovery error. Null when [state] is `available`.
  final MtnMinecraftInfoWorldError? error;

  /// Minecraft display name from `Data.LevelName`.
  final String? name;

  /// `Data.DataVersion`, when present.
  final int? dataVersion;

  /// `Data.Version`, when present.
  final MtnMinecraftInfoWorldVersion? version;

  /// `Data.LastPlayed` converted from Unix epoch milliseconds to UTC.
  final DateTime? lastPlayed;
}
