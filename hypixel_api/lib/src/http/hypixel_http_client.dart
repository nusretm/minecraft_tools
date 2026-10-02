import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../auth/hypixel_api_rate_limit_state.dart';
import '../cache/hypixel_file_cache.dart';

class HypixelHttpException implements Exception {
  const HypixelHttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'HypixelHttpException($statusCode): $body';
}

class HypixelHttpClient {
  HypixelHttpClient({
    required this.cache,
    Uri? baseUri,
    HttpClient? httpClient,
  })  : baseUri = baseUri ?? Uri.parse('https://api.hypixel.net'),
        _httpClient = httpClient ?? HttpClient();

  final HypixelFileCache cache;
  final Uri baseUri;
  final HttpClient _httpClient;
  HypixelApiRateLimitState? _rateLimitState;

  HypixelApiRateLimitState? get rateLimitState => _rateLimitState;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration cacheTtl = const Duration(minutes: 5),
    bool refresh = false,
  }) async {
    final canonicalQuery = <String, String>{};
    for (final key in query.keys.toList()..sort()) {
      final value = query[key];
      if (value != null) canonicalQuery[key] = value.toString();
    }

    final canonical = StringBuffer('GET\n$path\n');
    for (final entry in canonicalQuery.entries) {
      canonical.writeln('${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}');
    }
    final key = sha256.convert(utf8.encode(canonical.toString())).toString();

    if (!refresh) {
      final cached = await cache.read(key);
      if (cached != null && !cached.isExpired) return cached.body;
    }

    final uri = baseUri.replace(path: path, queryParameters: canonicalQuery.isEmpty ? null : canonicalQuery);
    final request = await _httpClient.getUrl(uri);
    // HypixelApi is frequently used from short-lived CLI processes. Do not
    // leave an HTTP keep-alive socket behind after a request completes.
    // File caching already prevents unnecessary network calls, so keeping the
    // transport connection alive provides little value here.
    request.persistentConnection = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    _captureRateLimit(response.headers);
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HypixelHttpException(response.statusCode, text);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('Hypixel response is not a JSON object');
    final body = Map<String, dynamic>.from(decoded);
    if (body['success'] == false) throw FormatException('Hypixel API returned success=false: $body');

    final now = DateTime.now().toUtc();
    await cache.write(
      key: key,
      method: 'GET',
      path: path,
      query: canonicalQuery,
      cachedAt: now,
      expiresAt: now.add(cacheTtl),
      statusCode: response.statusCode,
      body: body,
    );
    return body;
  }


  void _captureRateLimit(HttpHeaders headers) {
    final limit = int.tryParse(headers.value('RateLimit-Limit') ?? '');
    final remaining = int.tryParse(headers.value('RateLimit-Remaining') ?? '');
    final resetSeconds = int.tryParse(headers.value('RateLimit-Reset') ?? '');
    if (limit == null || remaining == null || resetSeconds == null) return;

    _rateLimitState = HypixelApiRateLimitState(
      limit: limit,
      remaining: remaining,
      resetAfter: Duration(seconds: resetSeconds < 0 ? 0 : resetSeconds),
      observedAt: DateTime.now().toUtc(),
    );
  }

  /// Immediately closes any transport resources currently owned by this
  /// client. Normal callers do not need this for process shutdown because
  /// requests are non-persistent, but it is available for explicit teardown.
  void close({bool force = false}) => _httpClient.close(force: force);
}
