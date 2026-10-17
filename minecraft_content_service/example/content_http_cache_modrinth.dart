import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:minecraft_content_service/minecraft_content_service.dart';

class _CountingClient extends http.BaseClient {
  _CountingClient(this.inner);

  final http.Client inner;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    ++requests;
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

/// Real Modrinth HTTP-cache smoke; no downloads or installation.
/// dart run example/content_http_cache_modrinth.dart 6qAuTtLR
Future<void> main(List<String> args) async {
  final versionId = args.isEmpty ? '6qAuTtLR' : args.single;
  final client = _CountingClient(http.Client());
  final provider = MtnMinecraftContentProviderModrinth(
    userAgent: 'nusretm/minecraft_tools HTTP cache smoke (https://github.com/nusretm/minecraft_tools)',
    client: client,
  );
  final service = MtnMinecraftContentService(
    providers: <MtnMinecraftContentProvider>[provider],
    cacheDuration: const Duration(hours: 1),
  );
  try {
    final first = await service.getVersion(provider.name, versionId);
    final afterFirst = client.requests;
    final second = await service.getVersion(provider.name, versionId);
    if (client.requests != afterFirst || first.key != second.key) {
      throw StateError('Repeated exact-version lookup incorrectly used HTTP again.');
    }

    final content = first.content;
    final filter = <String>[first.gameVersions.isEmpty ? '1.21.11' : first.gameVersions.first];
    final listOne = await service.getVersions(provider.name, content, MtnMinecraftContentVersionListRequest(
      gameVersions: filter, offset: 0, limit: 10,
    ));
    final afterList = client.requests;
    final listTwo = await service.getVersions(provider.name, content, MtnMinecraftContentVersionListRequest(
      gameVersions: filter, offset: 10, limit: 10,
    ));
    if (client.requests != afterList) {
      throw StateError('Changing only local pagination offset fetched Modrinth list again.');
    }
    stdout.writeln('CP-11 PASS version=${first.version} firstExactHttp=$afterFirst repeatedExactHttp=0');
    stdout.writeln('versionListFirstPage=${listOne.versions.length} versionListSecondPage=${listTwo.versions.length}');
    stdout.writeln('versionListRepeatedHttp=0 cachedResponses=${service.providers.httpService.cachedResponseCount} totalHttp=${client.requests}');
  } finally {
    provider.close();
    client.close();
  }
}
