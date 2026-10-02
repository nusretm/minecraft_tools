import '../../history/hypixel_data_store.dart';
import '../calendar/hypixel_skyblock_calendar.dart';
import '../events/hypixel_skyblock_event_type.dart';
import '../mayor/hypixel_skyblock_election.dart';
import 'hypixel_skyblock_history_models.dart';
import 'hypixel_skyblock_bingo_history_models.dart';
import '../bingo/hypixel_skyblock_bingo.dart';
import 'hypixel_skyblock_special_history_models.dart';
import '../news/hypixel_skyblock_news.dart';

class HypixelSkyBlockHistory {
  HypixelSkyBlockHistory({
    required HypixelDataStore store,
    required HypixelSkyBlockCalendar calendar,
  })  : _store = store,
        _calendar = calendar;

  final HypixelDataStore _store;
  final HypixelSkyBlockCalendar _calendar;

  Future<void> observeElection(HypixelSkyBlockElection snapshot) async {
    final now = DateTime.now().toUtc();
    await _observeMayor(snapshot, now);
    await _observeFoxyExtraEvent(snapshot, now);
    if (snapshot.mayor.election case final previous?) {
      await _observeElectionRound(previous, snapshot.lastUpdated, now);
    }
    if (snapshot.current case final current?) {
      await _observeElectionRound(current, snapshot.lastUpdated, now);
    }
  }

  Future<void> observeNews(
    List<HypixelSkyBlockNewsItem> items, {
    DateTime? observedAt,
  }) async {
    final observed = (observedAt ?? DateTime.now()).toUtc();
    final existing = await news();
    final byId = <String, HypixelSkyBlockNewsHistoryEntry>{
      for (final entry in existing) entry.item.id: entry,
    };

    final currentIds = <String>{};
    final currentEntries = <HypixelSkyBlockNewsHistoryEntry>[];
    for (final item in items) {
      currentIds.add(item.id);
      final previous = byId[item.id];
      currentEntries.add(HypixelSkyBlockNewsHistoryEntry(
        item: item,
        firstObservedAt: previous?.firstObservedAt ?? observed,
        lastObservedAt: observed,
      ));
    }

    // Keep the official endpoint order for the current feed, then append news
    // that has dropped out of the endpoint but remains part of our history.
    final entries = <HypixelSkyBlockNewsHistoryEntry>[
      ...currentEntries,
      ...existing.where((entry) => !currentIds.contains(entry.item.id)),
    ];
    await _store.writeHistory('skyblock_news', {
      'version': 1,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
  }

  Future<List<HypixelSkyBlockNewsHistoryEntry>> news() async {
    final raw = await _store.readHistory('skyblock_news');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((entry) => HypixelSkyBlockNewsHistoryEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    return entries;
  }

  Future<void> observePlayerBingo({
    required String uuid,
    required HypixelSkyBlockPlayerBingoData data,
    DateTime? observedAt,
  }) async {
    final canonicalUuid = _canonicalUuid(uuid);
    final observed = (observedAt ?? DateTime.now()).toUtc();
    final entries = await bingoHistory(uuid: canonicalUuid);
    final byEventId = <int, HypixelSkyBlockBingoHistoryEntry>{
      for (final entry in entries) entry.eventId: entry,
    };

    for (final event in data.events) {
      final existing = byEventId[event.key];
      byEventId[event.key] = HypixelSkyBlockBingoHistoryEntry(
        uuid: canonicalUuid,
        eventId: event.key,
        points: event.points,
        completedGoals: event.completedGoals,
        firstObservedAt: existing?.firstObservedAt ?? observed,
        lastObservedAt: observed,
      );
    }

    final allRaw = await _store.readHistory('skyblock_bingo_players');
    final allEntries = ((allRaw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockBingoHistoryEntry.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .where((entry) => entry.uuid != canonicalUuid)
        .toList();
    allEntries.addAll(byEventId.values);
    allEntries.sort((a, b) {
      final byUuid = a.uuid.compareTo(b.uuid);
      if (byUuid != 0) return byUuid;
      return a.eventId.compareTo(b.eventId);
    });

    await _store.writeHistory('skyblock_bingo_players', {
      'version': 1,
      'entries': allEntries.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<HypixelSkyBlockBingoHistoryEntry>> bingoHistory({
    required String uuid,
  }) async {
    final canonicalUuid = _canonicalUuid(uuid);
    final raw = await _store.readHistory('skyblock_bingo_players');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockBingoHistoryEntry.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .where((entry) => entry.uuid == canonicalUuid)
        .toList();
    entries.sort((a, b) => a.eventId.compareTo(b.eventId));
    return entries;
  }

  Future<HypixelSkyBlockBingoStats> bingoStats({
    required String uuid,
  }) async {
    final canonicalUuid = _canonicalUuid(uuid);
    return HypixelSkyBlockBingoStats(
      uuid: canonicalUuid,
      entries: List.unmodifiable(await bingoHistory(uuid: canonicalUuid)),
    );
  }

  Future<List<HypixelSkyBlockMayorHistoryEntry>> mayors() async {
    final raw = await _store.readHistory('skyblock_mayors');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockMayorHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    entries.sort((a, b) => a.termYear.compareTo(b.termYear));
    return entries;
  }

  Future<List<HypixelSkyBlockElectionHistoryEntry>> elections() async {
    final raw = await _store.readHistory('skyblock_elections');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockElectionHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    entries.sort((a, b) => a.year.compareTo(b.year));
    return entries;
  }

  Future<HypixelSkyBlockMayorHistoryEntry?> mayorForYear(int termYear) async {
    for (final entry in await mayors()) {
      if (entry.termYear == termYear) return entry;
    }
    return null;
  }

  Future<HypixelSkyBlockMayorHistoryEntry?> mayorAt(DateTime instant) async {
    final utc = instant.toUtc();
    for (final entry in await mayors()) {
      if (!utc.isBefore(entry.termStartAt) && utc.isBefore(entry.termEndAt)) {
        return entry;
      }
    }
    return null;
  }

  Future<HypixelSkyBlockMayorStats> mayorStats(String mayorName) async {
    final normalized = mayorName.toLowerCase();
    final years = (await mayors())
        .where((e) => e.mayor.name.toLowerCase() == normalized)
        .map((e) => e.termYear)
        .toList()
      ..sort();
    return HypixelSkyBlockMayorStats(
      mayorName: mayorName,
      timesElected: years.length,
      termYears: List.unmodifiable(years),
    );
  }

  Future<HypixelSkyBlockPerkStats> perkStats(String perkName) async {
    final normalized = perkName.toLowerCase();
    final observations = <HypixelSkyBlockPerkObservation>[];
    for (final entry in await mayors()) {
      for (final perk in entry.mayor.perks) {
        if (perk.name.toLowerCase() == normalized) {
          observations.add(HypixelSkyBlockPerkObservation(
            perkName: perk.name,
            termYear: entry.termYear,
            mayorName: entry.mayor.name,
            source: HypixelSkyBlockPerkSource.mayor,
          ));
        }
      }
      final minister = entry.mayor.minister;
      if (minister != null && minister.perk.name.toLowerCase() == normalized) {
        observations.add(HypixelSkyBlockPerkObservation(
          perkName: minister.perk.name,
          termYear: entry.termYear,
          mayorName: entry.mayor.name,
          source: HypixelSkyBlockPerkSource.minister,
        ));
      }
    }
    observations.sort((a, b) => a.termYear.compareTo(b.termYear));
    return HypixelSkyBlockPerkStats(
      perkName: perkName,
      observations: List.unmodifiable(observations),
    );
  }

  Future<List<HypixelSkyBlockMayorHistoryEntry>> mayorsOverlapping({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = from.toUtc();
    final end = to.toUtc();
    return (await mayors())
        .where((e) => e.termEndAt.isAfter(start) && e.termStartAt.isBefore(end))
        .toList(growable: false);
  }


  Future<void> observeSpecialState(HypixelSkyBlockSpecialState state) async {
    final entries = await specialStates();
    final index = entries.indexWhere((e) => e.id == state.id);
    if (index < 0) {
      entries.add(state);
    } else {
      final existing = entries[index];
      entries[index] = HypixelSkyBlockSpecialState(
        id: state.id,
        kind: state.kind,
        sourceMayor: state.sourceMayor,
        sourceTermYear: state.sourceTermYear,
        name: state.name,
        activeFrom: state.activeFrom,
        activeUntil: state.activeUntil,
        firstObservedAt: existing.firstObservedAt,
        lastObservedAt: state.lastObservedAt,
        effectiveMayor: state.effectiveMayor,
        metadata: state.metadata,
      );
    }
    entries.sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
    await _store.writeHistory('skyblock_special_states', {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<HypixelSkyBlockSpecialState>> specialStates() async {
    final raw = await _store.readHistory('skyblock_special_states');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockSpecialState.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    entries.sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
    return entries;
  }

  Future<List<HypixelSkyBlockSpecialState>> specialStatesAt(DateTime instant) async {
    final utc = instant.toUtc();
    return (await specialStates()).where((e) => e.isActiveAt(utc)).toList(growable: false);
  }

  Future<HypixelSkyBlockSpecialState> observeJerryPerkpocalypse({
    required int sourceTermYear,
    required String effectiveMayor,
    DateTime? observedAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    final term = await mayorForYear(sourceTermYear);
    if (term == null || term.mayor.name.toLowerCase() != 'jerry') {
      throw StateError('Year $sourceTermYear is not a recorded Jerry mayor term.');
    }
    final observed = (observedAt ?? DateTime.now()).toUtc();
    if (observed.isBefore(term.termStartAt) || !observed.isBefore(term.termEndAt)) {
      throw ArgumentError.value(observedAt, 'observedAt', 'must be inside the Jerry mayor term');
    }
    const slot = Duration(hours: 6);
    final elapsedMs = observed.difference(term.termStartAt).inMilliseconds;
    final slotIndex = elapsedMs ~/ slot.inMilliseconds;
    final activeFrom = term.termStartAt.add(Duration(milliseconds: slotIndex * slot.inMilliseconds));
    final rawUntil = activeFrom.add(slot);
    final activeUntil = rawUntil.isAfter(term.termEndAt) ? term.termEndAt : rawUntil;
    final id = 'jerry:$sourceTermYear:$slotIndex';
    HypixelSkyBlockSpecialState? existing;
    for (final item in await specialStates()) {
      if (item.id == id) {
        existing = item;
        break;
      }
    }
    final state = HypixelSkyBlockSpecialState(
      id: id,
      kind: HypixelSkyBlockSpecialStateKind.jerryPerkpocalypse,
      sourceMayor: 'Jerry',
      sourceTermYear: sourceTermYear,
      name: 'Perkpocalypse: $effectiveMayor',
      effectiveMayor: effectiveMayor,
      activeFrom: activeFrom,
      activeUntil: activeUntil,
      firstObservedAt: existing?.firstObservedAt ?? observed,
      lastObservedAt: observed,
      metadata: metadata,
    );
    await observeSpecialState(state);
    return state;
  }

  Future<void> observeScheduledEvent(HypixelSkyBlockScheduledEventHistoryEntry event) async {
    final entries = await scheduledEvents();
    final index = entries.indexWhere((e) => e.id == event.id);
    if (index < 0) {
      entries.add(event);
    } else {
      final existing = entries[index];
      entries[index] = HypixelSkyBlockScheduledEventHistoryEntry(
        id: event.id,
        sourceMayor: event.sourceMayor,
        sourceTermYear: event.sourceTermYear,
        type: event.type,
        name: event.name,
        startAt: event.startAt,
        endAt: event.endAt,
        firstObservedAt: existing.firstObservedAt,
        lastObservedAt: event.lastObservedAt,
        metadata: event.metadata,
      );
    }
    entries.sort((a, b) => a.startAt.compareTo(b.startAt));
    await _store.writeHistory('skyblock_scheduled_events', {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<HypixelSkyBlockScheduledEventHistoryEntry>> scheduledEvents() async {
    final raw = await _store.readHistory('skyblock_scheduled_events');
    final entries = ((raw?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HypixelSkyBlockScheduledEventHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    entries.sort((a, b) => a.startAt.compareTo(b.startAt));
    return entries;
  }

  Future<List<HypixelSkyBlockScheduledEventHistoryEntry>> scheduledEventsOverlapping({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = from.toUtc();
    final end = to.toUtc();
    return (await scheduledEvents())
        .where((e) => e.endAt.isAfter(start) && e.startAt.isBefore(end))
        .toList(growable: false);
  }


  Future<List<HypixelSkyBlockSpecialState>> unresolvedFoxyExtraEvents() async {
    return (await specialStates())
        .where((state) =>
            state.kind == HypixelSkyBlockSpecialStateKind.foxyExtraEventSelection &&
            state.metadata['scheduleKnown'] != true)
        .toList(growable: false);
  }

  Future<HypixelSkyBlockScheduledEventHistoryEntry> resolveFoxyExtraEventSchedule({
    required int sourceTermYear,
    required DateTime startAt,
    required DateTime endAt,
    DateTime? observedAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    final states = await specialStates();
    HypixelSkyBlockSpecialState? selection;
    for (final state in states) {
      if (state.kind == HypixelSkyBlockSpecialStateKind.foxyExtraEventSelection &&
          state.sourceTermYear == sourceTermYear) {
        selection = state;
        break;
      }
    }
    if (selection == null) {
      throw StateError('No recorded Foxy Extra Event selection for term year $sourceTermYear.');
    }

    final typeName = selection.metadata['selectedEventType'] as String?;
    final eventName = selection.metadata['selectedEventName'] as String?;
    if (typeName == null || eventName == null) {
      throw StateError('Recorded Foxy Extra Event selection is incomplete.');
    }

    HypixelSkyBlockEventType type;
    try {
      type = HypixelSkyBlockEventType.values.byName(typeName);
    } on ArgumentError {
      throw StateError('Unknown Foxy Extra Event type: $typeName');
    }

    final start = startAt.toUtc();
    final end = endAt.toUtc();
    if (!end.isAfter(start)) {
      throw ArgumentError.value(endAt, 'endAt', 'must be after startAt');
    }

    final observed = (observedAt ?? DateTime.now()).toUtc();
    final scheduledEventId = 'foxy:$sourceTermYear:extra-event:schedule';
    HypixelSkyBlockScheduledEventHistoryEntry? existingScheduled;
    for (final event in await scheduledEvents()) {
      if (event.id == scheduledEventId) {
        existingScheduled = event;
        break;
      }
    }

    final scheduled = HypixelSkyBlockScheduledEventHistoryEntry(
      id: scheduledEventId,
      sourceMayor: 'Foxy',
      sourceTermYear: sourceTermYear,
      type: type,
      name: eventName,
      startAt: start,
      endAt: end,
      firstObservedAt: existingScheduled?.firstObservedAt ?? observed,
      lastObservedAt: observed,
      metadata: {
        'sourcePerk': 'Extra Event',
        'selectionStateId': selection.id,
        ...metadata,
      },
    );
    await observeScheduledEvent(scheduled);

    final updatedSelection = HypixelSkyBlockSpecialState(
      id: selection.id,
      kind: selection.kind,
      sourceMayor: selection.sourceMayor,
      sourceTermYear: selection.sourceTermYear,
      name: selection.name,
      activeFrom: selection.activeFrom,
      activeUntil: selection.activeUntil,
      firstObservedAt: selection.firstObservedAt,
      lastObservedAt: observed,
      effectiveMayor: selection.effectiveMayor,
      metadata: {
        ...selection.metadata,
        'scheduleKnown': true,
        'scheduledEventId': scheduledEventId,
        'scheduledStartAt': start.millisecondsSinceEpoch,
        'scheduledEndAt': end.millisecondsSinceEpoch,
      },
    );
    await observeSpecialState(updatedSelection);
    return scheduled;
  }

  Future<HypixelSkyBlockSpecialState> observeCarryoverEffect({
    required String id,
    required String sourceMayor,
    required int sourceTermYear,
    required String name,
    required DateTime activeFrom,
    required DateTime activeUntil,
    DateTime? observedAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    final start = activeFrom.toUtc();
    final end = activeUntil.toUtc();
    if (!end.isAfter(start)) {
      throw ArgumentError.value(activeUntil, 'activeUntil', 'must be after activeFrom');
    }
    final observed = (observedAt ?? DateTime.now()).toUtc();
    HypixelSkyBlockSpecialState? existing;
    for (final state in await specialStates()) {
      if (state.id == id) {
        existing = state;
        break;
      }
    }
    final state = HypixelSkyBlockSpecialState(
      id: id,
      kind: HypixelSkyBlockSpecialStateKind.carryoverEffect,
      sourceMayor: sourceMayor,
      sourceTermYear: sourceTermYear,
      name: name,
      activeFrom: start,
      activeUntil: end,
      firstObservedAt: existing?.firstObservedAt ?? observed,
      lastObservedAt: observed,
      metadata: metadata,
    );
    await observeSpecialState(state);
    return state;
  }

  Future<List<HypixelSkyBlockSpecialState>> carryoverEffects({DateTime? at}) async {
    final effects = (await specialStates())
        .where((state) => state.kind == HypixelSkyBlockSpecialStateKind.carryoverEffect);
    if (at == null) return effects.toList(growable: false);
    final utc = at.toUtc();
    return effects.where((state) => state.isActiveAt(utc)).toList(growable: false);
  }

  Future<void> _observeFoxyExtraEvent(
    HypixelSkyBlockElection snapshot,
    DateTime observedAt,
  ) async {
    HypixelSkyBlockPerk? perk;
    String? sourceRole;

    if (snapshot.mayor.name.toLowerCase() == 'foxy') {
      for (final item in snapshot.mayor.perks) {
        if (item.name.toLowerCase() == 'extra event') {
          perk = item;
          sourceRole = 'mayor';
          break;
        }
      }
    }

    final minister = snapshot.mayor.minister;
    if (perk == null &&
        minister != null &&
        minister.name.toLowerCase() == 'foxy' &&
        minister.perk.name.toLowerCase() == 'extra event') {
      perk = minister.perk;
      sourceRole = 'minister';
    }

    if (perk == null) return;

    final selected = _parseFoxyExtraEvent(perk.description);
    if (selected == null) return;

    final termYear = _termYearForSnapshot(snapshot, observedAt);
    final termStartAt = _calendar.toDateTime(year: termYear, month: 3, day: 27);
    final termEndAt = _calendar.toDateTime(year: termYear + 1, month: 3, day: 27);
    final id = 'foxy:$termYear:extra-event';

    HypixelSkyBlockSpecialState? existing;
    for (final item in await specialStates()) {
      if (item.id == id) {
        existing = item;
        break;
      }
    }

    await observeSpecialState(HypixelSkyBlockSpecialState(
      id: id,
      kind: HypixelSkyBlockSpecialStateKind.foxyExtraEventSelection,
      sourceMayor: 'Foxy',
      sourceTermYear: termYear,
      name: 'Foxy Extra Event: ${selected.name}',
      activeFrom: termStartAt,
      activeUntil: termEndAt,
      firstObservedAt: existing?.firstObservedAt ?? observedAt,
      lastObservedAt: observedAt,
      metadata: {
        'sourcePerk': 'Extra Event',
        'sourceRole': sourceRole,
        'selectedEventType': selected.type.name,
        'selectedEventName': selected.name,
        'description': perk.description,
        'scheduleKnown': false,
      },
    ));
  }

  _FoxyExtraEventSelection? _parseFoxyExtraEvent(String description) {
    final normalized = description.toLowerCase();
    if (normalized.contains('spooky festival')) {
      return const _FoxyExtraEventSelection(
        type: HypixelSkyBlockEventType.spookyFestival,
        name: 'Spooky Festival',
      );
    }
    if (normalized.contains('mining fiesta')) {
      return const _FoxyExtraEventSelection(
        type: HypixelSkyBlockEventType.miningFiesta,
        name: 'Mining Fiesta',
      );
    }
    if (normalized.contains('fishing festival')) {
      return const _FoxyExtraEventSelection(
        type: HypixelSkyBlockEventType.fishingFestival,
        name: 'Fishing Festival',
      );
    }
    return null;
  }

  int _termYearForSnapshot(
    HypixelSkyBlockElection snapshot,
    DateTime observedAt,
  ) {
    final electedInYear = snapshot.mayor.election?.year;
    final skyDate = _calendar.fromDateTime(observedAt);
    final currentYearBoundary = _calendar.toDateTime(
      year: skyDate.year,
      month: 3,
      day: 27,
    );
    final inferredTermYear = observedAt.isBefore(currentYearBoundary)
        ? skyDate.year - 1
        : skyDate.year;
    return electedInYear != null && electedInYear > 0
        ? electedInYear + 1
        : inferredTermYear;
  }

  Future<void> _observeMayor(HypixelSkyBlockElection snapshot, DateTime observedAt) async {
    final termYear = _termYearForSnapshot(snapshot, observedAt);
    final termStartAt = _calendar.toDateTime(year: termYear, month: 3, day: 27);
    final termEndAt = _calendar.toDateTime(year: termYear + 1, month: 3, day: 27);

    final entries = await mayors();
    final index = entries.indexWhere((e) => e.termYear == termYear);
    final firstObservedAt = index < 0 ? observedAt : entries[index].firstObservedAt;
    final entry = HypixelSkyBlockMayorHistoryEntry(
      termYear: termYear,
      mayor: snapshot.mayor,
      termStartAt: termStartAt,
      termEndAt: termEndAt,
      firstObservedAt: firstObservedAt,
      lastObservedAt: observedAt,
      sourceLastUpdated: snapshot.lastUpdated,
    );
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    entries.sort((a, b) => a.termYear.compareTo(b.termYear));
    await _store.writeHistory('skyblock_mayors', {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _observeElectionRound(
    HypixelSkyBlockElectionRound round,
    DateTime sourceLastUpdated,
    DateTime observedAt,
  ) async {
    if (round.year <= 0) return;
    final entries = await elections();
    final index = entries.indexWhere((e) => e.year == round.year);
    final firstObservedAt = index < 0 ? observedAt : entries[index].firstObservedAt;
    final entry = HypixelSkyBlockElectionHistoryEntry(
      year: round.year,
      election: round,
      firstObservedAt: firstObservedAt,
      lastObservedAt: observedAt,
      sourceLastUpdated: sourceLastUpdated,
    );
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    entries.sort((a, b) => a.year.compareTo(b.year));
    await _store.writeHistory('skyblock_elections', {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  static String _canonicalUuid(String value) =>
      value.replaceAll('-', '').trim().toLowerCase();
}

class _FoxyExtraEventSelection {
  const _FoxyExtraEventSelection({required this.type, required this.name});
  final HypixelSkyBlockEventType type;
  final String name;
}
