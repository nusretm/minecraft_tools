import 'dart:convert';
import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('query order shares cache while different query gets another entry', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_api_cache_test_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    var sawPersistentRequest = false;

    final subscription = server.listen((request) async {
      requests++;
      sawPersistentRequest = sawPersistentRequest || request.persistentConnection;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'request': requests}));
      await request.response.close();
    });

    final cache = HypixelFileCache(directory: Directory('${temp.path}${Platform.pathSeparator}cache'));
    final client = HypixelHttpClient(
      cache: cache,
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    try {
      final first = await client.getJson('/test', query: {'b': 2, 'a': 1});
      final same = await client.getJson('/test', query: {'a': 1, 'b': 2});
      final different = await client.getJson('/test', query: {'a': 1, 'b': 3});

      expect(first['request'], 1);
      expect(same['request'], 1);
      expect(different['request'], 2);
      expect(requests, 2);
      expect(sawPersistentRequest, isFalse);
      expect((await cache.directory.list().where((e) => e is File && e.path.endsWith('.json')).length), 2);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('refresh bypasses a valid cache entry', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_api_refresh_test_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    var sawPersistentRequest = false;
    final subscription = server.listen((request) async {
      requests++;
      sawPersistentRequest = sawPersistentRequest || request.persistentConnection;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'request': requests}));
      await request.response.close();
    });

    final client = HypixelHttpClient(
      cache: HypixelFileCache(directory: Directory('${temp.path}${Platform.pathSeparator}cache')),
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    try {
      await client.getJson('/test');
      await client.getJson('/test');
      await client.getJson('/test', refresh: true);
      expect(requests, 2);
      expect(sawPersistentRequest, isFalse);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}
