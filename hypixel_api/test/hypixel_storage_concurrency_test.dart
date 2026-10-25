import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

/// Reproduces concurrent access from Home and the notification scheduler.
/// These are expected contracts, not workarounds for the current .tmp race.
/// Run on Windows as well as other desktop platforms; no Hypixel network.
void main() {
  test('same cache key accepts simultaneous writes without corrupting the file', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_cache_concurrent_');
    try {
      final cache = HypixelFileCache(
        directory: Directory('${directory.path}${Platform.pathSeparator}cache'),
      );
      final now = DateTime.now().toUtc();
      final padding = List<String>.filled(16384, 'x').join();

      // Each batch targets the SAME key and therefore the same temporary
      // filename in the current implementation. Wait for every writer.
      for (int batch = 0; batch < 3; batch++) {
        await Future.wait<void>(<Future<void>>[
          for (int writer = 0; writer < 16; writer++)
            cache.write(
              key: 'same-key',
              method: 'GET',
              path: '/v2/resources/skyblock/election',
              query: const <String, String>{},
              cachedAt: now,
              expiresAt: now.add(const Duration(minutes: 10)),
              statusCode: 200,
              body: <String, dynamic>{
                'batch': batch,
                'writer': writer,
                'padding': padding,
              },
            ),
        ]);

        final entry = await cache.read('same-key');
        expect(entry, isNotNull, reason: 'No writer may publish a partial JSON cache file.');
        expect(entry!.body['batch'], batch);
        expect(entry.body['writer'], isA<int>());
        expect(entry.body['padding'], padding);
        expect(await File(
          '${cache.directory.path}${Platform.pathSeparator}same-key.json.tmp',
        ).exists(), isFalse, reason: 'No shared temporary file may remain after all writes.');
      }
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('same history name accepts simultaneous writes without losing the JSON file', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_history_concurrent_');
    try {
      final store = HypixelDataStore(folder: directory.path);
      final padding = List<String>.filled(16384, 'y').join();

      // A direct writer-level integrity contract: last writer wins, but no
      // FileSystemException, broken JSON or dangling shared .tmp is allowed.
      for (int batch = 0; batch < 3; batch++) {
        await Future.wait<void>(<Future<void>>[
          for (int writer = 0; writer < 16; writer++)
            store.writeHistory('skyblock_mayors', <String, dynamic>{
              'version': 1,
              'batch': batch,
              'writer': writer,
              'padding': padding,
            }),
        ]);

        final saved = await store.readHistory('skyblock_mayors');
        expect(saved, isNotNull, reason: 'The history file must remain valid JSON.');
        expect(saved!['batch'], batch);
        expect(saved['writer'], isA<int>());
        expect(saved['padding'], padding);
        expect(await File('${store.historyFile('skyblock_mayors').path}.tmp').exists(),
          isFalse, reason: 'No shared history temporary file may remain.');
      }
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('parallel election observations preserve all different mayor terms', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_elections_concurrent_');
    try {
      final history = HypixelSkyBlockHistory(
        store: HypixelDataStore(folder: directory.path),
        calendar: const HypixelSkyBlockCalendar(),
      );
      const count = 12;
      final snapshots = <HypixelSkyBlockElection>[
        for (int index = 0; index < count; index++)
          HypixelSkyBlockElection(
            lastUpdated: DateTime.utc(2026, 10, 25),
            mayor: HypixelSkyBlockMayor(
              key: 'mayor-$index',
              name: 'Mayor $index',
              perks: const <HypixelSkyBlockPerk>[],
              election: HypixelSkyBlockElectionRound(
                year: 600 + index,
                candidates: const <HypixelSkyBlockCandidate>[],
              ),
            ),
          ),
      ];

      // ObserveElection does a read/modify/write on shared history. Even if
      // individual renames become safe, concurrent observations must not
      // silently overwrite one another's distinct mayor terms.
      await Future.wait<void>(<Future<void>>[
        for (final snapshot in snapshots) history.observeElection(snapshot),
      ]);

      final mayors = await history.mayors();
      expect(mayors.map((entry) => entry.termYear).toSet(),
        <int>{for (int index = 0; index < count; index++) 601 + index},
        reason: 'Independent mayor observations must all survive concurrent persistence.');

      final elections = await history.elections();
      expect(elections.map((entry) => entry.year).toSet(),
        <int>{for (int index = 0; index < count; index++) 600 + index},
        reason: 'All observed election rounds must survive concurrent persistence.');
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
  test('separate store instances preserve one shared transaction history', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_history_shared_');
    try {
      final first = HypixelDataStore(folder: directory.path);
      final second = HypixelDataStore(folder: directory.path);
      await Future.wait<void>(<Future<void>>[
        for (int index = 0; index < 40; index++)
          (index.isEven ? first : second).updateHistory('counter', (previous) =>
              <String, dynamic>{'count': ((previous?['count'] as int?) ?? 0) + 1}),
      ]);
      final saved = await first.readHistory('counter');
      expect(saved?['count'], 40,
        reason: 'Store instances targeting the same file must share a read-modify-write gate.');
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('separate cache instances do not collide on the same key', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_cache_shared_');
    try {
      final folder = Directory('${directory.path}${Platform.pathSeparator}cache');
      final first = HypixelFileCache(directory: folder);
      final second = HypixelFileCache(directory: folder);
      final now = DateTime.now().toUtc();
      await Future.wait<void>(<Future<void>>[
        for (int index = 0; index < 24; index++)
          (index.isEven ? first : second).write(
            key: 'shared', method: 'GET', path: '/election',
            query: const <String, String>{},
            cachedAt: now,
            expiresAt: now.add(const Duration(minutes: 5)),
            statusCode: 200,
            body: <String, dynamic>{'writer': index},
          ),
      ]);
      final saved = await second.read('shared');
      expect(saved, isNotNull);
      expect(saved!.body['writer'], isA<int>());
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('failed history mutation releases the file queue for the next writer', () async {
    final directory = await Directory.systemTemp.createTemp('hypixel_history_failure_');
    try {
      final store = HypixelDataStore(folder: directory.path);
      await expectLater(
        store.updateHistory('records', (_) => throw StateError('synthetic failure')),
        throwsStateError,
      );
      await store.updateHistory('records', (_) => <String, dynamic>{'count': 1});
      expect((await store.readHistory('records'))?['count'], 1,
        reason: 'An operation error must not poison later writes to the same file.');
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

}
