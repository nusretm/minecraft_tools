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

  test("Defend Jerry's Workshop is child of Season of Jerry", () {
    final start = calendar.toDateTime(year: 516, month: 12, day: 24);
    final events = api.skyBlock.scheduledEvents(
      from: start,
      to: start.add(const Duration(hours: 2)),
    );

    final defend = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.defendJerrysWorkshop,
    );
    expect(defend.parentType, HypixelSkyBlockEventType.seasonOfJerry);
    expect(defend.duration, const Duration(hours: 1));
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
