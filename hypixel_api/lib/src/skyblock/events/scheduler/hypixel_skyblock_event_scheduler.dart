import 'dart:async';

import '../../hypixel_skyblock_api.dart';
import '../hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_timeline.dart';
import 'hypixel_skyblock_event_trigger.dart';

typedef HypixelSkyBlockEventCallback = void Function(HypixelSkyBlockEvent event);

class HypixelSkyBlockEventScheduler {
  HypixelSkyBlockEventScheduler({
    required HypixelSkyBlockApi api,
    required this.onEvent,
    required this.onRemind,
    this.reminderBefore = const Duration(minutes: 5),
    this.refreshInterval = const Duration(minutes: 5),
    this.lookAhead = const Duration(days: 7),
    this.includePhaseBoundaries = true,
  }) : _api = api;

  final HypixelSkyBlockApi _api;
  final HypixelSkyBlockEventCallback? onEvent;
  final HypixelSkyBlockEventCallback? onRemind;
  final Duration reminderBefore;
  final Duration refreshInterval;
  final Duration lookAhead;
  final bool includePhaseBoundaries;

  final _timelineBuilder = const HypixelSkyBlockEventTimeline();
  final Set<String> _fired = <String>{};

  Timer? _timer;
  List<HypixelSkyBlockEventTrigger> _timeline = const [];
  DateTime? _nextRefreshAt;
  bool _running = false;
  bool _handlingWake = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _refresh(forceNetwork: false);
    if (_running) _scheduleNextWake();
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _timeline = const [];
  }

  Future<void> refresh({bool forceNetwork = false}) async {
    if (!_running) return;
    _timer?.cancel();
    await _refresh(forceNetwork: forceNetwork);
    if (_running) _scheduleNextWake();
  }

  Future<void> _refresh({required bool forceNetwork}) async {
    final now = DateTime.now().toUtc();
    final events = await _api.events(
      from: now.subtract(reminderBefore),
      to: now.add(lookAhead),
      refreshMayor: forceNetwork,
    );
    _timeline = _timelineBuilder.build(
      events: events,
      reminderBefore: reminderBefore,
      includePhaseBoundaries: includePhaseBoundaries,
    );
    _nextRefreshAt = now.add(refreshInterval);
    _pruneFired(now);
  }

  void _scheduleNextWake() {
    _timer?.cancel();
    if (!_running) return;

    final now = DateTime.now().toUtc();
    DateTime? nextTrigger;
    for (final trigger in _timeline) {
      if (_fired.contains(trigger.id)) continue;
      if (!trigger.at.isBefore(now)) {
        nextTrigger = trigger.at;
        break;
      }
    }

    DateTime? wakeAt = nextTrigger;
    final refreshAt = _nextRefreshAt;
    if (refreshAt != null && (wakeAt == null || refreshAt.isBefore(wakeAt))) {
      wakeAt = refreshAt;
    }
    if (wakeAt == null) return;

    var delay = wakeAt.difference(now);
    if (delay.isNegative) delay = Duration.zero;
    _timer = Timer(delay, _wake);
  }

  Future<void> _wake() async {
    if (!_running || _handlingWake) return;
    _handlingWake = true;
    try {
      final now = DateTime.now().toUtc();

      // Fire due triggers from the current timeline before refreshing it. If a
      // refresh boundary happens to share the exact timestamp with an event
      // start/end, replacing the timeline first could otherwise drop that
      // lifecycle callback.
      final due = _timeline
          .where((trigger) => !_fired.contains(trigger.id) && !trigger.at.isAfter(now))
          .toList(growable: false);

      for (final trigger in due) {
        _fired.add(trigger.id);
        if (trigger.type == HypixelSkyBlockEventTriggerType.event) {
          onEvent?.call(trigger.event);
        } else {
          onRemind?.call(trigger.event);
        }
      }

      final refreshAt = _nextRefreshAt;
      if (refreshAt != null && !refreshAt.isAfter(now)) {
        await _refresh(forceNetwork: false);
      }
    } finally {
      _handlingWake = false;
      if (_running) _scheduleNextWake();
    }
  }

  void _pruneFired(DateTime now) {
    // IDs contain the trigger timestamp in microseconds. Keep only recent IDs
    // so a long-running launcher cannot grow this set without bound.
    final cutoff = now.subtract(lookAhead).microsecondsSinceEpoch;
    _fired.removeWhere((id) {
      final separator = id.indexOf('|');
      if (separator <= 0) return true;
      return (int.tryParse(id.substring(0, separator)) ?? 0) < cutoff;
    });
  }
}
