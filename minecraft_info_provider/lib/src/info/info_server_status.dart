import 'dart:convert';

enum MtnMinecraftInfoServerState {
  online,
  offline,
  unavailable,
}

enum MtnMinecraftInfoServerUnavailableReason {
  dns,
  timeout,
  connection,
}

enum MtnMinecraftInfoServerModLoader {
  unknown,
  forge,
}

final class MtnMinecraftInfoServerStatusPlayer {
  const MtnMinecraftInfoServerStatusPlayer({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
      };
}

final class MtnMinecraftInfoServerAdvertisedMod {
  const MtnMinecraftInfoServerAdvertisedMod({
    required this.id,
    this.versionMarker,
  });

  final String id;

  /// Version or loader-specific marker advertised by the server.
  ///
  /// This is advisory metadata. It does not by itself prove that the mod is
  /// required on the client.
  final String? versionMarker;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        if (versionMarker != null) 'versionMarker': versionMarker,
      };
}

final class MtnMinecraftInfoServerAdvertisedChannel {
  const MtnMinecraftInfoServerAdvertisedChannel({
    required this.name,
    required this.version,
    required this.requiredForClient,
  });

  final String name;
  final String version;

  /// Loader-provided statement that this network channel is required.
  final bool requiredForClient;

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'version': version,
        'requiredForClient': requiredForClient,
      };
}

final class MtnMinecraftInfoServerModMetadata {
  MtnMinecraftInfoServerModMetadata({
    required this.loader,
    required Iterable<MtnMinecraftInfoServerAdvertisedMod> mods,
    required Iterable<MtnMinecraftInfoServerAdvertisedChannel> channels,
    this.fmlNetworkVersion,
    this.advertisedListsComplete,
  })  : mods = List<MtnMinecraftInfoServerAdvertisedMod>.unmodifiable(mods),
        channels =
            List<MtnMinecraftInfoServerAdvertisedChannel>.unmodifiable(
          channels,
        );

  final MtnMinecraftInfoServerModLoader loader;

  /// Mods advertised by the status response.
  ///
  /// Presence here does not imply a client-side requirement.
  final List<MtnMinecraftInfoServerAdvertisedMod> mods;

  /// Loader network channels advertised by the status response.
  final List<MtnMinecraftInfoServerAdvertisedChannel> channels;

  final int? fmlNetworkVersion;

  /// True when the loader says the advertised lists are complete, false when
  /// it explicitly says they were truncated, and null when completeness is
  /// not known from the response format.
  final bool? advertisedListsComplete;

  Map<String, Object?> toMap() => <String, Object?>{
        'loader': loader.name,
        'mods': mods
            .map((MtnMinecraftInfoServerAdvertisedMod mod) => mod.toMap())
            .toList(growable: false),
        'channels': channels
            .map(
              (MtnMinecraftInfoServerAdvertisedChannel channel) =>
                  channel.toMap(),
            )
            .toList(growable: false),
        if (fmlNetworkVersion != null)
          'fmlNetworkVersion': fmlNetworkVersion,
        if (advertisedListsComplete != null)
          'advertisedListsComplete': advertisedListsComplete,
      };
}

final class MtnMinecraftInfoServerStatus {
  MtnMinecraftInfoServerStatus({
    required this.state,
    required this.host,
    required this.port,
    this.versionName,
    this.protocol,
    this.onlinePlayers,
    this.maxPlayers,
    Iterable<MtnMinecraftInfoServerStatusPlayer> playerSample =
        const <MtnMinecraftInfoServerStatusPlayer>[],
    this.motd,
    this.rawJson,
    this.favicon,
    this.latency,
    this.enforcesSecureChat,
    this.advertisesModded = false,
    this.modMetadata,
    this.isStale = false,
    this.lastSuccessfulAt,
    this.failureSince,
    this.unavailableReason,
  }) : playerSample =
            List<MtnMinecraftInfoServerStatusPlayer>.unmodifiable(
          playerSample,
        );

  factory MtnMinecraftInfoServerStatus.unavailable({
    required String host,
    required int port,
    required MtnMinecraftInfoServerUnavailableReason reason,
  }) =>
      MtnMinecraftInfoServerStatus(
        state: MtnMinecraftInfoServerState.unavailable,
        host: host,
        port: port,
        unavailableReason: reason,
      );

  final MtnMinecraftInfoServerState state;
  final String host;
  final int port;

  bool get isOnline => state == MtnMinecraftInfoServerState.online;

  bool get isOffline => state == MtnMinecraftInfoServerState.offline;

  /// True when this object carries the last known server data because the
  /// current query did not produce a fresh status response.
  final bool isStale;

  /// Timestamp of the most recent successful status response.
  final DateTime? lastSuccessfulAt;

  /// Timestamp when the current consecutive reachability-failure window began.
  final DateTime? failureSince;

  /// Transport-level reason when [state] is unavailable.
  final MtnMinecraftInfoServerUnavailableReason? unavailableReason;

  final String? versionName;
  final int? protocol;
  final int? onlinePlayers;
  final int? maxPlayers;
  final List<MtnMinecraftInfoServerStatusPlayer> playerSample;

  /// Plain-text projection of the server description/chat component.
  final String? motd;

  /// Exact JSON status response for fields not modeled by this package.
  final String? rawJson;

  /// Data-URI favicon string when advertised by the server.
  final String? favicon;

  /// Ping/pong round-trip latency when measurement succeeded.
  final Duration? latency;

  /// Status flag advertised by newer Java servers when present.
  final bool? enforcesSecureChat;

  /// True only when the response explicitly advertises a modded server or
  /// exposes recognized loader metadata.
  final bool advertisesModded;

  final MtnMinecraftInfoServerModMetadata? modMetadata;

  Map<String, Object?> toMap() => <String, Object?>{
        'state': state.name,
        'host': host,
        'port': port,
        if (versionName != null) 'versionName': versionName,
        if (protocol != null) 'protocol': protocol,
        if (onlinePlayers != null) 'onlinePlayers': onlinePlayers,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
        if (playerSample.isNotEmpty)
          'playerSample': playerSample
              .map(
                (MtnMinecraftInfoServerStatusPlayer player) => player.toMap(),
              )
              .toList(growable: false),
        if (motd != null) 'motd': motd,
        if (favicon != null) 'favicon': favicon,
        if (latency != null) 'latencyMilliseconds': latency!.inMilliseconds,
        if (enforcesSecureChat != null)
          'enforcesSecureChat': enforcesSecureChat,
        'advertisesModded': advertisesModded,
        'isStale': isStale,
        if (lastSuccessfulAt != null)
          'lastSuccessfulAt': lastSuccessfulAt!.toIso8601String(),
        if (failureSince != null)
          'failureSince': failureSince!.toIso8601String(),
        if (unavailableReason != null)
          'unavailableReason': unavailableReason!.name,
        if (modMetadata != null) 'modMetadata': modMetadata!.toMap(),
      };

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => toJson();
}
