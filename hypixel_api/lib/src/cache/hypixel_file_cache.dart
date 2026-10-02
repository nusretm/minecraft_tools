import 'dart:convert';
import 'dart:io';

class HypixelCacheEntry {
  const HypixelCacheEntry({
    required this.cachedAt,
    required this.expiresAt,
    required this.statusCode,
    required this.body,
  });

  final DateTime cachedAt;
  final DateTime expiresAt;
  final int statusCode;
  final Map<String, dynamic> body;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);
}

class HypixelFileCache {
  HypixelFileCache({required this.directory});

  final Directory directory;

  Future<HypixelCacheEntry?> read(String key) async {
    final file = File(_pathFor(key));
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return HypixelCacheEntry(
        cachedAt: DateTime.fromMillisecondsSinceEpoch(raw['cachedAt'] as int, isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(raw['expiresAt'] as int, isUtc: true),
        statusCode: raw['statusCode'] as int,
        body: Map<String, dynamic>.from(raw['body'] as Map),
      );
    } catch (_) {
      await file.delete().catchError((_) => file);
      return null;
    }
  }

  Future<void> write({
    required String key,
    required String method,
    required String path,
    required Map<String, String> query,
    required DateTime cachedAt,
    required DateTime expiresAt,
    required int statusCode,
    required Map<String, dynamic> body,
  }) async {
    await directory.create(recursive: true);
    final file = File(_pathFor(key));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode({
      'version': 1,
      'key': key,
      'method': method,
      'path': path,
      'query': query,
      'cachedAt': cachedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'statusCode': statusCode,
      'body': body,
    }), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<int> clearExpired() async {
    if (!await directory.exists()) return 0;
    var removed = 0;
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final raw = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final expiresAt = raw['expiresAt'] as int?;
        if (expiresAt == null || expiresAt <= DateTime.now().toUtc().millisecondsSinceEpoch) {
          await entity.delete();
          removed++;
        }
      } catch (_) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }

  String _pathFor(String key) => '${directory.path}${Platform.pathSeparator}$key.json';
}
