import 'dart:convert';
import 'dart:io';

import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('mtn_loader_resolver_'); });
  tearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });

  MtnLauncherGameLoaderMinecraftVersion game(String mcVersion, {String? versionId, MtnLauncherGameVersionType type = MtnLauncherGameVersionType.release}) {
    return (mcVersion: mcVersion, versionId: versionId ?? mcVersion, type: type);
  }

  MtnLauncherGameLoaderVersion build(MtnLauncherGameLoaderMinecraftVersion game, String version, MtnLauncherGameLoaderChannel channel, {String? url}) {
    return MtnLauncherGameLoaderVersion(
      mcVersion: game.mcVersion,
      version: version,
      url: url ?? 'https://example.com/$version',
      type: game.type,
      channel: channel,
    );
  }

  MtnLauncherGameLoaderVersionList create(
    String filename, {
    required Future<List<MtnLauncherGameLoaderMinecraftVersion>> Function(MtnLauncherGameLoaderVersionList) catalog,
    required Future<List<MtnLauncherGameLoaderVersion>> Function(MtnLauncherGameLoaderVersionList, MtnLauncherGameLoaderMinecraftVersion) builds,
    Duration cacheDuration = const Duration(hours: 1),
  }) {
    return MtnLauncherGameLoaderVersionList(
      cacheDirectory: directory.path,
      filename: filename,
      onLoadFromWeb: catalog,
      onGenerateMinecraftVersionList: builds,
      cacheDuration: cacheDuration,
    );
  }

  Future<Map<String, dynamic>> readCache(String filename) async {
    return jsonDecode(await File('${directory.path}${Platform.pathSeparator}$filename').readAsString()) as Map<String, dynamic>;
  }

  Future<void> writeCache(String filename, Map<String, dynamic> cache) async {
    await File('${directory.path}${Platform.pathSeparator}$filename').writeAsString(jsonEncode(cache));
  }

  test('Catalog state changes from notLoaded to fresh', () async {
    final list = create('state.json', catalog: (list) async => [game('1.21.1')], builds: (list, game) async => []);
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.notLoaded);
    await list.load();
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
  });

  test('Successful empty catalog is fresh', () async {
    final list = create('empty-catalog.json', catalog: (list) async => [], builds: (list, game) async => []);
    expect(await list.load(), isEmpty);
    expect(list.hasMinecraftVersionCatalog, true);
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
  });

  test('Failed first catalog load is unavailable', () async {
    final list = create('unavailable.json', catalog: (list) async => throw const FormatException('bad catalog'), builds: (list, game) async => []);
    expect(await list.load(), isEmpty);
    expect(list.hasMinecraftVersionCatalog, false);
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.unavailable);
  });

  test('Expired catalog is stale', () async {
    final list = create('expired.json', catalog: (list) async => [game('1.21.1')], builds: (list, game) async => [], cacheDuration: Duration.zero);
    await list.load();
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.stale);
  });

  test('Failed refresh retains stale catalog and error details', () async {
    final first = create('stale.json', catalog: (list) async => [game('1.21.1')], builds: (list, game) async => []);
    await first.load();
    final cache = await readCache('stale.json');
    cache['catalogUpdatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await writeCache('stale.json', cache);

    final second = create('stale.json', catalog: (list) async => throw const FormatException('refresh failed'), builds: (list, game) async => []);
    await second.load();
    expect(second.catalogState, MtnLauncherGameLoaderCatalogState.stale);
    expect(second.supportsMinecraftVersion('1.21.1'), true);
    expect(second.errorCode, -4);
    expect(second.errorMessage, contains('refresh failed'));
  });

  test('Fresh unsupported result is null but stale negative result is unknown', () async {
    final fresh = create('fresh-negative.json', catalog: (list) async => [game('1.21.1')], builds: (list, game) async => []);
    expect(await fresh.resolveVersion(mcVersion: '1.20.1'), isNull);

    final seed = create('stale-negative.json', catalog: (list) async => [game('1.21.1')], builds: (list, game) async => []);
    await seed.load();
    final cache = await readCache('stale-negative.json');
    cache['catalogUpdatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await writeCache('stale-negative.json', cache);
    final stale = create('stale-negative.json', catalog: (list) async => throw const FormatException('offline'), builds: (list, game) async => []);
    await expectLater(stale.resolveVersion(mcVersion: '1.20.1'), throwsA(isA<StateError>()));
  });

  test('Exact selection preserves case and accepts explicit beta and alpha', () async {
    final g = game('1.21.1');
    final list = create('exact.json', catalog: (list) async => [g], builds: (list, game) async => [
      build(game, 'Loader-Beta.1', MtnLauncherGameLoaderChannel.beta),
      build(game, 'Loader-Alpha.1', MtnLauncherGameLoaderChannel.alpha),
    ]);
    expect((await list.resolveVersion(mcVersion: '1.21.1', version: 'Loader-Beta.1'))!.channel, MtnLauncherGameLoaderChannel.beta);
    expect((await list.resolveVersion(mcVersion: '1.21.1', version: 'Loader-Alpha.1'))!.channel, MtnLauncherGameLoaderChannel.alpha);
    expect(await list.resolveVersion(mcVersion: '1.21.1', version: 'loader-beta.1'), isNull);
    await expectLater(list.resolveVersion(mcVersion: '   '), throwsA(isA<ArgumentError>()));
    await expectLater(list.resolveVersion(mcVersion: '1.21.1', version: ' '), throwsA(isA<ArgumentError>()));
  });

  test('Automatic selection prefers the highest stable version', () async {
    final g = game('1.21.1');
    final list = create('stable.json', catalog: (list) async => [g], builds: (list, game) async => [
      build(game, '99.0', MtnLauncherGameLoaderChannel.unknown),
      build(game, '3.0-beta.1', MtnLauncherGameLoaderChannel.beta),
      build(game, '1.9', MtnLauncherGameLoaderChannel.stable),
      build(game, '1.10', MtnLauncherGameLoaderChannel.stable),
    ]);
    expect((await list.resolveVersion(mcVersion: '1.21.1'))!.version, '1.10');
  });

  test('Unknown fallback is optional and prerelease channels are never automatic', () async {
    final g = game('1.21.1');
    final list = create('fallback.json', catalog: (list) async => [g], builds: (list, game) async => [
      build(game, '1.0-unknown', MtnLauncherGameLoaderChannel.unknown),
      build(game, '4.0-beta', MtnLauncherGameLoaderChannel.beta),
      build(game, '5.0-alpha', MtnLauncherGameLoaderChannel.alpha),
      build(game, '6.0-experimental', MtnLauncherGameLoaderChannel.experimental),
    ]);
    expect((await list.resolveVersion(mcVersion: '1.21.1'))!.version, '1.0-unknown');
    expect(await list.resolveVersion(mcVersion: '1.21.1', allowUnknownChannelFallback: false), isNull);
  });

  test('Successful empty build discovery is authoritative and cached', () async {
    var calls = 0;
    final g = game('1.21.1');
    final list = create('empty-builds.json', catalog: (list) async => [g], builds: (list, game) async { calls++; return []; });
    expect(await list.resolveVersion(mcVersion: '1.21.1'), isNull);
    expect(await list.resolveVersion(mcVersion: '1.21.1', version: 'missing'), isNull);
    expect(calls, 1);
  });

  test('Failed build discovery without cache throws StateError', () async {
    final g = game('1.21.1');
    final list = create('failed-builds.json', catalog: (list) async => [g], builds: (list, game) async => throw const FormatException('bad builds'));
    await expectLater(list.resolveVersion(mcVersion: '1.21.1'), throwsA(isA<StateError>()));
  });

  test('Failed build refresh can select from stale build cache', () async {
    final g = game('1.21.1');
    final first = create('stale-builds.json', catalog: (list) async => [g], builds: (list, game) async => [build(game, '1.0', MtnLauncherGameLoaderChannel.stable)]);
    await first.resolveVersion(mcVersion: '1.21.1');
    final cache = await readCache('stale-builds.json');
    (cache['generated'] as List<dynamic>).single['updatedAt'] = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    await writeCache('stale-builds.json', cache);

    final second = create('stale-builds.json', catalog: (list) async => throw StateError('catalog callback unexpected'), builds: (list, game) async => throw const FormatException('build refresh failed'));
    expect((await second.resolveVersion(mcVersion: '1.21.1'))!.version, '1.0');
    expect(second.errorMessage, contains('build refresh failed'));
  });

  test('Partial discovery failure across related game IDs is not a definitive selection', () async {
    final firstGame = game('1.21.1', versionId: 'release');
    final secondGame = game('1.21.1', versionId: 'preview');
    final list = create('partial.json', catalog: (list) async => [firstGame, secondGame], builds: (list, game) async {
      if (game.versionId == 'preview') throw const FormatException('partial failure');
      return [build(game, '1.0', MtnLauncherGameLoaderChannel.stable)];
    });
    await expectLater(list.resolveVersion(mcVersion: '1.21.1'), throwsA(isA<StateError>()));
  });

  test('Conflicting metadata for one exact version throws StateError', () async {
    final firstGame = game('1.21.1', versionId: 'release');
    final secondGame = game('1.21.1', versionId: 'preview');
    final list = create('conflict.json', catalog: (list) async => [firstGame, secondGame], builds: (list, game) async => [
      build(game, 'same-id', MtnLauncherGameLoaderChannel.beta, url: 'https://example.com/${game.versionId}'),
    ]);
    await expectLater(list.resolveVersion(mcVersion: '1.21.1', version: 'same-id'), throwsA(isA<StateError>()));
  });

  test('Automatic selection has deterministic version type and URL tie-breaks', () async {
    final release = game('1.21.1', versionId: 'release');
    final snapshot = game('1.21.1', versionId: 'snapshot', type: MtnLauncherGameVersionType.snapshot);
    final list = create('deterministic.json', catalog: (list) async => [snapshot, release], builds: (list, game) async {
      if (game.type == MtnLauncherGameVersionType.snapshot) return [build(game, '2.0', MtnLauncherGameLoaderChannel.stable, url: 'https://example.com/0')];
      return [
        build(game, '2.0', MtnLauncherGameLoaderChannel.stable, url: 'https://example.com/b'),
        build(game, '2.0', MtnLauncherGameLoaderChannel.stable, url: 'https://example.com/a'),
      ];
    });
    final selected = await list.resolveVersion(mcVersion: '1.21.1');
    expect(selected!.type, MtnLauncherGameVersionType.release);
    expect(selected.url, 'https://example.com/a');
  });

  test('Concurrent resolvers coalesce catalog and same-key build discovery', () async {
    var catalogCalls = 0;
    var buildCalls = 0;
    final g = game('1.21.1');
    final list = create('concurrent.json', catalog: (list) async {
      catalogCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [g];
    }, builds: (list, game) async {
      buildCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [build(game, '1.0', MtnLauncherGameLoaderChannel.stable)];
    });
    final results = await Future.wait([
      list.resolveVersion(mcVersion: '1.21.1'),
      list.resolveVersion(mcVersion: '1.21.1'),
    ]);
    expect(results[0]!.version, '1.0');
    expect(results[1]!.version, '1.0');
    expect(catalogCalls, 1);
    expect(buildCalls, 1);
  });
}
