import 'dart:convert';

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
    required this.host,
    required this.port,
    required this.versionName,
    required this.protocol,
    required this.onlinePlayers,
    required this.maxPlayers,
    required Iterable<MtnMinecraftInfoServerStatusPlayer> playerSample,
    required this.motd,
    required this.rawJson,
    this.favicon,
    this.latency,
    this.enforcesSecureChat,
    this.advertisesModded = false,
    this.modMetadata,
  }) : playerSample =
            List<MtnMinecraftInfoServerStatusPlayer>.unmodifiable(
          playerSample,
        );

  final String host;
  final int port;
  final String versionName;
  final int protocol;
  final int onlinePlayers;
  final int maxPlayers;
  final List<MtnMinecraftInfoServerStatusPlayer> playerSample;

  /// Plain-text projection of the server description/chat component.
  final String motd;

  /// Exact JSON status response for fields not modeled by this package.
  final String rawJson;

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
        'host': host,
        'port': port,
        'versionName': versionName,
        'protocol': protocol,
        'onlinePlayers': onlinePlayers,
        'maxPlayers': maxPlayers,
        'playerSample': playerSample
            .map(
              (MtnMinecraftInfoServerStatusPlayer player) => player.toMap(),
            )
            .toList(growable: false),
        'motd': motd,
        if (favicon != null) 'favicon': favicon,
        if (latency != null) 'latencyMilliseconds': latency!.inMilliseconds,
        if (enforcesSecureChat != null)
          'enforcesSecureChat': enforcesSecureChat,
        'advertisesModded': advertisesModded,
        if (modMetadata != null) 'modMetadata': modMetadata!.toMap(),
      };

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => toJson();
}
