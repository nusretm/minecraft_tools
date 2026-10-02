import '../events/hypixel_skyblock_event.dart';
import '../events/hypixel_skyblock_event_category.dart';
import '../events/hypixel_skyblock_event_type.dart';
import '../events/hypixel_skyblock_event_phase.dart';

enum HypixelSkyBlockSpecialStateKind {
  jerryPerkpocalypse,
  scheduledEvent,
  carryoverEffect,
  foxyExtraEventSelection,
}

class HypixelSkyBlockSpecialState {
  const HypixelSkyBlockSpecialState({
    required this.id,
    required this.kind,
    required this.sourceMayor,
    required this.sourceTermYear,
    required this.name,
    required this.activeFrom,
    required this.activeUntil,
    required this.firstObservedAt,
    required this.lastObservedAt,
    this.effectiveMayor,
    this.metadata = const {},
  });

  final String id;
  final HypixelSkyBlockSpecialStateKind kind;
  final String sourceMayor;
  final int sourceTermYear;
  final String name;
  final DateTime activeFrom;
  final DateTime activeUntil;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final String? effectiveMayor;
  final Map<String, dynamic> metadata;

  bool isActiveAt(DateTime instant) {
    final utc = instant.toUtc();
    return !utc.isBefore(activeFrom) && utc.isBefore(activeUntil);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'sourceMayor': sourceMayor,
        'sourceTermYear': sourceTermYear,
        'name': name,
        'activeFrom': activeFrom.millisecondsSinceEpoch,
        'activeUntil': activeUntil.millisecondsSinceEpoch,
        'firstObservedAt': firstObservedAt.millisecondsSinceEpoch,
        'lastObservedAt': lastObservedAt.millisecondsSinceEpoch,
        if (effectiveMayor != null) 'effectiveMayor': effectiveMayor,
        'metadata': metadata,
      };

  factory HypixelSkyBlockSpecialState.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockSpecialState(
        id: json['id'] as String,
        kind: HypixelSkyBlockSpecialStateKind.values.byName(json['kind'] as String),
        sourceMayor: json['sourceMayor'] as String,
        sourceTermYear: (json['sourceTermYear'] as num).toInt(),
        name: json['name'] as String,
        activeFrom: DateTime.fromMillisecondsSinceEpoch(
          (json['activeFrom'] as num).toInt(),
          isUtc: true,
        ),
        activeUntil: DateTime.fromMillisecondsSinceEpoch(
          (json['activeUntil'] as num).toInt(),
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
        effectiveMayor: json['effectiveMayor'] as String?,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
}

class HypixelSkyBlockScheduledEventHistoryEntry {
  const HypixelSkyBlockScheduledEventHistoryEntry({
    required this.id,
    required this.sourceMayor,
    required this.sourceTermYear,
    required this.type,
    required this.name,
    required this.startAt,
    required this.endAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    this.metadata = const {},
  });

  final String id;
  final String sourceMayor;
  final int sourceTermYear;
  final HypixelSkyBlockEventType type;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final Map<String, dynamic> metadata;

  HypixelSkyBlockEvent toEvent() {
    final phases = type == HypixelSkyBlockEventType.spookyFestival
        ? <HypixelSkyBlockEventPhase>[
            HypixelSkyBlockEventPhase(
              type: HypixelSkyBlockEventPhaseType.activity,
              name: 'Spooky Fishing / Fear Mongerer',
              startAt: startAt.subtract(const Duration(hours: 1)),
              endAt: endAt.add(const Duration(hours: 1)),
            ),
            HypixelSkyBlockEventPhase(
              type: HypixelSkyBlockEventPhaseType.event,
              name: 'Spooky Festival scoring',
              startAt: startAt,
              endAt: endAt,
            ),
          ]
        : const <HypixelSkyBlockEventPhase>[];

    return HypixelSkyBlockEvent(
      type: type,
      name: name,
      category: HypixelSkyBlockEventCategory.mayor,
      startAt: startAt,
      endAt: endAt,
      phases: phases,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceMayor': sourceMayor,
        'sourceTermYear': sourceTermYear,
        'type': type.name,
        'name': name,
        'startAt': startAt.millisecondsSinceEpoch,
        'endAt': endAt.millisecondsSinceEpoch,
        'firstObservedAt': firstObservedAt.millisecondsSinceEpoch,
        'lastObservedAt': lastObservedAt.millisecondsSinceEpoch,
        'metadata': metadata,
      };

  factory HypixelSkyBlockScheduledEventHistoryEntry.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockScheduledEventHistoryEntry(
        id: json['id'] as String,
        sourceMayor: json['sourceMayor'] as String,
        sourceTermYear: (json['sourceTermYear'] as num).toInt(),
        type: HypixelSkyBlockEventType.values.byName(json['type'] as String),
        name: json['name'] as String,
        startAt: DateTime.fromMillisecondsSinceEpoch(
          (json['startAt'] as num).toInt(),
          isUtc: true,
        ),
        endAt: DateTime.fromMillisecondsSinceEpoch(
          (json['endAt'] as num).toInt(),
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
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
}
