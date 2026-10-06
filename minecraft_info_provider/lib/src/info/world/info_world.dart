import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../player/info_player.dart';

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

/// Aggregate discovery state for the player list belonging to one world.
enum MtnMinecraftInfoWorldPlayersState {
  available,
  invalid,
}

/// World-local failure while discovering the aggregate player list.
///
/// Individual corrupt player files remain represented by
/// [MtnMinecraftInfoPlayer.state] and do not make this aggregate invalid.
enum MtnMinecraftInfoWorldPlayersError {
  invalidPath,
  readFailed,
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
    required List<MtnMinecraftInfoPlayer> players,
    required this.playersState,
    required this.playersError,
    Uint8List? icon,
    this.name,
    this.dataVersion,
    this.version,
    this.lastPlayed,
    this.singleplayerUuid,
  })  : players = List<MtnMinecraftInfoPlayer>.unmodifiable(players),
        _icon = icon == null ? null : Uint8List.fromList(icon);

  factory MtnMinecraftInfoWorld.available({
    required Directory directory,
    required String directoryName,
    String? name,
    int? dataVersion,
    MtnMinecraftInfoWorldVersion? version,
    DateTime? lastPlayed,
    String? singleplayerUuid,
    List<MtnMinecraftInfoPlayer> players = const <MtnMinecraftInfoPlayer>[],
    MtnMinecraftInfoWorldPlayersState playersState = MtnMinecraftInfoWorldPlayersState.available,
    MtnMinecraftInfoWorldPlayersError? playersError,
    Uint8List? icon,
  }) =>
      MtnMinecraftInfoWorld._(
        directory: directory,
        directoryName: directoryName,
        state: MtnMinecraftInfoWorldState.available,
        error: null,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
        name: name,
        dataVersion: dataVersion,
        version: version,
        lastPlayed: lastPlayed,
        singleplayerUuid: singleplayerUuid,
      );

  factory MtnMinecraftInfoWorld.invalid({
    required Directory directory,
    required String directoryName,
    required MtnMinecraftInfoWorldError error,
    List<MtnMinecraftInfoPlayer> players = const <MtnMinecraftInfoPlayer>[],
    MtnMinecraftInfoWorldPlayersState playersState = MtnMinecraftInfoWorldPlayersState.available,
    MtnMinecraftInfoWorldPlayersError? playersError,
    Uint8List? icon,
  }) =>
      MtnMinecraftInfoWorld._(
        directory: directory,
        directoryName: directoryName,
        state: MtnMinecraftInfoWorldState.invalid,
        error: error,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
      );

  static const String iconFileName = 'icon.png';

  /// Absolute world directory under the provider's `saves` directory.
  final Directory directory;

  /// Filesystem directory name. This is distinct from [name].
  final String directoryName;

  File get levelFile => File(p.join(directory.path, 'level.dat'));

  /// Conventional Java Edition world icon path.
  File get iconFile => File(p.join(directory.path, iconFileName));

  /// Player snapshots discovered inside this world.
  ///
  /// Empty when [playersState] is invalid because the aggregate player
  /// storage could not be enumerated safely.
  final List<MtnMinecraftInfoPlayer> players;

  final MtnMinecraftInfoWorldPlayersState playersState;

  /// Aggregate player-list discovery error.
  ///
  /// Null when [playersState] is [MtnMinecraftInfoWorldPlayersState.available].
  final MtnMinecraftInfoWorldPlayersError? playersError;

  /// Canonical lowercase UUID referenced by 26.1+ `Data.singleplayer_uuid`.
  ///
  /// Null means the world does not persist a singleplayer player reference.
  final String? singleplayerUuid;

  /// Discovered player snapshot referenced by [singleplayerUuid], when present.
  ///
  /// The UUID remains authoritative. This derived relationship is null when
  /// the referenced player file is missing or aggregate player discovery
  /// could not make that snapshot available.
  MtnMinecraftInfoPlayer? get singleplayerPlayer {
    final String? uuid = singleplayerUuid;
    if (uuid == null) return null;
    for (final MtnMinecraftInfoPlayer player in players) {
      if (player.uuid == uuid) return player;
    }
    return null;
  }

  final Uint8List? _icon;

  /// Raw `icon.png` bytes, when a readable regular icon file exists.
  ///
  /// A defensive copy is returned so this immutable world snapshot cannot be
  /// modified through the byte buffer.
  Uint8List? get icon => _icon == null ? null : Uint8List.fromList(_icon);

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
