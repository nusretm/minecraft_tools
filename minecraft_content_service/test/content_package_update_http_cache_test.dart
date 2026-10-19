import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

class UpdatesProviderFake extends MtnMinecraftContentProvider {
  UpdatesProviderFake(this.client) : super(name: 'updates');

  final http.Client client;
  bool failLastPage = false;

  @override
  bool get ready => true;

  Future<void> _hit(String path) async {
    final response = await httpService.send(
      client: client,
      uri: Uri.parse('https://updates.example.test/$path'),
      method: 'GET',
      headers: const <String, String>{'Accept': 'application/json'},
      enqueue: (request) => runRequest(request),
    );
    if (response.statusCode != 200) throw StateError('Metadata lookup failed.');
  }

  MtnMinecraftContent _content() => MtnMinecraftContentMod(
    key: '$name:sample',
    name: 'Sample Mod',
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: name, id: 'sample'),
    ],
  );

  MtnMinecraftContentVersion _version(String id, DateTime published) => MtnMinecraftContentVersion(
    key: '$name:$id',
    content: _content(),
    name: id,
    version: id,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    gameVersions: const <String>['1.21.11'],
    modLoaders: const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    publishedAt: published,
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: name, id: id),
    ],
  );

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) =>
      throw UnsupportedError('No search needed.');

  @override
  Future<MtnMinecraftContent> getContent(String id) async {
    await _hit('content/$id');
    return _content();
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String id) async {
    await _hit('version/$id');
    return _version(id, DateTime.utc(2026, 1, 1));
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    await _hit('versions?offset=${request.offset}');
    if (failLastPage && request.offset == 50) throw StateError('Failed second page');
    final values = request.offset == 0
        ? <MtnMinecraftContentVersion>[
            for (var i = 0; i < 50; i++) _version('older-$i', DateTime.utc(2026, 1, 1)),
          ]
        : <MtnMinecraftContentVersion>[_version('newest', DateTime.utc(2026, 10, 1))];
    return MtnMinecraftContentVersionListResult(
      versions: values, offset: request.offset, limit: request.limit,
      hasMore: request.offset == 0, total: 51,
    );
  }
}

MtnMinecraftContentPackage makeUpdatePackage() => MtnMinecraftContentPackage(
  id: 'local-test',
  title: 'Test',
  minecraftVersion: '1.21.11',
  modLoader: MtnMinecraftModLoaderType.fabric,
  loaderVersion: '0.16.14',
  ramMiB: 4096,
  ownerName: 'Test',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
  items: <MtnMinecraftContentPackageItem>[
    MtnMinecraftContentPackageItem(
      provider: 'updates', projectId: 'sample', type: MtnMinecraftContentType.mod,
      title: 'Sample Mod', direct: true, selectedVersionId: 'current',
      permissions: const <MtnMinecraftContentItemPermission>[MtnMinecraftContentItemPermission.update],
    ),
  ],
);

void main() {
  test('package checks later pages, reuses six-hour HTTP cache and bypasses it when forced', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final provider = UpdatesProviderFake(client);
    final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
    final package = makeUpdatePackage();

    await package.checkUpdates(service: service);
    expect(package.updateList.values.single.key, 'updates:newest');
    expect(package.getItem('updates:sample')!.canUpdate, isTrue);
    final checkedAt = package.lastSuccessfulUpdateCheckAt!;
    expect(package.needsUpdateCheck(now: checkedAt.add(const Duration(hours: 5))), isFalse);
    expect(package.needsUpdateCheck(now: checkedAt.add(const Duration(hours: 6))), isTrue);
    expect(calls, 4); // content, selected version and two version pages

    final reloaded = MtnMinecraftContentPackage.fromLocalMap(package.toLocalMap());
    expect(reloaded.lastSuccessfulUpdateCheckAt, checkedAt);
    expect(reloaded.updateList.values.single.key, 'updates:newest'); // restored before attaching service
    await reloaded.restoreCachedUpdates(service);
    expect(reloaded.updateList.values.single.key, 'updates:newest');
    expect(calls, 4); // pure cache restoration; no provider call

    await reloaded.checkUpdates(force: true);
    expect(reloaded.updateList.values.single.key, 'updates:newest');
    expect(calls, 8); // fresh content, selected version and two pages
  });

  test('failed later page does not replace a previously valid updateList', () async {
    var calls = 0;
    final provider = UpdatesProviderFake(MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    }));
    final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
    final package = makeUpdatePackage();
    await package.checkUpdates(service: service);
    provider.failLastPage = true;

    final lastSuccessful = package.lastSuccessfulUpdateCheckAt;
    await expectLater(package.checkUpdates(force: true), throwsStateError);
    expect(package.updateList.values.single.key, 'updates:newest');
    expect(package.lastSuccessfulUpdateCheckAt, lastSuccessful);
    expect(calls, 8);
  });

  test('local update snapshot is ignored after selection changes and is never published', () async {
    final provider = UpdatesProviderFake(MockClient((request) async => http.Response('{}', 200)));
    final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
    final package = makeUpdatePackage();
    await package.checkUpdates(service: service);
    final local = package.toLocalMap();
    expect(local['localUpdateCheck'], isNotNull);
    expect(package.lastSuccessfulUpdateCheckAt, isNotNull);

    final changed = Map<String, dynamic>.from(local);
    changed['items'] = (local['items'] as List).map((value) => Map<String, dynamic>.from(value as Map)).toList(growable: false);
    final items = (changed['items'] as List).cast<Map<String, dynamic>>();
    items.single['selectedVersionId'] = 'other';
    final stale = MtnMinecraftContentPackage.fromLocalMap(changed);
    expect(stale.updateList, isEmpty);
    expect(stale.lastSuccessfulUpdateCheckAt, isNull);
    expect(stale.needsUpdateCheck(), isTrue);

    final readOnly = Map<String, dynamic>.from(local)..['mutationPolicy'] = 'readOnly';
    final blocked = MtnMinecraftContentPackage.fromLocalMap(readOnly);
    expect(blocked.hasUpdateEligibleItems, isFalse);
    expect(blocked.updateList, isEmpty);
    expect(blocked.needsUpdateCheck(), isFalse);

    final updated = MtnMinecraftContentPackage.fromLocalMap(local);
    expect(updated.updateList.length, 1);
    expect(updated.lastSuccessfulUpdateCheckAt, isNotNull);
    // The portable map does not contain any machine-local update metadata.
    // This package is an unlocked local draft; portable serialization needs
    // a full lock, so only the local map is inspected here.
    expect(local['localUpdateCheck']['updates'], hasLength(1));
  });

  test('record storage restores cached updates without network and skips an empty cache', () async {
    const id = '13b7c070-0fa9-47ac-b907-ff1822404ca9';
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final directory = await Directory.systemTemp.createTemp('content-update-cache-');
    try {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });
      final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[UpdatesProviderFake(client)]);
      final storage = MtnMinecraftContentPackageRecordStorage(directory: directory, contentService: service);
      await storage.save(id, MtnMinecraftContentPackageRecord(
        package: makeUpdatePackage(), source: MtnMinecraftContentPackageSource.local,
      ), key: key, keyId: 'test-key');

      final cold = (await storage.load(id, key: key))!;
      expect(cold.package.updateList, isEmpty);
      expect(calls, 0);
      await cold.package.checkUpdates();
      expect(calls, 4);
      final warm = (await storage.load(id, key: key))!;
      expect(warm.package.updateList.values.single.key, 'updates:newest');
      expect(calls, 4);

      // The app will save the updated encrypted record after a successful
      // check. A completely new service has no HTTP response cache.
      await storage.save(id, cold, key: key, keyId: 'test-key');
      var restartedCalls = 0;
      final restarted = MtnMinecraftContentPackageRecordStorage(
        directory: directory,
        contentService: MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[
          UpdatesProviderFake(MockClient((request) async {
            restartedCalls++;
            return http.Response('{}', 200);
          })),
        ]),
      );
      final persisted = (await restarted.load(id, key: key))!.package;
      expect(persisted.updateList.values.single.key, 'updates:newest');
      expect(persisted.lastSuccessfulUpdateCheckAt, isNotNull);
      expect(persisted.needsUpdateCheck(), isFalse);
      expect(restartedCalls, 0);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
