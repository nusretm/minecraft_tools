import 'dart:async';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

class PackageMetadataServiceFake extends MtnMinecraftContentService {
  final Map<String, MtnMinecraftContent> contents = <String, MtnMinecraftContent>{};
  final Map<String, MtnMinecraftContentVersion> versions = <String, MtnMinecraftContentVersion>{};
  final Map<String, int> contentCalls = <String, int>{};
  final Map<String, int> versionCalls = <String, int>{};
  Completer<MtnMinecraftContent>? delayedContent;

  @override
  Future<MtnMinecraftContent> getContent(String providerName, String id) async {
    final key = '$providerName:$id';
    contentCalls[key] = (contentCalls[key] ?? 0) + 1;
    final delay = delayedContent;
    if (delay != null) return delay.future;
    final result = contents[key];
    if (result == null) throw StateError('Missing content $key');
    return result;
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String providerName, String id) async {
    final key = '$providerName:$id';
    versionCalls[key] = (versionCalls[key] ?? 0) + 1;
    final result = versions[key];
    if (result == null) throw StateError('Missing version $key');
    return result;
  }
}

MtnMinecraftContent project(String id, {String? name}) => MtnMinecraftContentMod(
  key: 'modrinth:$id',
  name: name ?? id,
  providers: <MtnMinecraftContentProviderMetadata>[
    MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id),
  ],
);

MtnMinecraftContentVersion version(
  MtnMinecraftContent content,
  String id, {
  String? fileId = 'file-id',
  String hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String fileName = 'mod.jar',
  int size = 64,
  bool available = true,
}) {
  return MtnMinecraftContentVersion(
    key: 'modrinth:$id',
    content: content,
    name: id,
    version: '1.0.0',
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id),
    ],
    files: <MtnMinecraftContentFile>[
      MtnMinecraftContentFile(
        fileName: fileName,
        size: size,
        available: available,
        providers: <MtnMinecraftContentProviderMetadata>[
          if (fileId != null) MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: fileId),
        ],
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha1', value: hash),
        ],
      ),
    ],
  );
}

MtnMinecraftContentPackageItem packageItem(String id, {bool direct = true}) => MtnMinecraftContentPackageItem(
  provider: 'modrinth',
  projectId: id,
  title: id,
  type: MtnMinecraftContentType.mod,
  direct: direct,
);

MtnMinecraftContentPackageLockedVersion locked(String id, {String fileName = 'mod.jar', String? hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', int? size = 64}) =>
    MtnMinecraftContentPackageLockedVersion(
      itemKey: 'modrinth:$id',
      versionId: 'ver-$id',
      fileName: fileName,
      hashAlgorithm: hash == null ? null : 'sha1',
      hashValue: hash,
      size: size,
      fileId: 'file-id',
    );

void main() {
  test('content/version successes cache independently and refresh bypasses cached result', () async {
    final service = PackageMetadataServiceFake();
    final a = project('a');
    service.contents['modrinth:a'] = a;
    service.versions['modrinth:ver-a'] = version(a, 'ver-a');
    final cache = MtnMinecraftContentPackageMetadataCache(service);

    expect(identical(await cache.getContent('modrinth', 'a'), await cache.getContent('modrinth', 'a')), isTrue);
    expect(identical(await cache.getVersion('modrinth', 'ver-a'), await cache.getVersion('modrinth', 'ver-a')), isTrue);
    expect(service.contentCalls['modrinth:a'], 1);
    expect(service.versionCalls['modrinth:ver-a'], 1);
    expect(cache.cachedContentCount, 1);
    expect(cache.cachedVersionCount, 1);

    final refreshed = project('a', name: 'Updated');
    service.contents['modrinth:a'] = refreshed;
    expect((await cache.getContent('modrinth', 'a')).name, 'a');
    expect((await cache.getContent('modrinth', 'a', refresh: true)).name, 'Updated');
    expect(service.contentCalls['modrinth:a'], 2);

    cache.invalidateContent('modrinth', 'a');
    cache.invalidateVersion('modrinth', 'ver-a');
    expect(cache.cachedContentCount, 0);
    expect(cache.cachedVersionCount, 0);
    await cache.getContent('modrinth', 'a');
    await cache.getVersion('modrinth', 'ver-a');
    expect(service.contentCalls['modrinth:a'], 3);
    expect(service.versionCalls['modrinth:ver-a'], 2);
    cache.clear();
    expect(cache.cachedContentCount, 0);
    expect(cache.cachedVersionCount, 0);
  });

  test('parallel requests share one in-flight request and invalidated result never poisons cache', () async {
    final service = PackageMetadataServiceFake();
    final oldRequest = Completer<MtnMinecraftContent>();
    service.delayedContent = oldRequest;
    final cache = MtnMinecraftContentPackageMetadataCache(service);

    final first = cache.getContent('modrinth', 'a');
    final second = cache.getContent('modrinth', 'a');
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(service.contentCalls['modrinth:a'], 1);

    cache.invalidateContent('modrinth', 'a');
    service.delayedContent = null;
    service.contents['modrinth:a'] = project('a', name: 'Newer');
    expect((await cache.getContent('modrinth', 'a')).name, 'Newer');
    oldRequest.complete(project('a', name: 'Stale'));
    expect((await first).name, 'Stale');
    expect((await second).name, 'Stale');
    expect((await cache.getContent('modrinth', 'a')).name, 'Newer');
    expect(service.contentCalls['modrinth:a'], 2);
  });

  test('failed or mismatched content and version identities never enter cache', () async {
    final service = PackageMetadataServiceFake();
    final cache = MtnMinecraftContentPackageMetadataCache(service);
    await expectLater(cache.getContent('modrinth', 'a'), throwsStateError);
    expect(cache.cachedContentCount, 0);

    service.contents['modrinth:a'] = project('wrong');
    await expectLater(cache.getContent('modrinth', 'a'), throwsFormatException);
    expect(cache.cachedContentCount, 0);

    final a = project('a');
    service.contents['modrinth:a'] = a;
    await cache.getContent('modrinth', 'a');
    service.versions['modrinth:ver-a'] = version(a, 'wrong-version');
    await expectLater(cache.getVersion('modrinth', 'ver-a'), throwsFormatException);
    expect(cache.cachedVersionCount, 0);
    expect(service.contentCalls['modrinth:a'], 3);
  });

  test('locked hydration resolves exact version and artifact without changing serialized state', () async {
    final service = PackageMetadataServiceFake();
    final content = project('a');
    service.contents['modrinth:a'] = content;
    service.versions['modrinth:ver-a'] = version(content, 'ver-a');
    final item = packageItem('a');
    final cache = MtnMinecraftContentPackageMetadataCache(service);
    await item.hydrate(service, cache: cache, lock: locked('a'));

    expect(item.state, MtnMinecraftContentItemState.loaded);
    expect(item.content, same(content));
    expect(item.version, same(service.versions['modrinth:ver-a']));
    expect(item.file!.fileName, 'mod.jar');
    expect(item.loadError, isNull);
    expect(item.toMap().containsKey('version'), isFalse);
    expect(item.toMap().containsKey('file'), isFalse);
    expect(item.toMap().containsKey('state'), isFalse);
    expect(service.versionCalls['modrinth:ver-a'], 1);
  });

  test('file mismatch errors remain isolated, explicit refresh can recover exact lock', () async {
    final service = PackageMetadataServiceFake();
    final content = project('a');
    service.contents['modrinth:a'] = content;
    service.versions['modrinth:ver-a'] = version(content, 'ver-a', hash: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    final item = packageItem('a');
    final cache = MtnMinecraftContentPackageMetadataCache(service);
    final exact = locked('a');

    await expectLater(item.hydrate(service, cache: cache, lock: exact), throwsFormatException);
    expect(item.state, MtnMinecraftContentItemState.error);
    expect(item.file, isNull);
    expect(item.version, isNull);
    expect(item.loadError, isNotNull);

    service.versions['modrinth:ver-a'] = version(content, 'ver-a');
    await item.hydrate(service, cache: cache, lock: exact, refresh: true);
    expect(item.state, MtnMinecraftContentItemState.loaded);
    expect(item.file!.fileName, 'mod.jar');
    expect(service.versionCalls['modrinth:ver-a'], 2);
  });

  test('foreign cache, foreign lock and disabled provider artifact are rejected', () async {
    final service = PackageMetadataServiceFake();
    final other = PackageMetadataServiceFake();
    final item = packageItem('a');
    expect(() => item.hydrate(service, cache: MtnMinecraftContentPackageMetadataCache(other)), throwsArgumentError);
    expect(() => item.hydrate(service, lock: locked('b')), throwsArgumentError);

    final content = project('a');
    service.contents['modrinth:a'] = content;
    service.versions['modrinth:ver-a'] = version(content, 'ver-a', available: false);
    await expectLater(item.hydrate(service, lock: locked('a')), throwsFormatException);
    expect(item.state, MtnMinecraftContentItemState.error);
  });

  test('sequential package hydration continues after one exact version failure', () async {
    final service = PackageMetadataServiceFake();
    for (final id in <String>['a', 'b', 'lib']) {
      final content = project(id);
      service.contents['modrinth:$id'] = content;
      service.versions['modrinth:ver-$id'] = version(content, 'ver-$id', fileName: id == 'b' ? 'mismatch.jar' : 'mod.jar');
    }
    final package = MtnMinecraftContentPackage(
      id: 'example',
      title: 'Example',
      minecraftVersion: '1.21.11',
      modLoader: MtnMinecraftModLoaderType.fabric,
      items: <MtnMinecraftContentPackageItem>[
        packageItem('b'),
        packageItem('lib', direct: false),
        packageItem('a'),
      ],
      lock: MtnMinecraftContentPackageLock(
        versions: <MtnMinecraftContentPackageLockedVersion>[
          locked('a'), locked('b'), locked('lib'),
        ],
        edges: <MtnMinecraftContentPackageLockedEdge>[
          MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:a', targetKey: 'modrinth:lib', type: MtnMinecraftContentDependencyType.required),
          MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:b', targetKey: 'modrinth:lib', type: MtnMinecraftContentDependencyType.required),
        ],
      ),
    );
    final exportBefore = package.toJson();
    await package.hydrateSequential(service);
    expect(package.getItem('modrinth:a')!.state, MtnMinecraftContentItemState.loaded);
    expect(package.getItem('modrinth:lib')!.state, MtnMinecraftContentItemState.loaded);
    expect(package.getItem('modrinth:b')!.state, MtnMinecraftContentItemState.error);
    expect(package.toJson(), exportBefore);
    expect(package.effectiveEnabled(package.getItem('modrinth:lib')!), isTrue);
    expect(service.versionCalls.length, 3);
  });
}
