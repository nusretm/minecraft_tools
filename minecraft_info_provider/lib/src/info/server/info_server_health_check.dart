import 'dart:async';

import 'info_server.dart';

typedef MtnMinecraftInfoServerHealthCheckCallback = void Function(
  MtnMinecraftInfoServerHealthCheck checker,
  MtnMinecraftInfoServer server,
);

/// Coordinates automatic status checks for a managed server collection.
///
/// Each [MtnMinecraftInfoServer] owns its own timer and query lifecycle. This
/// class only manages membership, a shared interval, and collection callbacks.
final class MtnMinecraftInfoServerHealthCheck {
  MtnMinecraftInfoServerHealthCheck({
    int intervalSec = MtnMinecraftInfoServer.minimumAutoCheckSec,
    this.onAdd,
    this.onChange,
    this.onRemove,
  }) : _intervalSec = intervalSec < MtnMinecraftInfoServer.minimumAutoCheckSec
            ? MtnMinecraftInfoServer.minimumAutoCheckSec
            : intervalSec;

  final List<MtnMinecraftInfoServer> _servers = <MtnMinecraftInfoServer>[];
  final Set<MtnMinecraftInfoServer> _initialChecks =
      <MtnMinecraftInfoServer>{};

  int _intervalSec;
  bool _active = false;
  bool _disposed = false;

  MtnMinecraftInfoServerHealthCheckCallback? onAdd;
  MtnMinecraftInfoServerHealthCheckCallback? onChange;
  MtnMinecraftInfoServerHealthCheckCallback? onRemove;

  List<MtnMinecraftInfoServer> get servers =>
      List<MtnMinecraftInfoServer>.unmodifiable(_servers);

  bool get active => _active;

  int get intervalSec => _intervalSec;

  set intervalSec(int value) {
    _ensureNotDisposed();

    final int next = value < MtnMinecraftInfoServer.minimumAutoCheckSec
        ? MtnMinecraftInfoServer.minimumAutoCheckSec
        : value;
    if (_intervalSec == next) return;

    _intervalSec = next;
    for (final MtnMinecraftInfoServer server in _servers) {
      server.autoCheckSec = next;
    }
  }

  bool add(MtnMinecraftInfoServer server) {
    _ensureNotDisposed();
    if (_servers.contains(server)) return false;

    final MtnMinecraftInfoServerChangeCallback? previous = server.onChange;
    server.autoCheck = false;
    server.autoCheckSec = _intervalSec;
    server.onChange = (MtnMinecraftInfoServer changed) {
      try {
        previous?.call(changed);
      } finally {
        if (!_disposed && _servers.contains(changed)) {
          onChange?.call(this, changed);
        }
      }
    };

    _servers.add(server);
    onAdd?.call(this, server);

    _initialChecks.add(server);
    unawaited(_queryAddedServer(server));
    return true;
  }

  bool remove(MtnMinecraftInfoServer server) {
    if (_disposed) return false;
    if (!_servers.remove(server)) return false;

    _initialChecks.remove(server);
    server.dispose();
    onRemove?.call(this, server);
    return true;
  }

  void start() {
    _ensureNotDisposed();
    if (_active) return;

    _active = true;
    for (final MtnMinecraftInfoServer server in _servers) {
      server.autoCheckSec = _intervalSec;
      if (!_initialChecks.contains(server)) {
        server.autoCheck = true;
      }
    }
  }

  void stop() {
    if (_disposed || !_active) return;

    _active = false;
    for (final MtnMinecraftInfoServer server in _servers) {
      server.autoCheck = false;
    }
  }

  void dispose() {
    if (_disposed) return;

    _active = false;
    _disposed = true;

    final List<MtnMinecraftInfoServer> current =
        List<MtnMinecraftInfoServer>.of(_servers);
    _servers.clear();
    _initialChecks.clear();

    for (final MtnMinecraftInfoServer server in current) {
      server.dispose();
      onRemove?.call(this, server);
    }

    onAdd = null;
    onChange = null;
    onRemove = null;
  }

  Future<void> _queryAddedServer(MtnMinecraftInfoServer server) async {
    try {
      await server.queryStatus();
    } on Object {
      // One failed initial query must not prevent later automatic checks.
    } finally {
      final bool wasPending = _initialChecks.remove(server);
      if (wasPending &&
          !_disposed &&
          _active &&
          _servers.contains(server)) {
        server.autoCheckSec = _intervalSec;
        server.autoCheck = true;
      }
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('MtnMinecraftInfoServerHealthCheck is disposed');
    }
  }
}
