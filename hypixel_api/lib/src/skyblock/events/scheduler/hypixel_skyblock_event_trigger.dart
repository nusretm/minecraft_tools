import '../hypixel_skyblock_event.dart';
import '../hypixel_skyblock_event_phase.dart';

enum HypixelSkyBlockEventTriggerType {
  remind,
  endRemind,
  event,
  eventEnd,
  phaseStart,
  phaseEnd,
}

class HypixelSkyBlockEventTrigger {
  const HypixelSkyBlockEventTrigger({
    required this.at,
    required this.event,
    required this.type,
    this.phase,
  });

  final DateTime at;
  final HypixelSkyBlockEvent event;
  final HypixelSkyBlockEventTriggerType type;
  final HypixelSkyBlockEventPhase? phase;

  String get id => '${at.microsecondsSinceEpoch}|${event.type.name}|${type.name}|${phase?.name ?? ''}';
}
