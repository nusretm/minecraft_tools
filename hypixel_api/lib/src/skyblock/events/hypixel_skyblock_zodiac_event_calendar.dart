import '../calendar/hypixel_skyblock_calendar.dart';
import 'hypixel_skyblock_event.dart';
import 'hypixel_skyblock_event_category.dart';
import 'hypixel_skyblock_event_type.dart';

class HypixelSkyBlockZodiacEventCalendar {
  const HypixelSkyBlockZodiacEventCalendar(this.calendar);

  final HypixelSkyBlockCalendar calendar;

  HypixelSkyBlockEvent? eventForYear(int year) {
    final type = switch (year % 12) {
      6 => HypixelSkyBlockEventType.yearOfTheSeal,
      8 => HypixelSkyBlockEventType.yearOfTheWitch,
      11 => HypixelSkyBlockEventType.yearOfThePig,
      _ => null,
    };

    if (type == null) return null;

    final start = calendar.toDateTime(year: year, month: 1, day: 1);
    final end = calendar.toDateTime(year: year + 1, month: 1, day: 1);

    return HypixelSkyBlockEvent(
      type: type,
      name: _nameFor(type),
      category: HypixelSkyBlockEventCategory.zodiac,
      startAt: start,
      endAt: end,
    );
  }

  String _nameFor(HypixelSkyBlockEventType type) => switch (type) {
        HypixelSkyBlockEventType.yearOfTheSeal => 'Year of the Seal',
        HypixelSkyBlockEventType.yearOfTheWitch => 'Year of the Witch',
        HypixelSkyBlockEventType.yearOfThePig => 'Year of the Pig',
        _ => throw ArgumentError.value(type, 'type', 'is not a Zodiac event'),
      };
}
