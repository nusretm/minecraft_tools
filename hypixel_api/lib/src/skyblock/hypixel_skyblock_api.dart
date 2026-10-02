import '../auth/hypixel_api_key.dart';
import '../history/hypixel_data_store.dart';
import '../http/hypixel_http_client.dart';
import 'calendar/hypixel_skyblock_calendar.dart';
import 'bingo/hypixel_skyblock_bingo.dart';
import 'events/hypixel_skyblock_contest_event_calendar.dart';
import 'events/hypixel_skyblock_event_category.dart';
import 'events/hypixel_skyblock_event_type.dart';
import 'events/hypixel_skyblock_event.dart';
import 'events/hypixel_skyblock_event_calendar.dart';
import 'events/hypixel_skyblock_mayor_event_calendar.dart';
import 'events/hypixel_skyblock_realtime_event_calendar.dart';
import 'events/scheduler/hypixel_skyblock_event_scheduler.dart';
import 'history/hypixel_skyblock_history.dart';
import 'history/hypixel_skyblock_special_history_models.dart';
import 'mayor/hypixel_skyblock_election.dart';
import 'news/hypixel_skyblock_news.dart';

class HypixelSkyBlockApi {
  HypixelSkyBlockApi({
    required HypixelHttpClient http,
    required HypixelDataStore dataStore,
    DateTime? now,
    Duration electionCacheTtl = const Duration(minutes: 5),
    Duration bingoResourceCacheTtl = const Duration(minutes: 5),
    Duration bingoPlayerCacheTtl = const Duration(minutes: 5),
    Duration newsCacheTtl = const Duration(minutes: 15),
    required HypixelApiKey? Function() apiKeyProvider,
  })  : calendar = const HypixelSkyBlockCalendar(),
        _http = http,
        _now = now,
        _electionCacheTtl = electionCacheTtl,
        _bingoResourceCacheTtl = bingoResourceCacheTtl,
        _bingoPlayerCacheTtl = bingoPlayerCacheTtl,
        _newsCacheTtl = newsCacheTtl,
        _apiKeyProvider = apiKeyProvider {
    history = HypixelSkyBlockHistory(store: dataStore, calendar: calendar);
  }

  final HypixelSkyBlockCalendar calendar;
  final HypixelHttpClient _http;
  final Duration _electionCacheTtl;
  final Duration _bingoResourceCacheTtl;
  final Duration _bingoPlayerCacheTtl;
  final Duration _newsCacheTtl;
  final HypixelApiKey? Function() _apiKeyProvider;
  final DateTime? _now;
  late final HypixelSkyBlockHistory history;


  HypixelSkyBlockEventScheduler createEventScheduler({
    Duration reminderBefore = const Duration(minutes: 5),
    Duration refreshInterval = const Duration(minutes: 5),
    Duration lookAhead = const Duration(days: 7),
    bool includePhaseBoundaries = true,
    HypixelSkyBlockEventCallback? onEvent,
    HypixelSkyBlockEventCallback? onRemind,
  }) =>
      HypixelSkyBlockEventScheduler(
        api: this,
        reminderBefore: reminderBefore,
        refreshInterval: refreshInterval,
        lookAhead: lookAhead,
        includePhaseBoundaries: includePhaseBoundaries,
        onEvent: onEvent,
        onRemind: onRemind,
      );

  Future<HypixelSkyBlockElection> election({bool refresh = false}) async {
    final json = await _http.getJson(
      '/v2/resources/skyblock/election',
      cacheTtl: _electionCacheTtl,
      refresh: refresh,
    );
    final value = HypixelSkyBlockElection.fromJson(json);
    await history.observeElection(value);
    return value;
  }

  Future<HypixelSkyBlockMayor> mayor({bool refresh = false}) async =>
      (await election(refresh: refresh)).mayor;

  Future<List<HypixelSkyBlockNewsItem>> news({bool refresh = false}) async {
    final json = await _http.getJson(
      '/v2/skyblock/news',
      cacheTtl: _newsCacheTtl,
      refresh: refresh,
    );
    final items = ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((entry) => HypixelSkyBlockNewsItem.fromJson(
              Map<String, dynamic>.from(entry),
            ))
        .toList(growable: false);
    await history.observeNews(items);
    return items;
  }

  Future<HypixelSkyBlockBingoEventResource> bingoEvent({bool refresh = false}) async {
    final json = await _http.getJson(
      '/v2/resources/skyblock/bingo',
      cacheTtl: _bingoResourceCacheTtl,
      refresh: refresh,
    );
    return HypixelSkyBlockBingoEventResource.fromJson(json);
  }

  Future<HypixelSkyBlockPlayerBingoData?> playerBingo({
    required String uuid,
    bool refresh = false,
  }) async {
    final apiKey = _apiKeyProvider();
    if (apiKey == null || apiKey.value.isEmpty) {
      throw StateError('Hypixel API key is required for /v2/skyblock/bingo');
    }
    if (apiKey.isExpired) {
      throw StateError('Hypixel API key has expired');
    }
    try {
      final json = await _http.getJson(
        '/v2/skyblock/bingo',
        query: {'uuid': uuid},
        headers: {'API-Key': apiKey.value},
        cacheTtl: _bingoPlayerCacheTtl,
        refresh: refresh,
      );
      final value = HypixelSkyBlockPlayerBingoData.fromJson(json);
      await history.observePlayerBingo(uuid: uuid, data: value);
      return value;
    } on HypixelHttpException catch (error) {
      // Hypixel explicitly defines 404 for this endpoint as "no Bingo data
      // could be found for the provided player UUID". That is a valid
      // empty state (for example, a player who has never participated in
      // Bingo), not a transport/auth failure.
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<HypixelSkyBlockBingo> bingo({
    required String uuid,
    bool refresh = false,
  }) async {
    final event = await bingoEvent(refresh: refresh);
    final player = await playerBingo(uuid: uuid, refresh: refresh);
    return HypixelSkyBlockBingo(
      event: event,
      playerProgress: player?.eventById(event.id),
    );
  }

  Future<List<HypixelSkyBlockEvent>> events({
    DateTime? from,
    DateTime? to,
    Duration defaultRange = const Duration(days: 7),
    bool includeMayorEvents = true,
    bool refreshMayor = false,
  }) async {
    final start = (from ?? _now ?? DateTime.now()).toUtc();
    final end = (to ?? start.add(defaultRange)).toUtc();

    if (!end.isAfter(start)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final result = scheduledEvents(from: start, to: end);

    if (includeMayorEvents) {
      // Refresh/observe the current snapshot first, then reconstruct mayor
      // events from persistent history. This keeps previous mayor terms usable
      // after Hypixel moves on to a new current mayor.
      await election(refresh: refreshMayor);
      final mayorCalendar = HypixelSkyBlockMayorEventCalendar(calendar);
      for (final entry in await history.mayors()) {
        result.addAll(mayorCalendar.eventsForMayor(
          mayor: entry.mayor,
          termStart: entry.termStartAt,
          termEnd: entry.termEndAt,
          from: start,
          to: end,
        ));
      }

      // Persisted scheduled events are independent from the current mayor
      // lifetime. Keep them in the timeline even after their source mayor
      // has left office.
      for (final scheduled in await history.scheduledEventsOverlapping(
        from: start,
        to: end,
      )) {
        result.add(scheduled.toEvent());
      }

      // Reconstruct events created by observed special-mayor states. Do not
      // require the state itself to overlap the requested range: an event may
      // have started during the state and legitimately continue after that
      // state has ended.
      for (final state in await history.specialStates()) {
        if (state.kind != HypixelSkyBlockSpecialStateKind.jerryPerkpocalypse ||
            state.effectiveMayor == null) {
          continue;
        }
        result.addAll(mayorCalendar.eventsForEffectiveMayorState(
          effectiveMayor: state.effectiveMayor!,
          activeFrom: state.activeFrom,
          activeUntil: state.activeUntil,
          from: start,
          to: end,
        ));
      }
    }

    try {
      final bingo = await bingoEvent(refresh: refreshMayor);
      if (bingo.startAt.isBefore(end) && bingo.endAt.isAfter(start)) {
        result.add(HypixelSkyBlockEvent(
          type: HypixelSkyBlockEventType.bingo,
          name: 'Bingo - ${bingo.name}',
          category: HypixelSkyBlockEventCategory.gregorian,
          startAt: bingo.startAt,
          endAt: bingo.endAt,
          remindBeforeEnd: true,
          remindOnEnd: true,
        ));
      }
    } catch (_) {
      // Bingo resource failure must not prevent deterministic event timelines.
    }

    final deduplicated = <String, HypixelSkyBlockEvent>{};
    for (final event in result) {
      final key = '${event.type.name}|${event.startAt.millisecondsSinceEpoch}|${event.endAt.millisecondsSinceEpoch}|${event.name}';
      deduplicated.putIfAbsent(key, () => event);
    }
    result
      ..clear()
      ..addAll(deduplicated.values);

    result.sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      if (byTime != 0) return byTime;
      return a.type.index.compareTo(b.type.index);
    });
    return result;
  }

  List<HypixelSkyBlockEvent> scheduledEvents({
    DateTime? from,
    DateTime? to,
    Duration defaultRange = const Duration(days: 7),
  }) {
    final start = (from ?? _now ?? DateTime.now()).toUtc();
    final end = (to ?? start.add(defaultRange)).toUtc();

    if (!end.isAfter(start)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final result = <HypixelSkyBlockEvent>[
      ...HypixelSkyBlockEventCalendar(calendar).events(from: start, to: end),
      ...const HypixelSkyBlockRealtimeEventCalendar().events(from: start, to: end),
      ...HypixelSkyBlockContestEventCalendar(calendar).events(from: start, to: end),
    ];

    result.sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      if (byTime != 0) return byTime;
      return a.type.index.compareTo(b.type.index);
    });
    return result;
  }
}
