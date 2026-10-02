import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  const calendar = HypixelSkyBlockCalendar();
  const mayorEvents = HypixelSkyBlockMayorEventCalendar(calendar);

  HypixelSkyBlockElection election({
    required String mayorName,
    required List<String> perks,
    String? ministerPerk,
    int electionYear = 516,
  }) {
    return HypixelSkyBlockElection(
      lastUpdated: DateTime.utc(2026, 10, 1),
      mayor: HypixelSkyBlockMayor(
        key: mayorName.toLowerCase(),
        name: mayorName,
        perks: perks
            .map((name) => HypixelSkyBlockPerk(name: name, description: ''))
            .toList(),
        minister: ministerPerk == null
            ? null
            : HypixelSkyBlockMinister(
                key: 'minister',
                name: 'Minister',
                perk: HypixelSkyBlockPerk(
                  name: ministerPerk,
                  description: '',
                  minister: true,
                ),
              ),
        election: HypixelSkyBlockElectionRound(
          year: electionYear,
          candidates: const [],
        ),
      ),
    );
  }

  test('Diana Mythological Ritual spans the mayor term', () {
    final state = election(
      mayorName: 'Diana',
      perks: const ['Mythological Ritual'],
    );
    final termStart = calendar.toDateTime(year: 517, month: 3, day: 27);
    final termEnd = calendar.toDateTime(year: 518, month: 3, day: 27);

    final events = mayorEvents.events(
      election: state,
      from: termStart,
      to: termEnd,
    );

    final ritual = events.singleWhere(
      (e) => e.type == HypixelSkyBlockEventType.mythologicalRitual,
    );
    expect(ritual.startAt, termStart);
    expect(ritual.endAt, termEnd);
    expect(ritual.category, HypixelSkyBlockEventCategory.mayor);
  });

  test('minister event perk is honored, unrelated minister perk is ignored', () {
    final withFiesta = election(
      mayorName: 'Diana',
      perks: const ['Mythological Ritual'],
      ministerPerk: 'Mining Fiesta',
    );
    final withoutFiesta = election(
      mayorName: 'Diana',
      perks: const ['Mythological Ritual'],
      ministerPerk: 'Mining XP Buff',
    );
    final from = calendar.toDateTime(year: 517, month: 4, day: 1);
    final to = calendar.toDateTime(year: 517, month: 11, day: 1);

    expect(
      mayorEvents
          .events(election: withFiesta, from: from, to: to)
          .where((e) => e.type == HypixelSkyBlockEventType.miningFiesta)
          .length,
      4,
    );
    expect(
      mayorEvents
          .events(election: withoutFiesta, from: from, to: to)
          .where((e) => e.type == HypixelSkyBlockEventType.miningFiesta),
      isEmpty,
    );
  });

  test('Mining Fiesta occurs five times within a mayor term', () {
    final state = election(
      mayorName: 'Cole',
      perks: const ['Mining Fiesta'],
    );
    final termStart = calendar.toDateTime(year: 517, month: 3, day: 27);
    final termEnd = calendar.toDateTime(year: 518, month: 3, day: 27);

    final fiestas = mayorEvents
        .events(election: state, from: termStart, to: termEnd)
        .where((e) => e.type == HypixelSkyBlockEventType.miningFiesta)
        .toList();

    expect(fiestas, hasLength(5));
    expect(
      fiestas.map((e) {
        final d = calendar.fromDateTime(e.startAt);
        return '${d.year}/${d.month}/${d.day} ${d.hour}';
      }).toList(),
      const [
        '517/4/1 18',
        '517/6/1 18',
        '517/8/1 18',
        '517/10/1 18',
        '518/2/1 18',
      ],
    );
    expect(fiestas.every((e) => e.duration == const Duration(minutes: 140)), isTrue);
  });

  test('Fishing Festival runs for first three days of each month in term', () {
    final state = election(
      mayorName: 'Marina',
      perks: const ['Fishing Festival'],
    );
    final from = calendar.toDateTime(year: 517, month: 4, day: 1);
    final to = calendar.toDateTime(year: 517, month: 7, day: 1);

    final festivals = mayorEvents
        .events(election: state, from: from, to: to)
        .where((e) => e.type == HypixelSkyBlockEventType.fishingFestival)
        .toList();

    expect(festivals, hasLength(3));
    expect(festivals.every((e) => e.duration == const Duration(hours: 1)), isTrue);
  });

  test('term-long Foxy and Diaz perks create term events', () {
    final termStart = calendar.toDateTime(year: 517, month: 3, day: 27);
    final termEnd = calendar.toDateTime(year: 518, month: 3, day: 27);

    final carnival = mayorEvents.events(
      election: election(
        mayorName: 'Foxy',
        perks: const ['Chivalrous Carnival'],
      ),
      from: termStart,
      to: termEnd,
    );
    expect(carnival.single.type, HypixelSkyBlockEventType.carnival);

    final stonks = mayorEvents.events(
      election: election(
        mayorName: 'Diaz',
        perks: const ['Stock Exchange'],
      ),
      from: termStart,
      to: termEnd,
    );
    expect(stonks.single.type, HypixelSkyBlockEventType.stonkExchange);
  });
}
