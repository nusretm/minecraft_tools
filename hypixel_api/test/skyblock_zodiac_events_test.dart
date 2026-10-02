import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  final api = HypixelApi();
  const calendar = HypixelSkyBlockCalendar();

  test('Year of the Seal is remainder 6 and lasts one SkyBlock year', () {
    final start = calendar.toDateTime(year: 510, month: 1, day: 1);
    final end = calendar.toDateTime(year: 511, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(from: start, to: end);

    final event = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.yearOfTheSeal,
    );

    expect(510 % 12, 6);
    expect(event.category, HypixelSkyBlockEventCategory.zodiac);
    expect(event.startAt, start);
    expect(event.endAt, end);
    expect(event.duration, HypixelSkyBlockCalendar.skyBlockYear);
  });

  test('Year of the Witch is remainder 8', () {
    final start = calendar.toDateTime(year: 476, month: 1, day: 1);
    final end = calendar.toDateTime(year: 477, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(from: start, to: end);

    final event = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.yearOfTheWitch,
    );

    expect(476 % 12, 8);
    expect(event.startAt, start);
    expect(event.endAt, end);
  });

  test('Year of the Pig is remainder 11', () {
    final start = calendar.toDateTime(year: 515, month: 1, day: 1);
    final end = calendar.toDateTime(year: 516, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(from: start, to: end);

    final event = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.yearOfThePig,
    );

    expect(515 % 12, 11);
    expect(event.startAt, start);
    expect(event.endAt, end);
  });

  test('non-Zodiac year has no Zodiac event', () {
    final start = calendar.toDateTime(year: 517, month: 1, day: 1);
    final end = calendar.toDateTime(year: 518, month: 1, day: 1);
    final events = api.skyBlock.scheduledEvents(from: start, to: end);

    expect(
      events.where((e) => e.category == HypixelSkyBlockEventCategory.zodiac),
      isEmpty,
    );
  });
}
