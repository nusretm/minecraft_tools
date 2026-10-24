import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  final api = HypixelApi();
  const calendar = HypixelSkyBlockCalendar();

  test('Year 516 Spooky Festival starts Autumn 29 and lasts 3 SB days', () {
    final expected = calendar.toDateTime(year: 516, month: 8, day: 29);
    final events = api.skyBlock.scheduledEvents(
      from: expected.subtract(const Duration(minutes: 1)),
      to: expected.add(const Duration(hours: 2)),
    );

    final event = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.spookyFestival,
    );
    expect(event.startAt, expected);
    expect(event.duration, const Duration(hours: 1));
  });

  test('Season of Jerry represents all of Late Winter, not the three-day festival', () {
    final start = calendar.toDateTime(year: 521, month: 12, day: 1);
    final nextYear = calendar.toDateTime(year: 522, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(
      from: start,
      to: nextYear,
    );

    final season = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.seasonOfJerry,
    );
    expect(season.startAt, start);
    expect(season.endAt, nextYear);
    expect(season.duration, const Duration(hours: 10, minutes: 20));
    expect(season.isActiveAt(start), isTrue);
    expect(season.isActiveAt(nextYear), isFalse);
  });

  test("Defend Jerry's Workshop spans Late Winter 25 and 26, under Season of Jerry", () {
    final start = calendar.toDateTime(year: 521, month: 12, day: 25);
    final end = calendar.toDateTime(year: 521, month: 12, day: 27);
    final events = api.skyBlock.scheduledEvents(
      from: start.subtract(const Duration(minutes: 1)),
      to: end.add(const Duration(minutes: 1)),
    );

    final defend = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.defendJerrysWorkshop,
    );
    expect(defend.parentType, HypixelSkyBlockEventType.seasonOfJerry);
    expect(defend.startAt, start);
    expect(defend.endAt, end);
    expect(defend.duration, const Duration(minutes: 40));
    expect(defend.isActiveAt(start), isTrue);
    expect(defend.isActiveAt(end), isFalse);
    expect(defend.isActiveAt(start.subtract(const Duration(microseconds: 1))), isFalse);
  });

  test('New Year Celebration spans the final two SkyBlock days, 30 and 31', () {
    final start = calendar.toDateTime(year: 521, month: 12, day: 30);
    final end = calendar.toDateTime(year: 522, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(
      from: start.subtract(const Duration(minutes: 1)),
      to: end.add(const Duration(minutes: 1)),
    );

    final celebration = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.newYearCelebration,
    );
    expect(celebration.startAt, start);
    expect(celebration.endAt, end);
    expect(celebration.duration, const Duration(minutes: 40));
    expect(celebration.isActiveAt(start), isTrue);
    expect(celebration.isActiveAt(end), isFalse);
  });

  test('Late Winter events respect half-open calendar query bounds', () {
    final defendStart = calendar.toDateTime(year: 521, month: 12, day: 25);
    final defendEnd = calendar.toDateTime(year: 521, month: 12, day: 27);
    final newYearStart = calendar.toDateTime(year: 521, month: 12, day: 30);
    final newYearEnd = calendar.toDateTime(year: 522, month: 1, day: 1);

    final beforeDefend = api.skyBlock.scheduledEvents(
      from: defendStart.subtract(const Duration(minutes: 20)),
      to: defendStart,
    );
    final afterDefend = api.skyBlock.scheduledEvents(
      from: defendEnd,
      to: newYearStart,
    );
    final afterNewYear = api.skyBlock.scheduledEvents(
      from: newYearEnd,
      to: newYearEnd.add(const Duration(minutes: 20)),
    );

    expect(beforeDefend.where((e) => e.type == HypixelSkyBlockEventType.defendJerrysWorkshop), isEmpty);
    expect(afterDefend.where((e) => e.type == HypixelSkyBlockEventType.defendJerrysWorkshop), isEmpty);
    expect(afterNewYear.where((e) => e.type == HypixelSkyBlockEventType.newYearCelebration), isEmpty);
    expect(afterNewYear.where((e) => e.type == HypixelSkyBlockEventType.seasonOfJerry), isEmpty);
  });

  test('Traveling Zoo occurs twice each year', () {
    final start = calendar.toDateTime(year: 516, month: 1, day: 1);
    final end = calendar.toDateTime(year: 517, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(from: start, to: end);
    final zoo = events
        .where((e) => e.type == HypixelSkyBlockEventType.travelingZoo)
        .toList();
    expect(zoo, hasLength(2));
  });
}
