import '../calendar/hypixel_skyblock_calendar.dart';
import 'hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';
import 'hypixel_skyblock_event_phase.dart';
import 'hypixel_skyblock_zodiac_event_calendar.dart';

class HypixelSkyBlockEventCalendar {
  const HypixelSkyBlockEventCalendar(this.calendar);

  final HypixelSkyBlockCalendar calendar;

  List<HypixelSkyBlockEvent> events({
    required DateTime from,
    required DateTime to,
  }) {
    final start = from.toUtc();
    final end = to.toUtc();
    final firstDate = calendar.fromDateTime(start);
    final lastDate = calendar.fromDateTime(end.subtract(const Duration(microseconds: 1)));

    final result = <HypixelSkyBlockEvent>[];

    final zodiac = HypixelSkyBlockZodiacEventCalendar(calendar);

    for (var year = firstDate.year; year <= lastDate.year; year++) {
      result.addAll(_eventsForYear(year));
      final zodiacEvent = zodiac.eventForYear(year);
      if (zodiacEvent != null) result.add(zodiacEvent);
    }

    result.removeWhere(
      (event) => !event.endAt.isAfter(start) || !event.startAt.isBefore(end),
    );
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return result;
  }

  List<HypixelSkyBlockEvent> _eventsForYear(int year) {
    DateTime at(int month, int day) =>
        calendar.toDateTime(year: year, month: month, day: day);

    DateTime afterDays(DateTime start, int days) =>
        start.add(Duration(minutes: days * 20));

    final earlySummer = at(4, 1);
    final earlyWinter = at(10, 1);
    final spooky = at(8, 29);
    final electionOver = at(3, 27);
    final electionOpen = at(6, 27);
    final jerry = at(12, 24);
    final newYear = at(12, 29);

    return <HypixelSkyBlockEvent>[
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.electionOver,
        name: 'Election Over',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: electionOver,
        endAt: electionOver.add(const Duration(seconds: 1)),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.travelingZoo,
        name: 'Traveling Zoo',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: earlySummer,
        endAt: afterDays(earlySummer, 3),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.electionBoothOpens,
        name: 'Election Booth Opens',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: electionOpen,
        endAt: electionOpen.add(const Duration(seconds: 1)),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.spookyFestival,
        name: 'Spooky Festival',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: spooky,
        endAt: afterDays(spooky, 3),
        phases: [
          HypixelSkyBlockEventPhase(
            type: HypixelSkyBlockEventPhaseType.activity,
            name: 'Spooky Fishing / Fear Mongerer',
            startAt: spooky.subtract(const Duration(hours: 1)),
            endAt: afterDays(spooky, 3).add(const Duration(hours: 1)),
          ),
          HypixelSkyBlockEventPhase(
            type: HypixelSkyBlockEventPhaseType.event,
            name: 'Spooky Festival scoring',
            startAt: spooky,
            endAt: afterDays(spooky, 3),
          ),
        ],
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.travelingZoo,
        name: 'Traveling Zoo',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: earlyWinter,
        endAt: afterDays(earlyWinter, 3),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.seasonOfJerry,
        name: 'Season of Jerry',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: jerry,
        endAt: afterDays(jerry, 3),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.defendJerrysWorkshop,
        name: "Defend Jerry's Workshop",
        category: HypixelSkyBlockEventCategory.calendar,
        parentType: HypixelSkyBlockEventType.seasonOfJerry,
        startAt: jerry,
        endAt: afterDays(jerry, 3),
      ),
      HypixelSkyBlockEvent(
        type: HypixelSkyBlockEventType.newYearCelebration,
        name: 'New Year Celebration',
        category: HypixelSkyBlockEventCategory.calendar,
        startAt: newYear,
        endAt: afterDays(newYear, 3),
      ),
    ];
  }
}
