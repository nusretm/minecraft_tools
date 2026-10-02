import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  const calendar = HypixelSkyBlockCalendar();
  const mayorEvents = HypixelSkyBlockMayorEventCalendar(calendar);

  test('Jerry Marina state can schedule a Fishing Festival that outlives the state', () {
    final festivalStart = calendar.toDateTime(year: 600, month: 6, day: 1);
    final activeFrom = festivalStart.subtract(const Duration(hours: 5, minutes: 50));
    final activeUntil = festivalStart.add(const Duration(minutes: 10));

    final events = mayorEvents.eventsForEffectiveMayorState(
      effectiveMayor: 'Marina',
      activeFrom: activeFrom,
      activeUntil: activeUntil,
      from: festivalStart.add(const Duration(minutes: 20)),
      to: festivalStart.add(const Duration(minutes: 40)),
    );

    expect(events, hasLength(1));
    expect(events.single.type, HypixelSkyBlockEventType.fishingFestival);
    expect(events.single.startAt, festivalStart);
    expect(events.single.endAt, festivalStart.add(const Duration(hours: 1)));
    expect(events.single.endAt.isAfter(activeUntil), isTrue);
  });

  test('Jerry Diana state clips term-wide Mythological Ritual to the observed slot', () {
    final activeFrom = calendar.toDateTime(year: 600, month: 5, day: 10);
    final activeUntil = activeFrom.add(const Duration(hours: 6));

    final events = mayorEvents.eventsForEffectiveMayorState(
      effectiveMayor: 'Diana',
      activeFrom: activeFrom,
      activeUntil: activeUntil,
      from: activeFrom,
      to: activeUntil,
    );

    expect(events, hasLength(1));
    expect(events.single.type, HypixelSkyBlockEventType.mythologicalRitual);
    expect(events.single.startAt, activeFrom);
    expect(events.single.endAt, activeUntil);
  });

  test('non event-producing effective mayor yields no calendar events', () {
    final start = calendar.toDateTime(year: 600, month: 5, day: 10);
    final events = mayorEvents.eventsForEffectiveMayorState(
      effectiveMayor: 'Aatrox',
      activeFrom: start,
      activeUntil: start.add(const Duration(hours: 6)),
      from: start,
      to: start.add(const Duration(hours: 6)),
    );

    expect(events, isEmpty);
  });
}
