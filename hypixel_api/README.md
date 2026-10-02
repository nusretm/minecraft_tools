# HypixelApi

Pure Dart Hypixel/SkyBlock API, calendar, event timeline, persistent history and reminder scheduler.

The package has no Flutter dependency and is intended to be reusable from applications such as MtnLauncher.

## Features

- SkyBlock date/time conversion from UTC
- Deterministic SkyBlock calendar events
- Zodiac events
- Dark Auction start markers
- Jacob's Farming Contest and Miria's Starlyn Contest timing
- Mayor/election API and persistent mayor/election history
- Mayor-perk-driven events
- Jerry Perkpocalypse observation history without guessing rotation
- Foxy Extra Event observation + externally resolved schedules
- Persistent special/carryover state history
- Current Bingo metadata/goals
- Player Bingo history and derived statistics
- Bingo start/end reminders
- Official SkyBlock news feed + persistent news history
- SHA-256 request cache
- API key metadata + Hypixel rate-limit response state
- One-shot-timer event scheduler (no fixed event polling)

## Requirements

```text
Dart >= 3.3.0 < 4.0.0
```

## Basic usage

```dart
import 'package:hypixel_api/hypixel_api.dart';

final api = HypixelApi(
  dataFolder: r'D:\my_app\hypixel',
);

final events = await api.skyBlock.events(
  from: DateTime.now(),
  to: DateTime.now().add(const Duration(days: 7)),
);

for (final event in events) {
  print('${event.startAt}: ${event.name}');
}

api.close();
```

When `dataFolder` is omitted, the default is:

```text
Directory.systemTemp/hypixel_api
```

## API key

The library does **not** embed a Hypixel API key.

Authenticated endpoints such as player Bingo require a key supplied by the application:

```dart
final api = HypixelApi(
  apiKey: HypixelApiKey(
    value: keyFromYourBackend,
    type: HypixelApiKeyType.production,
    expiresAt: expiry,
    requestLimit: configuredLimit,
    requestWindow: const Duration(minutes: 5),
  ),
);
```

A key can be replaced without rebuilding `HypixelSkyBlockApi`:

```dart
api.updateApiKey(HypixelApiKey(
  value: renewedKey,
  type: HypixelApiKeyType.production,
));
```

API key values are never included in request-cache hashes, cache metadata or domain history.

`api.rateLimit` exposes the most recently observed `RateLimit-Limit`, `RateLimit-Remaining` and `RateLimit-Reset` response headers. This runtime state is separate from configured/dashboard key metadata.

## Data layout

```text
hypixel_api/
├── cache/
│   └── requests/
│       └── <sha256>.json
└── history/
    ├── skyblock_mayors.json
    ├── skyblock_elections.json
    ├── skyblock_special_states.json
    ├── skyblock_scheduled_events.json
    ├── skyblock_bingo_players.json
    └── skyblock_news.json
```

`clearCache()` and `clearExpiredCache()` affect request cache only. Persistent history is domain data and is not removed.

## Request cache identity

The cache filename is SHA-256 over:

```text
HTTP method + path + canonical sorted query
```

Query order does not change the key; query values do. Authentication headers are deliberately excluded.

## Mayor and election history

Every successful election-resource read is observed into persistent history.

```dart
final election = await api.skyBlock.election();
final mayors = await api.skyBlock.history.mayors();
final elections = await api.skyBlock.history.elections();

final diana = await api.skyBlock.history.mayorStats('Diana');
final fiesta = await api.skyBlock.history.perkStats('Mining Fiesta');
```

Statistics are derived from stored history rather than persisted as counters.

Mayor-dependent events are generated from active perks, including minister-provided perks. Previous mayor terms remain usable after the current mayor changes.

## Special mayor state

Jerry Perkpocalypse is observation-driven because the official election resource does not expose the currently effective rotating mayor. Unknown rotation is never guessed.

```dart
await api.skyBlock.history.observeJerryPerkpocalypse(
  sourceTermYear: 517,
  effectiveMayor: 'Cole',
  observedAt: DateTime.now(),
);
```

Foxy Extra Event selection can be retained when its type is known but schedule is not:

```dart
final unresolved =
    await api.skyBlock.history.unresolvedFoxyExtraEvents();
```

A trusted timestamp can later resolve it into a persistent scheduled event:

```dart
await api.skyBlock.history.resolveFoxyExtraEventSchedule(
  sourceTermYear: 517,
  startAt: start,
  endAt: end,
);
```

Verified non-calendar carryover effects can be stored separately with `observeCarryoverEffect(...)`; they are not turned into fake timeline events.

## Bingo

Current resource metadata and goals:

```dart
final current = await api.skyBlock.bingoEvent();
```

Player data requires an API key:

```dart
final data = await api.skyBlock.playerBingo(uuid: uuid);

for (final event in data?.events ?? const []) {
  print('${event.key}: ${event.points}');
}
```

Current resource + matching player progress convenience model:

```dart
final bingo = await api.skyBlock.bingo(uuid: uuid);
print(bingo.playerProgress?.points);
```

A Hypixel 404 from the player Bingo endpoint is treated as “no Bingo participation data” and returns `null` rather than failing the whole current-Bingo query.

Player snapshots are persisted and merged by canonical UUID + Bingo event ID:

```dart
final history = await api.skyBlock.history.bingoHistory(uuid: uuid);
final stats = await api.skyBlock.history.bingoStats(uuid: uuid);

print(stats.eventsParticipated);
print(stats.totalPoints);
print(stats.totalCompletedGoals);
print(stats.highestPoints);
```

## News

The official keyless SkyBlock news feed is available through:

```dart
final news = await api.skyBlock.news();
final history = await api.skyBlock.history.news();
```

Observed feed items are persisted by stable link identity so older items remain available after they leave the current feed.

## Event scheduler

The scheduler uses one next-trigger timer rather than fixed polling for event delivery.

```dart
final scheduler = api.skyBlock.createEventScheduler(
  reminderBefore: const Duration(minutes: 5),
  refreshInterval: const Duration(minutes: 5),
  onRemind: (event) {
    print('Reminder: ${event.name}');
  },
  onEvent: (event) {
    print('Started: ${event.name}');
  },
);

await scheduler.start();
// ...
await scheduler.stop();
```

For Bingo, with a five-minute reminder:

```text
start - 5m  -> onRemind(event)
start       -> onEvent(event)
end - 5m    -> onRemind(event)
end         -> onRemind(event)
```

Spooky Festival also exposes documented extended activity phases. Other event types do not receive invented pre/post phases or end reminders.

## Event filtering

`events()` is the complete asynchronous timeline including dynamic/history-backed events.

```dart
final events = await api.skyBlock.events(
  from: from,
  to: to,
);
```

`scheduledEvents()` is deterministic/no-network calendar generation.

```dart
final deterministic = api.skyBlock.scheduledEvents(
  from: from,
  to: to,
);
```

The CLI `--event-only` filter hides high-frequency contest events and Dark Auction while retaining significant calendar, Zodiac, mayor and Bingo events.

## CLI

```powershell
dart run bin/main.dart --help

dart run bin/main.dart --days 7 --event-only
dart run bin/main.dart --mayor
dart run bin/main.dart --history
dart run bin/main.dart --mayor-stats Diana
dart run bin/main.dart --perk-stats "Mining Fiesta"
dart run bin/main.dart --news
dart run bin/main.dart --news-history
```

Authenticated Bingo commands accept either `--api-key` or the `HYPIXEL_API_KEY` environment variable:

```powershell
$env:HYPIXEL_API_KEY="..."
dart run bin/main.dart --bingo <uuid>
dart run bin/main.dart --bingo-history <uuid>
dart run bin/main.dart --bingo-stats <uuid>
```

Common options:

```text
--refresh
--data-folder <path>
--api-key <key>
```

Prefer environment/backend injection over putting a key in source code or command history.

## Deliberately not guessed

The package does not manufacture data that Hypixel does not expose reliably:

- Jacob crop combinations
- Jerry Perkpocalypse rotation order/current effective mayor
- Foxy Extra Event timestamp when only event type is known
- Derpy calendar events where the behavior is a game-state/carryover effect rather than a timed event

These remain explicit unknown/observation states until a trusted source is available.

## Integration boundary

For MtnLauncher, keep `HypixelApi` as the Pure Dart data/runtime layer and wrap it at the application/plugin boundary. The library does not depend on launcher UI, Flutter, or a generic plugin contract.
