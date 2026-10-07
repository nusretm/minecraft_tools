import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/minecraft_content_models.dart';
import '../minecraft_content_provider.dart';
import '../minecraft_content_provider_models.dart';
import 'minecraft_content_provider_curseforge_mapper.dart';

class MtnMinecraftContentProviderCurseForge extends MtnMinecraftContentProvider {
  MtnMinecraftContentProviderCurseForge({
    String? apiKey,
    http.Client? client,
    Uri? baseUri,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUri = baseUri ?? Uri.parse('https://api.curseforge.com/'),
       super(name: providerName) {
    this.apiKey = apiKey;
    if (!this.baseUri.hasScheme || this.baseUri.host.isEmpty) throw ArgumentError.value(this.baseUri, 'baseUri', 'CurseForge baseUri must be absolute.');
  }

  static const String providerName = 'curseforge';
  static const int minecraftGameId = 432;

  String? _apiKey;
  final Uri baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Map<MtnMinecraftContentType, int>? _classIdsByContentType;
  Map<int, MtnMinecraftContentType>? _contentTypesByClassId;

  set apiKey(String? value) {
    final normalized = value?.trim();
    _apiKey = normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  bool get ready => _apiKey != null;

  @override
  Future<Uri?> resolveDownloadSource(MtnMinecraftContentVersion version, MtnMinecraftContentFile file) async {
    requireReady();
    if (!version.files.any((item) => identical(item, file))) throw ArgumentError.value(file, 'file', 'Download-source file must belong to the supplied version.');

    final modId = MtnMinecraftContentProviderCurseForgeMapper.providerId(name, version.content);
    final fileId = MtnMinecraftContentProviderCurseForgeMapper.fileProviderId(name, file);
    final envelope = await _getEnvelope(baseUri.resolve('v1/mods/$modId/files/$fileId/download-url'));
    final value = MtnMinecraftContentProviderCurseForgeMapper.dataString(envelope);
    if (value == null || value.isEmpty) return null;
    return Uri.parse(value);
  }

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async {
    requireReady();
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
    requireReady();

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
  Future<MtnMinecraftContentVersion> getVersion(String id) async {
    requireReady();

    final fileId = int.tryParse(id.trim());
    if (fileId == null || fileId <= 0) throw ArgumentError.value(id, 'id', 'CurseForge version/file id must be a positive integer.');

    final envelope = await _postEnvelope(
      baseUri.resolve('v1/mods/files'),
      <String, dynamic>{'fileIds': <int>[fileId]},
    );
    final files = MtnMinecraftContentProviderCurseForgeMapper.dataList(envelope);
    if (files.length != 1) throw FormatException('CurseForge exact version lookup expected one file for id $fileId but received ${files.length}.');

    final file = files.single;
    final returnedFileId = MtnMinecraftContentModel.intFromMap(file['id'], fallback: -1);
    if (returnedFileId != fileId) throw FormatException('CurseForge exact version lookup returned file $returnedFileId instead of $fileId.');

    final modId = MtnMinecraftContentModel.intFromMap(file['modId'], fallback: -1);
    if (modId <= 0) throw FormatException('CurseForge file $fileId does not contain a valid owning mod id.');

    final content = await getContent(modId.toString());
    return MtnMinecraftContentProviderCurseForgeMapper.version(name, content, file);
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async {
    requireReady();

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
      if (totalCount > 10000) throw StateError('CurseForge returned more than 10000 matching files; complete generic version filtering cannot be guaranteed.');

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

  Future<Map<String, dynamic>> _getEnvelope(Uri uri) {
    return _requestEnvelope(
      uri,
      (apiKey) => _client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'x-api-key': apiKey,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _postEnvelope(Uri uri, Map<String, dynamic> body) {
    return _requestEnvelope(
      uri,
      (apiKey) => _client.post(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _requestEnvelope(Uri uri, Future<http.Response> Function(String apiKey) request) async {
    final response = await runRequest(() async {
      var retriedAfterRateLimit = false;

      while (true) {
        final apiKey = _apiKey;
        if (apiKey == null) throw MtnMinecraftContentProviderNotReadyException(providerName: name);

        final response = await request(apiKey);

        if (response.statusCode != 429 || retriedAfterRateLimit) return response;

        final retryAfter = _retryAfter(response);
        if (retryAfter == null) return response;

        throttleRequests(retryAfter);
        await waitForRequestAvailability();
        requireReady();
        retriedAfterRateLimit = true;
      }
    });

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

  Duration? _retryAfter(http.Response response) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() != 'retry-after') continue;

      final seconds = int.tryParse(entry.value.trim());
      if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
      return null;
    }

    return null;
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
