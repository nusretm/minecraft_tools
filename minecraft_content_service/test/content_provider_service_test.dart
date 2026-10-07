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
    });
  });
}

class _FakeContentProvider extends MtnMinecraftContentProvider {
  _FakeContentProvider({
    required super.name,
    required this.content,
    List<MtnMinecraftContentVersion>? versions,
  }) : versions = List<MtnMinecraftContentVersion>.unmodifiable(versions ?? <MtnMinecraftContentVersion>[]);

  final MtnMinecraftContent content;
  final List<MtnMinecraftContentVersion> versions;

  int searchCount = 0;
  MtnMinecraftContentSearchRequest? lastSearchRequest;
  String? lastContentId;
  MtnMinecraftContent? lastVersionsContent;
  MtnMinecraftContentVersionListRequest? lastVersionsRequest;

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    searchCount++;
    lastSearchRequest = request;
    return MtnMinecraftContentSearchResult(
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
