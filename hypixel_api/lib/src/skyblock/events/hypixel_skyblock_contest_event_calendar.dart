import '../calendar/hypixel_skyblock_calendar.dart';
import 'hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';

class HypixelSkyBlockContestEventCalendar {
  const HypixelSkyBlockContestEventCalendar(this.calendar);

  final HypixelSkyBlockCalendar calendar;

  List<HypixelSkyBlockEvent> events({
    required DateTime from,
    required DateTime to,
  }) {
    final start = from.toUtc();
    final end = to.toUtc();

    if (!end.isAfter(start)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final result = <HypixelSkyBlockEvent>[
      ..._jacobEvents(from: start, to: end),
      ..._miriaEvents(from: start, to: end),
    ];

    result.sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      if (byTime != 0) return byTime;
      return a.type.index.compareTo(b.type.index);
    });
    return result;
  }

  List<HypixelSkyBlockEvent> _jacobEvents({
    required DateTime from,
    required DateTime to,
  }) {
    final result = <HypixelSkyBlockEvent>[];

    // Jacob's Farming Contest starts once per real-life hour at XX:15 and
    // lasts one SkyBlock day (20 real-life minutes), ending at XX:35.
    var next = DateTime.utc(from.year, from.month, from.day, from.hour, 15);
    if (next.add(const Duration(minutes: 20)).isAfter(from) == false) {
      next = next.add(const Duration(hours: 1));
    }

    // If the requested range starts during an already-active contest, include
    // that contest too.
    if (next.isAfter(from)) {
      final previous = next.subtract(const Duration(hours: 1));
      if (previous.add(const Duration(minutes: 20)).isAfter(from)) {
        next = previous;
      }
    }

    while (next.isBefore(to)) {
      final event = HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.jacobsFarmingContest,
        name: "Jacob's Farming Contest",
        category: HypixelSkyBlockEventCategory.contest,
        startAt: next,
        endAt: next.add(const Duration(minutes: 20)),
      );
      if (event.endAt.isAfter(from)) result.add(event);
      next = next.add(const Duration(hours: 1));
    }

    return result;
  }

  List<HypixelSkyBlockEvent> _miriaEvents({
    required DateTime from,
    required DateTime to,
  }) {
    final result = <HypixelSkyBlockEvent>[];

    // Miria hosts a Starlyn Contest every SkyBlock day. A SkyBlock day is
    // exactly 20 real-life minutes, so contests are consecutive and align to
    // the canonical SkyBlock epoch/day boundaries.
    final elapsed = from.difference(HypixelSkyBlockCalendar.epochUtc);
    final dayMicros = HypixelSkyBlockCalendar.skyBlockDay.inMicroseconds;
    var dayIndex = elapsed.inMicroseconds ~/ dayMicros;
    if (elapsed.inMicroseconds < 0 && elapsed.inMicroseconds % dayMicros != 0) {
      dayIndex--;
    }

    var next = HypixelSkyBlockCalendar.epochUtc.add(
      Duration(microseconds: dayIndex * dayMicros),
    );

    while (next.add(HypixelSkyBlockCalendar.skyBlockDay).isBefore(from) ||
        next.add(HypixelSkyBlockCalendar.skyBlockDay).isAtSameMomentAs(from)) {
      next = next.add(HypixelSkyBlockCalendar.skyBlockDay);
    }

    while (next.isBefore(to)) {
      final event = HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.miriaContest,
        name: "Miria's Starlyn Contest",
        category: HypixelSkyBlockEventCategory.contest,
        startAt: next,
        endAt: next.add(HypixelSkyBlockCalendar.skyBlockDay),
      );
      if (event.endAt.isAfter(from)) result.add(event);
      next = next.add(HypixelSkyBlockCalendar.skyBlockDay);
    }

    return result;
  }
}
