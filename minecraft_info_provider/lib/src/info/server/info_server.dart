import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'info_server_address.dart';
import 'info_server_legacy_status_client.dart';
import 'info_server_srv.dart';
import 'info_server_status.dart';
import 'info_server_status_client.dart';

typedef MtnMinecraftInfoServerChangeCallback = void Function(
  MtnMinecraftInfoServer server,
);

/// One server entry from the Java Edition `servers.dat` list.
final class MtnMinecraftInfoServer {
  static const int minimumAutoCheckSec = 15;

  MtnMinecraftInfoServer({
    required this.name,
    required this.address,
    this.icon,
    this.hidden = false,
    this.acceptServerResourcePacks,
    this.onChange,
  });

  factory MtnMinecraftInfoServer.clone(MtnMinecraftInfoServer source) {
    final MtnMinecraftInfoServer clone = MtnMinecraftInfoServer(
      name: source.name,
      address: source.address,
      icon: source.icon,
      hidden: source.hidden,
      acceptServerResourcePacks: source.acceptServerResourcePacks,
      onChange: source.onChange,
    );
    clone.autoCheckSec = source.autoCheckSec;
    return clone;
  }

  final String name;
  final String address;

  MtnMinecraftInfoServerAddress get parsedAddress =>
      MtnMinecraftInfoServerAddress.parse(address);

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

  bool _autoCheck = false;
  int _autoCheckSec = minimumAutoCheckSec;
  Timer? _autoCheckTimer;
  bool _autoCheckRunning = false;
  bool _disposed = false;

  /// Whether this server automatically refreshes its runtime status.
  ///
  /// Enabling auto-check schedules the first query after [autoCheckSec].
  bool get autoCheck => _autoCheck;

  set autoCheck(bool value) {
    if (_disposed && value) {
      throw StateError('Cannot enable auto-check on a disposed server');
    }
    if (_autoCheck == value) return;

    _autoCheck = value;
    if (value) {
      _scheduleAutoCheck();
    } else {
      _cancelAutoCheckTimer();
    }
  }

  /// Delay between completed automatic status checks.
  ///
  /// Values below [minimumAutoCheckSec] are clamped to that minimum.
  int get autoCheckSec => _autoCheckSec;

  set autoCheckSec(int value) {
    if (_disposed) {
      throw StateError('Cannot change auto-check interval on a disposed server');
    }

    final int next =
        value < minimumAutoCheckSec ? minimumAutoCheckSec : value;
    if (_autoCheckSec == next) return;

    _autoCheckSec = next;
    if (_autoCheck && !_autoCheckRunning) {
      _scheduleAutoCheck();
    }
  }

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
    bool allowLegacyFallback = true,
    MtnMinecraftInfoSrvResolver? srvResolver,
  }) async {
    if (_disposed) {
      throw StateError('Cannot query a disposed server');
    }
    if (offlineAfter <= Duration.zero) {
      throw ArgumentError.value(
        offlineAfter,
        'offlineAfter',
        'Offline grace period must be greater than zero',
      );
    }

    final MtnMinecraftInfoServerStatus? previousStatus = _status;
    final bool canDiscoverLegacy =
        previousStatus?.format != MtnMinecraftInfoServerStatusFormat.modern;

    final MtnMinecraftInfoServerAddress target =
        MtnMinecraftInfoServerAddress.parse(address);
    final List<MtnMinecraftInfoServerAddress> candidates =
        <MtnMinecraftInfoServerAddress>[target];
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
              (MtnMinecraftInfoSrvRecord record) =>
                  MtnMinecraftInfoServerAddress.endpoint(
                host: record.target,
                port: record.port,
              ),
            ),
          );
      }
    }

    MtnMinecraftInfoServerStatus? queried;
    for (final MtnMinecraftInfoServerAddress candidate in candidates) {
      MtnMinecraftInfoServerStatus result;
      try {
        result = await const MtnMinecraftInfoServerStatusClient().query(
          host: candidate.host,
          port: candidate.port,
          timeout: timeout,
          protocolVersion: protocolVersion,
          measureLatency: measureLatency,
          handshakeHost: target.host,
          handshakePort: target.port,
        );

        if (allowLegacyFallback &&
            canDiscoverLegacy &&
            result.state != MtnMinecraftInfoServerState.online &&
            result.unavailableReason ==
                MtnMinecraftInfoServerUnavailableReason.timeout) {
          final MtnMinecraftInfoServerStatus? legacy =
              await const MtnMinecraftInfoServerLegacyStatusClient().query(
            host: candidate.host,
            port: candidate.port,
            handshakeHost: target.host,
            handshakePort: target.port,
            timeout: timeout,
            measureLatency: measureLatency,
          );
          if (legacy != null) result = legacy;
        }
      } on MtnMinecraftInfoServerStatusException catch (error) {
        if (!allowLegacyFallback ||
            !canDiscoverLegacy ||
            error.error != MtnMinecraftInfoServerStatusError.invalidPacket) {
          rethrow;
        }

        final MtnMinecraftInfoServerStatus? legacy =
            await const MtnMinecraftInfoServerLegacyStatusClient().query(
          host: candidate.host,
          port: candidate.port,
          handshakeHost: target.host,
          handshakePort: target.port,
          timeout: timeout,
          measureLatency: measureLatency,
        );
        if (legacy == null) rethrow;
        result = legacy;
      }

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

    if (_disposed) return next;

    final bool changed = !_sameEffectiveStatus(previous, next);
    _status = next;
    if (changed) {
      onChange?.call(this);
    }
    return next;
  }

  void _scheduleAutoCheck() {
    _cancelAutoCheckTimer();
    if (_disposed || !_autoCheck || _autoCheckRunning) return;

    _autoCheckTimer = Timer(
      Duration(seconds: _autoCheckSec),
      () {
        _autoCheckTimer = null;
        unawaited(_runAutoCheck());
      },
    );
  }

  Future<void> _runAutoCheck() async {
    if (_disposed || !_autoCheck || _autoCheckRunning) return;

    _autoCheckRunning = true;
    try {
      await queryStatus();
    } on Object {
      // Automatic monitoring must remain alive even if one query fails.
    } finally {
      _autoCheckRunning = false;
      if (!_disposed && _autoCheck) {
        _scheduleAutoCheck();
      }
    }
  }

  void _cancelAutoCheckTimer() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
  }

  /// Stops automatic checks and releases runtime callbacks.
  ///
  /// An in-flight query may finish its transport work, but cannot publish a
  /// new status or schedule another automatic check after disposal.
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _autoCheck = false;
    _cancelAutoCheckTimer();
    onChange = null;
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
    format: source.format,
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
      left.format == right.format &&
      left.port == right.port &&
      left.versionName == right.versionName &&
      left.protocol == right.protocol &&
      left.onlinePlayers == right.onlinePlayers &&
      left.maxPlayers == right.maxPlayers &&
      _samePlayers(left.playerSample, right.playerSample) &&
      left.motd?.text == right.motd?.text &&
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
