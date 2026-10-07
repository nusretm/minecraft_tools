import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentProviderModrinth', () {
    test('search sends User-Agent and maps project hits', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;

        return http.Response(
          jsonEncode(<String, dynamic>{
            'hits': <Map<String, dynamic>>[
              <String, dynamic>{
                'project_id': 'AABBCCDD',
                'project_type': 'mod',
                'all_project_types': <String>['mod', 'datapack'],
                'title': 'Example Mod',
                'description': 'Example summary',
                'author': 'example-author',
                'categories': <String>['fabric', 'technology'],
                'versions': <String>['1.21.1'],
                'downloads': 1234,
                'follows': 50,
                'icon_url': 'https://cdn.modrinth.com/example.png',
                'date_created': '2026-01-01T00:00:00Z',
                'date_modified': '2026-02-01T00:00:00Z',
                'latest_version': 'VVVVVVVV',
                'license': 'MIT',
                'environment': <String>['client_and_server'],
                'organization_id': null,
              },
            ],
            'offset': 10,
            'limit': 25,
            'total_hits': 40,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final provider = MtnMinecraftContentProviderModrinth(userAgent: 'nusretm/minecraft_tools/1.0', client: client);
      final result = await provider.search(
        MtnMinecraftContentSearchRequest(
          query: 'example',
          types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          offset: 10,
          limit: 25,
        ),
      );

      expect(captured.headers.entries.firstWhere((entry) => entry.key.toLowerCase() == 'user-agent').value, 'nusretm/minecraft_tools/1.0');
      expect(captured.url.path, '/v2/search');
      expect(captured.url.queryParameters['query'], 'example');
      expect(captured.url.queryParameters['offset'], '10');
      expect(captured.url.queryParameters['limit'], '25');

      final facets = jsonDecode(captured.url.queryParameters['facets']!) as List<dynamic>;
      expect(facets, <dynamic>[
        <dynamic>['project_type:mod'],
        <dynamic>['versions:1.21.1'],
        <dynamic>['categories:fabric'],
      ]);

      expect(result.offset, 10);
      expect(result.limit, 25);
      expect(result.total, 40);
      expect(result.hasMore, isTrue);
      expect(result.contents.single, isA<MtnMinecraftContentMod>());

      final content = result.contents.single;
      expect(content.key, 'modrinth:AABBCCDD');
      expect(content.name, 'Example Mod');
      expect(content.providers.single.provider, MtnMinecraftContentProviderModrinth.providerName);
      expect(content.providers.single.id, 'AABBCCDD');
      expect(content.providers.single.metadata['all_project_types'], <String>['mod', 'datapack']);
      expect(content.authors.single.username, 'example-author');
      expect(content.license?.id, 'MIT');
    });

    test('getContent maps full project metadata and preserves raw response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v2/project/example-project');

        return http.Response(
          jsonEncode(_projectJson()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final provider = MtnMinecraftContentProviderModrinth(userAgent: 'nusretm/minecraft_tools/1.0', client: client);
      final content = await provider.getContent('example-project');

      expect(content, isA<MtnMinecraftContentMod>());
      expect(content.key, 'modrinth:AABBCCDD');
      expect(content.slug, 'example-project');
      expect(content.summary, 'Example summary');
      expect(content.description, 'Long **Markdown** body');
      expect(content.categories.map((item) => item.slug), <String>['technology', 'fabric', 'adventure']);
      expect(content.categories.first.primary, isTrue);
      expect(content.categories.last.primary, isFalse);
      expect(content.links?.source, 'https://github.com/example/project');
      expect(content.links?.issues, 'https://github.com/example/project/issues');
      expect(content.links?.donations.single.platform, 'Patreon');
      expect(content.icon?.url, 'https://cdn.modrinth.com/icon.png');
      expect(content.gallery.single.featured, isTrue);
      expect(content.license?.name, 'MIT License');
      expect(content.releasedAt, DateTime.parse('2026-01-03T00:00:00Z'));
      expect(content.providers.single.metadata['downloads'], 5000);
    });

    test('getVersions maps files and dependencies, filters releases, and keeps content identity', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;

        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            _versionJson(id: 'V3', version: '3.0.0', type: 'release', date: '2026-03-01T00:00:00Z'),
            _versionJson(id: 'V1', version: '1.0.0-beta', type: 'beta', date: '2026-01-01T00:00:00Z'),
            _versionJson(id: 'V2', version: '2.0.0', type: 'release', date: '2026-02-01T00:00:00Z'),
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final provider = MtnMinecraftContentProviderModrinth(userAgent: 'nusretm/minecraft_tools/1.0', client: client);
      final content = MtnMinecraftContentMod(
        key: 'modrinth:AABBCCDD',
        name: 'Example Mod',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderModrinth.providerName, id: 'AABBCCDD'),
        ],
      );

      final result = await provider.getVersions(
        content,
        MtnMinecraftContentVersionListRequest(
          gameVersions: <String>['1.21.1'],
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
          releaseTypes: <MtnMinecraftContentVersionReleaseType>[MtnMinecraftContentVersionReleaseType.release],
          limit: 50,
        ),
      );

      expect(captured.url.path, '/v2/project/AABBCCDD/version');
      expect(jsonDecode(captured.url.queryParameters['loaders']!), <dynamic>['fabric']);
      expect(jsonDecode(captured.url.queryParameters['game_versions']!), <dynamic>['1.21.1']);
      expect(captured.url.queryParameters['include_changelog'], 'true');

      expect(result.total, 2);
      expect(result.hasMore, isFalse);
      expect(result.versions.map((item) => item.version), <String>['2.0.0', '3.0.0']);

      final version = result.versions.first;
      expect(version.content, same(content));
      expect(version.key, 'modrinth:V2');
      expect(version.environment, MtnMinecraftContentEnvironment.clientAndServer);
      expect(version.files.single.fileName, 'example.jar');
      expect(version.files.single.providers.single.id, isNull);
      expect(version.files.single.hashes.map((hash) => hash.algorithm), containsAll(<String>['sha1', 'sha512']));
      expect(version.dependencies.single.type, MtnMinecraftContentDependencyType.required);
      expect(version.dependencies.single.providerContentId, 'DEPEND01');
      expect(version.dependencies.single.providerVersionId, 'DEPVER01');
      expect(version.providers.single.metadata['status'], 'listed');
    });

    test('throws provider-specific exception for HTTP errors', () async {
      final client = MockClient((request) async => http.Response('{"error":"not_found"}', 404));
      final provider = MtnMinecraftContentProviderModrinth(userAgent: 'nusretm/minecraft_tools/1.0', client: client);

      await expectLater(
        provider.getContent('missing'),
        throwsA(
          isA<MtnMinecraftContentProviderModrinthException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.responseBody, 'responseBody', contains('not_found')),
        ),
      );
    });

    test('requires a non-empty application User-Agent', () {
      expect(() => MtnMinecraftContentProviderModrinth(userAgent: '   ', client: MockClient((request) async => http.Response('{}', 200))), throwsArgumentError);
    });
  });
}

Map<String, dynamic> _projectJson() {
  return <String, dynamic>{
    'id': 'AABBCCDD',
    'team': 'TEAM0001',
    'title': 'Example Mod',
    'description': 'Example summary',
    'body': 'Long **Markdown** body',
    'status': 'approved',
    'project_type': 'mod',
    'categories': <String>['technology', 'fabric'],
    'additional_categories': <String>['adventure'],
    'environment': <String>['client_and_server'],
    'game_versions': <String>['1.21.1'],
    'loaders': <String>['fabric'],
    'versions': <String>['V1', 'V2'],
    'license': <String, dynamic>{
      'id': 'MIT',
      'name': 'MIT License',
      'url': 'https://spdx.org/licenses/MIT.html',
    },
    'published': '2026-01-01T00:00:00Z',
    'updated': '2026-02-01T00:00:00Z',
    'downloads': 5000,
    'followers': 200,
    'gallery': <Map<String, dynamic>>[
      <String, dynamic>{
        'url': 'https://cdn.modrinth.com/gallery.png',
        'featured': true,
        'title': 'Gallery',
        'description': 'Screenshot',
        'created': '2026-01-02T00:00:00Z',
        'ordering': 0,
      },
    ],
    'thread_id': 'THREAD01',
    'monetization_status': 'monetized',
    'slug': 'example-project',
    'organization': null,
    'requested_status': null,
    'approved': '2026-01-03T00:00:00Z',
    'queued': null,
    'icon_url': 'https://cdn.modrinth.com/icon.png',
    'raw_icon_url': 'https://cdn.modrinth.com/icon-raw.png',
    'color': 123,
    'issues_url': 'https://github.com/example/project/issues',
    'source_url': 'https://github.com/example/project',
    'wiki_url': 'https://github.com/example/project/wiki',
    'discord_url': 'https://discord.gg/example',
    'donation_urls': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'patreon', 'platform': 'Patreon', 'url': 'https://patreon.com/example'},
    ],
    'client_side': 'required',
    'server_side': 'required',
  };
}

Map<String, dynamic> _versionJson({
  required String id,
  required String version,
  required String type,
  required String date,
}) {
  return <String, dynamic>{
    'name': 'Example $version',
    'version_number': version,
    'changelog': 'Changes for $version',
    'dependencies': <Map<String, dynamic>>[
      <String, dynamic>{
        'version_id': 'DEPVER01',
        'project_id': 'DEPEND01',
        'file_name': null,
        'dependency_type': 'required',
      },
    ],
    'game_versions': <String>['1.21.1'],
    'version_type': type,
    'loaders': <String>['fabric'],
    'featured': true,
    'status': 'listed',
    'requested_status': null,
    'id': id,
    'project_id': 'AABBCCDD',
    'author_id': 'AUTHOR01',
    'date_published': date,
    'downloads': 100,
    'changelog_url': null,
    'environment': 'client_and_server',
    'files': <Map<String, dynamic>>[
      <String, dynamic>{
        'hashes': <String, dynamic>{'sha512': 'abc512', 'sha1': 'abc1'},
        'url': 'https://cdn.modrinth.com/example.jar',
        'filename': 'example.jar',
        'primary': true,
        'size': 12345,
        'file_type': null,
      },
    ],
  };
}
