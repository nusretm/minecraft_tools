import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentProviderCurseForge', () {
    test('search discovers Minecraft classes, sends API key, and maps results', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);

        if (request.url.path == '/v1/categories') {
          return _jsonResponse(<String, dynamic>{'data': _classes()});
        }

        if (request.url.path == '/v1/mods/search') {
          return _jsonResponse(<String, dynamic>{
            'data': <Map<String, dynamic>>[_modJson()],
            'pagination': <String, dynamic>{
              'index': 10,
              'pageSize': 25,
              'resultCount': 1,
              'totalCount': 30,
            },
          });
        }

        throw StateError('Unexpected request: ${request.url}');
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      final result = await provider.search(
        MtnMinecraftContentSearchRequest(
          query: 'Skyblocker',
          types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
          gameVersions: <String>['26.1.2'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          offset: 10,
          limit: 25,
        ),
      );

      expect(requests.length, 2);
      final categoriesRequest = requests.first;
      expect(categoriesRequest.url.queryParameters['gameId'], '432');
      expect(categoriesRequest.url.queryParameters['classesOnly'], 'true');

      final searchRequest = requests.last;
      expect(searchRequest.headers.entries.firstWhere((entry) => entry.key.toLowerCase() == 'x-api-key').value, 'secret-key');
      expect(searchRequest.url.queryParameters['gameId'], '432');
      expect(searchRequest.url.queryParameters['classId'], '6');
      expect(searchRequest.url.queryParameters['searchFilter'], 'Skyblocker');
      expect(searchRequest.url.queryParameters['gameVersion'], '26.1.2');
      expect(searchRequest.url.queryParameters['modLoaderType'], '4');
      expect(searchRequest.url.queryParameters['index'], '10');
      expect(searchRequest.url.queryParameters['pageSize'], '25');

      expect(result.total, 30);
      expect(result.hasMore, isTrue);
      expect(result.contents.single, isA<MtnMinecraftContentMod>());

      final content = result.contents.single;
      expect(content.key, 'curseforge:12345');
      expect(content.name, 'Skyblocker');
      expect(content.providers.single.provider, MtnMinecraftContentProviderCurseForge.providerName);
      expect(content.providers.single.id, '12345');
      expect(content.authors.single.name, 'ExampleAuthor');
      expect(content.categories.first.primary, isTrue);
      expect(content.icon?.url, 'https://example.test/logo.png');
    });

    test('content class discovery is cached across operations', () async {
      var classRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/categories') {
          classRequests++;
          return _jsonResponse(<String, dynamic>{'data': _classes()});
        }
        if (request.url.path == '/v1/mods/search') {
          return _jsonResponse(<String, dynamic>{
            'data': <Map<String, dynamic>>[_modJson()],
            'pagination': <String, dynamic>{'index': 0, 'pageSize': 10, 'resultCount': 1, 'totalCount': 1},
          });
        }
        if (request.url.path == '/v1/mods/12345') {
          return _jsonResponse(<String, dynamic>{'data': _modJson()});
        }
        if (request.url.path == '/v1/mods/12345/description') {
          return _jsonResponse(<String, dynamic>{'data': '<p>Full description</p>'});
        }
        throw StateError('Unexpected request: ${request.url}');
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      await provider.search(MtnMinecraftContentSearchRequest(types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod], limit: 10));
      final content = await provider.getContent('12345');

      expect(classRequests, 1);
      expect(content.description, '<p>Full description</p>');
      expect(content.links?.source, 'https://example.test/source');
      expect(content.gallery.single.url, 'https://example.test/screenshot.png');
      expect(content.providers.single.metadata['mainFileId'], 9001);
    });

    test('getVersions maps CurseForge files, hashes, fingerprint, modules, and dependencies', () async {
      late http.Request fileRequest;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/mods/12345/files') {
          fileRequest = request;
          return _jsonResponse(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              _fileJson(id: 9002, releaseType: 2, displayName: 'Skyblocker beta', date: '2026-08-01T00:00:00Z'),
              _fileJson(id: 9001, releaseType: 1, displayName: 'Skyblocker 1.0', date: '2026-07-01T00:00:00Z'),
              _fileJson(id: 9003, releaseType: 1, displayName: 'Skyblocker 2.0', date: '2026-09-01T00:00:00Z'),
            ],
            'pagination': <String, dynamic>{'index': 0, 'pageSize': 50, 'resultCount': 3, 'totalCount': 3},
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      final content = MtnMinecraftContentMod(
        key: 'curseforge:12345',
        name: 'Skyblocker',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '12345'),
        ],
      );

      final result = await provider.getVersions(
        content,
        MtnMinecraftContentVersionListRequest(
          gameVersions: <String>['26.1.2'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          releaseTypes: <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release],
          limit: 50,
        ),
      );

      expect(fileRequest.url.queryParameters['gameVersion'], '26.1.2');
      expect(fileRequest.url.queryParameters['modLoaderType'], '4');
      expect(fileRequest.url.queryParameters['index'], '0');
      expect(fileRequest.url.queryParameters['pageSize'], '50');

      expect(result.total, 2);
      expect(result.versions.map((item) => item.key), <String>['curseforge:9001', 'curseforge:9003']);

      final version = result.versions.first;
      expect(version.content, same(content));
      expect(version.version, 'Skyblocker 1.0');
      expect(version.gameVersions, <String>['26.1.2']);
      expect(version.modLoaders, <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric]);
      expect(version.files.single.providers.single.id, '9001');
      expect(version.files.single.downloadUrl, isNull);
      expect(version.files.single.fingerprint, 987654321);
      expect(version.files.single.hashes.map((item) => item.algorithm), containsAll(<String>['sha1', 'md5']));
      expect(version.files.single.modules.single.name, 'fabric.mod.json');
      expect(version.dependencies.map((item) => item.type), <MtnMinecraftContentDependencyType>[
        MtnMinecraftContentDependencyType.required,
        MtnMinecraftContentDependencyType.included,
      ]);
      expect(version.dependencies.first.providerContentId, '777');
    });

    test('non-mod versions normalize loader to vanilla without sending a fake loader filter', () async {
      late http.Request fileRequest;
      final client = MockClient((request) async {
        fileRequest = request;
        return _jsonResponse(<String, dynamic>{
          'data': <Map<String, dynamic>>[_fileJson(id: 8001, releaseType: 1, displayName: 'Pack 1', date: '2026-07-01T00:00:00Z')],
          'pagination': <String, dynamic>{'index': 0, 'pageSize': 50, 'resultCount': 1, 'totalCount': 1},
        });
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      final content = MtnMinecraftContentResourcePack(
        key: 'curseforge:456',
        name: 'Pack',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '456'),
        ],
      );

      final result = await provider.getVersions(
        content,
        MtnMinecraftContentVersionListRequest(modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla]),
      );
      expect(fileRequest.url.queryParameters.containsKey('modLoaderType'), isFalse);
      expect(result.versions.single.modLoaders, <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla]);

      await expectLater(
        provider.getVersions(
          content,
          MtnMinecraftContentVersionListRequest(modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported request shapes instead of lying about pagination', () async {
      final provider = MtnMinecraftContentProviderCurseForge(
        apiKey: 'secret-key',
        client: MockClient((request) async => throw StateError('HTTP should not be reached.')),
      );

      await expectLater(
        provider.search(MtnMinecraftContentSearchRequest()),
        throwsArgumentError,
      );
      await expectLater(
        provider.search(MtnMinecraftContentSearchRequest(types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod, MtnMinecraftContentType.modPack])),
        throwsArgumentError,
      );

      final content = MtnMinecraftContentMod(
        key: 'curseforge:12345',
        name: 'Skyblocker',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '12345'),
        ],
      );

      await expectLater(
        provider.getVersions(content, MtnMinecraftContentVersionListRequest(gameVersions: <String>['26.1.2', '26.2'])),
        throwsArgumentError,
      );
      await expectLater(
        provider.getVersions(content, MtnMinecraftContentVersionListRequest(modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric, MtnMinecraftModLoaderType.quilt])),
        throwsArgumentError,
      );
      await expectLater(
        provider.search(
          MtnMinecraftContentSearchRequest(
            types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
            gameVersions: <String>['26.1.2'],
            modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric, MtnMinecraftModLoaderType.quilt],
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        provider.search(
          MtnMinecraftContentSearchRequest(
            types: <MtnMinecraftContentType>[MtnMinecraftContentType.resourcePack],
            modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          ),
        ),
        throwsArgumentError,
      );
    });


    test('rejects incomplete version traversal beyond the CurseForge ten-thousand result boundary', () async {
      final client = MockClient((request) async {
        return _jsonResponse(<String, dynamic>{
          'data': <Map<String, dynamic>>[_fileJson(id: 9001, releaseType: 1, displayName: 'Skyblocker 1.0', date: '2026-07-01T00:00:00Z')],
          'pagination': <String, dynamic>{'index': 0, 'pageSize': 50, 'resultCount': 1, 'totalCount': 10001},
        });
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      final content = MtnMinecraftContentMod(
        key: 'curseforge:12345',
        name: 'Skyblocker',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '12345'),
        ],
      );

      await expectLater(
        provider.getVersions(content, MtnMinecraftContentVersionListRequest()),
        throwsStateError,
      );
    });

    test('rejects invalid ids and exposes provider HTTP errors without leaking key', () async {
      final client = MockClient((request) async => http.Response('{"error":"forbidden"}', 403));
      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);

      await expectLater(provider.getContent('slug-is-not-an-id'), throwsArgumentError);

      await expectLater(
        provider.search(MtnMinecraftContentSearchRequest(types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod])),
        throwsA(
          isA<MtnMinecraftContentProviderCurseForgeException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.responseBody, 'responseBody', contains('forbidden'))
              .having((error) => error.toString(), 'toString', isNot(contains('secret-key'))),
        ),
      );
    });

    test('can stay registered while API key readiness changes', () async {
      var requestCount = 0;
      final provider = MtnMinecraftContentProviderCurseForge(
        client: MockClient((request) async {
          requestCount++;
          return http.Response('{}', 200);
        }),
      );

      expect(provider.ready, isFalse);

      await expectLater(
        provider.search(MtnMinecraftContentSearchRequest(types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod])),
        throwsA(isA<MtnMinecraftContentProviderNotReadyException>()),
      );
      expect(requestCount, 0);

      provider.apiKey = ' secret-key ';
      expect(provider.ready, isTrue);

      provider.apiKey = '   ';
      expect(provider.ready, isFalse);

      provider.apiKey = null;
      expect(provider.ready, isFalse);
    });

    test('retries one 429 response when CurseForge supplies Retry-After', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;

        if (requestCount == 1) {
          return http.Response(
            '{"error":"rate_limited"}',
            429,
            headers: <String, String>{'retry-after': '0'},
          );
        }

        if (request.url.path == '/v1/categories') {
          return _jsonResponse(<String, dynamic>{'data': _classes()});
        }

        if (request.url.path == '/v1/mods/search') {
          return _jsonResponse(<String, dynamic>{
            'data': <Map<String, dynamic>>[],
            'pagination': <String, dynamic>{'index': 0, 'pageSize': 10, 'resultCount': 0, 'totalCount': 0},
          });
        }

        throw StateError('Unexpected request: ${request.url}');
      });

      final provider = MtnMinecraftContentProviderCurseForge(apiKey: 'secret-key', client: client);
      final result = await provider.search(
        MtnMinecraftContentSearchRequest(types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod], limit: 10),
      );

      expect(requestCount, 3);
      expect(result.contents, isEmpty);
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> value) {
  return http.Response(jsonEncode(value), 200, headers: <String, String>{'content-type': 'application/json'});
}

List<Map<String, dynamic>> _classes() {
  return <Map<String, dynamic>>[
    <String, dynamic>{'id': 6, 'gameId': 432, 'name': 'Mods', 'slug': 'mc-mods', 'isClass': true},
    <String, dynamic>{'id': 4471, 'gameId': 432, 'name': 'Modpacks', 'slug': 'modpacks', 'isClass': true},
    <String, dynamic>{'id': 12, 'gameId': 432, 'name': 'Resource Packs', 'slug': 'resource-packs', 'isClass': true},
    <String, dynamic>{'id': 6552, 'gameId': 432, 'name': 'Shaders', 'slug': 'shaders', 'isClass': true},
    <String, dynamic>{'id': 9999, 'gameId': 432, 'name': 'Data Packs', 'slug': 'data-packs', 'isClass': true},
  ];
}

Map<String, dynamic> _modJson() {
  return <String, dynamic>{
    'id': 12345,
    'gameId': 432,
    'name': 'Skyblocker',
    'slug': 'skyblocker',
    'links': <String, dynamic>{
      'websiteUrl': 'https://example.test/project',
      'wikiUrl': 'https://example.test/wiki',
      'issuesUrl': 'https://example.test/issues',
      'sourceUrl': 'https://example.test/source',
    },
    'summary': 'Example summary',
    'status': 4,
    'downloadCount': 1000,
    'isFeatured': true,
    'primaryCategoryId': 100,
    'categories': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 100,
        'gameId': 432,
        'name': 'Utility & QoL',
        'slug': 'utility-qol',
        'url': 'https://example.test/category',
        'iconUrl': 'https://example.test/category.png',
        'isClass': false,
        'classId': 6,
        'parentCategoryId': null,
      },
    ],
    'classId': 6,
    'authors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 55, 'name': 'ExampleAuthor', 'url': 'https://example.test/author'},
    ],
    'logo': <String, dynamic>{
      'id': 1,
      'modId': 12345,
      'title': 'Logo',
      'description': null,
      'thumbnailUrl': 'https://example.test/logo-thumb.png',
      'url': 'https://example.test/logo.png',
    },
    'screenshots': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'modId': 12345,
        'title': 'Screenshot',
        'description': 'Screenshot description',
        'thumbnailUrl': 'https://example.test/screenshot-thumb.png',
        'url': 'https://example.test/screenshot.png',
      },
    ],
    'mainFileId': 9001,
    'latestFiles': <dynamic>[],
    'latestFilesIndexes': <dynamic>[],
    'dateCreated': '2026-01-01T00:00:00Z',
    'dateModified': '2026-09-01T00:00:00Z',
    'dateReleased': '2026-01-02T00:00:00Z',
    'allowModDistribution': true,
    'gamePopularityRank': 10,
    'isAvailable': true,
    'thumbsUpCount': 12,
    'rating': 4.5,
  };
}

Map<String, dynamic> _fileJson({
  required int id,
  required int releaseType,
  required String displayName,
  required String date,
}) {
  return <String, dynamic>{
    'id': id,
    'gameId': 432,
    'modId': id == 8001 ? 456 : 12345,
    'isAvailable': true,
    'displayName': displayName,
    'fileName': 'skyblocker-$id.jar',
    'releaseType': releaseType,
    'fileStatus': 4,
    'hashes': <Map<String, dynamic>>[
      <String, dynamic>{'value': 'sha1-value', 'algo': 1},
      <String, dynamic>{'value': 'md5-value', 'algo': 2},
    ],
    'fileDate': date,
    'fileLength': 123456,
    'downloadCount': 500,
    'fileSizeOnDisk': 123500,
    'downloadUrl': null,
    'gameVersions': <String>['26.1.2', 'Fabric'],
    'sortableGameVersions': <Map<String, dynamic>>[
      <String, dynamic>{
        'gameVersionName': '26.1.2',
        'gameVersionPadded': '00026.00001.00002',
        'gameVersion': '26.1.2',
        'gameVersionReleaseDate': '2026-01-01T00:00:00Z',
        'gameVersionTypeId': 777,
      },
    ],
    'dependencies': <Map<String, dynamic>>[
      <String, dynamic>{'modId': 777, 'relationType': 3},
      <String, dynamic>{'modId': 888, 'relationType': 6},
    ],
    'fileFingerprint': 987654321,
    'modules': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'fabric.mod.json', 'fingerprint': 111},
    ],
  };
}
