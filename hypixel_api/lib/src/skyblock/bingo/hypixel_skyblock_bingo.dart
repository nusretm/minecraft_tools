class HypixelSkyBlockBingoGoal {
  const HypixelSkyBlockBingoGoal({
    required this.id,
    required this.name,
    required this.lore,
    required this.fullLore,
    required this.tiers,
    required this.progress,
    required this.requiredAmount,
  });

  factory HypixelSkyBlockBingoGoal.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockBingoGoal(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        lore: json['lore']?.toString() ?? '',
        fullLore: (json['fullLore'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        tiers: (json['tiers'] as List? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(growable: false),
        progress: (json['progress'] as num?)?.toInt(),
        requiredAmount: (json['requiredAmount'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final String lore;
  final List<String> fullLore;
  final List<int> tiers;
  final int? progress;
  final int? requiredAmount;
}

class HypixelSkyBlockBingoEventResource {
  const HypixelSkyBlockBingoEventResource({
    required this.lastUpdated,
    required this.id,
    required this.name,
    required this.startAt,
    required this.endAt,
    required this.modifier,
    required this.goals,
  });

  factory HypixelSkyBlockBingoEventResource.fromJson(Map<String, dynamic> json) {
    return HypixelSkyBlockBingoEventResource(
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        (json['lastUpdated'] as num).toInt(),
        isUtc: true,
      ),
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      startAt: DateTime.fromMillisecondsSinceEpoch(
        (json['start'] as num).toInt(),
        isUtc: true,
      ),
      endAt: DateTime.fromMillisecondsSinceEpoch(
        (json['end'] as num).toInt(),
        isUtc: true,
      ),
      modifier: json['modifier']?.toString() ?? '',
      goals: (json['goals'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => HypixelSkyBlockBingoGoal.fromJson(
                Map<String, dynamic>.from(value),
              ))
          .toList(growable: false),
    );
  }

  final DateTime lastUpdated;
  final int id;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final String modifier;
  final List<HypixelSkyBlockBingoGoal> goals;
}

class HypixelSkyBlockPlayerBingoEvent {
  const HypixelSkyBlockPlayerBingoEvent({
    required this.key,
    required this.points,
    required this.completedGoals,
  });

  factory HypixelSkyBlockPlayerBingoEvent.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockPlayerBingoEvent(
        key: (json['key'] as num).toInt(),
        points: (json['points'] as num?)?.toInt() ?? 0,
        completedGoals: (json['completed_goals'] as List? ?? const [])
            .expand((value) => value is List ? value : [value])
            .map((value) => value.toString())
            .toSet(),
      );

  final int key;
  final int points;
  final Set<String> completedGoals;
}

class HypixelSkyBlockPlayerBingoData {
  const HypixelSkyBlockPlayerBingoData({required this.events});

  factory HypixelSkyBlockPlayerBingoData.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockPlayerBingoData(
        events: (json['events'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => HypixelSkyBlockPlayerBingoEvent.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
      );

  final List<HypixelSkyBlockPlayerBingoEvent> events;

  HypixelSkyBlockPlayerBingoEvent? eventById(int eventId) {
    for (final event in events) {
      if (event.key == eventId) return event;
    }
    return null;
  }
}

class HypixelSkyBlockBingo {
  const HypixelSkyBlockBingo({
    required this.event,
    required this.playerProgress,
  });

  final HypixelSkyBlockBingoEventResource event;
  final HypixelSkyBlockPlayerBingoEvent? playerProgress;

  bool isGoalCompleted(String goalId) =>
      playerProgress?.completedGoals.contains(goalId) ?? false;
}
