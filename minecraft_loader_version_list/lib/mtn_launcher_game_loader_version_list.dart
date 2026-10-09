import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:minecraft_models/minecraft_models.dart';

/// Availability and freshness of the Minecraft support catalog.
enum MtnLauncherGameLoaderCatalogState {
  notLoaded,
  fresh,
  stale,
  unavailable,
}

class MtnLauncherGameLoaderVersionList {
  MtnLauncherGameLoaderVersionList({
    required this.cacheDirectory,
    required this.filename,
    required this.onLoadFromWeb,
    required this.onGenerateMinecraftVersionList,
    this.cacheDuration = const Duration(hours: 1),
  }) {
    if (filename.isEmpty || filename == '.' || filename == '..' || filename.contains('/') || filename.contains('\\')) {
      throw ArgumentError.value(filename, 'filename', 'Must be a file name, not a path');
    }
  }

  final String cacheDirectory;
  final String filename;
  final Future<List<MtnLauncherGameLoaderMinecraftVersion>> Function(MtnLauncherGameLoaderVersionList list) onLoadFromWeb;
  final Future<List<MtnLauncherGameLoaderVersion>> Function(MtnLauncherGameLoaderVersionList list, MtnLauncherGameLoaderMinecraftVersion game) onGenerateMinecraftVersionList;
  final Duration cacheDuration;

  final List<MtnLauncherGameLoaderMinecraftVersion> _minecraftVersions = [];
  List<MtnLauncherGameLoaderMinecraftVersion> get minecraftVersions => UnmodifiableListView(_minecraftVersions);
  final Map<String, _GeneratedVersions> _generated = {};
  final List<MtnLauncherGameLoaderVersion> _items = [];
  List<MtnLauncherGameLoaderVersion> get items => UnmodifiableListView(_items);
  bool _hasMinecraftVersionCatalog = false;
  bool get hasMinecraftVersionCatalog => _hasMinecraftVersionCatalog;
  DateTime? _catalogUpdatedAt;
  bool _catalogLoadCompleted = false;
  /// Current catalog availability without triggering a load or refresh.
  MtnLauncherGameLoaderCatalogState get catalogState {
    if (!_catalogLoadCompleted) return MtnLauncherGameLoaderCatalogState.notLoaded;
    if (!_hasMinecraftVersionCatalog) return MtnLauncherGameLoaderCatalogState.unavailable;
    return _isFresh(_catalogUpdatedAt) ? MtnLauncherGameLoaderCatalogState.fresh : MtnLauncherGameLoaderCatalogState.stale;
  }
  bool _cacheRead = false;
  Future<_CatalogLoadResult>? _pendingLoad;
  final Map<String, Future<_GeneratedLoadResult>> _pendingGenerated = {};
  Future<void> _pendingSave = Future<void>.value();

  int _errorCode = 0;
  String _errorMessage = '';
  int get errorCode => _errorCode;
  String get errorMessage => _errorMessage;
  File get _cacheFile => File('$cacheDirectory${Platform.pathSeparator}$filename');

  /// Records connection/status failures, then throws through the callback.
  Future<String> downloadUrl(String url) async {
    Uri uri;
    try {
      uri = Uri.parse(url);
      if (uri.scheme != 'https' && uri.scheme != 'http') throw FormatException('Unsupported URL scheme: ${uri.scheme}');
    } catch (error) {
      _errorCode = -1;
      _errorMessage = 'Invalid URL: $error';
      rethrow;
    }
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'MTNLauncher-VersionList/1.0',
        'Accept': 'application/json, application/xml, text/xml, */*',
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        _errorCode = response.statusCode;
        _errorMessage = 'HTTP ${response.statusCode}: $uri';
        throw HttpException(_errorMessage, uri: uri);
      }
      return utf8.decode(response.bodyBytes);
    } on TimeoutException catch (error) {
      _errorCode = -2;
      _errorMessage = 'Request timed out: $uri ($error)';
      rethrow;
    } on SocketException catch (error) {
      _errorCode = error.osError?.errorCode ?? -3;
      _errorMessage = 'Network error: $uri ($error)';
      rethrow;
    } on http.ClientException catch (error) {
      _errorCode = -3;
      _errorMessage = 'HTTP client error: $uri ($error)';
      rethrow;
    } catch (error) {
      if (_errorCode == 0) {
        _errorCode = -3;
        _errorMessage = 'Download failed: $uri ($error)';
      }
      rethrow;
    }
  }

  /// Load the complete supported-Minecraft catalog, not every loader build.
  Future<List<MtnLauncherGameLoaderMinecraftVersion>> load() async {
    await _load();
    return minecraftVersions;
  }

  Future<_CatalogLoadResult> _load() {
    if (_pendingLoad != null) return _pendingLoad!;
    final future = _loadOnce();
    _pendingLoad = future.whenComplete(() { _pendingLoad = null; });
    return _pendingLoad!;
  }

  Future<_CatalogLoadResult> _loadOnce() async {
    try {
      await _readCacheOnce();
      if (_hasMinecraftVersionCatalog && _isFresh(_catalogUpdatedAt)) return const _CatalogLoadResult(hasUsableData: true, authoritative: true);

      _errorCode = 0;
      _errorMessage = '';
      try {
        final incoming = await onLoadFromWeb(this);
        final unique = <String, MtnLauncherGameLoaderMinecraftVersion>{};
        for (final game in incoming) {
          if (game.mcVersion.isEmpty || game.versionId.isEmpty) throw const FormatException('Invalid Minecraft version support entry');
          unique[_key(game)] = game;
        }
        _minecraftVersions
          ..clear()
          ..addAll(unique.values);
        _hasMinecraftVersionCatalog = true;
        _catalogUpdatedAt = DateTime.now().toUtc();
        _generated.removeWhere((key, value) => !unique.containsKey(key));
        _rebuildItems();
      } catch (error) {
        if (_errorCode == 0) {
          _errorCode = -4;
          _errorMessage = 'Minecraft catalog load error: $error';
        }
        return _CatalogLoadResult(hasUsableData: _hasMinecraftVersionCatalog, authoritative: false, error: error);
      }
      await _saveCache();
      return const _CatalogLoadResult(hasUsableData: true, authoritative: true);
    } finally {
      _catalogLoadCompleted = true;
    }
  }

  /// Call load() first. If hasMinecraftVersionCatalog is false, compatibility
  /// is unknown; false from this method is not authoritative.
  bool supportsMinecraftVersion(String mcVersion, [List<MtnLauncherGameVersionType> types = const []]) {
    if (!_hasMinecraftVersionCatalog) return false;
    return _minecraftVersions.any((game) => game.mcVersion == mcVersion && (types.isEmpty || types.contains(game.type)));
  }

  /// Lazy loader-build discovery with a separate timestamp per upstream game ID.
  Future<List<MtnLauncherGameLoaderVersion>> loadMinecraftVersion(String mcVersion, [List<MtnLauncherGameVersionType> types = const []]) async {
    final catalog = await _load();
    if (!catalog.hasUsableData) return getFromMinecraftVersion(mcVersion, types);
    final matches = _minecraftVersions.where((game) => game.mcVersion == mcVersion && (types.isEmpty || types.contains(game.type)));
    for (final game in matches) {
      await _generate(game);
    }
    return getFromMinecraftVersion(mcVersion, types);
  }

  Future<_GeneratedLoadResult> _generate(MtnLauncherGameLoaderMinecraftVersion game) {
    final key = _key(game);
    final existing = _pendingGenerated[key];
    if (existing != null) return existing;
    final future = _generateOnce(key, game);
    _pendingGenerated[key] = future.whenComplete(() { _pendingGenerated.remove(key); });
    return _pendingGenerated[key]!;
  }

  Future<_GeneratedLoadResult> _generateOnce(String key, MtnLauncherGameLoaderMinecraftVersion game) async {
    final cached = _generated[key];
    if (cached != null && _isFresh(cached.updatedAt)) return _GeneratedLoadResult(versions: UnmodifiableListView(cached.versions), hasUsableData: true, authoritative: true);

    _errorCode = 0;
    _errorMessage = '';
    List<MtnLauncherGameLoaderVersion> incoming;
    try {
      incoming = List.of(await onGenerateMinecraftVersionList(this, game));
      for (final item in incoming) {
        if (item.mcVersion != game.mcVersion || item.type != game.type) {
          throw FormatException('Build ${item.version} does not match ${game.mcVersion} (${game.type.name})');
        }
      }
      sortItems(incoming);
    } catch (error) {
      if (_errorCode == 0) {
        _errorCode = -4;
        _errorMessage = 'Loader version generation error: $error';
      }
      return _GeneratedLoadResult(
        versions: cached == null ? const [] : UnmodifiableListView(cached.versions),
        hasUsableData: cached != null,
        authoritative: false,
        error: error,
      );
    }

    _generated[key] = _GeneratedVersions(game: game, updatedAt: DateTime.now().toUtc(), versions: incoming);
    _rebuildItems();
    await _saveCache();
    return _GeneratedLoadResult(versions: UnmodifiableListView(incoming), hasUsableData: true, authoritative: true);
  }

  /// Resolves an exact upstream build ID or the highest eligible automatic candidate.
  Future<MtnLauncherGameLoaderVersion?> resolveVersion({
    required String mcVersion,
    String? version,
    List<MtnLauncherGameVersionType> types = const [],
    bool allowUnknownChannelFallback = true,
  }) async {
    if (mcVersion.trim().isEmpty) throw ArgumentError.value(mcVersion, 'mcVersion', 'Must not be empty');
    if (version != null && version.trim().isEmpty) throw ArgumentError.value(version, 'version', 'Must not be empty');

    final catalog = await _load();
    if (!catalog.hasUsableData) throw StateError('Minecraft version catalog is unavailable: ${catalog.error}');

    final games = _minecraftVersions.where((game) => game.mcVersion == mcVersion && (types.isEmpty || types.contains(game.type))).toList();
    if (games.isEmpty) {
      if (!catalog.authoritative) throw StateError('Minecraft version support could not be confirmed from the stale catalog: $mcVersion');
      return null;
    }

    final results = await Future.wait(games.map(_generate));
    for (int i = 0; i < results.length; i++) {
      if (!results[i].hasUsableData) throw StateError('Loader version metadata is unavailable for ${games[i].versionId}: ${results[i].error}');
    }
    final candidates = results.expand((result) => result.versions).toList();

    if (version != null) {
      final exact = candidates.where((candidate) => candidate.version == version).toList();
      if (exact.isEmpty) {
        if (!catalog.authoritative || results.any((result) => !result.authoritative)) throw StateError('Exact loader version could not be confirmed from stale metadata: $version');
        return null;
      }
      final first = exact.first;
      for (final candidate in exact.skip(1)) {
        if (candidate.mcVersion != first.mcVersion || candidate.type != first.type || candidate.channel != first.channel || candidate.url != first.url) {
          throw StateError('Conflicting loader metadata for exact version $version');
        }
      }
      exact.sort(_compareResolutionCandidates);
      return exact.first;
    }

    var selectable = candidates.where((candidate) => candidate.channel == MtnLauncherGameLoaderChannel.stable).toList();
    if (selectable.isEmpty && allowUnknownChannelFallback) {
      selectable = candidates.where((candidate) => candidate.channel == MtnLauncherGameLoaderChannel.unknown).toList();
    }
    if (selectable.isEmpty) {
      if (!catalog.authoritative || results.any((result) => !result.authoritative)) throw StateError('Loader version selection could not be confirmed from stale metadata for $mcVersion');
      return null;
    }
    selectable.sort(_compareResolutionCandidates);
    return selectable.first;
  }

  /// Synchronous lookup of builds already generated or restored from disk.
  List<MtnLauncherGameLoaderVersion> getFromMinecraftVersion(String mcVersion, [List<MtnLauncherGameVersionType> types = const []]) {
    return List.unmodifiable(_items.where((item) => item.mcVersion == mcVersion && (types.isEmpty || types.contains(item.type))));
  }

  void sortItems(List<MtnLauncherGameLoaderVersion> versions) {
    versions.sort((a, b) {
      final mcOrder = _compareNatural(b.mcVersion, a.mcVersion);
      if (mcOrder != 0) return mcOrder;
      return _compareNatural(b.text, a.text);
    });
  }

  int _compareNatural(String a, String b) {
    final aParts = RegExp(r'\d+|\D+').allMatches(a).map((match) => match.group(0)!).toList();
    final bParts = RegExp(r'\d+|\D+').allMatches(b).map((match) => match.group(0)!).toList();
    for (int i = 0; i < aParts.length && i < bParts.length; i++) {
      final left = int.tryParse(aParts[i]);
      final right = int.tryParse(bParts[i]);
      final order = left != null && right != null ? left.compareTo(right) : aParts[i].toLowerCase().compareTo(bParts[i].toLowerCase());
      if (order != 0) return order;
    }
    return aParts.length.compareTo(bParts.length);
  }

  int _compareResolutionCandidates(MtnLauncherGameLoaderVersion a, MtnLauncherGameLoaderVersion b) {
    var order = _compareNatural(b.version, a.version);
    if (order != 0) return order;
    order = b.version.compareTo(a.version);
    if (order != 0) return order;
    order = a.type.name.compareTo(b.type.name);
    if (order != 0) return order;
    order = a.url.compareTo(b.url);
    if (order != 0) return order;
    return a.channel.name.compareTo(b.channel.name);
  }

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null) return false;
    final age = DateTime.now().toUtc().difference(timestamp);
    return !age.isNegative && age < cacheDuration;
  }

  String _key(MtnLauncherGameLoaderMinecraftVersion game) => jsonEncode([game.mcVersion, game.versionId, game.type.name]);

  void _rebuildItems() {
    _items.clear();
    for (final entry in _generated.values) {
      _items.addAll(entry.versions);
    }
    sortItems(_items);
  }

  Future<void> _readCacheOnce() async {
    if (_cacheRead) return;
    _cacheRead = true;
    final file = _cacheFile;
    if (!await file.exists()) return;
    try {
      final root = jsonDecode(await file.readAsString());
      if (root is! Map<String, dynamic> || root['schemaVersion'] != 1) return;
      final catalogDate = DateTime.parse(root['catalogUpdatedAt'] as String).toUtc();
      final restoredVersions = <MtnLauncherGameLoaderMinecraftVersion>[];
      for (final raw in root['minecraftVersions'] as List<dynamic>) {
        final entry = raw as Map<String, dynamic>;
        restoredVersions.add((
          mcVersion: entry['mcVersion'] as String,
          versionId: entry['versionId'] as String,
          type: MtnLauncherGameVersionType.values.byName(entry['type'] as String),
        ));
      }
      final restoredGenerated = <String, _GeneratedVersions>{};
      for (final raw in root['generated'] as List<dynamic>) {
        final entry = raw as Map<String, dynamic>;
        final game = (
          mcVersion: entry['mcVersion'] as String,
          versionId: entry['versionId'] as String,
          type: MtnLauncherGameVersionType.values.byName(entry['type'] as String),
        );
        final versions = (entry['items'] as List<dynamic>).map((raw) => MtnLauncherGameLoaderVersion.fromJson(raw as Map<String, dynamic>)).toList();
        restoredGenerated[_key(game)] = _GeneratedVersions(game: game, updatedAt: DateTime.parse(entry['updatedAt'] as String).toUtc(), versions: versions);
      }
      _minecraftVersions
        ..clear()
        ..addAll(restoredVersions);
      _catalogUpdatedAt = catalogDate;
      _hasMinecraftVersionCatalog = true;
      _generated
        ..clear()
        ..addAll(restoredGenerated);
      _rebuildItems();
    } catch (_) {
      // Invalid/legacy cache: refresh from the provider.
    }
  }

  Future<void> _saveCache() async {
    _pendingSave = _pendingSave.then((_) async {
      final file = _cacheFile;
      try {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        final root = {
          'schemaVersion': 1,
          'catalogUpdatedAt': _catalogUpdatedAt?.toIso8601String(),
          'minecraftVersions': _minecraftVersions.map((game) => {
            'mcVersion': game.mcVersion,
            'versionId': game.versionId,
            'type': game.type.name,
          }).toList(),
          'generated': _generated.values.map((entry) => {
            'mcVersion': entry.game.mcVersion,
            'versionId': entry.game.versionId,
            'type': entry.game.type.name,
            'updatedAt': entry.updatedAt.toIso8601String(),
            'items': entry.versions.map((item) => item.toJson()).toList(),
          }).toList(),
        };
        await temporary.writeAsString(jsonEncode(root), flush: true);
        // Windows File.rename may not replace an existing target.
        final backup = File('${file.path}.bak');
        if (await file.exists()) {
          if (await backup.exists()) await backup.delete();
          await file.rename(backup.path);
        }
        try {
          await temporary.rename(file.path);
          if (await backup.exists()) await backup.delete();
        } catch (_) {
          if (!await file.exists() && await backup.exists()) await backup.rename(file.path);
          rethrow;
        }
      } catch (error) {
        _errorCode = -5;
        _errorMessage = 'Version cache write error: $error';
      }
    });
    await _pendingSave;
  }
}

class _GeneratedVersions {
  _GeneratedVersions({required this.game, required this.updatedAt, required this.versions});
  final MtnLauncherGameLoaderMinecraftVersion game;
  final DateTime updatedAt;
  final List<MtnLauncherGameLoaderVersion> versions;
}

class _CatalogLoadResult {
  const _CatalogLoadResult({required this.hasUsableData, required this.authoritative, this.error});
  final bool hasUsableData;
  final bool authoritative;
  final Object? error;
}

class _GeneratedLoadResult {
  const _GeneratedLoadResult({required this.versions, required this.hasUsableData, required this.authoritative, this.error});
  final List<MtnLauncherGameLoaderVersion> versions;
  final bool hasUsableData;
  final bool authoritative;
  final Object? error;
}
