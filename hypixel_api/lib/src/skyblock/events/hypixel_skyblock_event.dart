import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';
import 'hypixel_skyblock_event_phase.dart';

class HypixelSkyBlockEvent {
  const HypixelSkyBlockEvent({
    required this.type,
    required this.name,
    required this.category,
    required this.startAt,
    required this.endAt,
    this.parentType,
    this.confirmed = true,
    this.phases = const [],
    this.remindBeforeEnd = false,
    this.remindOnEnd = false,
  });

  final HypixelSkyBlockEventType type;
  final String name;
  final HypixelSkyBlockEventCategory category;
  final DateTime startAt;
  final DateTime endAt;
  final HypixelSkyBlockEventType? parentType;
  final bool confirmed;
  final List<HypixelSkyBlockEventPhase> phases;

  /// Adds an [onRemind] trigger at `endAt - reminderBefore`.
  final bool remindBeforeEnd;

  /// Adds an [onRemind] trigger at the exact [endAt] boundary.
  final bool remindOnEnd;

  Duration get duration => endAt.difference(startAt);

  bool get isStartMarker => duration <= const Duration(seconds: 1);

  Iterable<HypixelSkyBlockEventPhase> activePhasesAt(DateTime dateTime) =>
      phases.where((phase) => phase.isActiveAt(dateTime));

  bool isActiveAt(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return !utc.isBefore(startAt) && utc.isBefore(endAt);
  }

  @override
  String toString() => '$name: $startAt -> $endAt';
}
