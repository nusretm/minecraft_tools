import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  const calendar = HypixelSkyBlockCalendar();

  test('epoch is Early Spring 1, Year 1 00:00', () {
    final value = calendar.fromDateTime(HypixelSkyBlockCalendar.epochUtc);
    expect(value.year, 1);
    expect(value.month, 1);
    expect(value.day, 1);
    expect(value.hour, 0);
    expect(value.minute, 0);
  });

  test('one SkyBlock day is 20 real minutes', () {
    final value = calendar.fromDateTime(
      HypixelSkyBlockCalendar.epochUtc.add(const Duration(minutes: 20)),
    );
    expect(value.day, 2);
  });

  test('one SkyBlock year is 124 real hours', () {
    final value = calendar.fromDateTime(
      HypixelSkyBlockCalendar.epochUtc.add(const Duration(hours: 124)),
    );
    expect(value.year, 2);
    expect(value.month, 1);
    expect(value.day, 1);
  });

  test('round trip exact day boundary', () {
    final real = calendar.toDateTime(year: 516, month: 8, day: 29);
    final sb = calendar.fromDateTime(real);
    expect(sb.year, 516);
    expect(sb.month, 8);
    expect(sb.day, 29);
    expect(sb.hour, 0);
  });
}
