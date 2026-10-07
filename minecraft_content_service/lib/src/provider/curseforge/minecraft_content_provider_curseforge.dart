import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/minecraft_content_models.dart';
import '../minecraft_content_provider.dart';
import '../minecraft_content_provider_models.dart';
import 'minecraft_content_provider_curseforge_mapper.dart';

class MtnMinecraftContentProviderCurseForge extends MtnMinecraftContentProvider {
  MtnMinecraftContentProviderCurseForge({
    required String apiKey,
    http.Client? client,
    Uri? baseUri,
  }) : _apiKey = apiKey,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUri = baseUri ?? Uri.parse('https://api.curseforge.com/'),
       super(name: providerName) {
    if (apiKey.trim().isEmpty) throw ArgumentError('CurseForge API key cannot be empty.');
    if (!this.baseUri.hasScheme || this.baseUri.host.isEmpty) throw ArgumentError.value(this.baseUri, 'baseUri', 'CurseForge baseUri must be absolute.');
  }

  static const String providerName = 'curseforge';
  static const int minecraftGameId = 432;

  final String _apiKey;
  final Uri baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Map<MtnMinecraftContentType, int>? _classIdsByContentType;
  Map<int, MtnMinecraftContentType>? _contentTypesByClassId;

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    MtnMinecraftContentProviderCurseForgeMapper.validateSearchRequest(request);

    await _ensureContentClasses();
    final contentType = request.types.single;
    final classId = _classIdsByContentType![contentType];
    if (classId == null) throw StateError('CurseForge does not expose a Minecraft class for content type: ${contentType.name}');

    final query = MtnMinecraftContentProviderCurseForgeMapper.searchQuery(request, minecraftGameId, classId);
    final envelope = await _getEnvelope(baseUri.resolve('v1/mods/search').replace(queryParameters: query));

    return MtnMinecraftContentProviderCurseForgeMapper.searchResult(name, contentType, request, envelope);
  }

  @override
  Future<MtnMinecraftContent> getContent(String id) async {
    final modId = int.tryParse(id.trim());
    if (modId == null || modId <= 0) throw ArgumentError.value(id, 'id', 'CurseForge content id must be a positive integer.');

    await _ensureContentClasses();

    final modEnvelope = await _getEnvelope(baseUri.resolve('v1/mods/$modId'));
    final descriptionEnvelope = await _getEnvelope(baseUri.resolve('v1/mods/$modId/description'));

    final mod = MtnMinecraftContentProviderCurseForgeMapper.dataMap(modEnvelope, 'CurseForge mod');
    final classId = MtnMinecraftContentModel.intFromMap(mod['classId'], fallback: -1);
    final contentType = _contentTypesByClassId![classId];
    if (contentType == null) throw FormatException('Unsupported CurseForge Minecraft class id: $classId');

    final description = MtnMinecraftContentProviderCurseForgeMapper.dataString(descriptionEnvelope);
    return MtnMinecraftContentProviderCurseForgeMapper.content(name, contentType, mod, description: description);
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    final modId = MtnMinecraftContentProviderCurseForgeMapper.providerId(name, content);
    MtnMinecraftContentProviderCurseForgeMapper.validateVersionRequest(content, request);

    final files = <Map<String, dynamic>>[];
    var index = 0;

    while (index < 10000) {
      final query = MtnMinecraftContentProviderCurseForgeMapper.versionQuery(content, request, index: index, pageSize: 50);
      final envelope = await _getEnvelope(baseUri.resolve('v1/mods/$modId/files').replace(queryParameters: query));
      final page = MtnMinecraftContentProviderCurseForgeMapper.dataList(envelope);
      files.addAll(page);

      final pagination = MtnMinecraftContentModel.mapFromMap(envelope['pagination']);
      final resultCount = MtnMinecraftContentModel.intFromMap(pagination['resultCount'], fallback: page.length);
      final totalCount = MtnMinecraftContentModel.intFromMap(pagination['totalCount'], fallback: files.length);

      if (resultCount <= 0) break;

      index += resultCount;
      if (index >= totalCount || resultCount < 50) break;
    }

    return MtnMinecraftContentProviderCurseForgeMapper.versionResult(name, content, request, files);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<void> _ensureContentClasses() async {
    if (_classIdsByContentType != null && _contentTypesByClassId != null) return;

    final envelope = await _getEnvelope(
      baseUri.resolve('v1/categories').replace(
        queryParameters: <String, String>{
          'gameId': minecraftGameId.toString(),
          'classesOnly': 'true',
        },
      ),
    );
    final maps = MtnMinecraftContentProviderCurseForgeMapper.contentClassMaps(MtnMinecraftContentProviderCurseForgeMapper.dataList(envelope));
    _classIdsByContentType = maps.$1;
    _contentTypesByClassId = maps.$2;
  }

  Future<Map<String, dynamic>> _getEnvelope(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'x-api-key': _apiKey,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MtnMinecraftContentProviderCurseForgeException(
        uri: uri,
        statusCode: response.statusCode,
        message: 'CurseForge request failed with HTTP ${response.statusCode}.',
        responseBody: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<Object?, Object?>) throw MtnMinecraftContentProviderCurseForgeException(uri: uri, message: 'Expected a JSON object from CurseForge.');

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
}

class MtnMinecraftContentProviderCurseForgeException implements Exception {
  const MtnMinecraftContentProviderCurseForgeException({
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
  String toString() => 'MtnMinecraftContentProviderCurseForgeException(uri=$uri, statusCode=$statusCode, message=$message)';
}
