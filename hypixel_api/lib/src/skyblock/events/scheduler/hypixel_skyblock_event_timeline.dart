import '../hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_trigger.dart';

class HypixelSkyBlockEventTimeline {
  const HypixelSkyBlockEventTimeline();

  List<HypixelSkyBlockEventTrigger> build({
    required Iterable<HypixelSkyBlockEvent> events,
    required Duration reminderBefore,
    bool includePhaseBoundaries = true,
  }) {
    final result = <HypixelSkyBlockEventTrigger>[];

    for (final event in events) {
      if (reminderBefore > Duration.zero) {
        result.add(HypixelSkyBlockEventTrigger(
          at: event.startAt.subtract(reminderBefore),
          event: event,
          type: HypixelSkyBlockEventTriggerType.remind,
        ));
      }

      result.add(HypixelSkyBlockEventTrigger(
        at: event.startAt,
        event: event,
        type: HypixelSkyBlockEventTriggerType.event,
      ));

      if (event.remindBeforeEnd && reminderBefore > Duration.zero) {
        final at = event.endAt.subtract(reminderBefore);
        // Avoid creating an end reminder before the event itself starts.
        if (!at.isBefore(event.startAt)) {
          result.add(HypixelSkyBlockEventTrigger(
            at: at,
            event: event,
            type: HypixelSkyBlockEventTriggerType.endRemind,
          ));
        }
      }

      if (event.remindOnEnd) {
        result.add(HypixelSkyBlockEventTrigger(
          at: event.endAt,
          event: event,
          type: HypixelSkyBlockEventTriggerType.eventEnd,
        ));
      }

      if (!includePhaseBoundaries) continue;
      for (final phase in event.phases) {
        // The official event phase has the same boundaries as onEvent and the
        // event's end; do not duplicate its start notification.
        if (phase.startAt != event.startAt) {
          result.add(HypixelSkyBlockEventTrigger(
            at: phase.startAt,
            event: event,
            type: HypixelSkyBlockEventTriggerType.phaseStart,
            phase: phase,
          ));
        }
        if (phase.endAt != event.endAt) {
          result.add(HypixelSkyBlockEventTrigger(
            at: phase.endAt,
            event: event,
            type: HypixelSkyBlockEventTriggerType.phaseEnd,
            phase: phase,
          ));
        }
      }
    }

    result.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return _priority(a.type).compareTo(_priority(b.type));
    });
    return result;
  }

  int _priority(HypixelSkyBlockEventTriggerType type) => switch (type) {
        HypixelSkyBlockEventTriggerType.remind => 0,
        HypixelSkyBlockEventTriggerType.endRemind => 1,
        HypixelSkyBlockEventTriggerType.phaseStart => 2,
        HypixelSkyBlockEventTriggerType.event => 3,
        HypixelSkyBlockEventTriggerType.eventEnd => 4,
        HypixelSkyBlockEventTriggerType.phaseEnd => 5,
      };
}
