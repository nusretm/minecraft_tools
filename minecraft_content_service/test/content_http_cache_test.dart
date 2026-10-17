import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

Future<http.Response> fetch(
  MtnMinecraftContentHttpService cache,
  http.Client client,
  Uri uri, {
  String method = 'GET',
  String? body,
  String token = 'A',
  bool cacheable = true,
  Future<bool> Function(http.Response)? onRateLimited,
  void Function(http.Response)? onResponse,
}) => cache.send(
  client: client,
  uri: uri,
  method: method,
  body: body,
  headers: <String, String>{'Accept': 'application/json', 'x-api-key': token},
  enqueue: (request) => request(),
  cacheable: cacheable,
  onRateLimited: onRateLimited,
  onResponse: onResponse,
);

void main() {
  test('same canonical URL and parameters reuse one response, default TTL is one hour', () async {
    var calls = 0;
    final client = MockClient((request) async {
      ++calls;
      return http.Response('{"ok":true}', 200);
    });
    final cache = MtnMinecraftContentHttpService();
    expect(cache.cacheDuration, const Duration(hours: 1));
    final first = await fetch(cache, client, Uri.parse('https://example.test/v2/search?b=2&a=1'));
    final second = await fetch(cache, client, Uri.parse('https://example.test/v2/search?a=1&b=2'));
    expect(first.body, second.body);
    expect(calls, 1);
    expect(cache.cachedResponseCount, 1);
    cache.clear();
    await fetch(cache, client, Uri.parse('https://example.test/v2/search?a=1&b=2'));
    expect(calls, 2);
  });

  test('in-flight equivalent requests join before entering the request gate', () async {
    var calls = 0;
    var queued = 0;
    final delayed = Completer<http.Response>();
    final client = MockClient((request) {
      ++calls;
      return delayed.future;
    });
    final cache = MtnMinecraftContentHttpService();
    final uri = Uri.parse('https://example.test/v2/project/id');
    Future<http.Response> request() => cache.send(
      client: client, uri: uri, method: 'GET',
      headers: <String, String>{'Accept': 'application/json'},
      enqueue: (work) {
        ++queued;
        return work();
      },
    );
    final first = request();
    final second = request();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(queued, 1);
    delayed.complete(http.Response('{"project":1}', 200));
    await Future.wait(<Future<http.Response>>[first, second]);
    await request();
    expect(calls, 1);
    expect(queued, 1);
  });

  test('configurable TTL expires; zero disables completed response caching', () async {
    var calls = 0;
    final client = MockClient((request) async => http.Response('${++calls}', 200));
    final uri = Uri.parse('https://example.test/v2/version/id');
    final cache = MtnMinecraftContentHttpService(cacheDuration: const Duration(milliseconds: 10));
    expect((await fetch(cache, client, uri)).body, '1');
    expect((await fetch(cache, client, uri)).body, '1');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect((await fetch(cache, client, uri)).body, '2');
    final disabled = MtnMinecraftContentHttpService(cacheDuration: Duration.zero);
    expect((await fetch(disabled, client, uri)).body, '3');
    expect((await fetch(disabled, client, uri)).body, '4');
    expect(() => MtnMinecraftContentHttpService(cacheDuration: const Duration(seconds: -1)), throwsArgumentError);
  });

  test('POST request body and auth scope separate cached responses', () async {
    var calls = 0;
    final client = MockClient((request) async {
      ++calls;
      expect(request.method, 'POST');
      return http.Response('{"data":$calls}', 200);
    });
    final cache = MtnMinecraftContentHttpService();
    final uri = Uri.parse('https://api.curseforge.test/v1/mods/files');
    final one = await fetch(cache, client, uri, method: 'POST', body: '{"fileIds":[42]}');
    final same = await fetch(cache, client, uri, method: 'POST', body: '{"fileIds":[42]}');
    final otherBody = await fetch(cache, client, uri, method: 'POST', body: '{"fileIds":[43]}');
    final otherCredential = await fetch(cache, client, uri, method: 'POST', body: '{"fileIds":[42]}', token: 'B');
    expect(one.body, same.body);
    expect(otherBody.body, isNot(one.body));
    expect(otherCredential.body, isNot(one.body));
    expect(calls, 3);
  });

  test('failed replies are not cached, 429 retry is bounded and successful final reply is cached', () async {
    var calls = 0;
    var seen = 0;
    final client = MockClient((request) async {
      ++calls;
      if (calls == 1) return http.Response('rate limited', 429);
      if (calls == 2) return http.Response('success', 200);
      return http.Response('failure', 503);
    });
    final cache = MtnMinecraftContentHttpService();
    final uri = Uri.parse('https://example.test/project/id');
    final first = await fetch(cache, client, uri,
      onResponse: (_) => ++seen,
      onRateLimited: (_) async => true,
    );
    expect(first.body, 'success');
    expect(calls, 2);
    expect(seen, 2);
    await fetch(cache, client, uri);
    expect(calls, 2);
    cache.clear();
    await fetch(cache, client, uri);
    await fetch(cache, client, uri);
    expect(calls, 4);
    expect(cache.cachedResponseCount, 0);
  });

  test('non-cacheable endpoints bypass cache without affecting other requests', () async {
    var calls = 0;
    final client = MockClient((request) async => http.Response('url-${++calls}', 200));
    final cache = MtnMinecraftContentHttpService();
    final uri = Uri.parse('https://example.test/v1/mods/1/files/2/download-url');
    expect((await fetch(cache, client, uri, cacheable: false)).body, 'url-1');
    expect((await fetch(cache, client, uri, cacheable: false)).body, 'url-2');
    expect(cache.cachedResponseCount, 0);
    expect(calls, 2);
  });

  test('one service owns all registered provider HTTP caches, including late registration', () {
    final modrinth = MtnMinecraftContentProviderModrinth(
      userAgent: 'test', client: MockClient((request) async => http.Response('{}', 200)),
    );
    final curseforge = MtnMinecraftContentProviderCurseForge(
      apiKey: 'secret', client: MockClient((request) async => http.Response('{}', 200)),
    );
    final service = MtnMinecraftContentService(
      providers: <MtnMinecraftContentProvider>[modrinth],
      cacheDuration: const Duration(minutes: 20),
    );
    service.providers.register(curseforge);
    expect(identical(modrinth.httpService, curseforge.httpService), isTrue);
    expect(service.providers.httpService.cacheDuration, const Duration(minutes: 20));
  });

  test('Modrinth local pagination reuses the same full-list HTTP response', () async {
    var calls = 0;
    final client = MockClient((request) async {
      ++calls;
      expect(request.url.path, '/v2/project/project123/version');
      return http.Response('[]', 200);
    });
    final provider = MtnMinecraftContentProviderModrinth(userAgent: 'test', client: client);
    final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
    final content = MtnMinecraftContentMod(
      key: 'modrinth:project123', name: 'Test',
      providers: <MtnMinecraftContentProviderMetadata>[
        MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'project123'),
      ],
    );
    await service.getVersions('modrinth', content, MtnMinecraftContentVersionListRequest(limit: 10, offset: 0));
    await service.getVersions('modrinth', content, MtnMinecraftContentVersionListRequest(limit: 10, offset: 10));
    expect(calls, 1);
    expect(service.providers.httpService.cachedResponseCount, 1);
  });
}
