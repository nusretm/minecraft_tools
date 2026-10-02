import 'hypixel_skyblock_date.dart';

class HypixelSkyBlockCalendar {
  const HypixelSkyBlockCalendar();

  static final DateTime epochUtc = DateTime.utc(2019, 6, 11, 17, 55);

  static const Duration skyBlockHour = Duration(seconds: 50);
  static const Duration skyBlockDay = Duration(minutes: 20);
  static const int daysPerMonth = 31;
  static const int monthsPerYear = 12;
  static const int daysPerYear = daysPerMonth * monthsPerYear;
  static const Duration skyBlockYear = Duration(hours: 124);

  HypixelSkyBlockDate fromDateTime(DateTime value) {
    final utc = value.toUtc();
    if (utc.isBefore(epochUtc)) {
      throw ArgumentError.value(value, 'value', 'must not be before SkyBlock epoch');
    }

    final elapsedMicros = utc.difference(epochUtc).inMicroseconds;
    const dayMicros = 20 * 60 * 1000000;
    const hourMicros = 50 * 1000000;

    final totalDays = elapsedMicros ~/ dayMicros;
    final withinDayMicros = elapsedMicros % dayMicros;

    final year = (totalDays ~/ daysPerYear) + 1;
    final dayOfYear = totalDays % daysPerYear;
    final month = (dayOfYear ~/ daysPerMonth) + 1;
    final day = (dayOfYear % daysPerMonth) + 1;

    final hour = withinDayMicros ~/ hourMicros;
    final withinHourMicros = withinDayMicros % hourMicros;
    final minute = (withinHourMicros * 60) ~/ hourMicros;
    final second = ((withinHourMicros * 3600) ~/ hourMicros) % 60;

    return HypixelSkyBlockDate(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
    );
  }

  DateTime toDateTime({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
  }) {
    if (year < 1) throw ArgumentError.value(year, 'year');
    if (month < 1 || month > monthsPerYear) {
      throw ArgumentError.value(month, 'month');
    }
    if (day < 1 || day > daysPerMonth) {
      throw ArgumentError.value(day, 'day');
    }
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute');
    }
    if (second < 0 || second > 59) {
      throw ArgumentError.value(second, 'second');
    }

    final absoluteDay =
        ((year - 1) * daysPerYear) + ((month - 1) * daysPerMonth) + (day - 1);

    final dayOffset = Duration(minutes: absoluteDay * 20);
    final timeOffsetMicros =
        (((hour * 3600) + (minute * 60) + second) * 50 * 1000000) ~/ 3600;

    return epochUtc
        .add(dayOffset)
        .add(Duration(microseconds: timeOffsetMicros));
  }
}
