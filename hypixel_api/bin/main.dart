import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }

  final days = _readDays(args) ?? 7;
  if (days <= 0) {
    stderr.writeln('--days must be greater than zero.');
    exitCode = 64;
    return;
  }

  final dataFolder = _readValue(args, '--data-folder');
  final refresh = args.contains('--refresh');
  final showMayor = args.contains('--mayor');
  final showHistory = args.contains('--history');
  final mayorStatsName = _readValue(args, '--mayor-stats');
  final perkStatsName = _readValue(args, '--perk-stats');
  final eventOnly = args.contains('--event-only');
  final bingoUuid = _readValue(args, '--bingo');
  final bingoHistoryUuid = _readValue(args, '--bingo-history');
  final bingoStatsUuid = _readValue(args, '--bingo-stats');
  final showNews = args.contains('--news');
  final showNewsHistory = args.contains('--news-history');

  final apiKeyValue = _readValue(args, '--api-key') ??
      Platform.environment['HYPIXEL_API_KEY'];
  final apiKey = apiKeyValue == null || apiKeyValue.trim().isEmpty
      ? null
      : HypixelApiKey(
          value: apiKeyValue.trim(),
          type: HypixelApiKeyType.development,
        );

  final api = HypixelApi(dataFolder: dataFolder, apiKey: apiKey);
  try {
    final now = DateTime.now().toUtc();
    final skyBlockNow = api.skyBlock.calendar.fromDateTime(now);

    print('Hypixel SkyBlock');
    print('UTC now:      ${now.toIso8601String()}');
    print('SkyBlock now: $skyBlockNow');
    print('Data folder:  ${api.dataFolder}');

    if (showNews) {
      print('');
      final items = await api.skyBlock.news(refresh: refresh);
      print('SkyBlock news (${items.length}):');
      if (items.isEmpty) {
        print('  No news items.');
      } else {
        for (final item in items) {
          print('  ${item.title} - ${item.text}');
          print('    ${item.link}');
        }
      }
      return;
    }

    if (showNewsHistory) {
      print('');
      await api.skyBlock.news(refresh: refresh);
      final entries = await api.skyBlock.history.news();
      print('SkyBlock news history (${entries.length}):');
      if (entries.isEmpty) {
        print('  No observed news items.');
      } else {
        for (final entry in entries) {
          print('  ${entry.item.title} - ${entry.item.text}');
          print('    ${entry.item.link}');
          print('    first: ${entry.firstObservedAt.toIso8601String()}');
          print('    last:  ${entry.lastObservedAt.toIso8601String()}');
        }
      }
      return;
    }

    if (bingoHistoryUuid != null) {
      _requireApiKey(api, '--bingo-history');
      print('');
      await api.skyBlock.playerBingo(uuid: bingoHistoryUuid, refresh: refresh);
      final entries =
          await api.skyBlock.history.bingoHistory(uuid: bingoHistoryUuid);
      print('Bingo history (${entries.length}):');
      if (entries.isEmpty) {
        print('  No observed Bingo participation.');
      } else {
        for (final entry in entries) {
          print('  #${entry.eventId}: ${entry.points} points, '
              '${entry.completedGoals.length} completed goals');
        }
      }
      return;
    }

    if (bingoStatsUuid != null) {
      _requireApiKey(api, '--bingo-stats');
      print('');
      await api.skyBlock.playerBingo(uuid: bingoStatsUuid, refresh: refresh);
      final stats =
          await api.skyBlock.history.bingoStats(uuid: bingoStatsUuid);
      print('Bingo stats: ${stats.uuid}');
      print('Events participated: ${stats.eventsParticipated}');
      print('Total points:        ${stats.totalPoints}');
      print('Completed goals:     ${stats.totalCompletedGoals}');
      print('Highest points:      ${stats.highestPoints ?? 'unknown'}');
      print('Last event:          '
          '${stats.lastEventId == null ? 'unknown' : '#${stats.lastEventId}'}');
      return;
    }

    if (bingoUuid != null) {
      _requireApiKey(api, '--bingo');
      print('');
      final bingo = await api.skyBlock.bingo(uuid: bingoUuid, refresh: refresh);
      print('Bingo:        ${bingo.event.name} (#${bingo.event.id})');
      print('Modifier:     ${bingo.event.modifier}');
      print('Starts:       ${bingo.event.startAt.toIso8601String()}');
      print('Ends:         ${bingo.event.endAt.toIso8601String()}');
      print('Goals:        ${bingo.event.goals.length}');
      final progress = bingo.playerProgress;
      if (progress == null) {
        print('Player data:  no progress for current Bingo');
      } else {
        print('Points:       ${progress.points}');
        print('Completed:    '
            '${progress.completedGoals.length}/${bingo.event.goals.length}');
        for (final goal in bingo.event.goals) {
          final mark = bingo.isGoalCompleted(goal.id) ? '[x]' : '[ ]';
          print('  $mark ${goal.name}');
        }
      }
      return;
    }

    if (showMayor) {
      print('');
      final election = await api.skyBlock.election(refresh: refresh);
      print('Mayor:        ${election.mayor.name}');
      if (election.mayor.perks.isEmpty) {
        print('Mayor perks:  none');
      } else {
        print('Mayor perks:');
        for (final perk in election.mayor.perks) {
          print('  - ${perk.name}');
          if (perk.description.isNotEmpty) print('    ${perk.description}');
        }
      }
      if (election.mayor.minister case final minister?) {
        print('Minister:     ${minister.name}');
        print('Minister perk: ${minister.perk.name}');
        if (minister.perk.description.isNotEmpty) {
          print('  ${minister.perk.description}');
        }
      }
      print('Last updated: ${election.lastUpdated.toIso8601String()}');
      if (election.current case final current?) {
        print('Election:     '
            'Year ${current.year} (${current.candidates.length} candidates)');
      }
      return;
    }

    if (showHistory) {
      await api.skyBlock.election(refresh: refresh);
      final mayors = await api.skyBlock.history.mayors();
      final elections = await api.skyBlock.history.elections();
      print('');
      print('Mayor history (${mayors.length}):');
      for (final entry in mayors) {
        final minister = entry.mayor.minister == null
            ? ''
            : ' / minister ${entry.mayor.minister!.name} '
                '(${entry.mayor.minister!.perk.name})';
        print('  Year ${entry.termYear}: ${entry.mayor.name}$minister');
      }
      print('Election history (${elections.length}): '
          '${elections.map((e) => e.year).join(', ')}');
      return;
    }

    if (mayorStatsName != null) {
      await api.skyBlock.election(refresh: refresh);
      final stats = await api.skyBlock.history.mayorStats(mayorStatsName);
      print('');
      print('Mayor stats: ${stats.mayorName}');
      print('Times elected: ${stats.timesElected}');
      print('Term years:    ${stats.termYears.join(', ')}');
      print('Last elected:  ${stats.lastElectedYear ?? 'unknown'}');
      print('Previous:      ${stats.previousElectedYear ?? 'unknown'}');
      return;
    }

    if (perkStatsName != null) {
      await api.skyBlock.election(refresh: refresh);
      final stats = await api.skyBlock.history.perkStats(perkStatsName);
      print('');
      print('Perk stats: ${stats.perkName}');
      print('Times observed: ${stats.timesObserved}');
      print('Last observed:  ${stats.lastObservedYear ?? 'unknown'}');
      for (final observation in stats.observations) {
        print('  Year ${observation.termYear}: '
            '${observation.mayorName} / ${observation.source.name}');
      }
      return;
    }

    print('');
    print('Events for next $days day(s):');

    final events = await api.skyBlock.events(
      from: now,
      to: now.add(Duration(days: days)),
    );
    final visibleEvents = eventOnly
        ? events
            .where((event) =>
                event.category != HypixelSkyBlockEventCategory.contest &&
                event.type != HypixelSkyBlockEventType.darkAuction)
            .toList()
        : events;

    if (visibleEvents.isEmpty) {
      print('  No events in range.');
      return;
    }

    for (final event in visibleEvents) {
      final parent = event.parentType == null ? '' : ' [child]';
      final timing =
          event.isStartMarker ? '[start marker]' : '(${event.duration.inMinutes} min)';
      print('  ${event.startAt.toIso8601String()}  '
          '${event.name}$parent  $timing');
    }
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } finally {
    api.close(force: true);
  }
}

void _requireApiKey(HypixelApi api, String option) {
  if (api.apiKey != null) return;
  throw StateError(
    '$option requires a Hypixel API key. Use --api-key <key> or set '
    'HYPIXEL_API_KEY.',
  );
}

int? _readDays(List<String> args) {
  final value = _readValue(args, '--days');
  return value == null ? null : int.tryParse(value);
}

String? _readValue(List<String> args, String option) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == option && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$option=')) {
      return args[i].substring(option.length + 1);
    }
  }
  return null;
}

void _printHelp() {
  print('Hypixel SkyBlock CLI');
  print('');
  print('Usage: dart run bin/main.dart [options]');
  print('');
  print('Events:');
  print('  --days <n>                 Event range in real days (default: 7)');
  print('  --event-only               Hide contests and Dark Auction');
  print('');
  print('Mayor/history:');
  print('  --mayor');
  print('  --history');
  print('  --mayor-stats <name>');
  print('  --perk-stats <name>');
  print('');
  print('Bingo:');
  print('  --bingo <uuid>');
  print('  --bingo-history <uuid>');
  print('  --bingo-stats <uuid>');
  print('');
  print('News:');
  print('  --news');
  print('  --news-history');
  print('');
  print('Common:');
  print('  --refresh                  Bypass request cache');
  print('  --data-folder <path>       Override persistent data root');
  print('  --api-key <key>            API key for authenticated endpoints');
  print('                              (or HYPIXEL_API_KEY environment variable)');
  print('  -h, --help                 Show this help');
}
