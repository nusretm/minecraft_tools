import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('Bingo history persists per UUID and stats are derived', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_bingo_history_');
    try {
      final history = HypixelSkyBlockHistory(
        store: HypixelDataStore(folder: temp.path),
        calendar: const HypixelSkyBlockCalendar(),
      );

      final firstObserved = DateTime.utc(2026, 10, 1, 12);
      await history.observePlayerBingo(
        uuid: '3f6a05df-1b83-411c-b10c-7c340b5250de',
        observedAt: firstObserved,
        data: const HypixelSkyBlockPlayerBingoData(events: [
          HypixelSkyBlockPlayerBingoEvent(
            key: 57,
            points: 12,
            completedGoals: {'a', 'b'},
          ),
          HypixelSkyBlockPlayerBingoEvent(
            key: 58,
            points: 3,
            completedGoals: {'c'},
          ),
        ]),
      );

      final secondObserved = DateTime.utc(2026, 10, 1, 13);
      await history.observePlayerBingo(
        // Same UUID without dashes must update the same player history.
        uuid: '3f6a05df1b83411cb10c7c340b5250de',
        observedAt: secondObserved,
        data: const HypixelSkyBlockPlayerBingoData(events: [
          HypixelSkyBlockPlayerBingoEvent(
            key: 57,
            points: 12,
            completedGoals: {'a', 'b'},
          ),
          HypixelSkyBlockPlayerBingoEvent(
            key: 58,
            points: 8,
            completedGoals: {'c', 'd', 'e'},
          ),
        ]),
      );

      final entries = await history.bingoHistory(
        uuid: '3f6a05df-1b83-411c-b10c-7c340b5250de',
      );
      expect(entries, hasLength(2));
      expect(entries.map((e) => e.eventId), [57, 58]);
      expect(entries.last.points, 8);
      expect(entries.last.completedGoals, {'c', 'd', 'e'});
      expect(entries.last.firstObservedAt, firstObserved);
      expect(entries.last.lastObservedAt, secondObserved);

      final stats = await history.bingoStats(
        uuid: '3f6a05df1b83411cb10c7c340b5250de',
      );
      expect(stats.eventsParticipated, 2);
      expect(stats.totalPoints, 20);
      expect(stats.totalCompletedGoals, 5);
      expect(stats.highestPoints, 12);
      expect(stats.lastEventId, 58);
      expect(stats.uniqueCompletedGoalIds, {'a', 'b', 'c', 'd', 'e'});
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}
