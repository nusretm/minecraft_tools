import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'mtn_launcher_game_loader_version.dart';
import 'mtn_launcher_game_version_type.dart';

typedef MtnLauncherGameLoaderMinecraftVersion = ({
  String mcVersion,
  String versionId,
  MtnLauncherGameVersionType type,
});

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
  bool _cacheRead = false;
  Future<List<MtnLauncherGameLoaderMinecraftVersion>>? _pendingLoad;
  final Map<String, Future<List<MtnLauncherGameLoaderVersion>>> _pendingGenerated = {};
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
  Future<List<MtnLauncherGameLoaderMinecraftVersion>> load() {
    if (_pendingLoad != null) return _pendingLoad!;
    final future = _loadOnce();
    _pendingLoad = future.whenComplete(() { _pendingLoad = null; });
    return _pendingLoad!;
  }

  Future<List<MtnLauncherGameLoaderMinecraftVersion>> _loadOnce() async {
    await _readCacheOnce();
    if (_hasMinecraftVersionCatalog && _isFresh(_catalogUpdatedAt)) return minecraftVersions;

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
      return minecraftVersions;
    }
    await _saveCache();
    return minecraftVersions;
  }

  /// Call load() first. If hasMinecraftVersionCatalog is false, compatibility
  /// is unknown; false from this method is not authoritative.
  bool supportsMinecraftVersion(String mcVersion, [List<MtnLauncherGameVersionType> types = const []]) {
    if (!_hasMinecraftVersionCatalog) return false;
    return _minecraftVersions.any((game) => game.mcVersion == mcVersion && (types.isEmpty || types.contains(game.type)));
  }

  /// Lazy loader-build discovery with a separate timestamp per upstream game ID.
  Future<List<MtnLauncherGameLoaderVersion>> loadMinecraftVersion(String mcVersion, [List<MtnLauncherGameVersionType> types = const []]) async {
    await load();
    if (!_hasMinecraftVersionCatalog) return getFromMinecraftVersion(mcVersion, types);
    final matches = _minecraftVersions.where((game) => game.mcVersion == mcVersion && (types.isEmpty || types.contains(game.type)));
    for (final game in matches) {
      await _generate(game);
    }
    return getFromMinecraftVersion(mcVersion, types);
  }

  Future<List<MtnLauncherGameLoaderVersion>> _generate(MtnLauncherGameLoaderMinecraftVersion game) {
    final key = _key(game);
    final existing = _pendingGenerated[key];
    if (existing != null) return existing;
    final future = _generateOnce(key, game);
    _pendingGenerated[key] = future.whenComplete(() { _pendingGenerated.remove(key); });
    return _pendingGenerated[key]!;
  }

  Future<List<MtnLauncherGameLoaderVersion>> _generateOnce(String key, MtnLauncherGameLoaderMinecraftVersion game) async {
    final cached = _generated[key];
    if (cached != null && _isFresh(cached.updatedAt)) return UnmodifiableListView(cached.versions);

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
      return cached == null ? const [] : UnmodifiableListView(cached.versions);
    }

    _generated[key] = _GeneratedVersions(game: game, updatedAt: DateTime.now().toUtc(), versions: incoming);
    _rebuildItems();
    await _saveCache();
    return UnmodifiableListView(incoming);
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