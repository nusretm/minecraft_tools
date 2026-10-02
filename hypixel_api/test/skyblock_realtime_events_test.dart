import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  final api = HypixelApi();

  test('Dark Auction starts at minute 55 every real-life hour', () {
    final events = api.skyBlock.scheduledEvents(
      from: DateTime.utc(2026, 10, 1, 13, 53),
      to: DateTime.utc(2026, 10, 1, 16, 0),
    );

    final auctions = events
        .where((event) => event.type == HypixelSkyBlockEventType.darkAuction)
        .toList();

    expect(auctions, hasLength(3));
    expect(auctions[0].startAt, DateTime.utc(2026, 10, 1, 13, 55));
    expect(auctions[1].startAt, DateTime.utc(2026, 10, 1, 14, 55));
    expect(auctions[2].startAt, DateTime.utc(2026, 10, 1, 15, 55));
    expect(auctions.every((event) => event.isStartMarker), isTrue);
    expect(
      auctions.every(
        (event) => event.category == HypixelSkyBlockEventCategory.realtime,
      ),
      isTrue,
    );
  });

  test('Dark Auction includes an event exactly at the range start', () {
    final events = api.skyBlock.scheduledEvents(
      from: DateTime.utc(2026, 10, 1, 13, 55),
      to: DateTime.utc(2026, 10, 1, 14, 0),
    );

    final auction = events.singleWhere(
      (event) => event.type == HypixelSkyBlockEventType.darkAuction,
    );
    expect(auction.startAt, DateTime.utc(2026, 10, 1, 13, 55));
  });

  test('Dark Auction does not include the event at exclusive range end', () {
    final events = api.skyBlock.scheduledEvents(
      from: DateTime.utc(2026, 10, 1, 13, 56),
      to: DateTime.utc(2026, 10, 1, 14, 55),
    );

    expect(
      events.where((event) => event.type == HypixelSkyBlockEventType.darkAuction),
      isEmpty,
    );
  });
}
