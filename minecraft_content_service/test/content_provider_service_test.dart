import 'dart:async';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentProviderList', () {
    test('preserves registration order and rejects duplicate provider names', () {
      final contentA = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final contentB = MtnMinecraftContentMod(key: 'content-b', name: 'Content B');
      final providerA = _FakeContentProvider(name: 'provider-a', content: contentA);
      final providerB = _FakeContentProvider(name: 'provider-b', content: contentB);
      final providers = MtnMinecraftContentProviderList();

      providers.register(providerA);
      providers.register(providerB);

      expect(providers.items, <MtnMinecraftContentProvider>[providerA, providerB]);
      expect(providers.getFromName('provider-a'), same(providerA));
      expect(providers.requireFromName('provider-b'), same(providerB));

      expect(
        () => providers.register(_FakeContentProvider(name: 'provider-a', content: contentB)),
        throwsStateError,
      );

      expect(providers.unregister('provider-a'), isTrue);
      expect(providers.unregister('provider-a'), isFalse);
      expect(providers.items, <MtnMinecraftContentProvider>[providerB]);
    });

    test('registered providers remain visible even when they are not ready', () {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content, ready: false);
      final providers = MtnMinecraftContentProviderList(<MtnMinecraftContentProvider>[provider]);

      expect(providers.items.single, same(provider));
      expect(providers.items.single.ready, isFalse);
      expect(providers.readyItems, isEmpty);
      expect(
        () => providers.requireReadyFromName('provider-a'),
        throwsA(isA<MtnMinecraftContentProviderNotReadyException>()),
      );

      provider.ready = true;
      expect(providers.readyItems, <MtnMinecraftContentProvider>[provider]);
      expect(providers.requireReadyFromName('provider-a'), same(provider));
    });
  });

  group('MtnMinecraftContentService', () {
    test('routes operations only through the selected registered provider', () async {
      final content = MtnMinecraftContentMod(key: 'fabric-api', name: 'Fabric API');
      final version = MtnMinecraftContentVersion(
        key: 'fabric-api-1',
        content: content,
        name: 'Fabric API 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final provider = _FakeContentProvider(name: 'provider-a', content: content, versions: <MtnMinecraftContentVersion>[version]);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final searchRequest = MtnMinecraftContentSearchRequest(
        query: 'fabric',
        types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        offset: 10,
        limit: 25,
      );
      final searchResult = await service.search('provider-a', searchRequest);

      expect(searchResult.provider, 'provider-a');
      expect(searchResult.contents.single, same(content));
      expect(provider.lastSearchRequest, same(searchRequest));
      expect(provider.searchCount, 1);

      expect(await service.getContent('provider-a', 'remote-content-id'), same(content));
      expect(provider.lastContentId, 'remote-content-id');

      final versionsRequest = MtnMinecraftContentVersionListRequest(
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        releaseTypes: <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release],
        limit: 20,
      );
      final versionsResult = await service.getVersions('provider-a', content, versionsRequest);

      expect(versionsResult.versions.single, same(version));
      expect(provider.lastVersionsContent, same(content));
      expect(provider.lastVersionsRequest, same(versionsRequest));
    });

    test('searchAll queries only ready providers and preserves registration order without deduplication', () async {
      final firstContent = MtnMinecraftContentMod(key: 'provider-a:same-project', name: 'Same Project');
      final skippedContent = MtnMinecraftContentMod(key: 'provider-b:same-project', name: 'Same Project');
      final secondContent = MtnMinecraftContentMod(key: 'provider-c:same-project', name: 'Same Project');
      final firstProvider = _FakeContentProvider(name: 'provider-a', content: firstContent);
      final skippedProvider = _FakeContentProvider(name: 'provider-b', content: skippedContent, ready: false);
      final secondProvider = _FakeContentProvider(name: 'provider-c', content: secondContent);
      final service = MtnMinecraftContentService(
        providers: <MtnMinecraftContentProvider>[firstProvider, skippedProvider, secondProvider],
      );
      final request = MtnMinecraftContentSearchRequest(
        query: 'same',
        types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
        limit: 10,
      );

      final results = await service.searchAll(request);

      expect(results.map((result) => result.provider), <String>['provider-a', 'provider-c']);
      expect(results[0].contents.single, same(firstContent));
      expect(results[1].contents.single, same(secondContent));
      expect(results[0].contents.single.name, results[1].contents.single.name);
      expect(firstProvider.lastSearchRequest, same(request));
      expect(secondProvider.lastSearchRequest, same(request));
      expect(skippedProvider.searchCount, 0);
    });

    test('searchAll returns an empty list when no registered provider is ready', () async {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content, ready: false);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final results = await service.searchAll(MtnMinecraftContentSearchRequest());

      expect(results, isEmpty);
      expect(provider.searchCount, 0);
    });

    test('rejects registered providers that are not ready before dispatch', () {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content, ready: false);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      expect(
        () => service.search('provider-a', MtnMinecraftContentSearchRequest()),
        throwsA(isA<MtnMinecraftContentProviderNotReadyException>().having((error) => error.providerName, 'providerName', 'provider-a')),
      );
      expect(provider.searchCount, 0);
    });

    test('rejects unregistered providers before dispatch', () {
      final service = MtnMinecraftContentService();

      expect(
        () => service.search('missing-provider', MtnMinecraftContentSearchRequest()),
        throwsStateError,
      );
      expect(
        () => service.getContent('missing-provider', 'content-id'),
        throwsStateError,
      );
      expect(
        () => service.getVersions('missing-provider', MtnMinecraftContentMod(key: 'content-a', name: 'Content A'), MtnMinecraftContentVersionListRequest()),
        throwsStateError,
      );
    });

    test('rejects empty remote content ids', () {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      expect(() => service.getContent('provider-a', ''), throwsArgumentError);
    });
  });

  group('provider request runtime', () {
    test('serializes provider requests through the shared request gate', () async {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final events = <String>[];

      final first = provider.runRequest(() async {
        events.add('first-start');
        firstStarted.complete();
        await releaseFirst.future;
        events.add('first-end');
        return 1;
      });

      await firstStarted.future;

      final second = provider.runRequest(() async {
        events.add('second-start');
        events.add('second-end');
        return 2;
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, <String>['first-start']);

      releaseFirst.complete();

      expect(await first, 1);
      expect(await second, 2);
      expect(events, <String>['first-start', 'first-end', 'second-start', 'second-end']);
    });

    test('exposes provider-owned rate-limit state without changing readiness', () {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content);

      provider.setRateLimit(limit: 300, remaining: 12, resetAfter: const Duration(seconds: 60));

      expect(provider.ready, isTrue);
      expect(provider.rateLimit.limit, 300);
      expect(provider.rateLimit.remaining, 12);
      expect(provider.rateLimit.resetAt, isNotNull);
      expect(provider.rateLimit.limited, isFalse);
    });
  });

  group('provider request/result contracts', () {
    test('request filters are immutable and common pagination is bounded', () {
      final types = <MtnMinecraftContentType>[MtnMinecraftContentType.mod];
      final request = MtnMinecraftContentSearchRequest(types: types);

      types.add(MtnMinecraftContentType.modPack);

      expect(request.types, <MtnMinecraftContentType>[MtnMinecraftContentType.mod]);
      expect(() => request.types.add(MtnMinecraftContentType.modPack), throwsUnsupportedError);
      expect(() => MtnMinecraftContentSearchRequest(offset: -1), throwsArgumentError);
      expect(() => MtnMinecraftContentSearchRequest(limit: 0), throwsArgumentError);
      expect(() => MtnMinecraftContentSearchRequest(limit: 51), throwsArgumentError);
      expect(() => MtnMinecraftContentVersionListRequest(limit: 51), throwsArgumentError);
      expect(
        () => MtnMinecraftContentSearchResult(
          provider: ' ',
          contents: <MtnMinecraftContent>[],
          offset: 0,
          limit: 10,
          total: 0,
          hasMore: false,
        ),
        throwsArgumentError,
      );
    });
  });
}

class _FakeContentProvider extends MtnMinecraftContentProvider {
  _FakeContentProvider({
    required super.name,
    required this.content,
    this.ready = true,
    List<MtnMinecraftContentVersion>? versions,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions ?? <MtnMinecraftContentVersion>[]);

  final MtnMinecraftContent content;
  final List<MtnMinecraftContentVersion> versions;

  @override
  bool ready;

  int searchCount = 0;
  MtnMinecraftContentSearchRequest? lastSearchRequest;
  String? lastContentId;
  MtnMinecraftContent? lastVersionsContent;
  MtnMinecraftContentVersionListRequest? lastVersionsRequest;

  void setRateLimit({
    int? limit,
    int? remaining,
    Duration? resetAfter,
  }) {
    updateRateLimit(limit: limit, remaining: remaining, resetAfter: resetAfter);
  }

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    searchCount++;
    lastSearchRequest = request;
    return MtnMinecraftContentSearchResult(
      provider: name,
      contents: <MtnMinecraftContent>[content],
      offset: request.offset,
      limit: request.limit,
      total: 1,
      hasMore: false,
    );
  }

  @override
  Future<MtnMinecraftContent> getContent(String id) async {
    lastContentId = id;
    return content;
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    lastVersionsContent = content;
    lastVersionsRequest = request;
    return MtnMinecraftContentVersionListResult(
      versions: versions,
      offset: request.offset,
      limit: request.limit,
      total: versions.length,
      hasMore: false,
    );
  }
}
