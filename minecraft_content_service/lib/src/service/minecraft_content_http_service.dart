import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Single transport and in-memory response-cache authority for content providers.
///
/// The request key contains the HTTP method, full canonical URL, sorted request
/// headers (including authorization identity) and body. Only the SHA-256 digest
/// is retained; credentials are never stored as readable cache keys.
/// Successful responses have a default one-hour freshness window; callers may
/// request a different TTL without introducing a second cache. Failures and
/// HTTP 429 are never cached. In-flight equivalent calls share one request.
/// A cached-only lookup never triggers a provider request.
class MtnMinecraftContentHttpCacheMissException implements Exception {
  const MtnMinecraftContentHttpCacheMissException();

  @override
  String toString() => 'MtnMinecraftContentHttpCacheMissException';
}

/// Async-local policy shares the existing transport for nested provider calls.
final class _MtnMinecraftContentHttpCacheOptions {
  _MtnMinecraftContentHttpCacheOptions(this.cacheDuration, this.forceRefresh, this.cachedOnly);

  final Duration cacheDuration;
  final bool forceRefresh;
  final bool cachedOnly;
  final Set<String> refreshedKeys = <String>{};
}

class MtnMinecraftContentHttpService {
  MtnMinecraftContentHttpService({
    this.cacheDuration = const Duration(hours: 1),
    this.maxCachedResponses = 256,
  }) {
    if (cacheDuration.isNegative) throw ArgumentError.value(cacheDuration, 'cacheDuration', 'Cache duration cannot be negative.');
    if (maxCachedResponses < 1) throw ArgumentError.value(maxCachedResponses, 'maxCachedResponses', 'Cache capacity must be positive.');
  }

  final Duration cacheDuration;
  final int maxCachedResponses;

  /// Response, receipt time and longest granted retention window.
  final Map<String, (http.Response, DateTime, Duration)> _responses = <String, (http.Response, DateTime, Duration)>{};
  final Object _cacheOptionsKey = Object();
  final Map<String, Future<http.Response>> _pending = <String, Future<http.Response>>{};

  // Decoded objects share the lifetime of their owning cached HTTP response.
  // No second independent key/TTL/eviction authority is introduced.
  final Expando<Future<Object?>> _decodedJson = Expando<Future<Object?>>('content-http-json');

  /// Decode JSON once per response identity. The costly first decode runs off
  /// the calling isolate; subsequent cache hits reuse the same Future.
  Future<Object?> decodeJson(http.Response response) {
    final Future<Object?>? existing = _decodedJson[response];
    if (existing != null) return existing;
    final String body = response.body;
    final Future<Object?> decoded = Isolate.run(() => jsonDecode(body));
    _decodedJson[response] = decoded;
    return decoded;
  }


  int get cachedResponseCount {
    final now = DateTime.now();
    _responses.removeWhere((key, entry) => !entry.$2.add(entry.$3).isAfter(now));
    return _responses.length;
  }

  void clear() {
    _responses.clear();
    _pending.clear();
  }

  /// Applies one request policy across async nested calls to any provider.
  /// Async zones keep parallel package checks independent. forceRefresh fetches
  /// each unique HTTP request once within the operation, then reuses its result.
  Future<T> withCacheOptions<T>({
    Duration? cacheDuration,
    bool forceRefresh = false,
    bool cachedOnly = false,
    required Future<T> Function() action,
  }) {
    final duration = cacheDuration ?? this.cacheDuration;
    if (duration.isNegative) throw ArgumentError.value(duration, 'cacheDuration', 'Cache duration cannot be negative.');
    if (forceRefresh && cachedOnly) throw ArgumentError('Cannot force refresh while requiring cached-only responses.');
    return runZoned(action, zoneValues: <Object, Object>{
      _cacheOptionsKey: _MtnMinecraftContentHttpCacheOptions(duration, forceRefresh, cachedOnly),
    });
  }

  /// Cache lookup precedes the provider's serial/rate-limit queue.
  ///
  /// [enqueue] is the provider's existing request gate, [onResponse] observes
  /// actual HTTP replies, and [onRateLimited] preserves provider-specific 429
  /// throttling. Non-cacheable calls still use this single transport.
  Future<http.Response> send({
    required http.Client client,
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    required Future<http.Response> Function(Future<http.Response> Function()) enqueue,
    String? body,
    bool cacheable = true,
    Duration? cacheDuration,
    bool forceRefresh = false,
    bool cachedOnly = false,
    void Function(http.Response)? onResponse,
    Future<bool> Function(http.Response)? onRateLimited,
  }) {
    final verb = method.toUpperCase();
    if (verb != 'GET' && verb != 'POST') throw ArgumentError.value(method, 'method', 'Only GET and POST are supported by content metadata transport.');
    final scope = Zone.current[_cacheOptionsKey] as _MtnMinecraftContentHttpCacheOptions?;
    final duration = cacheDuration ?? scope?.cacheDuration ?? this.cacheDuration;
    if (duration.isNegative) throw ArgumentError.value(duration, 'cacheDuration', 'Cache duration cannot be negative.');
    final key = _requestKey(verb, uri, headers, body);
    final onlyCached = cachedOnly || (scope?.cachedOnly ?? false);
    final force = forceRefresh || (scope != null && scope.forceRefresh && !scope.refreshedKeys.contains(key));
    if (onlyCached && force) throw ArgumentError('Cannot force refresh and read only cached responses.');

    if (cacheable && duration > Duration.zero && !force) {
      final saved = _responses[key];
      if (saved != null && saved.$2.add(duration).isAfter(DateTime.now())) {
        // An older 1-hour caller may not consume a 6-hour-old response.
        // Extend retention for a longer-lived caller without changing receipt time.
        final retention = duration > saved.$3 ? duration : saved.$3;
        _responses.remove(key);
        _responses[key] = (saved.$1, saved.$2, retention);
        return Future<http.Response>.value(saved.$1);
      }
    }
    if (onlyCached) return Future<http.Response>.error(const MtnMinecraftContentHttpCacheMissException());

    if (cacheable && !force) {
      final running = _pending[key];
      if (running != null) return running;
    }

    Future<http.Response> network() => enqueue(() async {
      var retried = false;
      while (true) {
        final request = http.Request(verb, uri)..headers.addAll(headers);
        if (body != null) request.body = body;
        final response = await http.Response.fromStream(await client.send(request));
        onResponse?.call(response);
        if (response.statusCode != 429 || retried || onRateLimited == null) return response;
        if (!await onRateLimited(response)) return response;
        retried = true;
      }
    });

    if (!cacheable) return network();

    late final Future<http.Response> pending;
    pending = Future<http.Response>.sync(network).then((response) {
      if (identical(_pending[key], pending) &&
          response.statusCode >= 200 && response.statusCode < 300) {
        if (duration > Duration.zero) {
          _responses.remove(key);
          _responses[key] = (response, DateTime.now(), duration);
          while (_responses.length > maxCachedResponses) {
            _responses.remove(_responses.keys.first);
          }
        }
        if (scope != null && scope.forceRefresh) scope.refreshedKeys.add(key);
      }
      return response;
    }).whenComplete(() {
      if (identical(_pending[key], pending)) _pending.remove(key);
    });
    _pending[key] = pending;
    return pending;
  }

  String _requestKey(String method, Uri uri, Map<String, String> headers, String? body) {
    final query = uri.queryParametersAll.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final normalizedQuery = <List<Object>>[
      for (final entry in query) <Object>[entry.key, entry.value.toList()..sort()],
    ];
    final headerEntries = headers.entries.map((entry) => MapEntry(entry.key.toLowerCase(), entry.value)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final data = jsonEncode(<Object?>[
      method,
      uri.replace(query: '', fragment: '').toString(),
      normalizedQuery,
      <List<String>>[for (final entry in headerEntries) <String>[entry.key, entry.value]],
      body,
    ]);
    return sha256.convert(utf8.encode(data)).toString();
  }
}
