import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('mayor/election history persists and stats are derived from history', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_history_test_');
    try {
      final store = HypixelDataStore(folder: temp.path);
      const calendar = HypixelSkyBlockCalendar();
      final history = HypixelSkyBlockHistory(store: store, calendar: calendar);

      final snapshot = HypixelSkyBlockElection(
        lastUpdated: DateTime.utc(2026, 10, 1, 12),
        mayor: HypixelSkyBlockMayor(
          key: 'diana',
          name: 'Diana',
          perks: const [
            HypixelSkyBlockPerk(name: 'Mythological Ritual', description: 'x'),
          ],
          minister: const HypixelSkyBlockMinister(
            key: 'cole',
            name: 'Cole',
            perk: HypixelSkyBlockPerk(name: 'Mining XP Buff', description: 'x'),
          ),
          election: const HypixelSkyBlockElectionRound(
            year: 516,
            candidates: [],
          ),
        ),
        current: const HypixelSkyBlockElectionRound(
          year: 517,
          candidates: [],
        ),
      );

      await history.observeElection(snapshot);
      await history.observeElection(snapshot);

      final mayors = await history.mayors();
      expect(mayors, hasLength(1));
      expect(mayors.single.termYear, 517);
      expect(mayors.single.mayor.name, 'Diana');

      final elections = await history.elections();
      expect(elections.map((e) => e.year), containsAll([516, 517]));

      final diana = await history.mayorStats('Diana');
      expect(diana.timesElected, 1);
      expect(diana.lastElectedYear, 517);

      final ritual = await history.perkStats('Mythological Ritual');
      expect(ritual.timesObserved, 1);
      expect(ritual.lastObservedYear, 517);
      expect(ritual.lastObservation?.source, HypixelSkyBlockPerkSource.mayor);

      final mining = await history.perkStats('Mining XP Buff');
      expect(mining.timesObserved, 1);
      expect(mining.lastObservation?.source, HypixelSkyBlockPerkSource.minister);

      expect(await store.historyFile('skyblock_mayors').exists(), isTrue);
      expect(await store.historyFile('skyblock_elections').exists(), isTrue);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}
