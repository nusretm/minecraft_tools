import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  const calendar = HypixelSkyBlockCalendar();

  test('Spooky exposes the three-hour activity window around scoring', () {
    final scoringStart = calendar.toDateTime(year: 517, month: 8, day: 29);
    final scoringEnd = scoringStart.add(const Duration(hours: 1));
    final events = HypixelSkyBlockEventCalendar(calendar).events(
      from: scoringStart.subtract(const Duration(hours: 2)),
      to: scoringEnd.add(const Duration(hours: 2)),
    );
    final spooky = events.singleWhere(
      (event) => event.type == HypixelSkyBlockEventType.spookyFestival,
    );

    final activity = spooky.phases.singleWhere(
      (phase) => phase.type == HypixelSkyBlockEventPhaseType.activity,
    );
    expect(activity.startAt, scoringStart.subtract(const Duration(hours: 1)));
    expect(activity.endAt, scoringEnd.add(const Duration(hours: 1)));
    expect(activity.duration, const Duration(hours: 3));
  });

  test('timeline keeps colliding event triggers at one timestamp', () {
    final at = DateTime.utc(2026, 10, 2, 14, 55);
    final events = [
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.darkAuction,
        name: 'Dark Auction',
        category: HypixelSkyBlockEventCategory.realtime,
        startAt: at,
        endAt: at.add(const Duration(seconds: 1)),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.travelingZoo,
        name: 'Traveling Zoo',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: at,
        endAt: at.add(const Duration(hours: 1)),
      ),
    ];

    final triggers = const HypixelSkyBlockEventTimeline().build(
      events: events,
      reminderBefore: const Duration(minutes: 5),
    );
    final onTime = triggers.where(
      (trigger) =>
          trigger.at == at &&
          trigger.type == HypixelSkyBlockEventTriggerType.event,
    );
    expect(onTime.length, 2);
  });

  test('Spooky activity phase creates start and end reminders', () {
    final scoringStart = calendar.toDateTime(year: 517, month: 8, day: 29);
    final spooky = HypixelSkyBlockEventCalendar(calendar)
        .events(
          from: scoringStart.subtract(const Duration(hours: 2)),
          to: scoringStart.add(const Duration(hours: 3)),
        )
        .singleWhere(
          (event) => event.type == HypixelSkyBlockEventType.spookyFestival,
        );

    final triggers = const HypixelSkyBlockEventTimeline().build(
      events: [spooky],
      reminderBefore: const Duration(minutes: 5),
    );

    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.phaseStart &&
          trigger.at == scoringStart.subtract(const Duration(hours: 1))),
      isTrue,
    );
    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.phaseEnd &&
          trigger.at == scoringStart.add(const Duration(hours: 2))),
      isTrue,
    );
  });
  test('Bingo creates start, pre-end, and exact-end triggers', () {
    final start = DateTime.utc(2026, 10, 1, 4);
    final end = DateTime.utc(2026, 10, 8, 4);
    final bingo = HypixelSkyBlockEvent(
      type: HypixelSkyBlockEventType.bingo,
      name: 'Bingo - October 2026',
      category: HypixelSkyBlockEventCategory.gregorian,
      startAt: start,
      endAt: end,
      remindBeforeEnd: true,
      remindOnEnd: true,
    );

    final triggers = const HypixelSkyBlockEventTimeline().build(
      events: [bingo],
      reminderBefore: const Duration(minutes: 5),
    );

    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.remind &&
          trigger.at == start.subtract(const Duration(minutes: 5))),
      isTrue,
    );
    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.event &&
          trigger.at == start),
      isTrue,
    );
    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.endRemind &&
          trigger.at == end.subtract(const Duration(minutes: 5))),
      isTrue,
    );
    expect(
      triggers.any((trigger) =>
          trigger.type == HypixelSkyBlockEventTriggerType.eventEnd &&
          trigger.at == end),
      isTrue,
    );
  });

}
