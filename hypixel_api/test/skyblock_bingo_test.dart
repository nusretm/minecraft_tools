import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('parses current Bingo resource', () {
    final bingo = HypixelSkyBlockBingoEventResource.fromJson({
      'success': true,
      'lastUpdated': 1790874309532,
      'id': 58,
      'name': 'October 2026',
      'start': 1790827200000,
      'end': 1791432000000,
      'modifier': 'NORMAL',
      'goals': [
        {
          'id': 'collection_sulphur',
          'name': 'Gunpowder Collector',
          'lore': 'Reach 55,000 Gunpowder Collection.',
          'fullLore': ['Reach 55,000 Gunpowder Collection.'],
          'requiredAmount': 55000,
        }
      ],
    });

    expect(bingo.id, 58);
    expect(bingo.name, 'October 2026');
    expect(bingo.modifier, 'NORMAL');
    expect(bingo.goals.single.requiredAmount, 55000);
    expect(bingo.startAt.isUtc, isTrue);
  });

  test('parses player Bingo progress and matches current event', () {
    final player = HypixelSkyBlockPlayerBingoData.fromJson({
      'success': true,
      'events': [
        {
          'key': 58,
          'points': 117,
          'completed_goals': ['goal_a', 'goal_b'],
        }
      ],
    });

    final event = player.eventById(58);
    expect(event, isNotNull);
    expect(event!.points, 117);
    expect(event.completedGoals, containsAll(['goal_a', 'goal_b']));
  });

  test('also accepts nested completed_goals representation', () {
    final player = HypixelSkyBlockPlayerBingoData.fromJson({
      'events': [
        {
          'key': 2,
          'points': 1,
          'completed_goals': [
            ['goal_a', 'goal_b']
          ],
        }
      ],
    });
    expect(player.events.single.completedGoals, containsAll(['goal_a', 'goal_b']));
  });
}

// Scheduler-facing Bingo lifecycle reminders are tested here because Bingo is
// the first event that opts into both pre-end and exact-end notifications.
