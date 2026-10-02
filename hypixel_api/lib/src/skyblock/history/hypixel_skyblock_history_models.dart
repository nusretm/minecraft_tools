import '../mayor/hypixel_skyblock_election.dart';

enum HypixelSkyBlockPerkSource {
  mayor,
  minister,
}

class HypixelSkyBlockMayorHistoryEntry {
  const HypixelSkyBlockMayorHistoryEntry({
    required this.termYear,
    required this.mayor,
    required this.termStartAt,
    required this.termEndAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.sourceLastUpdated,
  });

  final int termYear;
  final HypixelSkyBlockMayor mayor;
  final DateTime termStartAt;
  final DateTime termEndAt;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final DateTime sourceLastUpdated;

  Map<String, dynamic> toJson() => {
        'termYear': termYear,
        'mayor': mayor.toJson(),
        'termStartAt': termStartAt.millisecondsSinceEpoch,
        'termEndAt': termEndAt.millisecondsSinceEpoch,
        'firstObservedAt': firstObservedAt.millisecondsSinceEpoch,
        'lastObservedAt': lastObservedAt.millisecondsSinceEpoch,
        'sourceLastUpdated': sourceLastUpdated.millisecondsSinceEpoch,
      };

  factory HypixelSkyBlockMayorHistoryEntry.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockMayorHistoryEntry(
        termYear: (json['termYear'] as num).toInt(),
        mayor: HypixelSkyBlockMayor.fromJson(
          Map<String, dynamic>.from(json['mayor'] as Map),
        ),
        termStartAt: DateTime.fromMillisecondsSinceEpoch(
          (json['termStartAt'] as num).toInt(),
          isUtc: true,
        ),
        termEndAt: DateTime.fromMillisecondsSinceEpoch(
          (json['termEndAt'] as num).toInt(),
          isUtc: true,
        ),
        firstObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['firstObservedAt'] as num).toInt(),
          isUtc: true,
        ),
        lastObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['lastObservedAt'] as num).toInt(),
          isUtc: true,
        ),
        sourceLastUpdated: DateTime.fromMillisecondsSinceEpoch(
          (json['sourceLastUpdated'] as num).toInt(),
          isUtc: true,
        ),
      );
}

class HypixelSkyBlockElectionHistoryEntry {
  const HypixelSkyBlockElectionHistoryEntry({
    required this.year,
    required this.election,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.sourceLastUpdated,
  });

  final int year;
  final HypixelSkyBlockElectionRound election;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final DateTime sourceLastUpdated;

  Map<String, dynamic> toJson() => {
        'year': year,
        'election': election.toJson(),
        'firstObservedAt': firstObservedAt.millisecondsSinceEpoch,
        'lastObservedAt': lastObservedAt.millisecondsSinceEpoch,
        'sourceLastUpdated': sourceLastUpdated.millisecondsSinceEpoch,
      };

  factory HypixelSkyBlockElectionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockElectionHistoryEntry(
        year: (json['year'] as num).toInt(),
        election: HypixelSkyBlockElectionRound.fromJson(
          Map<String, dynamic>.from(json['election'] as Map),
        ),
        firstObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['firstObservedAt'] as num).toInt(),
          isUtc: true,
        ),
        lastObservedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['lastObservedAt'] as num).toInt(),
          isUtc: true,
        ),
        sourceLastUpdated: DateTime.fromMillisecondsSinceEpoch(
          (json['sourceLastUpdated'] as num).toInt(),
          isUtc: true,
        ),
      );
}

class HypixelSkyBlockMayorStats {
  const HypixelSkyBlockMayorStats({
    required this.mayorName,
    required this.timesElected,
    required this.termYears,
  });

  final String mayorName;
  final int timesElected;
  final List<int> termYears;

  int? get lastElectedYear => termYears.isEmpty ? null : termYears.last;
  int? get previousElectedYear => termYears.length < 2 ? null : termYears[termYears.length - 2];
}

class HypixelSkyBlockPerkObservation {
  const HypixelSkyBlockPerkObservation({
    required this.perkName,
    required this.termYear,
    required this.mayorName,
    required this.source,
  });

  final String perkName;
  final int termYear;
  final String mayorName;
  final HypixelSkyBlockPerkSource source;
}

class HypixelSkyBlockPerkStats {
  const HypixelSkyBlockPerkStats({
    required this.perkName,
    required this.observations,
  });

  final String perkName;
  final List<HypixelSkyBlockPerkObservation> observations;

  int get timesObserved => observations.length;
  int? get lastObservedYear => observations.isEmpty ? null : observations.last.termYear;
  HypixelSkyBlockPerkObservation? get lastObservation =>
      observations.isEmpty ? null : observations.last;
}
