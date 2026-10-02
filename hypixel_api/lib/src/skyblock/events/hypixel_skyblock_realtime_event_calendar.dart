import 'hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';

class HypixelSkyBlockRealtimeEventCalendar {
  const HypixelSkyBlockRealtimeEventCalendar();

  List<HypixelSkyBlockEvent> events({
    required DateTime from,
    required DateTime to,
  }) {
    final start = from.toUtc();
    final end = to.toUtc();

    if (!end.isAfter(start)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final result = <HypixelSkyBlockEvent>[];
    var next = DateTime.utc(
      start.year,
      start.month,
      start.day,
      start.hour,
      55,
    );

    if (next.isBefore(start)) {
      next = next.add(const Duration(hours: 1));
    }

    while (next.isBefore(end)) {
      result.add(
        HypixelSkyBlockEvent(
          type: HypixelSkyBlockEventType.darkAuction,
          name: 'Dark Auction',
          category: HypixelSkyBlockEventCategory.realtime,
          startAt: next,
          // The start time is deterministic, but the auction duration is not.
          // Keep this as a start marker instead of claiming a fixed duration.
          endAt: next.add(const Duration(seconds: 1)),
        ),
      );
      next = next.add(const Duration(hours: 1));
    }

    return result;
  }
}
