import '../bingo/hypixel_skyblock_bingo.dart';

class HypixelSkyBlockBingoHistoryEntry {
  const HypixelSkyBlockBingoHistoryEntry({
    required this.uuid,
    required this.eventId,
    required this.points,
    required this.completedGoals,
    required this.firstObservedAt,
    required this.lastObservedAt,
  });

  final String uuid;
  final int eventId;
  final int points;
  final Set<String> completedGoals;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'eventId': eventId,
        'points': points,
        'completedGoals': completedGoals.toList()..sort(),
        'firstObservedAt': firstObservedAt.millisecondsSinceEpoch,
        'lastObservedAt': lastObservedAt.millisecondsSinceEpoch,
      };

  factory HypixelSkyBlockBingoHistoryEntry.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockBingoHistoryEntry(
        uuid: json['uuid']?.toString() ?? '',
        eventId: (json['eventId'] as num).toInt(),
        points: (json['points'] as num?)?.toInt() ?? 0,
        completedGoals: (json['completedGoals'] as List? ?? const [])
            .map((value) => value.toString())
            .toSet(),
        firstObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['firstObservedAt'] as num).toInt(),
          isUtc: true,
        ),
        lastObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['lastObservedAt'] as num).toInt(),
          isUtc: true,
        ),
      );

  HypixelSkyBlockPlayerBingoEvent toPlayerEvent() =>
      HypixelSkyBlockPlayerBingoEvent(
        key: eventId,
        points: points,
        completedGoals: completedGoals,
      );
}

class HypixelSkyBlockBingoStats {
  const HypixelSkyBlockBingoStats({
    required this.uuid,
    required this.entries,
  });

  final String uuid;
  final List<HypixelSkyBlockBingoHistoryEntry> entries;

  int get eventsParticipated => entries.length;
  int get totalPoints => entries.fold(0, (sum, entry) => sum + entry.points);
  int get totalCompletedGoals =>
      entries.fold(0, (sum, entry) => sum + entry.completedGoals.length);

  int? get lastEventId => entries.isEmpty ? null : entries.last.eventId;
  int? get highestPoints => entries.isEmpty
      ? null
      : entries.map((entry) => entry.points).reduce((a, b) => a > b ? a : b);

  Set<String> get uniqueCompletedGoalIds => {
        for (final entry in entries) ...entry.completedGoals,
      };
}
