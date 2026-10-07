import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/minecraft_content_models.dart';
import '../minecraft_content_provider.dart';
import '../minecraft_content_provider_models.dart';
import 'minecraft_content_provider_modrinth_mapper.dart';

class MtnMinecraftContentProviderModrinth extends MtnMinecraftContentProvider {
  MtnMinecraftContentProviderModrinth({
    required this.userAgent,
    http.Client? client,
    Uri? baseUri,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUri = baseUri ?? Uri.parse('https://api.modrinth.com/v2/'),
       super(name: providerName) {
    if (userAgent.trim().isEmpty) throw ArgumentError.value(userAgent, 'userAgent', 'Modrinth User-Agent cannot be empty.');
    if (!this.baseUri.hasScheme || this.baseUri.host.isEmpty) throw ArgumentError.value(this.baseUri, 'baseUri', 'Modrinth baseUri must be absolute.');
  }

  static const String providerName = 'modrinth';

  final String userAgent;
  final Uri baseUri;
  final http.Client _client;
  final bool _ownsClient;

  @override
  bool get ready => true;

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    requireReady();

    final facets = MtnMinecraftContentProviderModrinthMapper.searchFacets(request);
    final query = <String, String>{
      if (request.query != null && request.query!.trim().isNotEmpty) 'query': request.query!.trim(),
      if (facets.isNotEmpty) 'facets': jsonEncode(facets),
      'offset': request.offset.toString(),
      'limit': request.limit.toString(),
    };

    final map = await _getMap(baseUri.resolve('search').replace(queryParameters: query));
    return MtnMinecraftContentProviderModrinthMapper.searchResult(name, map);
  }

  @override
  Future<MtnMinecraftContent> getContent(String id) async {
    requireReady();
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id', 'Modrinth project id or slug cannot be empty.');

    final map = await _getMap(baseUri.resolve('project/${Uri.encodeComponent(id.trim())}'));
    return MtnMinecraftContentProviderModrinthMapper.project(name, map);
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String id) async {
    requireReady();
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id', 'Modrinth version id cannot be empty.');

    final map = await _getMap(baseUri.resolve('version/${Uri.encodeComponent(id.trim())}'));
    final projectId = MtnMinecraftContentModel.stringFromMap(map['project_id']);
    final content = await getContent(projectId);
    return MtnMinecraftContentProviderModrinthMapper.version(name, content, map);
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    requireReady();

    final projectId = MtnMinecraftContentProviderModrinthMapper.providerId(name, content);
    final query = MtnMinecraftContentProviderModrinthMapper.versionQuery(request);

    final value = await _get(baseUri.resolve('project/${Uri.encodeComponent(projectId)}/version').replace(queryParameters: query));
    final decoded = jsonDecode(value);
    if (decoded is! List<Object?>) throw MtnMinecraftContentProviderModrinthException(uri: baseUri, message: 'Expected a JSON array while reading Modrinth project versions.');

    return MtnMinecraftContentProviderModrinthMapper.versionResult(name, content, request, decoded);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> _getMap(Uri uri) async {
    final value = await _get(uri);
    final decoded = jsonDecode(value);
    if (decoded is! Map<Object?, Object?>) throw MtnMinecraftContentProviderModrinthException(uri: uri, message: 'Expected a JSON object from Modrinth.');
    return decoded.map((key, item) => MapEntry(key.toString(), item));
  }

  Future<String> _get(Uri uri) async {
    final response = await runRequest(() async {
      var retriedAfterRateLimit = false;

      while (true) {
        final response = await _client.get(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'User-Agent': userAgent,
          },
        );

        _updateRateLimitFromResponse(response);

        if (response.statusCode != 429 || retriedAfterRateLimit) return response;

        final retryAfter = _retryAfter(response);
        if (retryAfter == null) return response;

        throttleRequests(retryAfter);
        await waitForRequestAvailability();
        retriedAfterRateLimit = true;
      }
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MtnMinecraftContentProviderModrinthException(
        uri: uri,
        statusCode: response.statusCode,
        message: 'Modrinth request failed with HTTP ${response.statusCode}.',
        responseBody: response.body,
      );
    }

    return response.body;
  }

  void _updateRateLimitFromResponse(http.Response response) {
    final limit = int.tryParse(_header(response, 'x-ratelimit-limit') ?? '');
    final remaining = int.tryParse(_header(response, 'x-ratelimit-remaining') ?? '');
    final resetSeconds = int.tryParse(_header(response, 'x-ratelimit-reset') ?? '');

    if (limit == null && remaining == null && resetSeconds == null) return;

    updateRateLimit(
      limit: limit,
      remaining: remaining,
      resetAfter: resetSeconds == null || resetSeconds < 0 ? null : Duration(seconds: resetSeconds),
    );
  }

  Duration? _retryAfter(http.Response response) {
    final retryAfterSeconds = int.tryParse(_header(response, 'retry-after') ?? '');
    if (retryAfterSeconds != null && retryAfterSeconds >= 0) return Duration(seconds: retryAfterSeconds);

    final resetSeconds = int.tryParse(_header(response, 'x-ratelimit-reset') ?? '');
    if (resetSeconds != null && resetSeconds >= 0) return Duration(seconds: resetSeconds);

    return null;
  }

  String? _header(http.Response response, String name) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }
}

class MtnMinecraftContentProviderModrinthException implements Exception {
  const MtnMinecraftContentProviderModrinthException({
    required this.uri,
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final Uri uri;
  final int? statusCode;
  final String message;
  final String? responseBody;

  @override
  String toString() => 'MtnMinecraftContentProviderModrinthException(uri=$uri, statusCode=$statusCode, message=$message)';
}
