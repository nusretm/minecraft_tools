import 'dart:convert';
import 'dart:io';

import 'info_server_srv.dart';
import 'info_server_status.dart';
import 'info_server_status_client.dart';

typedef MtnMinecraftInfoServerChangeCallback = void Function(
  MtnMinecraftInfoServer server,
);

/// One server entry from the Java Edition `servers.dat` list.
final class MtnMinecraftInfoServer {
  MtnMinecraftInfoServer({
    required this.name,
    required this.address,
    this.icon,
    this.hidden = false,
    this.acceptServerResourcePacks,
    this.onChange,
  });

  factory MtnMinecraftInfoServer.clone(MtnMinecraftInfoServer source) =>
      MtnMinecraftInfoServer(
        name: source.name,
        address: source.address,
        icon: source.icon,
        hidden: source.hidden,
        acceptServerResourcePacks: source.acceptServerResourcePacks,
        onChange: source.onChange,
      );

  final String name;
  final String address;

  /// Raw base64-encoded PNG payload persisted by Minecraft, when present.
  final String? icon;

  /// Whether Minecraft hides the address in its multiplayer UI.
  final bool hidden;

  /// True/false map to Minecraft's `acceptTextures` byte 1/0.
  ///
  /// Null means the tag is absent and Minecraft may ask the player.
  final bool? acceptServerResourcePacks;

  /// Runtime-only callback invoked when the effective public status changes.
  MtnMinecraftInfoServerChangeCallback? onChange;

  /// Most recent effective runtime status for this server instance.
  ///
  /// This field is not persisted to `servers.dat`.
  MtnMinecraftInfoServerStatus? _status;

  MtnMinecraftInfoServerStatus? get status => _status;

  DateTime? _failureSince;

  /// Queries this server and updates [status].
  ///
  /// A server that has previously answered successfully remains effectively
  /// online through transient reachability failures for [offlineAfter].
  /// Consecutive non-DNS reachability failures beyond that period transition
  /// the server to offline. DNS failures are always unavailable.
  Future<MtnMinecraftInfoServerStatus> queryStatus({
    Duration timeout = const Duration(seconds: 5),
    Duration offlineAfter = const Duration(minutes: 1),
    int protocolVersion = -1,
    bool measureLatency = true,
    MtnMinecraftInfoSrvResolver? srvResolver,
  }) async {
    if (offlineAfter <= Duration.zero) {
      throw ArgumentError.value(
        offlineAfter,
        'offlineAfter',
        'Offline grace period must be greater than zero',
      );
    }

    final _ServerAddress target = _ServerAddress.parse(address);
    final List<_ServerAddress> candidates = <_ServerAddress>[target];
    var srvUnavailable = false;

    if (!target.hasExplicitPort &&
        InternetAddress.tryParse(target.host) == null) {
      final MtnMinecraftInfoSrvResolver resolver =
          srvResolver ?? MtnMinecraftInfoDnsSrvResolver();
      final List<MtnMinecraftInfoSrvRecord> records =
          await resolver.lookupMinecraft(
        host: target.host,
        timeout: timeout,
      );
      if (records.length == 1 && records.single.target == '.') {
        candidates.clear();
        srvUnavailable = true;
      } else if (records.isNotEmpty) {
        candidates
          ..clear()
          ..addAll(
            records.map(
              (MtnMinecraftInfoSrvRecord record) => _ServerAddress(
                host: record.target,
                port: record.port,
                hasExplicitPort: true,
              ),
            ),
          );
      }
    }

    MtnMinecraftInfoServerStatus? queried;
    for (final _ServerAddress candidate in candidates) {
      final MtnMinecraftInfoServerStatus result =
          await const MtnMinecraftInfoServerStatusClient().query(
        host: candidate.host,
        port: candidate.port,
        timeout: timeout,
        protocolVersion: protocolVersion,
        measureLatency: measureLatency,
        handshakeHost: target.host,
        handshakePort: target.port,
      );
      queried = result;
      if (result.state == MtnMinecraftInfoServerState.online) {
        break;
      }
    }
    queried ??= MtnMinecraftInfoServerStatus.unavailable(
      host: target.host,
      port: target.port,
      reason: srvUnavailable
          ? MtnMinecraftInfoServerUnavailableReason.srvUnavailable
          : MtnMinecraftInfoServerUnavailableReason.connection,
    );

    final MtnMinecraftInfoServerStatus next;
    final DateTime now = DateTime.now().toUtc();
    final MtnMinecraftInfoServerStatus? previous = _status;

    if (queried.state == MtnMinecraftInfoServerState.online) {
      _failureSince = null;
      next = _copyStatus(
        queried,
        state: MtnMinecraftInfoServerState.online,
        isStale: false,
        lastSuccessfulAt: now,
      );
    } else if (queried.unavailableReason ==
            MtnMinecraftInfoServerUnavailableReason.dns ||
        queried.unavailableReason ==
            MtnMinecraftInfoServerUnavailableReason.srvUnavailable) {
      _failureSince = null;
      next = previous == null
          ? queried
          : _copyStatus(
              previous,
              state: MtnMinecraftInfoServerState.unavailable,
              isStale: true,
              lastSuccessfulAt: previous.lastSuccessfulAt,
              unavailableReason: queried.unavailableReason,
            );
    } else if (previous?.lastSuccessfulAt != null) {
      _failureSince ??= now;
      final bool offline =
          now.difference(_failureSince!) >= offlineAfter;
      next = _copyStatus(
        previous!,
        state: offline
            ? MtnMinecraftInfoServerState.offline
            : MtnMinecraftInfoServerState.online,
        isStale: true,
        lastSuccessfulAt: previous.lastSuccessfulAt,
        failureSince: _failureSince,
        unavailableReason: queried.unavailableReason,
      );
    } else {
      _failureSince = null;
      next = queried;
    }

    final bool changed = !_sameEffectiveStatus(previous, next);
    _status = next;
    if (changed) {
      onChange?.call(this);
    }
    return next;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'address': address,
        if (icon != null) 'icon': icon,
        'hidden': hidden,
        if (acceptServerResourcePacks != null)
          'acceptServerResourcePacks': acceptServerResourcePacks,
      };

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => toJson();
}

final class _ServerAddress {
  const _ServerAddress({
    required this.host,
    required this.port,
    required this.hasExplicitPort,
  });

  factory _ServerAddress.parse(String address) {
    final String value = address.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(
        address,
        'address',
        'Server address must not be empty',
      );
    }

    if (value.startsWith('[')) {
      final int closing = value.indexOf(']');
      if (closing <= 1) {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid bracketed IPv6 server address',
        );
      }
      final String host = value.substring(1, closing);
      if (closing == value.length - 1) {
        return _ServerAddress(
          host: host,
          port: 25565,
          hasExplicitPort: false,
        );
      }
      if (value[closing + 1] != ':') {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid bracketed IPv6 server address',
        );
      }
      return _ServerAddress(
        host: host,
        port: _parsePort(value.substring(closing + 2), address),
        hasExplicitPort: true,
      );
    }

    final int firstColon = value.indexOf(':');
    final int lastColon = value.lastIndexOf(':');
    if (firstColon >= 0 && firstColon == lastColon) {
      return _ServerAddress(
        host: value.substring(0, firstColon),
        port: _parsePort(value.substring(firstColon + 1), address),
        hasExplicitPort: true,
      );
    }

    return _ServerAddress(
      host: value,
      port: 25565,
      hasExplicitPort: false,
    );
  }

  final String host;
  final int port;
  final bool hasExplicitPort;
}

int _parsePort(String raw, String address) {
  final int? port = int.tryParse(raw);
  if (port == null || port < 1 || port > 65535) {
    throw ArgumentError.value(
      address,
      'address',
      'Server port must be in the range 1..65535',
    );
  }
  return port;
}

MtnMinecraftInfoServerStatus _copyStatus(
  MtnMinecraftInfoServerStatus source, {
  required MtnMinecraftInfoServerState state,
  required bool isStale,
  required DateTime? lastSuccessfulAt,
  DateTime? failureSince,
  MtnMinecraftInfoServerUnavailableReason? unavailableReason,
}) {
  return MtnMinecraftInfoServerStatus(
    state: state,
    host: source.host,
    port: source.port,
    versionName: source.versionName,
    protocol: source.protocol,
    onlinePlayers: source.onlinePlayers,
    maxPlayers: source.maxPlayers,
    playerSample: source.playerSample,
    motd: source.motd,
    rawJson: source.rawJson,
    favicon: source.favicon,
    latency: isStale ? null : source.latency,
    enforcesSecureChat: source.enforcesSecureChat,
    advertisesModded: source.advertisesModded,
    modMetadata: source.modMetadata,
    isStale: isStale,
    lastSuccessfulAt: lastSuccessfulAt,
    failureSince: failureSince,
    unavailableReason: unavailableReason,
  );
}

bool _sameEffectiveStatus(
  MtnMinecraftInfoServerStatus? left,
  MtnMinecraftInfoServerStatus right,
) {
  if (left == null) return false;
  return left.state == right.state &&
      left.host == right.host &&
      left.port == right.port &&
      left.versionName == right.versionName &&
      left.protocol == right.protocol &&
      left.onlinePlayers == right.onlinePlayers &&
      left.maxPlayers == right.maxPlayers &&
      _samePlayers(left.playerSample, right.playerSample) &&
      left.motd == right.motd &&
      left.rawJson == right.rawJson &&
      left.favicon == right.favicon &&
      left.latency == right.latency &&
      left.enforcesSecureChat == right.enforcesSecureChat &&
      left.advertisesModded == right.advertisesModded &&
      _sameModMetadata(left.modMetadata, right.modMetadata) &&
      left.isStale == right.isStale &&
      left.failureSince == right.failureSince &&
      left.unavailableReason == right.unavailableReason;
}

bool _samePlayers(
  List<MtnMinecraftInfoServerStatusPlayer> left,
  List<MtnMinecraftInfoServerStatusPlayer> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].id != right[index].id ||
        left[index].name != right[index].name) {
      return false;
    }
  }
  return true;
}

bool _sameModMetadata(
  MtnMinecraftInfoServerModMetadata? left,
  MtnMinecraftInfoServerModMetadata? right,
) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  return jsonEncode(left.toMap()) == jsonEncode(right.toMap());
}
