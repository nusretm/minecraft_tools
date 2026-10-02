import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('Jerry Perkpocalypse observation is aligned to a six-hour slot', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_special_history_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);

      final snapshot = HypixelSkyBlockElection(
        lastUpdated: DateTime.utc(2026, 10, 1),
        mayor: const HypixelSkyBlockMayor(
          key: 'jerry',
          name: 'Jerry',
          perks: [
            HypixelSkyBlockPerk(name: 'Perkpocalypse', description: 'x'),
          ],
          election: HypixelSkyBlockElectionRound(year: 516, candidates: []),
        ),
        current: const HypixelSkyBlockElectionRound(year: 517, candidates: []),
      );
      await history.observeElection(snapshot);

      final term = (await history.mayorForYear(517))!;
      final observedAt = term.termStartAt.add(const Duration(hours: 7, minutes: 30));
      final state = await history.observeJerryPerkpocalypse(
        sourceTermYear: 517,
        effectiveMayor: 'Cole',
        observedAt: observedAt,
      );

      expect(state.kind, HypixelSkyBlockSpecialStateKind.jerryPerkpocalypse);
      expect(state.effectiveMayor, 'Cole');
      expect(state.activeFrom, term.termStartAt.add(const Duration(hours: 6)));
      expect(state.activeUntil, term.termStartAt.add(const Duration(hours: 12)));
      expect(await store.historyFile('skyblock_special_states').exists(), isTrue);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('scheduled mayor event can outlive its source mayor term', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_scheduled_history_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);

      final termEnd = calendar.toDateTime(year: 518, month: 3, day: 27);
      final event = HypixelSkyBlockScheduledEventHistoryEntry(
        id: 'foxy:517:extra:mining-fiesta:1',
        sourceMayor: 'Foxy',
        sourceTermYear: 517,
        type: HypixelSkyBlockEventType.miningFiesta,
        name: 'Mining Fiesta',
        startAt: termEnd.add(const Duration(minutes: 20)),
        endAt: termEnd.add(const Duration(hours: 2, minutes: 40)),
        firstObservedAt: termEnd.subtract(const Duration(hours: 1)),
        lastObservedAt: termEnd.subtract(const Duration(hours: 1)),
        metadata: const {'sourcePerk': 'Extra Event'},
      );

      await history.observeScheduledEvent(event);
      final found = await history.scheduledEventsOverlapping(
        from: termEnd,
        to: termEnd.add(const Duration(hours: 3)),
      );

      expect(found, hasLength(1));
      expect(found.single.sourceMayor, 'Foxy');
      expect(found.single.startAt.isAfter(termEnd), isTrue);
      expect(await store.historyFile('skyblock_scheduled_events').exists(), isTrue);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('Foxy Extra Event selection is observed from perk description', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_foxy_history_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);

      final snapshot = HypixelSkyBlockElection(
        lastUpdated: DateTime.utc(2026, 10, 1),
        mayor: const HypixelSkyBlockMayor(
          key: 'foxy',
          name: 'Foxy',
          perks: [
            HypixelSkyBlockPerk(
              name: 'Extra Event',
              description: 'Schedules an extra Mining Fiesta during the year.',
            ),
          ],
          election: HypixelSkyBlockElectionRound(year: 516, candidates: []),
        ),
        current: const HypixelSkyBlockElectionRound(year: 517, candidates: []),
      );

      await history.observeElection(snapshot);
      final states = await history.specialStates();
      final state = states.singleWhere(
        (e) => e.kind == HypixelSkyBlockSpecialStateKind.foxyExtraEventSelection,
      );

      expect(state.sourceMayor, 'Foxy');
      expect(state.sourceTermYear, 517);
      expect(state.metadata['selectedEventType'], HypixelSkyBlockEventType.miningFiesta.name);
      expect(state.metadata['selectedEventName'], 'Mining Fiesta');
      expect(state.metadata['scheduleKnown'], isFalse);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('Foxy Extra Event schedule can be resolved later without losing selection history', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_foxy_resolve_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);

      final snapshot = HypixelSkyBlockElection(
        lastUpdated: DateTime.utc(2026, 10, 1),
        mayor: const HypixelSkyBlockMayor(
          key: 'foxy',
          name: 'Foxy',
          perks: [
            HypixelSkyBlockPerk(
              name: 'Extra Event',
              description: 'Schedules an extra Spooky Festival during the year.',
            ),
          ],
          election: HypixelSkyBlockElectionRound(year: 516, candidates: []),
        ),
        current: const HypixelSkyBlockElectionRound(year: 517, candidates: []),
      );
      await history.observeElection(snapshot);

      expect(await history.unresolvedFoxyExtraEvents(), hasLength(1));
      final start = calendar.toDateTime(year: 517, month: 8, day: 10);
      final end = start.add(const Duration(hours: 1));
      final scheduled = await history.resolveFoxyExtraEventSchedule(
        sourceTermYear: 517,
        startAt: start,
        endAt: end,
        observedAt: DateTime.utc(2026, 10, 1, 12),
      );

      expect(scheduled.type, HypixelSkyBlockEventType.spookyFestival);
      expect(await history.unresolvedFoxyExtraEvents(), isEmpty);
      final states = await history.specialStates();
      final selection = states.singleWhere(
        (e) => e.kind == HypixelSkyBlockSpecialStateKind.foxyExtraEventSelection,
      );
      expect(selection.metadata['scheduleKnown'], isTrue);
      expect(selection.metadata['scheduledEventId'], scheduled.id);

      final event = scheduled.toEvent();
      expect(event.phases, hasLength(2));
      expect(event.phases.first.startAt, start.subtract(const Duration(hours: 1)));
      expect(event.phases.first.endAt, end.add(const Duration(hours: 1)));
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('carryover effects are persisted separately from calendar events', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_carryover_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);
      final start = DateTime.utc(2026, 10, 10);
      final end = start.add(const Duration(hours: 8));

      await history.observeCarryoverEffect(
        id: 'derpy:example:carryover',
        sourceMayor: 'Derpy',
        sourceTermYear: 517,
        name: 'Observed carryover effect',
        activeFrom: start,
        activeUntil: end,
        observedAt: start,
        metadata: const {'verified': true},
      );

      expect(await history.carryoverEffects(), hasLength(1));
      expect(
        await history.carryoverEffects(at: start.add(const Duration(hours: 1))),
        hasLength(1),
      );
      expect(await history.carryoverEffects(at: end), isEmpty);
      expect(await history.scheduledEvents(), isEmpty);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

}
