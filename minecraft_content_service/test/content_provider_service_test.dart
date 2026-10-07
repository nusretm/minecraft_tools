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

    test('resolveDependencyGraph builds deterministic depth-first graph with resolved and unresolved edges', () async {
      final rootContent = MtnMinecraftContentMod(key: 'root', name: 'Root');
      final contentB = MtnMinecraftContentMod(
        key: 'provider-a:b',
        name: 'B',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'b'),
        ],
      );
      final contentC = MtnMinecraftContentMod(
        key: 'provider-a:c',
        name: 'C',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'c'),
        ],
      );
      final contentD = MtnMinecraftContentMod(
        key: 'provider-a:d',
        name: 'D',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'd'),
        ],
      );

      final dependencyD = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.tool,
        provider: 'provider-a',
        providerContentId: 'd',
        providerVersionId: 'd-v1',
      );
      final versionD = MtnMinecraftContentVersion(
        key: 'provider-a:d-v1',
        content: contentD,
        name: 'D 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final versionB = MtnMinecraftContentVersion(
        key: 'provider-a:b-v1',
        content: contentB,
        name: 'B 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[dependencyD],
      );
      final versionCOld = MtnMinecraftContentVersion(
        key: 'provider-a:c-v1',
        content: contentC,
        name: 'C 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        publishedAt: DateTime.utc(2026, 1, 1),
      );
      final versionCNew = MtnMinecraftContentVersion(
        key: 'provider-a:c-v2',
        content: contentC,
        name: 'C 2',
        version: '2',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        publishedAt: DateTime.utc(2026, 2, 1),
      );

      final dependencyB = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'provider-a',
        providerContentId: 'b',
        providerVersionId: 'b-v1',
      );
      final dependencyC = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.optional,
        provider: 'provider-a',
        providerContentId: 'c',
        versionConstraint: 'ignored-by-this-checkpoint',
      );
      final unresolvedDependency = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.incompatible,
        fileName: 'missing.jar',
      );
      final root = MtnMinecraftContentVersion(
        key: 'root:v1',
        content: rootContent,
        name: 'Root 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        gameVersions: <String>['1.21.1'],
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[dependencyB, dependencyC, unresolvedDependency],
      );

      final provider = _GraphContentProvider(
        name: 'provider-a',
        contentsById: <String, MtnMinecraftContent>{
          'b': contentB,
          'c': contentC,
          'd': contentD,
        },
        versionsById: <String, MtnMinecraftContentVersion>{
          'b-v1': versionB,
          'd-v1': versionD,
        },
        versionsByContentId: <String, List<MtnMinecraftContentVersion>>{
          'c': <MtnMinecraftContentVersion>[versionCOld, versionCNew],
        },
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final graph = await service.resolveDependencyGraph(
        root,
        MtnMinecraftContentVersionSelectionRequest(
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          releaseTypes: <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release],
        ),
      );

      expect(graph.root, same(root));
      expect(graph.versions.first, same(root));
      expect(graph.versions.map((version) => version.key), <String>['root:v1', 'provider-a:b-v1', 'provider-a:d-v1', 'provider-a:c-v2']);
      expect(graph.edges.map((edge) => edge.source.key), <String>['root:v1', 'provider-a:b-v1', 'root:v1', 'root:v1']);
      expect(graph.edges.map((edge) => edge.target?.key), <String?>['provider-a:b-v1', 'provider-a:d-v1', 'provider-a:c-v2', null]);
      expect(
        graph.edges.map((edge) => edge.dependency.type),
        <MtnMinecraftContentDependencyType>[
          MtnMinecraftContentDependencyType.required,
          MtnMinecraftContentDependencyType.tool,
          MtnMinecraftContentDependencyType.optional,
          MtnMinecraftContentDependencyType.incompatible,
        ],
      );
      expect(graph.unresolvedEdges.single.dependency, same(unresolvedDependency));
      expect(graph.cyclicEdges, isEmpty);
      expect(provider.versionIds, <String>['b-v1', 'd-v1']);
      expect(provider.contentIds, <String>['c']);
      expect(provider.versionListContentIds, <String>['c']);
      expect(root.dependencies, <MtnMinecraftContentDependency>[dependencyB, dependencyC, unresolvedDependency]);
      expect(dependencyC.content, isNull);
      expect(dependencyC.version, isNull);
    });

    test('resolveDependencyGraph collapses shared version nodes and expands them only once', () async {
      final rootContent = MtnMinecraftContentMod(key: 'root', name: 'Root');
      final contentB = MtnMinecraftContentMod(
        key: 'provider-a:b',
        name: 'B',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'b')],
      );
      final contentC = MtnMinecraftContentMod(
        key: 'provider-a:c',
        name: 'C',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'c')],
      );
      final contentD = MtnMinecraftContentMod(
        key: 'provider-a:d',
        name: 'D',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'd')],
      );
      final contentE = MtnMinecraftContentMod(
        key: 'provider-a:e',
        name: 'E',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'e')],
      );

      final dependencyE = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'provider-a',
        providerContentId: 'e',
        providerVersionId: 'e-v1',
      );
      final dependencyDFromB = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'provider-a',
        providerContentId: 'd',
        providerVersionId: 'd-v1',
      );
      final dependencyDFromC = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.optional,
        provider: 'provider-a',
        providerContentId: 'd',
        providerVersionId: 'd-v1',
      );

      final versionE = MtnMinecraftContentVersion(
        key: 'provider-a:e-v1',
        content: contentE,
        name: 'E 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final versionD = MtnMinecraftContentVersion(
        key: 'provider-a:d-v1',
        content: contentD,
        name: 'D 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[dependencyE],
      );
      final versionB = MtnMinecraftContentVersion(
        key: 'provider-a:b-v1',
        content: contentB,
        name: 'B 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[dependencyDFromB],
      );
      final versionC = MtnMinecraftContentVersion(
        key: 'provider-a:c-v1',
        content: contentC,
        name: 'C 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[dependencyDFromC],
      );
      final root = MtnMinecraftContentVersion(
        key: 'root:v1',
        content: rootContent,
        name: 'Root 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'b', providerVersionId: 'b-v1'),
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'c', providerVersionId: 'c-v1'),
        ],
      );

      final provider = _GraphContentProvider(
        name: 'provider-a',
        contentsById: <String, MtnMinecraftContent>{
          'b': contentB,
          'c': contentC,
          'd': contentD,
          'e': contentE,
        },
        versionsById: <String, MtnMinecraftContentVersion>{
          'b-v1': versionB,
          'c-v1': versionC,
          'd-v1': versionD,
          'e-v1': versionE,
        },
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final graph = await service.resolveDependencyGraph(root, MtnMinecraftContentVersionSelectionRequest());

      expect(graph.versions.map((version) => version.key), <String>['root:v1', 'provider-a:b-v1', 'provider-a:d-v1', 'provider-a:e-v1', 'provider-a:c-v1']);
      expect(graph.versions.where((version) => version.key == 'provider-a:d-v1'), hasLength(1));
      expect(graph.edges.map((edge) => edge.source.key + '->' + (edge.target?.key ?? 'null')), <String>[
        'root:v1->provider-a:b-v1',
        'provider-a:b-v1->provider-a:d-v1',
        'provider-a:d-v1->provider-a:e-v1',
        'root:v1->provider-a:c-v1',
        'provider-a:c-v1->provider-a:d-v1',
      ]);
      expect(graph.edges.where((edge) => edge.source.key == 'provider-a:d-v1'), hasLength(1));
      expect(provider.versionIds.where((id) => id == 'd-v1'), hasLength(2));
    });

    test('resolveDependencyGraph preserves cyclic edge and stops recursive expansion', () async {
      final contentA = MtnMinecraftContentMod(
        key: 'provider-a:a',
        name: 'A',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'a')],
      );
      final contentB = MtnMinecraftContentMod(
        key: 'provider-a:b',
        name: 'B',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'b')],
      );
      final contentC = MtnMinecraftContentMod(
        key: 'provider-a:c',
        name: 'C',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'c')],
      );

      final versionC = MtnMinecraftContentVersion(
        key: 'provider-a:c-v1',
        content: contentC,
        name: 'C 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'a', providerVersionId: 'a-v1'),
        ],
      );
      final versionB = MtnMinecraftContentVersion(
        key: 'provider-a:b-v1',
        content: contentB,
        name: 'B 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'c', providerVersionId: 'c-v1'),
        ],
      );
      final root = MtnMinecraftContentVersion(
        key: 'provider-a:a-v1',
        content: contentA,
        name: 'A 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'b', providerVersionId: 'b-v1'),
        ],
      );

      final provider = _GraphContentProvider(
        name: 'provider-a',
        contentsById: <String, MtnMinecraftContent>{
          'a': contentA,
          'b': contentB,
          'c': contentC,
        },
        versionsById: <String, MtnMinecraftContentVersion>{
          'a-v1': root,
          'b-v1': versionB,
          'c-v1': versionC,
        },
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final graph = await service.resolveDependencyGraph(root, MtnMinecraftContentVersionSelectionRequest());

      expect(graph.versions.map((version) => version.key), <String>['provider-a:a-v1', 'provider-a:b-v1', 'provider-a:c-v1']);
      expect(graph.edges, hasLength(3));
      expect(graph.cyclicEdges, hasLength(1));
      expect(graph.cyclicEdges.single.source, same(versionC));
      expect(graph.cyclicEdges.single.target, same(root));
      expect(graph.cyclicEdges.single.cyclic, isTrue);
      expect(graph.unresolvedEdges, isEmpty);
    });

    test('resolveDependencyGraph marks a direct self dependency as cyclic without duplicating the root', () async {
      final content = MtnMinecraftContentMod(
        key: 'provider-a:a',
        name: 'A',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'a')],
      );
      final root = MtnMinecraftContentVersion(
        key: 'provider-a:a-v1',
        content: content,
        name: 'A 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.required, provider: 'provider-a', providerContentId: 'a', providerVersionId: 'a-v1'),
        ],
      );
      final provider = _GraphContentProvider(
        name: 'provider-a',
        contentsById: <String, MtnMinecraftContent>{'a': content},
        versionsById: <String, MtnMinecraftContentVersion>{'a-v1': root},
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

      final graph = await service.resolveDependencyGraph(root, MtnMinecraftContentVersionSelectionRequest());

      expect(graph.versions, <MtnMinecraftContentVersion>[root]);
      expect(graph.edges, hasLength(1));
      expect(graph.cyclicEdges.single.target, same(root));
      expect(graph.cyclicEdges.single.cyclic, isTrue);
      expect(provider.versionIds, <String>['a-v1']);
    });

    test('resolveDependencyGraph keeps providers isolated and graph collections immutable', () async {
      final rootContent = MtnMinecraftContentMod(key: 'root', name: 'Root');
      final contentA = MtnMinecraftContentMod(
        key: 'provider-a:a',
        name: 'A',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-a', id: 'a')],
      );
      final contentB = MtnMinecraftContentMod(
        key: 'provider-b:b',
        name: 'B',
        providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'provider-b', id: 'b')],
      );
      final versionA = MtnMinecraftContentVersion(
        key: 'provider-a:a-v1',
        content: contentA,
        name: 'A 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final versionB = MtnMinecraftContentVersion(
        key: 'provider-b:b-v1',
        content: contentB,
        name: 'B 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final root = MtnMinecraftContentVersion(
        key: 'root:v1',
        content: rootContent,
        name: 'Root 1',
        version: '1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.included, provider: 'provider-a', providerContentId: 'a', providerVersionId: 'a-v1'),
          MtnMinecraftContentDependency(type: MtnMinecraftContentDependencyType.embedded, provider: 'provider-b', providerContentId: 'b', providerVersionId: 'b-v1'),
        ],
      );

      final providerA = _GraphContentProvider(
        name: 'provider-a',
        contentsById: <String, MtnMinecraftContent>{'a': contentA},
        versionsById: <String, MtnMinecraftContentVersion>{'a-v1': versionA},
      );
      final providerB = _GraphContentProvider(
        name: 'provider-b',
        contentsById: <String, MtnMinecraftContent>{'b': contentB},
        versionsById: <String, MtnMinecraftContentVersion>{'b-v1': versionB},
      );
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[providerA, providerB]);

      final graph = await service.resolveDependencyGraph(root, MtnMinecraftContentVersionSelectionRequest());

      expect(graph.versions.map((version) => version.key), <String>['root:v1', 'provider-a:a-v1', 'provider-b:b-v1']);
      expect(providerA.versionIds, <String>['a-v1']);
      expect(providerB.versionIds, <String>['b-v1']);
      expect(() => graph.versions.add(versionA), throwsUnsupportedError);
      expect(() => graph.edges.clear(), throwsUnsupportedError);
      expect(() => graph.unresolvedEdges.clear(), throwsUnsupportedError);
      expect(() => graph.cyclicEdges.clear(), throwsUnsupportedError);
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

class _GraphContentProvider extends MtnMinecraftContentProvider {
  _GraphContentProvider({
    required super.name,
    required Map<String, MtnMinecraftContent> contentsById,
    required Map<String, MtnMinecraftContentVersion> versionsById,
    Map<String, List<MtnMinecraftContentVersion>>? versionsByContentId,
  }) : contentsById = Map<String, MtnMinecraftContent>.unmodifiable(contentsById),
       versionsById = Map<String, MtnMinecraftContentVersion>.unmodifiable(versionsById),
       versionsByContentId = Map<String, List<MtnMinecraftContentVersion>>.unmodifiable(
         (versionsByContentId ?? <String, List<MtnMinecraftContentVersion>>{}).map(
           (key, versions) => MapEntry(key, List<MtnMinecraftContentVersion>.unmodifiable(versions)),
         ),
       );

  final Map<String, MtnMinecraftContent> contentsById;
  final Map<String, MtnMinecraftContentVersion> versionsById;
  final Map<String, List<MtnMinecraftContentVersion>> versionsByContentId;
  final List<String> contentIds = <String>[];
  final List<String> versionIds = <String>[];
  final List<String> versionListContentIds = <String>[];

  @override
  bool get ready => true;

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    return MtnMinecraftContentSearchResult(
      provider: name,
      contents: const <MtnMinecraftContent>[],
      offset: request.offset,
      limit: request.limit,
      total: 0,
      hasMore: false,
    );
  }

  @override
  Future<MtnMinecraftContent> getContent(String id) async {
    contentIds.add(id);
    final content = contentsById[id];
    if (content == null) throw StateError('Graph fake provider ' + name + ' has no content id: ' + id);
    return content;
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String id) async {
    versionIds.add(id);
    final version = versionsById[id];
    if (version == null) throw StateError('Graph fake provider ' + name + ' has no version id: ' + id);
    return version;
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    String? contentId;
    for (final metadata in content.providers) {
      if (metadata.provider == name && metadata.id != null && metadata.id!.isNotEmpty) {
        contentId = metadata.id;
        break;
      }
    }
    if (contentId == null) throw StateError('Content ' + content.key + ' has no canonical ' + name + ' id.');

    versionListContentIds.add(contentId);
    final source = versionsByContentId[contentId] ?? const <MtnMinecraftContentVersion>[];
    final filtered = source.where((version) {
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
