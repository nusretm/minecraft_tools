import '../calendar/hypixel_skyblock_calendar.dart';
import '../mayor/hypixel_skyblock_election.dart';
import 'hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';

class HypixelSkyBlockMayorEventCalendar {
  const HypixelSkyBlockMayorEventCalendar(this.calendar);

  final HypixelSkyBlockCalendar calendar;

  List<HypixelSkyBlockEvent> events({
    required HypixelSkyBlockElection election,
    required DateTime from,
    required DateTime to,
  }) {
    final term = _termFor(election, from.toUtc());
    return eventsForMayor(
      mayor: election.mayor,
      termStart: term.start,
      termEnd: term.end,
      from: from,
      to: to,
    );
  }

  List<HypixelSkyBlockEvent> eventsForMayor({
    required HypixelSkyBlockMayor mayor,
    required DateTime termStart,
    required DateTime termEnd,
    required DateTime from,
    required DateTime to,
  }) {
    final start = from.toUtc();
    final end = to.toUtc();
    if (!end.isAfter(start)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final term = _MayorTerm(start: termStart.toUtc(), end: termEnd.toUtc());
    final result = <HypixelSkyBlockEvent>[];

    if (_hasPerk(mayor, 'Mythological Ritual')) {
      result.add(_termEvent(
        type: HypixelSkyBlockEventType.mythologicalRitual,
        name: 'Mythological Ritual',
        term: term,
      ));
    }

    if (_hasPerk(mayor, 'Chivalrous Carnival')) {
      result.add(_termEvent(
        type: HypixelSkyBlockEventType.carnival,
        name: 'Carnival',
        term: term,
      ));
    }

    if (_hasPerk(mayor, 'Stock Exchange')) {
      result.add(_termEvent(
        type: HypixelSkyBlockEventType.stonkExchange,
        name: 'Stonk Exchange',
        term: term,
      ));
    }

    if (_hasPerk(mayor, 'Fishing Festival')) {
      result.addAll(_fishingFestivals(term));
    }

    if (_hasPerk(mayor, 'Mining Fiesta')) {
      result.addAll(_miningFiestas(term));
    }

    result.removeWhere(
      (event) => !event.endAt.isAfter(start) || !event.startAt.isBefore(end),
    );
    result.sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      if (byTime != 0) return byTime;
      return a.type.index.compareTo(b.type.index);
    });
    return result;
  }


  List<HypixelSkyBlockEvent> eventsForEffectiveMayorState({
    required String effectiveMayor,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required DateTime from,
    required DateTime to,
  }) {
    final mayor = _effectiveMayor(effectiveMayor);
    if (mayor == null) return const [];

    // Treat the observed special-state window as the effective mayor term.
    // Term-wide perks are therefore active only inside the state window, while
    // scheduled events (Fishing Festival / Mining Fiesta) are allowed to finish
    // after the state ends if their own start time occurred while the state was
    // active.
    return eventsForMayor(
      mayor: mayor,
      termStart: activeFrom,
      termEnd: activeUntil,
      from: from,
      to: to,
    );
  }

  HypixelSkyBlockMayor? _effectiveMayor(String name) {
    final normalized = name.trim().toLowerCase();

    final perkName = switch (normalized) {
      'diana' => 'Mythological Ritual',
      'marina' => 'Fishing Festival',
      'cole' => 'Mining Fiesta',
      'foxy' => 'Chivalrous Carnival',
      'diaz' => 'Stock Exchange',
      _ => null,
    };
    if (perkName == null) return null;

    return HypixelSkyBlockMayor(
      key: normalized,
      name: name,
      perks: [
        HypixelSkyBlockPerk(
          name: perkName,
          description: '',
        ),
      ],
    );
  }

  bool _hasPerk(HypixelSkyBlockMayor mayor, String name) {
    if (mayor.perks.any((perk) => perk.name == name)) return true;
    return mayor.minister?.perk.name == name;
  }

  _MayorTerm _termFor(HypixelSkyBlockElection election, DateTime reference) {
    final electedFromYear = election.mayor.election?.year;
    if (electedFromYear != null && electedFromYear > 0) {
      final startYear = electedFromYear + 1;
      return _MayorTerm(
        start: calendar.toDateTime(year: startYear, month: 3, day: 27),
        end: calendar.toDateTime(year: startYear + 1, month: 3, day: 27),
      );
    }

    final skyDate = calendar.fromDateTime(reference);
    final thisYearBoundary = calendar.toDateTime(
      year: skyDate.year,
      month: 3,
      day: 27,
    );
    final startYear = reference.isBefore(thisYearBoundary)
        ? skyDate.year - 1
        : skyDate.year;
    return _MayorTerm(
      start: calendar.toDateTime(year: startYear, month: 3, day: 27),
      end: calendar.toDateTime(year: startYear + 1, month: 3, day: 27),
    );
  }

  HypixelSkyBlockEvent _termEvent({
    required HypixelSkyBlockEventType type,
    required String name,
    required _MayorTerm term,
  }) =>
      HypixelSkyBlockEvent(
        type: type,
        name: name,
        category: HypixelSkyBlockEventCategory.mayor,
        startAt: term.start,
        endAt: term.end,
      );

  List<HypixelSkyBlockEvent> _fishingFestivals(_MayorTerm term) {
    final result = <HypixelSkyBlockEvent>[];
    var cursor = calendar.fromDateTime(term.start);

    // The term starts on Late Spring 27. Start scanning from that month and
    // continue until the next election closes.
    for (var year = cursor.year; year <= cursor.year + 1; year++) {
      for (var month = 1; month <= 12; month++) {
        final eventStart = calendar.toDateTime(year: year, month: month, day: 1);
        final eventEnd = eventStart.add(const Duration(hours: 1)); // 3 SB days
        if (eventStart.isBefore(term.start) || !eventStart.isBefore(term.end)) {
          continue;
        }
        result.add(HypixelSkyBlockEvent(
          type: HypixelSkyBlockEventType.fishingFestival,
          name: 'Fishing Festival',
          category: HypixelSkyBlockEventCategory.mayor,
          startAt: eventStart,
          endAt: eventEnd,
        ));
      }
    }
    return result;
  }

  List<HypixelSkyBlockEvent> _miningFiestas(_MayorTerm term) {
    final result = <HypixelSkyBlockEvent>[];
    final termStartDate = calendar.fromDateTime(term.start);

    // Since 0.24.2, Mining Fiestas are spread across the 2nd, 4th, 6th,
    // 8th and 10th SkyBlock months. A mayor term runs from Late Spring 27 to
    // the following Late Spring 27, so the five occurrences within a term are
    // months 4/6/8/10 of the start year and month 2 of the following year.
    for (var year = termStartDate.year; year <= termStartDate.year + 1; year++) {
      for (final month in const [2, 4, 6, 8, 10]) {
        final eventStart = calendar.toDateTime(
          year: year,
          month: month,
          day: 1,
          hour: 18,
        );
        if (eventStart.isBefore(term.start) || !eventStart.isBefore(term.end)) {
          continue;
        }
        result.add(HypixelSkyBlockEvent(
          type: HypixelSkyBlockEventType.miningFiesta,
          name: 'Mining Fiesta',
          category: HypixelSkyBlockEventCategory.mayor,
          startAt: eventStart,
          endAt: eventStart.add(const Duration(minutes: 140)), // 7 SB days
        ));
      }
    }
    return result;
  }
}

class _MayorTerm {
  const _MayorTerm({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
