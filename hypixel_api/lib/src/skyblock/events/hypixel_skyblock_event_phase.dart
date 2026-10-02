enum HypixelSkyBlockEventPhaseType {
  preparation,
  activity,
  event,
  postActivity,
}

class HypixelSkyBlockEventPhase {
  const HypixelSkyBlockEventPhase({
    required this.type,
    required this.name,
    required this.startAt,
    required this.endAt,
  });

  final HypixelSkyBlockEventPhaseType type;
  final String name;
  final DateTime startAt;
  final DateTime endAt;

  Duration get duration => endAt.difference(startAt);

  bool isActiveAt(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return !utc.isBefore(startAt) && utc.isBefore(endAt);
  }
}
