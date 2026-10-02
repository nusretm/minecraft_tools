import 'dart:convert';
import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('news endpoint is keyless, cached, parsed, and persisted to history', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temp = await Directory.systemTemp.createTemp('hypixel_news_test_');
    var requestCount = 0;

    Future<void> serveOne() async {
      final request = await server.first;
      requestCount++;
      expect(request.uri.path, '/v2/skyblock/news');
      expect(request.headers.value('API-Key'), isNull);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'items': [
          {
            'item': {'material': 'INK_SACK', 'data': 3},
            'link': 'https://hypixel.net/threads/6147732/',
            'text': '1st September 2026',
            'title': 'SkyBlock v0.27.1',
          },
          {
            'item': {'material': 'GOLD_AXE'},
            'link': 'https://hypixel.net/threads/6132090/',
            'text': '4th August 2026',
            'title': 'SkyBlock v0.27',
          },
        ],
      }));
      await request.response.close();
    }

    final cache = HypixelFileCache(
      directory: Directory('${temp.path}${Platform.pathSeparator}cache'),
    );
    final http = HypixelHttpClient(
      cache: cache,
      baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
    );
    final dataStore = HypixelDataStore(folder: temp.path);
    final skyBlock = HypixelSkyBlockApi(
      http: http,
      dataStore: dataStore,
      apiKeyProvider: () => null,
      newsCacheTtl: const Duration(hours: 1),
    );

    final serving = serveOne();
    final first = await skyBlock.news();
    await serving;
    expect(first, hasLength(2));
    expect(first.first.title, 'SkyBlock v0.27.1');
    expect(first.first.text, '1st September 2026');
    expect(first.first.icon.material, 'INK_SACK');
    expect(first.first.icon.data, 3);

    final second = await skyBlock.news();
    expect(second, hasLength(2));
    expect(requestCount, 1, reason: 'second call should use request cache');

    final history = await skyBlock.history.news();
    expect(history, hasLength(2));
    expect(history.map((e) => e.item.title), contains('SkyBlock v0.27'));
    expect(await dataStore.historyFile('skyblock_news').exists(), isTrue);

    http.close(force: true);
    await server.close(force: true);
    await temp.delete(recursive: true);
  });

  test('news history deduplicates by official link and keeps first observation', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_news_history_test_');
    try {
      final history = HypixelSkyBlockHistory(
        store: HypixelDataStore(folder: temp.path),
        calendar: const HypixelSkyBlockCalendar(),
      );
      const item1 = HypixelSkyBlockNewsItem(
        title: 'SkyBlock v0.27',
        text: '4th August 2026',
        link: 'https://hypixel.net/threads/6132090/',
        icon: HypixelSkyBlockNewsItemIcon(material: 'GOLD_AXE'),
      );
      const item2 = HypixelSkyBlockNewsItem(
        title: 'SkyBlock v0.27 (updated title)',
        text: '4th August 2026',
        link: 'https://hypixel.net/threads/6132090/',
        icon: HypixelSkyBlockNewsItemIcon(material: 'GOLD_AXE'),
      );
      final firstAt = DateTime.utc(2026, 10, 1, 10);
      final secondAt = DateTime.utc(2026, 10, 1, 11);

      await history.observeNews(const [item1], observedAt: firstAt);
      await history.observeNews(const [item2], observedAt: secondAt);

      final entries = await history.news();
      expect(entries, hasLength(1));
      expect(entries.single.item.title, 'SkyBlock v0.27 (updated title)');
      expect(entries.single.firstObservedAt, firstAt);
      expect(entries.single.lastObservedAt, secondAt);
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}
