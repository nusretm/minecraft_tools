import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  const calendar = HypixelSkyBlockCalendar();
  const contests = HypixelSkyBlockContestEventCalendar(calendar);

  group("Jacob's Farming Contest", () {
    test('starts at XX:15 and lasts 20 minutes', () {
      final events = contests.events(
        from: DateTime.utc(2026, 10, 1, 13, 0),
        to: DateTime.utc(2026, 10, 1, 14, 0),
      ).where((event) =>
          event.type == HypixelSkyBlockEventType.jacobsFarmingContest).toList();

      expect(events, hasLength(1));
      expect(events.single.startAt, DateTime.utc(2026, 10, 1, 13, 15));
      expect(events.single.endAt, DateTime.utc(2026, 10, 1, 13, 35));
      expect(events.single.category, HypixelSkyBlockEventCategory.contest);
    });

    test('includes an already-active contest overlapping range start', () {
      final events = contests.events(
        from: DateTime.utc(2026, 10, 1, 13, 20),
        to: DateTime.utc(2026, 10, 1, 13, 30),
      ).where((event) =>
          event.type == HypixelSkyBlockEventType.jacobsFarmingContest).toList();

      expect(events, hasLength(1));
      expect(events.single.startAt, DateTime.utc(2026, 10, 1, 13, 15));
      expect(events.single.endAt, DateTime.utc(2026, 10, 1, 13, 35));
    });
  });

  group("Miria's Starlyn Contest", () {
    test('runs every SkyBlock day for exactly 20 minutes', () {
      final events = contests.events(
        from: DateTime.utc(2026, 10, 1, 13, 0),
        to: DateTime.utc(2026, 10, 1, 14, 0),
      ).where((event) => event.type == HypixelSkyBlockEventType.miriaContest).toList();

      expect(events, hasLength(4));
      expect(events[0].startAt, DateTime.utc(2026, 10, 1, 12, 55));
      expect(events[0].endAt, DateTime.utc(2026, 10, 1, 13, 15));
      expect(events[1].startAt, DateTime.utc(2026, 10, 1, 13, 15));
      expect(events[1].endAt, DateTime.utc(2026, 10, 1, 13, 35));
      expect(events[2].startAt, DateTime.utc(2026, 10, 1, 13, 35));
      expect(events[2].endAt, DateTime.utc(2026, 10, 1, 13, 55));
      expect(events[3].startAt, DateTime.utc(2026, 10, 1, 13, 55));
      expect(events[3].endAt, DateTime.utc(2026, 10, 1, 14, 15));
    });

    test('contests have no gaps between SkyBlock days', () {
      final events = contests.events(
        from: DateTime.utc(2026, 10, 1, 13, 15),
        to: DateTime.utc(2026, 10, 1, 14, 15),
      ).where((event) => event.type == HypixelSkyBlockEventType.miriaContest).toList();

      for (var i = 1; i < events.length; i++) {
        expect(events[i - 1].endAt, events[i].startAt);
      }
    });
  });
}
