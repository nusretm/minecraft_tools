part of 'minecraft_content_materialization_file_system.dart';

final Map<String, _MaterializationRootGate> _materializationRootGates = <String, _MaterializationRootGate>{};

String _materializationRootKey(
  MtnMinecraftContentMaterializationFileSystemPreflight preflight,
) {
  final normalized = p.normalize(p.absolute(preflight.resolvedInstallationRoot.path));
  final root = preflight.policy.caseSensitive ? normalized : normalized.toLowerCase();
  return '${preflight.policy.platform.name}:${preflight.policy.caseSensitive}:$root';
}

Future<void Function()> _acquireMaterializationRoot(
  MtnMinecraftContentMaterializationFileSystemPreflight preflight, {
  required bool exclusive,
}) {
  final key = _materializationRootKey(preflight);
  final gate = _materializationRootGates.putIfAbsent(key, () => _MaterializationRootGate());
  return gate.acquire(exclusive: exclusive, onEmpty: () {
    if (identical(_materializationRootGates[key], gate)) {
      _materializationRootGates.remove(key);
    }
  });
}

class _MaterializationRootGate {
  final List<_MaterializationRootWaiter> _queue = <_MaterializationRootWaiter>[];
  int _readers = 0;
  bool _writer = false;

  Future<void Function()> acquire({
    required bool exclusive,
    required void Function() onEmpty,
  }) {
    final waiter = _MaterializationRootWaiter(exclusive: exclusive, onEmpty: onEmpty);
    _queue.add(waiter);
    _drain();
    return waiter.ready.future;
  }

  void _drain() {
    if (_writer || _queue.isEmpty) {
      return;
    }

    if (_queue.first.exclusive) {
      if (_readers != 0) {
        return;
      }
      final waiter = _queue.removeAt(0);
      _writer = true;
      waiter.ready.complete(_release(waiter));
      return;
    }

    while (_queue.isNotEmpty && !_queue.first.exclusive) {
      final waiter = _queue.removeAt(0);
      _readers++;
      waiter.ready.complete(_release(waiter));
    }
  }

  void Function() _release(_MaterializationRootWaiter waiter) {
    bool released = false;
    return () {
      if (released) {
        return;
      }
      released = true;
      if (waiter.exclusive) {
        _writer = false;
      } else {
        _readers--;
      }
      _drain();
      if (!_writer && _readers == 0 && _queue.isEmpty) {
        waiter.onEmpty();
      }
    };
  }
}

class _MaterializationRootWaiter {
  _MaterializationRootWaiter({
    required this.exclusive,
    required this.onEmpty,
  });

  final bool exclusive;
  final void Function() onEmpty;
  final Completer<void Function()> ready = Completer<void Function()>();
}
