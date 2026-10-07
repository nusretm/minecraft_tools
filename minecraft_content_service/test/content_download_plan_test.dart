import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService download planning', () {
    test('reuses direct URLs in file-selection order without provider lookup', () async {
      final first = _version(
        'a:v1',
        _content('a'),
        file: _file(
          'a.jar',
          downloadUrl: 'https://cdn.example/a.jar',
          providers: <MtnMinecraftContentProviderMetadata>[
            MtnMinecraftContentProviderMetadata(provider: 'unknown-a'),
            MtnMinecraftContentProviderMetadata(provider: 'unknown-b'),
          ],
        ),
      );
      final second = _version(
        'b:v1',
        _content('b'),
        file: _file('b.jar', downloadUrl: 'https://cdn.example/b.jar'),
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[first, second]);

      final plan = await MtnMinecraftContentService().planSelectedFileDownloads(selection);

      expect(plan.selection, same(selection));
      expect(plan.items.map((item) => item.selection), selection.selections);
      expect(plan.items.map((item) => item.url.toString()), <String>['https://cdn.example/a.jar', 'https://cdn.example/b.jar']);
      expect(plan.issues, isEmpty);
      expect(plan.downloadable, isTrue);
    });

    test('resolves missing direct URL through the file provider', () async {
      final provider = _DownloadContentProvider(
        name: 'source',
        source: Uri.parse('https://cdn.example/resolved.jar'),
      );
      final version = _version(
        'a:v1',
        _content('a'),
        file: _file(
          'a.jar',
          downloadUrl: null,
          providers: <MtnMinecraftContentProviderMetadata>[
            MtnMinecraftContentProviderMetadata(provider: provider.name, id: 'file-a'),
          ],
        ),
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      final plan = await MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]).planSelectedFileDownloads(selection);

      expect(provider.resolveCount, 1);
      expect(provider.lastVersion, same(version));
      expect(provider.lastFile, same(version.files.single));
      expect(plan.items.single.url.toString(), 'https://cdn.example/resolved.jar');
      expect(plan.downloadable, isTrue);
    });

    test('aggregates source blockers and keeps successful items without making a partial batch downloadable', () async {
      final goodProvider = _DownloadContentProvider(name: 'good', source: Uri.parse('https://cdn.example/good.jar'));
      final notReadyProvider = _DownloadContentProvider(name: 'not-ready', ready: false, source: Uri.parse('https://cdn.example/not-ready.jar'));
      final unavailableProvider = _DownloadContentProvider(name: 'unavailable');
      final failedProvider = _DownloadContentProvider(name: 'failed', error: StateError('lookup failed'));

      final versions = <MtnMinecraftContentVersion>[
        _version('good:v1', _content('good'), file: _file('good.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'good')])),
        _version('missing:v1', _content('missing'), file: _file('missing.jar', downloadUrl: null)),
        _version('ambiguous:v1', _content('ambiguous'), file: _file('ambiguous.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'a'), MtnMinecraftContentProviderMetadata(provider: 'b')])),
        _version('unregistered:v1', _content('unregistered'), file: _file('unregistered.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'ghost')])),
        _version('not-ready:v1', _content('not-ready'), file: _file('not-ready.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'not-ready')])),
        _version('unavailable:v1', _content('unavailable'), file: _file('unavailable.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'unavailable')])),
        _version('failed:v1', _content('failed'), file: _file('failed.jar', downloadUrl: null, providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'failed')])),
      ];
      final selection = _selectionPlan(versions);
      final service = MtnMinecraftContentService(
        providers: <MtnMinecraftContentProvider>[
          goodProvider,
          notReadyProvider,
          unavailableProvider,
          failedProvider,
        ],
      );

      final plan = await service.planSelectedFileDownloads(selection);

      expect(plan.items, hasLength(1));
      expect(plan.items.single.selection.desired.version.key, 'good:v1');
      expect(
        plan.issues.map((issue) => issue.runtimeType),
        <Type>[
          MtnMinecraftContentDownloadIssueProviderMissing,
          MtnMinecraftContentDownloadIssueProviderAmbiguous,
          MtnMinecraftContentDownloadIssueProviderNotRegistered,
          MtnMinecraftContentDownloadIssueProviderNotReady,
          MtnMinecraftContentDownloadIssueSourceUnavailable,
          MtnMinecraftContentDownloadIssueSourceResolutionFailed,
        ],
      );
      expect(notReadyProvider.resolveCount, 0);
      expect(unavailableProvider.resolveCount, 1);
      expect(failedProvider.resolveCount, 1);
      expect(plan.downloadable, isFalse);
      expect(() => plan.items.clear(), throwsUnsupportedError);
      expect(() => plan.issues.clear(), throwsUnsupportedError);
    });

    test('reports invalid direct URL without falling back to provider lookup', () async {
      final provider = _DownloadContentProvider(name: 'source', source: Uri.parse('https://cdn.example/resolved.jar'));
      final version = _version(
        'a:v1',
        _content('a'),
        file: _file(
          'a.jar',
          downloadUrl: 'not-a-download-url',
          providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'source')],
        ),
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      final plan = await MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]).planSelectedFileDownloads(selection);

      expect(provider.resolveCount, 0);
      expect(plan.items, isEmpty);
      expect(plan.issues.single, isA<MtnMinecraftContentDownloadIssueInvalidUrl>());
      expect(plan.downloadable, isFalse);
    });

    test('reports invalid provider-resolved URL as a source issue', () async {
      final provider = _DownloadContentProvider(name: 'source', source: Uri.parse('/relative.jar'));
      final version = _version(
        'a:v1',
        _content('a'),
        file: _file(
          'a.jar',
          downloadUrl: null,
          providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'source')],
        ),
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      final plan = await MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]).planSelectedFileDownloads(selection);

      final issue = plan.issues.single as MtnMinecraftContentDownloadIssueInvalidUrl;
      expect(issue.providerName, 'source');
      expect(issue.value, '/relative.jar');
      expect(plan.downloadable, isFalse);
    });

    test('empty selection produces an empty downloadable batch', () async {
      final service = MtnMinecraftContentService();
      final desired = service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[]);
      final reconciliation = service.reconcileDependencyState(
        MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]),
        desired,
      );
      final selection = service.selectReconciliationFiles(reconciliation);

      final plan = await service.planSelectedFileDownloads(selection);

      expect(selection.selectable, isTrue);
      expect(plan.items, isEmpty);
      expect(plan.issues, isEmpty);
      expect(plan.downloadable, isTrue);
    });

    test('download plan requires every canonical selection to be represented exactly once', () {
      final version = _version('a:v1', _content('a'), file: _file('a.jar'));
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      expect(
        () => MtnMinecraftContentDownloadPlan(
          selection: selection,
          items: const <MtnMinecraftContentDownloadItem>[],
          issues: const <MtnMinecraftContentDownloadIssue>[],
        ),
        throwsArgumentError,
      );
    });

    test('rejects download planning before file-selection blockers are resolved', () async {
      final content = _content('a');
      final version = MtnMinecraftContentVersion(
        key: 'a:v1',
        content: content,
        name: 'a:v1',
        version: 'a:v1',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      expect(selection.selectable, isFalse);
      await expectLater(
        MtnMinecraftContentService().planSelectedFileDownloads(selection),
        throwsStateError,
      );
    });

    test('CurseForge resolves source with provider-owned project and file identities', () async {
      late http.Request observedRequest;
      final client = MockClient((request) async {
        observedRequest = request;
        return http.Response(
          jsonEncode(<String, dynamic>{'data': 'https://edge.example/curseforge.jar'}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final provider = MtnMinecraftContentProviderCurseForge(
        apiKey: 'secret',
        client: client,
        baseUri: Uri.parse('https://curseforge.example/'),
      );
      final content = _content(
        'curseforge:123',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '123'),
        ],
      );
      final version = _version(
        'curseforge:456',
        content,
        file: _file(
          'curseforge.jar',
          downloadUrl: null,
          providers: <MtnMinecraftContentProviderMetadata>[
            MtnMinecraftContentProviderMetadata(provider: MtnMinecraftContentProviderCurseForge.providerName, id: '456'),
          ],
        ),
      );
      final selection = _selectionPlan(<MtnMinecraftContentVersion>[version]);

      final plan = await MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]).planSelectedFileDownloads(selection);

      expect(plan.downloadable, isTrue);
      expect(plan.items.single.url.toString(), 'https://edge.example/curseforge.jar');
      expect(observedRequest.method, 'GET');
      expect(observedRequest.url.toString(), 'https://curseforge.example/v1/mods/123/files/456/download-url');
      expect(observedRequest.headers['x-api-key'], 'secret');
    });
  });
}

MtnMinecraftContentMod _content(
  String key, {
  List<MtnMinecraftContentProviderMetadata>? providers,
}) {
  return MtnMinecraftContentMod(
    key: key,
    name: key,
    providers: providers,
  );
}

MtnMinecraftContentFile _file(
  String fileName, {
  String? downloadUrl = 'https://cdn.example/file.jar',
  List<MtnMinecraftContentProviderMetadata>? providers,
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
    downloadUrl: downloadUrl,
    providers: providers,
  );
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content, {
  required MtnMinecraftContentFile file,
}) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
  );
}

MtnMinecraftContentFileSelectionPlan _selectionPlan(
  List<MtnMinecraftContentVersion> versions,
) {
  if (versions.isEmpty) throw ArgumentError.value(versions, 'versions', 'Test selection requires at least one version.');

  final root = versions.first;
  final installPlan = MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: versions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
  );
  final service = MtnMinecraftContentService();
  final desired = service.composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[installPlan]);
  final reconciliation = service.reconcileDependencyState(
    MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]),
    desired,
  );
  return service.selectReconciliationFiles(reconciliation);
}

class _DownloadContentProvider extends MtnMinecraftContentProvider {
  _DownloadContentProvider({
    required super.name,
    this.ready = true,
    this.source,
    this.error,
  });

  @override
  bool ready;

  final Uri? source;
  final Object? error;
  int resolveCount = 0;
  MtnMinecraftContentVersion? lastVersion;
  MtnMinecraftContentFile? lastFile;

  @override
  Future<Uri?> resolveDownloadSource(MtnMinecraftContentVersion version, MtnMinecraftContentFile file) async {
    resolveCount++;
    lastVersion = version;
    lastFile = file;
    final error = this.error;
    if (error != null) throw error;
    return source;
  }

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) {
    throw UnsupportedError('Not used by download-plan tests.');
  }

  @override
  Future<MtnMinecraftContent> getContent(String id) {
    throw UnsupportedError('Not used by download-plan tests.');
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String id) {
    throw UnsupportedError('Not used by download-plan tests.');
  }

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) {
    throw UnsupportedError('Not used by download-plan tests.');
  }
}
