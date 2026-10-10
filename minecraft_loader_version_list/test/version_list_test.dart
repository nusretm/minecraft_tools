import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';

void main() {
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('mtn_loader_versions_'); });
  tearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });

  MtnLauncherGameLoaderMinecraftVersion game(String mc, {String? id, MtnLauncherGameVersionType type = MtnLauncherGameVersionType.release}) {
    return (mcVersion: mc, versionId: id ?? mc, type: type);
  }

  MtnLauncherGameLoaderVersion build(MtnLauncherGameLoaderMinecraftVersion game, String version, {String url = 'https://example.com/installer.jar', MtnLauncherGameLoaderChannel channel = MtnLauncherGameLoaderChannel.unknown, String? sha1}) {
    return MtnLauncherGameLoaderVersion(mcVersion: game.mcVersion, version: version, url: url, type: game.type, channel: channel, sha1: sha1);
  }

  MtnLauncherGameLoaderVersionList create(
    String filename, {
    required Future<List<MtnLauncherGameLoaderMinecraftVersion>> Function(MtnLauncherGameLoaderVersionList) catalog,
    required Future<List<MtnLauncherGameLoaderVersion>> Function(MtnLauncherGameLoaderVersionList, MtnLauncherGameLoaderMinecraftVersion) builds,
  }) {
    return MtnLauncherGameLoaderVersionList(
      cacheDirectory: directory.path,
      filename: filename,
      onLoadFromWeb: catalog,
      onGenerateMinecraftVersionList: builds,
    );
  }

  test('Support catalog and type filters work without downloading builds', () async {
    var catalogs = 0;
    var builds = 0;
    final list = create('fabric.json', catalog: (list) async {
      catalogs++;
      return [
        game('1.21.1'),
        game('1.21.1', id: '1.21.1-pre1', type: MtnLauncherGameVersionType.preRelease),
        game('1.21.1', id: '24w33a', type: MtnLauncherGameVersionType.snapshot),
        game('1.20.1'),
      ];
    }, builds: (list, g) async { builds++; return [build(g, '0.16.0')]; });
    expect(list.hasMinecraftVersionCatalog, false);
    expect(list.supportsMinecraftVersion('1.21.1'), false);
    expect(await list.load(), hasLength(4));
    expect(list.hasMinecraftVersionCatalog, true);
    expect(list.supportsMinecraftVersion('1.21.1'), true);
    expect(list.supportsMinecraftVersion('1.21.1', [MtnLauncherGameVersionType.release]), true);
    expect(list.supportsMinecraftVersion('1.21.1', [MtnLauncherGameVersionType.preRelease, MtnLauncherGameVersionType.snapshot]), true);
    expect(list.supportsMinecraftVersion('1.21.1', [MtnLauncherGameVersionType.beta]), false);
    expect(list.supportsMinecraftVersion('1.21.2'), false);
    expect(list.getFromMinecraftVersion('1.21.1'), isEmpty);
    expect(builds, 0);
    await list.load();
    expect(catalogs, 1);
  });

  test('Generated builds are cached with complete versions, types and URLs', () async {
    final release = game('1.8.9');
    final preview = game('1.8.9', id: '1.8.9-pre1', type: MtnLauncherGameVersionType.preRelease);
    var calls = 0;
    final first = create('forge.json', catalog: (list) async => [release, preview], builds: (list, g) async {
      calls++;
      return [build(g, '${g.versionId}-11.15.1.2318-1.8.9', url: 'https://example.com/${g.versionId}.jar')];
    });
    await first.load();
    final items = await first.loadMinecraftVersion('1.8.9', [MtnLauncherGameVersionType.release]);
    expect(items.single.text, '11.15.1.2318-1.8.9');
    expect(items.single.url, 'https://example.com/1.8.9.jar');
    expect(first.getFromMinecraftVersion('1.8.9', [MtnLauncherGameVersionType.preRelease]), isEmpty);
    expect(calls, 1);
    await first.loadMinecraftVersion('1.8.9', [MtnLauncherGameVersionType.release]);
    expect(calls, 1);

    final disk = jsonDecode(await File('${directory.path}/forge.json').readAsString()) as Map<String, dynamic>;
    expect(disk['schemaVersion'], 1);
    expect((disk['generated'] as List).single['items'][0]['url'], 'https://example.com/1.8.9.jar');
    expect((disk['generated'] as List).single['items'][0]['channel'], 'unknown');

    final second = create('forge.json', catalog: (list) async => throw StateError('catalog callback unexpected'), builds: (list, g) async => throw StateError('build callback unexpected'));
    await second.load();
    expect(second.supportsMinecraftVersion('1.8.9'), true);
    expect(second.getFromMinecraftVersion('1.8.9').single.url, 'https://example.com/1.8.9.jar');
    await second.loadMinecraftVersion('1.8.9', [MtnLauncherGameVersionType.release]);
    expect(second.errorCode, 0);
  });

  test('Catalog and generated-build timestamps are independent', () async {
    final g = game('1.21.1');
    var catalogCalls = 0;
    var buildCalls = 0;
    final first = create('fabric.json', catalog: (list) async { catalogCalls++; return [g]; }, builds: (list, g) async {
      buildCalls++;
      return [build(g, '0.16.0')];
    });
    await first.loadMinecraftVersion('1.21.1');
    expect(catalogCalls, 1);
    expect(buildCalls, 1);

    final file = File('${directory.path}/fabric.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    disk['catalogUpdatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await file.writeAsString(jsonEncode(disk));

    final second = create('fabric.json', catalog: (list) async { catalogCalls++; return [g]; }, builds: (list, g) async {
      buildCalls++;
      return [build(g, 'unexpected')];
    });
    await second.loadMinecraftVersion('1.21.1');
    expect(catalogCalls, 2);
    expect(buildCalls, 1);
    expect(second.items.single.version, '0.16.0');
  });

  test('Failed catalog refresh leaves stale support available', () async {
    final g = game('1.21.1');
    final first = create('quilt.json', catalog: (list) async => [g], builds: (list, g) async => []);
    await first.load();
    final file = File('${directory.path}/quilt.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    disk['catalogUpdatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await file.writeAsString(jsonEncode(disk));

    final second = create('quilt.json', catalog: (list) async => throw const FormatException('bad metadata'), builds: (list, g) async => []);
    await second.load();
    expect(second.supportsMinecraftVersion('1.21.1'), true);
    expect(second.errorCode, -4);
    expect(second.errorMessage, contains('bad metadata'));
  });

  test('Failed generated refresh retains prior builds', () async {
    final g = game('1.21.1');
    final first = create('builds.json', catalog: (list) async => [g], builds: (list, g) async => [build(g, '0.27.0')]);
    await first.loadMinecraftVersion('1.21.1');
    final file = File('${directory.path}/builds.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    (disk['generated'] as List<dynamic>).single['updatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await file.writeAsString(jsonEncode(disk));

    final second = create('builds.json', catalog: (list) async => throw StateError('catalog unexpectedly requested'), builds: (list, g) async => throw const FormatException('bad payload'));
    final result = await second.loadMinecraftVersion('1.21.1');
    expect(result.single.version, '0.27.0');
    expect(second.errorCode, -4);
  });

  test('downloadUrl records an HTTP error and throws into load catch', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 503;
      await request.response.close();
    });
    try {
      final list = create('http.json', catalog: (list) async {
        await list.downloadUrl('http://${server.address.address}:${server.port}/fail');
        return [game('unreachable')];
      }, builds: (list, g) async => []);
      expect(await list.load(), isEmpty);
      expect(list.errorCode, 503);
      expect(list.errorMessage, contains('HTTP 503'));
      expect(list.hasMinecraftVersionCatalog, false);
    } finally {
      await server.close(force: true);
    }
  });

  test('Concurrent catalog and build queries coalesce', () async {
    var catalogCalls = 0;
    var buildCalls = 0;
    final list = create('parallel.json', catalog: (list) async {
      catalogCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [game('1.21.1')];
    }, builds: (list, g) async {
      buildCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [build(g, '0.16.0')];
    });
    await Future.wait([list.load(), list.load()]);
    final results = await Future.wait([list.loadMinecraftVersion('1.21.1'), list.loadMinecraftVersion('1.21.1')]);
    expect(results[0].single.version, '0.16.0');
    expect(results[1].single.version, '0.16.0');
    expect(catalogCalls, 1);
    expect(buildCalls, 1);
  });

  test('All Minecraft types round-trip through version JSON', () {
    for (final type in MtnLauncherGameVersionType.values) {
      final g = game('1.8.9', type: type);
      final item = build(g, '1.8.9-11.15.1.2318-1.8.9');
      final restored = MtnLauncherGameLoaderVersion.fromJson(item.toJson());
      expect(restored.type, type);
      expect(restored.version, item.version);
      expect(restored.url, item.url);
    }
  });

  test('Legacy cache without channel restores it as unknown', () async {
    final g = game('1.20.1');
    final first = create('legacy-channel.json', catalog: (list) async => [g], builds: (list, g) async => [build(g, '1.20.1-loader')]);
    await first.loadMinecraftVersion('1.20.1');

    final file = File('${directory.path}/legacy-channel.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    ((disk['generated'] as List<dynamic>).single['items'] as List<dynamic>).single.remove('channel');
    await file.writeAsString(jsonEncode(disk));

    final second = create('legacy-channel.json', catalog: (list) async => throw StateError('catalog callback unexpected'), builds: (list, g) async => throw StateError('build callback unexpected'));
    await second.load();
    expect(second.items.single.channel, MtnLauncherGameLoaderChannel.unknown);
  });

  test('Valid cache channel is preserved', () async {
    final g = game('1.20.1');
    final first = create('valid-channel.json', catalog: (list) async => [g], builds: (list, g) async => [build(g, 'loader', channel: MtnLauncherGameLoaderChannel.beta)]);
    await first.loadMinecraftVersion('1.20.1');

    final second = create('valid-channel.json', catalog: (list) async => throw StateError('catalog callback unexpected'), builds: (list, g) async => throw StateError('build callback unexpected'));
    await second.load();
    expect(second.items.single.channel, MtnLauncherGameLoaderChannel.beta);
  });

  test('Invalid cache channel is rejected and refreshed', () async {
    final g = game('1.20.1');
    final first = create('invalid-channel.json', catalog: (list) async => [g], builds: (list, g) async => [build(g, 'cached-loader', channel: MtnLauncherGameLoaderChannel.stable)]);
    await first.loadMinecraftVersion('1.20.1');

    final file = File('${directory.path}/invalid-channel.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    ((disk['generated'] as List<dynamic>).single['items'] as List<dynamic>).single['channel'] = 'preview';
    await file.writeAsString(jsonEncode(disk));

    var catalogCalls = 0;
    final second = create('invalid-channel.json', catalog: (list) async { catalogCalls++; return [g]; }, builds: (list, g) async => [build(g, 'fresh-loader')]);
    await second.load();
    expect(catalogCalls, 1);
    expect(second.items, isEmpty);
    expect(second.supportsMinecraftVersion('1.20.1'), true);
  });


  test('Source SHA-1 survives schema-1 cache publication and offline restore', () async {
    final g = game('1.21.11');
    const String sourceUrl = 'HTTPS://Example.invalid/Version/Profile.JSON?Exact=%2B';
    const String sourceSha1 = 'A19f49d4b31af176d9699c7e8fdc4ea2d551aa09';
    var catalogCalls = 0;
    var buildCalls = 0;

    final first = create('source-sha1.json', catalog: (list) async {
      catalogCalls++;
      return [g];
    }, builds: (list, g) async {
      buildCalls++;
      return [build(g, '1.21.11', url: sourceUrl, channel: MtnLauncherGameLoaderChannel.stable, sha1: sourceSha1)];
    });

    final initial = await first.loadMinecraftVersion('1.21.11');
    expect(initial.single.sha1, sourceSha1);
    expect(initial.single.url, sourceUrl);
    expect(catalogCalls, 1);
    expect(buildCalls, 1);

    final file = File('${directory.path}/source-sha1.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(disk['schemaVersion'], 1);
    final Map<String, dynamic> serialized = Map<String, dynamic>.from(
      ((disk['generated'] as List<dynamic>).single['items'] as List<dynamic>).single as Map<String, dynamic>,
    );
    expect(serialized['sha1'], sourceSha1);
    expect(serialized['url'], sourceUrl);
    expect(serialized['channel'], 'stable');

    final second = create('source-sha1.json',
      catalog: (list) async => throw StateError('catalog callback must not run with fresh cache'),
      builds: (list, g) async => throw StateError('build callback must not run with fresh cache'),
    );
    final restored = await second.loadMinecraftVersion('1.21.11');
    expect(second.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
    expect(restored.single, initial.single);
    expect(restored.single.sha1, sourceSha1);
    expect(restored.single.url, sourceUrl);
    expect((await second.resolveVersion(mcVersion: '1.21.11', version: '1.21.11'))!.sha1, sourceSha1);
    expect(second.errorCode, 0);
    expect(catalogCalls, 1);
    expect(buildCalls, 1);
  });

  test('Historical schema-1 cache without SHA-1 restores as null', () async {
    final g = game('1.20.1');
    final first = create('legacy-source-sha1.json',
      catalog: (list) async => [g],
      builds: (list, g) async => [build(g, '1.20.1-loader')],
    );
    await first.loadMinecraftVersion('1.20.1');

    final file = File('${directory.path}/legacy-source-sha1.json');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final Map<String, dynamic> serialized = Map<String, dynamic>.from(
      ((disk['generated'] as List<dynamic>).single['items'] as List<dynamic>).single as Map<String, dynamic>,
    );
    expect(disk['schemaVersion'], 1);
    expect(serialized.containsKey('sha1'), isFalse);

    final second = create('legacy-source-sha1.json',
      catalog: (list) async => throw StateError('catalog callback must not run with fresh cache'),
      builds: (list, g) async => throw StateError('build callback must not run with fresh cache'),
    );
    final result = await second.loadMinecraftVersion('1.20.1');
    expect(result.single.sha1, isNull);
    expect(result.single.toJson().containsKey('sha1'), isFalse);
    expect(second.errorCode, 0);
  });

  test('Malformed explicitly present SHA-1 rejects the cache and reacquires the catalog', () async {
    final g = game('1.21.11');
    const String sourceSha1 = 'A19f49d4b31af176d9699c7e8fdc4ea2d551aa09';
    final List<Object?> invalidValues = <Object?>[null, 42, false, '', ' \t\n'];

    for (var index = 0; index < invalidValues.length; index++) {
      final filename = 'invalid-source-sha1-$index.json';
      final first = create(filename,
        catalog: (list) async => [g],
        builds: (list, g) async => [build(g, '1.21.11', sha1: sourceSha1)],
      );
      await first.loadMinecraftVersion('1.21.11');

      final file = File('${directory.path}/$filename');
      final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      ((disk['generated'] as List<dynamic>).single['items'] as List<dynamic>).single['sha1'] = invalidValues[index];
      await file.writeAsString(jsonEncode(disk));

      var catalogCalls = 0;
      var buildCalls = 0;
      final second = create(filename, catalog: (list) async {
        catalogCalls++;
        return [g];
      }, builds: (list, g) async {
        buildCalls++;
        return [build(g, 'fresh-loader')];
      });
      await second.load();
      expect(catalogCalls, 1, reason: 'Invalid sha1 ${invalidValues[index]}');
      expect(buildCalls, 0);
      expect(second.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
      expect(second.items, isEmpty);
      expect(second.supportsMinecraftVersion('1.21.11'), isTrue);
      expect(second.errorCode, 0);
    }
  });

  test('Reject cache filename containing a path', () {
    expect(() => create('../bad.json', catalog: (list) async => [], builds: (list, g) async => []), throwsArgumentError);
  });
}
