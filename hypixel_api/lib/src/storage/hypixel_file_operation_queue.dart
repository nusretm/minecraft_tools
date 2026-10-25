import 'dart:async';
import 'dart:io';

/// Coordinates operations touching one physical file inside this isolate.
///
/// FileCache and DataStore use this same queue, so separate instances with
/// the same absolute file path cannot race through their shared .tmp file.
/// The completion future always succeeds; an operation failure cannot
/// permanently block the next operation.
final class HypixelFileOperationQueue {
  HypixelFileOperationQueue._();

  static final Map<String, Future<void>> _pending = <String, Future<void>>{};

  static Future<T> run<T>(String path, Future<T> Function() action) async {
    final String key = File(path).absolute.path;
    final Future<void>? previous = _pending[key];
    final Completer<void> completion = Completer<void>();
    _pending[key] = completion.future;

    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      if (identical(_pending[key], completion.future)) {
        _pending.remove(key);
      }
      completion.complete();
    }
  }
}
