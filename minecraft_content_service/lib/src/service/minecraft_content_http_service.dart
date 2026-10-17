import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Single transport and in-memory response-cache authority for content providers.
///
/// The request key contains the HTTP method, full canonical URL, sorted request
/// headers (including authorization identity) and body. Only the SHA-256 digest
/// is retained; credentials are never stored as readable cache keys.
/// Successful responses expire one hour after receipt by default. Failures and
/// HTTP 429 are never cached. In-flight equivalent calls share one request.
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

  final Map<String, (http.Response, DateTime)> _responses = <String, (http.Response, DateTime)>{};
  final Map<String, Future<http.Response>> _pending = <String, Future<http.Response>>{};

  int get cachedResponseCount {
    final now = DateTime.now();
    _responses.removeWhere((key, entry) => !entry.$2.isAfter(now));
    return _responses.length;
  }

  void clear() {
    _responses.clear();
    _pending.clear();
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
    void Function(http.Response)? onResponse,
    Future<bool> Function(http.Response)? onRateLimited,
  }) {
    final verb = method.toUpperCase();
    if (verb != 'GET' && verb != 'POST') throw ArgumentError.value(method, 'method', 'Only GET and POST are supported by content metadata transport.');
    final key = _requestKey(verb, uri, headers, body);
    if (cacheable) {
      final running = _pending[key];
      if (running != null) return running;
      final saved = _responses[key];
      if (saved != null) {
        if (saved.$2.isAfter(DateTime.now())) {
          // Keep frequently used entries at the end for bounded LRU eviction.
          _responses.remove(key);
          _responses[key] = saved;
          return Future<http.Response>.value(saved.$1);
        }
        _responses.remove(key);
      }
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
      if (identical(_pending[key], pending) && cacheDuration > Duration.zero &&
          response.statusCode >= 200 && response.statusCode < 300) {
        _responses.remove(key);
        _responses[key] = (response, DateTime.now().add(cacheDuration));
        while (_responses.length > maxCachedResponses) {
          _responses.remove(_responses.keys.first);
        }
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
