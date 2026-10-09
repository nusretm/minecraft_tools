import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('mtn_loader_cache_hardening_'); });
  tearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });

  File primary(String filename) => File('${directory.path}${Platform.pathSeparator}$filename');
  File backup(String filename) => File('${directory.path}${Platform.pathSeparator}$filename.bak');

  Map<String, dynamic> validCache(String mcVersion, {DateTime? updatedAt}) => {
    'schemaVersion': 1,
    'catalogUpdatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'minecraftVersions': [
      {'mcVersion': mcVersion, 'versionId': mcVersion, 'type': MtnLauncherGameVersionType.release.name},
    ],
    'generated': <dynamic>[],
  };

  MtnLauncherGameLoaderVersionList create(
    String filename, {
    required Future<List<MtnLauncherGameLoaderMinecraftVersion>> Function(MtnLauncherGameLoaderVersionList) catalog,
    String? cachePath,
  }) {
    return MtnLauncherGameLoaderVersionList(
      cacheDirectory: cachePath ?? directory.path,
      filename: filename,
      onLoadFromWeb: catalog,
      onGenerateMinecraftVersionList: (list, game) async => [],
    );
  }

  Future<void> expectConcurrentPublication({required String filename, required String directPath, required String aliasPath}) async {
    final cacheFile = File('$directPath${Platform.pathSeparator}$filename');
    await cacheFile.writeAsString(jsonEncode(validCache(
      'existing',
      updatedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    )));
    final ready = Completer<void>();
    var callbackCount = 0;

    Future<List<MtnLauncherGameLoaderMinecraftVersion>> catalog(String prefix) async {
      callbackCount++;
      if (callbackCount == 2) ready.complete();
      await ready.future;
      return List.generate(1000, (index) => (
        mcVersion: '$prefix.$index',
        versionId: '$prefix.$index',
        type: MtnLauncherGameVersionType.release,
      ));
    }

    final first = create(filename, cachePath: directPath, catalog: (list) => catalog('1'));
    final second = create(filename, cachePath: aliasPath, catalog: (list) => catalog('2'));
    await Future.wait([first.load(), second.load()]);

    expect(first.errorCode, 0);
    expect(second.errorCode, 0);
    expect(await File('${cacheFile.path}.tmp').exists(), false);

    final decoded = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 1);
    expect(decoded['minecraftVersions'], isA<List<dynamic>>().having((items) => items.isNotEmpty, 'is not empty', true));

    final restored = create(filename, cachePath: directPath, catalog: (list) async => throw const SocketException('offline'));
    await restored.load();
    expect(restored.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
    expect(restored.minecraftVersions, isNotEmpty);
  }

  test('Missing primary restores a valid backup', () async {
    const filename = 'missing-primary.json';
    await backup(filename).writeAsString(jsonEncode(validCache('1.21.1')));
    final list = create(filename, catalog: (list) async => throw const SocketException('offline'));

    await list.load();

    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
    expect(list.supportsMinecraftVersion('1.21.1'), true);
    expect(list.errorCode, 0);
  });

  test('Invalid primary restores a valid backup', () async {
    const filename = 'invalid-primary.json';
    await primary(filename).writeAsString('{invalid');
    await backup(filename).writeAsString(jsonEncode(validCache('1.21.1')));
    final list = create(filename, catalog: (list) async => throw const SocketException('offline'));

    await list.load();

    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.fresh);
    expect(list.supportsMinecraftVersion('1.21.1'), true);
    expect(list.errorCode, 0);
  });

  test('Valid primary has priority over an existing valid backup', () async {
    const filename = 'primary-priority.json';
    await primary(filename).writeAsString(jsonEncode(validCache('1.21.1')));
    await backup(filename).writeAsString(jsonEncode(validCache('1.20.1')));
    final list = create(filename, catalog: (list) async => throw StateError('network callback unexpected'));

    await list.load();

    expect(list.supportsMinecraftVersion('1.21.1'), true);
    expect(list.supportsMinecraftVersion('1.20.1'), false);
    expect(list.errorCode, 0);
  });

  test('Invalid primary and backup are not accepted as a catalog', () async {
    const filename = 'both-invalid.json';
    await primary(filename).writeAsString('{invalid');
    await backup(filename).writeAsString(jsonEncode({'schemaVersion': 2}));
    final list = create(filename, catalog: (list) async => throw const SocketException('offline'));

    await list.load();

    expect(list.hasMinecraftVersionCatalog, false);
    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.unavailable);
    expect(list.errorCode, -4);
  });

  test('Stale backup remains usable when refresh is offline', () async {
    const filename = 'offline-backup.json';
    await backup(filename).writeAsString(jsonEncode(validCache('1.21.1', updatedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)))));
    final list = create(filename, catalog: (list) async => throw const SocketException('offline'));

    await list.load();

    expect(list.catalogState, MtnLauncherGameLoaderCatalogState.stale);
    expect(list.supportsMinecraftVersion('1.21.1'), true);
    expect(list.errorCode, -4);
  });

  test('Separate instances serialize writes to one cache path', () async {
    await expectConcurrentPublication(filename: 'concurrent.json', directPath: directory.path, aliasPath: directory.path);
  });

  test('Dot-segment aliases share the same write queue', () async {
    final subdirectory = Directory('${directory.path}${Platform.pathSeparator}sub');
    await subdirectory.create();
    final aliasPath = '${subdirectory.path}${Platform.pathSeparator}..';

    await expectConcurrentPublication(filename: 'dot-segment.json', directPath: directory.path, aliasPath: aliasPath);
  });

  test('Directory link aliases share the same write queue', () async {
    final target = Directory('${directory.path}${Platform.pathSeparator}target');
    final alias = Link('${directory.path}${Platform.pathSeparator}alias');
    await target.create();
    try {
      await alias.create(target.path);
    } on FileSystemException catch (error) {
      markTestSkipped('Directory links are unavailable in this environment: $error');
      return;
    }

    await expectConcurrentPublication(filename: 'directory-link.json', directPath: target.path, aliasPath: alias.path);
  });
}
