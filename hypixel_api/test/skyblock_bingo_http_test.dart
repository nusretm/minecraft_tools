import 'dart:convert';
import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('authenticated Bingo request sends API-Key but does not require it in cache identity', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temp = await Directory.systemTemp.createTemp('hypixel_bingo_test_');
    String? receivedApiKey;

    final serve = () async {
      final request = await server.first;
      receivedApiKey = request.headers.value('API-Key');
      expect(request.uri.path, '/v2/skyblock/bingo');
      expect(request.uri.queryParameters['uuid'], 'abc');
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('RateLimit-Limit', '60');
      request.response.headers.set('RateLimit-Remaining', '59');
      request.response.headers.set('RateLimit-Reset', '42');
      request.response.write(jsonEncode({
        'success': true,
        'events': [
          {'key': 58, 'points': 10, 'completed_goals': ['goal_a']}
        ],
      }));
      await request.response.close();
    }();

    final cache = HypixelFileCache(directory: temp);
    final http = HypixelHttpClient(
      cache: cache,
      baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
    );
    final json = await http.getJson(
      '/v2/skyblock/bingo',
      query: const {'uuid': 'abc'},
      headers: const {'API-Key': 'secret-key'},
    );
    expect(json['success'], true);
    await serve;
    expect(receivedApiKey, 'secret-key');
    expect(http.rateLimitState?.limit, 60);
    expect(http.rateLimitState?.remaining, 59);
    expect(http.rateLimitState?.resetAfter, const Duration(seconds: 42));

    final files = <File>[];
    await for (final entity in temp.list()) {
      if (entity is File) files.add(entity);
    }
    expect(files, hasLength(1));
    final cacheText = await files.single.readAsString();
    expect(cacheText, isNot(contains('secret-key')));

    http.close(force: true);
    await server.close(force: true);
    await temp.delete(recursive: true);
  });


  test('player Bingo 404 is treated as no participation data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temp = await Directory.systemTemp.createTemp('hypixel_bingo_404_test_');

    final serve = () async {
      final request = await server.first;
      expect(request.uri.path, '/v2/skyblock/bingo');
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'cause': 'No bingo data could be found',
      }));
      await request.response.close();
    }();

    final cache = HypixelFileCache(directory: temp);
    final http = HypixelHttpClient(
      cache: cache,
      baseUri: Uri.parse('http://${server.address.address}:${server.port}'),
    );
    final dataStore = HypixelDataStore(folder: temp.path);
    final skyBlock = HypixelSkyBlockApi(
      http: http,
      dataStore: dataStore,
      apiKeyProvider: () => HypixelApiKey(
        value: 'test-key',
        type: HypixelApiKeyType.development,
      ),
    );

    final result = await skyBlock.playerBingo(uuid: 'abc');
    expect(result, isNull);

    await serve;
    http.close(force: true);
    await server.close(force: true);
    await temp.delete(recursive: true);
  });
}
