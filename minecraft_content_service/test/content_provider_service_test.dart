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
        gameVersions: <String>['1.21.1'],
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

      expect(await service.getVersion('provider-a', 'remote-version-id'), same(version));
      expect(provider.lastVersionId, 'remote-version-id');
    });

    test('resolveDependency resolves exact version identity before content-only identity and does not guess providers', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:content-id',
        name: 'Dependency Content',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'content-id'),
        ],
      );
      final version = MtnMinecraftContentVersion(
        key: 'provider-a:version-id',
        content: content,
        name: 'Dependency Version',
        version: '1.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final provider = _FakeContentProvider(name: 'provider-a', content: content, versions: <MtnMinecraftContentVersion>[version]);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final exact = await service.resolveDependency(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
          providerVersionId: 'version-id',
        ),
      );

      expect(exact.content, same(content));
      expect(exact.version, same(version));
      expect(exact.contentResolved, isTrue);
      expect(exact.versionResolved, isTrue);
      expect(provider.lastVersionId, 'version-id');
      expect(provider.getVersionCount, 1);

      final contentOnly = await service.resolveDependency(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
        ),
      );

      expect(contentOnly.content, same(content));
      expect(contentOnly.version, isNull);
      expect(provider.lastContentId, 'content-id');

      final noProvider = await service.resolveDependency(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          fileName: 'dependency.jar',
        ),
      );

      expect(noProvider.contentResolved, isFalse);
      expect(noProvider.versionResolved, isFalse);
      expect(provider.getVersionCount, 1);
    });

    test('resolveDependency reuses already resolved versions without provider dispatch and rejects content identity mismatch', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:content-id',
        name: 'Dependency Content',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'content-id'),
        ],
      );
      final version = MtnMinecraftContentVersion(
        key: 'provider-a:version-id',
        content: content,
        name: 'Dependency Version',
        version: '1.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final provider = _FakeContentProvider(name: 'provider-a', content: content, versions: <MtnMinecraftContentVersion>[version]);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final alreadyResolved = await service.resolveDependency(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          content: content,
          version: version,
        ),
      );

      expect(alreadyResolved.content, same(content));
      expect(alreadyResolved.version, same(version));
      expect(provider.getVersionCount, 0);

      await expectLater(
        service.resolveDependency(
          MtnMinecraftContentDependency(
            type: MtnMinecraftContentDependencyType.required,
            provider: 'provider-a',
            providerContentId: 'different-content-id',
            providerVersionId: 'version-id',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('resolveDependencyVersion preserves exact versions without listing provider versions', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:content-id',
        name: 'Dependency Content',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'content-id'),
        ],
      );
      final exactVersion = MtnMinecraftContentVersion(
        key: 'provider-a:exact-version',
        content: content,
        name: 'Exact Version',
        version: '1.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final provider = _FakeContentProvider(name: 'provider-a', content: content, versions: <MtnMinecraftContentVersion>[exactVersion]);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final resolution = await service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
          providerVersionId: 'exact-version',
        ),
        MtnMinecraftContentVersionSelectionRequest(
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        ),
      );

      expect(resolution.version, same(exactVersion));
      expect(provider.getVersionCount, 1);
      expect(provider.getVersionsCount, 0);
    });

    test('resolveDependencyVersion selects the latest compatible provider version', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:content-id',
        name: 'Dependency Content',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'content-id'),
        ],
      );
      final oldCompatible = MtnMinecraftContentVersion(
        key: 'provider-a:old-compatible',
        content: content,
        name: 'Old Compatible',
        version: '1.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        publishedAt: DateTime.utc(2026, 1, 1),
      );
      final incompatibleLoader = MtnMinecraftContentVersion(
        key: 'provider-a:forge',
        content: content,
        name: 'Forge',
        version: '2.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.forge],
        publishedAt: DateTime.utc(2026, 2, 1),
      );
      final betaCompatible = MtnMinecraftContentVersion(
        key: 'provider-a:beta',
        content: content,
        name: 'Beta',
        version: '3.0.0-beta',
        releaseType: MtnMinecraftContentVersionReleaseType.beta,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        publishedAt: DateTime.utc(2026, 3, 1),
      );
      final latestCompatible = MtnMinecraftContentVersion(
        key: 'provider-a:latest-compatible',
        content: content,
        name: 'Latest Compatible',
        version: '4.0.0',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        publishedAt: DateTime.utc(2026, 4, 1),
      );
      final provider = _FakeContentProvider(
        name: 'provider-a',
        content: content,
        versions: <MtnMinecraftContentVersion>[oldCompatible, incompatibleLoader, betaCompatible, latestCompatible],
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
      final request = MtnMinecraftContentVersionSelectionRequest(
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        releaseTypes: <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release],
      );

      final resolution = await service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
          versionConstraint: 'this-is-deliberately-not-interpreted',
        ),
        request,
      );

      expect(resolution.content, same(content));
      expect(resolution.version, same(latestCompatible));
      expect(provider.getVersionsCount, 1);
      expect(provider.lastVersionsRequest!.gameVersions, request.gameVersions);
      expect(provider.lastVersionsRequest!.modLoaders, request.modLoaders);
      expect(provider.lastVersionsRequest!.releaseTypes, request.releaseTypes);
    });

    test('resolveDependencyVersion reaches the final provider page and returns unresolved version when no match exists', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:content-id',
        name: 'Dependency Content',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'content-id'),
        ],
      );
      final versions = List<MtnMinecraftContentVersion>.generate(
        51,
        (index) => MtnMinecraftContentVersion(
          key: 'provider-a:version-$index',
          content: content,
          name: 'Version $index',
          version: '$index',
          releaseType: MtnMinecraftContentVersionReleaseType.release,
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          publishedAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
        ),
      );
      final provider = _FakeContentProvider(name: 'provider-a', content: content, versions: versions);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final selected = await service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
        ),
        MtnMinecraftContentVersionSelectionRequest(
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        ),
      );

      expect(selected.version, same(versions.last));
      expect(provider.getVersionsCount, 2);
      expect(provider.versionsRequests.map((request) => request.offset), <int>[0, 50]);

      provider.resetVersionListCalls();

      final unresolved = await service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'provider-a',
          providerContentId: 'content-id',
          versionConstraint: '>=999',
        ),
        MtnMinecraftContentVersionSelectionRequest(
          gameVersions: <String>['9.9.9'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        ),
      );

      expect(unresolved.content, same(content));
      expect(unresolved.contentResolved, isTrue);
      expect(unresolved.versionResolved, isFalse);
      expect(provider.getVersionsCount, 1);
    });

    test('resolveDependencyVersion does not guess a provider or dispatch to another provider', () async {
      final contentA = MtnMinecraftContentMod(key: 'provider-a:content-id', name: 'A');
      final contentB = MtnMinecraftContentMod(key: 'provider-b:content-id', name: 'B');
      final versionB = MtnMinecraftContentVersion(
        key: 'provider-b:version-id',
        content: contentB,
        name: 'B Version',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final providerA = _FakeContentProvider(name: 'provider-a', content: contentA);
      final providerB = _FakeContentProvider(name: 'provider-b', content: contentB, versions: <MtnMinecraftContentVersion>[versionB]);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[providerA, providerB]);

      final unresolved = await service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          fileName: 'dependency.jar',
          versionConstraint: 'latest',
        ),
        MtnMinecraftContentVersionSelectionRequest(),
      );

      expect(unresolved.contentResolved, isFalse);
      expect(unresolved.versionResolved, isFalse);
      expect(providerA.getVersionsCount, 0);
      expect(providerB.getVersionsCount, 0);
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
      expect(
        () => service.getVersion('missing-provider', 'version-id'),
        throwsStateError,
      );
    });

    test('rejects empty remote content ids', () {
      final content = MtnMinecraftContentMod(key: 'content-a', name: 'Content A');
      final provider = _FakeContentProvider(name: 'provider-a', content: content);
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      expect(() => service.getContent('provider-a', ''), throwsArgumentError);
      expect(() => service.getVersion('provider-a', ''), throwsArgumentError);
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

      final selectionGameVersions = <String>['1.21.1'];
      final selectionLoaders = <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric];
      final selectionReleaseTypes = <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release];
      final selectionRequest = MtnMinecraftContentVersionSelectionRequest(
        gameVersions: selectionGameVersions,
        modLoaders: selectionLoaders,
        releaseTypes: selectionReleaseTypes,
      );
      selectionGameVersions.add('1.21.2');
      selectionLoaders.add(MtnMinecraftModLoaderType.forge);
      selectionReleaseTypes.add(MtnMinecraftContentVersionReleaseType.beta);
      expect(selectionRequest.gameVersions, <String>['1.21.1']);
      expect(selectionRequest.modLoaders, <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric]);
      expect(selectionRequest.releaseTypes, <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release]);
      expect(() => selectionRequest.gameVersions.add('1.21.2'), throwsUnsupportedError);

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
  int getVersionCount = 0;
  int getVersionsCount = 0;
  final List<MtnMinecraftContentVersionListRequest> versionsRequests = <MtnMinecraftContentVersionListRequest>[];
  MtnMinecraftContentSearchRequest? lastSearchRequest;
  String? lastContentId;
  String? lastVersionId;
  MtnMinecraftContent? lastVersionsContent;
  MtnMinecraftContentVersionListRequest? lastVersionsRequest;

  void setRateLimit({
    int? limit,
    int? remaining,
    Duration? resetAfter,
  }) {
    updateRateLimit(limit: limit, remaining: remaining, resetAfter: resetAfter);
  }

  void resetVersionListCalls() {
    getVersionsCount = 0;
    versionsRequests.clear();
    lastVersionsContent = null;
    lastVersionsRequest = null;
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
  Future<MtnMinecraftContentVersion> getVersion(String id) async {
    getVersionCount++;
    lastVersionId = id;
    if (versions.isEmpty) throw StateError('Fake provider has no versions.');
    return versions.single;
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    getVersionsCount++;
    versionsRequests.add(request);
    lastVersionsContent = content;
    lastVersionsRequest = request;

    final filtered = versions.where((version) {
      final gameVersionMatches = request.gameVersions.isEmpty || version.gameVersions.any(request.gameVersions.contains);
      final loaderMatches = request.modLoaders.isEmpty || version.modLoaders.any(request.modLoaders.contains);
      final releaseMatches = request.releaseTypes.isEmpty || request.releaseTypes.contains(version.releaseType);
      return gameVersionMatches && loaderMatches && releaseMatches;
    }).toList(growable: false);

    final start = request.offset > filtered.length ? filtered.length : request.offset;
    final end = start + request.limit > filtered.length ? filtered.length : start + request.limit;

    return MtnMinecraftContentVersionListResult(
      versions: filtered.sublist(start, end),
      offset: request.offset,
      limit: request.limit,
      total: filtered.length,
      hasMore: end < filtered.length,
    );
  }
}
