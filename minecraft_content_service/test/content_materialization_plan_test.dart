import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService materialization planning', () {
    test('maps install retain replace and remove actions and derives resulting state in desired order', () async {
      final contentA = _content('a');
      final contentB = _content('b');
      final contentC = _content('c');
      final contentX = _content('x');

      final aOldFile = _file('a-old.jar');
      final aNewFile = _file('a-new.jar');
      final bFile = _file('b.jar');
      final cFile = _file('c.jar');
      final xFile = _file('x.jar');

      final aOld = _version('a:v1', contentA, aOldFile);
      final aNew = _version('a:v2', contentA, aNewFile);
      final b = _version('b:v1', contentB, bFile);
      final c = _version('c:v1', contentC, cFile);
      final x = _version('x:v1', contentX, xFile);

      final currentA = _artifact(aOld, aOldFile, 'mods/a.jar');
      final currentB = _artifact(b, bFile, 'mods/b.jar');
      final currentX = _artifact(x, xFile, 'mods/x.jar');
      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[currentX, currentA, currentB],
      );

      final service = MtnMinecraftContentService();
      final desired = service.composeDependencyInstallPlans(
        <MtnMinecraftContentDependencyInstallPlan>[
          _installPlan(aNew, <MtnMinecraftContentVersion>[aNew, b, c]),
        ],
      );
      final reconciliation = service.reconcileDependencyState(installation.dependencyInstalledState, desired);
      final selection = service.selectReconciliationFiles(reconciliation);
      final download = await service.planSelectedFileDownloads(selection);

      final targetByVersionKey = <String, MtnMinecraftContentMaterializationTarget>{
        for (final item in download.items)
          item.selection.desired.version.key: MtnMinecraftContentMaterializationTarget(
            download: item,
            relativePath: item.selection.desired.version.key == 'a:v2' ? 'mods/a.jar' : 'mods/x.jar',
          ),
      };

      final plan = service.planContentMaterialization(
        download,
        installation,
        download.items.map((item) => targetByVersionKey[item.selection.desired.version.key]!),
      );

      expect(plan.download, same(download));
      expect(plan.installation, same(installation));
      expect(plan.reconciliation, same(reconciliation));

      expect(plan.installs, hasLength(1));
      expect(plan.installs.single.target.download.selection.desired.version, same(c));
      expect(plan.installs.single.target.relativePath, 'mods/x.jar');

      expect(plan.retains, hasLength(1));
      expect(plan.retains.single.desired.version, same(b));
      expect(plan.retains.single.artifact, same(currentB));

      expect(plan.replacements, hasLength(1));
      expect(plan.replacements.single.replacement.current, same(aOld));
      expect(plan.replacements.single.replacement.desired.version, same(aNew));
      expect(plan.replacements.single.current, same(currentA));
      expect(plan.replacements.single.target.relativePath, 'mods/a.jar');

      expect(plan.removals, hasLength(1));
      expect(plan.removals.single.artifact, same(currentX));

      expect(
        plan.resultingInstallationState.artifacts.map((artifact) => artifact.version.key),
        <String>['a:v2', 'b:v1', 'c:v1'],
      );
      expect(
        plan.resultingInstallationState.artifacts.map((artifact) => artifact.relativePath),
        <String>['mods/a.jar', 'mods/b.jar', 'mods/x.jar'],
      );
      expect(plan.resultingInstallationState.artifacts[1], same(currentB));
    });

    test('allows a replacement to reuse the current artifact path', () async {
      final content = _content('a');
      final oldFile = _file('old.jar');
      final newFile = _file('new.jar');
      final oldVersion = _version('a:v1', content, oldFile);
      final newVersion = _version('a:v2', content, newFile);
      final current = _artifact(oldVersion, oldFile, 'mods/a.jar');
      final installation = MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[current]);

      final pipeline = await _pipeline(
        installation,
        <MtnMinecraftContentVersion>[newVersion],
      );
      final target = MtnMinecraftContentMaterializationTarget(
        download: pipeline.download.items.single,
        relativePath: 'mods/a.jar',
      );

      final plan = pipeline.service.planContentMaterialization(
        pipeline.download,
        installation,
        <MtnMinecraftContentMaterializationTarget>[target],
      );

      expect(plan.replacements.single.current, same(current));
      expect(plan.replacements.single.target.artifact.relativePath, current.relativePath);
      expect(plan.resultingInstallationState.artifacts.single, same(target.artifact));
    });

    test('rejects a final target path that collides with a retained artifact', () async {
      final contentA = _content('a');
      final contentB = _content('b');
      final aFile = _file('a.jar');
      final bFile = _file('b.jar');
      final a = _version('a:v1', contentA, aFile);
      final b = _version('b:v1', contentB, bFile);
      final currentA = _artifact(a, aFile, 'mods/a.jar');
      final installation = MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[currentA]);

      final pipeline = await _pipeline(
        installation,
        <MtnMinecraftContentVersion>[a, b],
      );
      final target = MtnMinecraftContentMaterializationTarget(
        download: pipeline.download.items.single,
        relativePath: 'mods/a.jar',
      );

      expect(
        () => pipeline.service.planContentMaterialization(
          pipeline.download,
          installation,
          <MtnMinecraftContentMaterializationTarget>[target],
        ),
        throwsArgumentError,
      );
    });

    test('requires exactly one canonical target per download item', () async {
      final version = _version('a:v1', _content('a'), _file('a.jar'));
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final pipeline = await _pipeline(installation, <MtnMinecraftContentVersion>[version]);

      expect(
        () => pipeline.service.planContentMaterialization(
          pipeline.download,
          installation,
          const <MtnMinecraftContentMaterializationTarget>[],
        ),
        throwsArgumentError,
      );

      final canonical = pipeline.download.items.single;
      final foreignSelection = MtnMinecraftContentFileSelection(
        desired: canonical.selection.desired,
        file: canonical.selection.file,
      );
      final foreignDownload = MtnMinecraftContentDownloadItem(
        selection: foreignSelection,
        url: canonical.url,
      );
      final foreignTarget = MtnMinecraftContentMaterializationTarget(
        download: foreignDownload,
        relativePath: 'mods/a.jar',
      );

      expect(
        () => pipeline.service.planContentMaterialization(
          pipeline.download,
          installation,
          <MtnMinecraftContentMaterializationTarget>[foreignTarget],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-downloadable upstream plan', () async {
      final version = _version(
        'a:v1',
        _content('a'),
        _file('a.jar', downloadUrl: 'not-a-url'),
      );
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final pipeline = await _pipeline(installation, <MtnMinecraftContentVersion>[version]);

      expect(pipeline.download.downloadable, isFalse);
      expect(
        () => pipeline.service.planContentMaterialization(
          pipeline.download,
          installation,
          const <MtnMinecraftContentMaterializationTarget>[],
        ),
        throwsStateError,
      );
    });

    test('requires the exact installation state used for reconciliation', () async {
      final oldFile = _file('a.jar');
      final oldVersion = _version('a:v1', _content('a'), oldFile);
      final currentArtifact = _artifact(oldVersion, oldFile, 'mods/a.jar');
      final installation = MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[currentArtifact]);
      final pipeline = await _pipeline(installation, <MtnMinecraftContentVersion>[oldVersion]);
      final equivalentInstallation = MtnMinecraftContentInstallationState(artifacts: <MtnMinecraftContentInstallationArtifact>[currentArtifact]);

      expect(
        () => pipeline.service.planContentMaterialization(
          pipeline.download,
          equivalentInstallation,
          const <MtnMinecraftContentMaterializationTarget>[],
        ),
        throwsStateError,
      );
    });

    test('preserves OS-neutral case-sensitive resulting path identity', () async {
      final a = _version('a:v1', _content('a'), _file('A.jar'));
      final b = _version('b:v1', _content('b'), _file('a.jar'));
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final pipeline = await _pipeline(installation, <MtnMinecraftContentVersion>[a, b]);

      final targets = <MtnMinecraftContentMaterializationTarget>[
        MtnMinecraftContentMaterializationTarget(download: pipeline.download.items[0], relativePath: 'mods/A.jar'),
        MtnMinecraftContentMaterializationTarget(download: pipeline.download.items[1], relativePath: 'mods/a.jar'),
      ];
      final plan = pipeline.service.planContentMaterialization(pipeline.download, installation, targets);

      expect(plan.resultingInstallationState.artifacts, hasLength(2));
    });

    test('supports an empty no-change materialization plan', () async {
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final service = MtnMinecraftContentService();
      final desired = service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[]);
      final reconciliation = service.reconcileDependencyState(installation.dependencyInstalledState, desired);
      final selection = service.selectReconciliationFiles(reconciliation);
      final download = await service.planSelectedFileDownloads(selection);

      final plan = service.planContentMaterialization(
        download,
        installation,
        const <MtnMinecraftContentMaterializationTarget>[],
      );

      expect(plan.installs, isEmpty);
      expect(plan.retains, isEmpty);
      expect(plan.replacements, isEmpty);
      expect(plan.removals, isEmpty);
      expect(plan.resultingInstallationState.artifacts, isEmpty);
    });

    test('keeps action collections immutable', () async {
      final version = _version('a:v1', _content('a'), _file('a.jar'));
      final installation = MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);
      final pipeline = await _pipeline(installation, <MtnMinecraftContentVersion>[version]);
      final target = MtnMinecraftContentMaterializationTarget(
        download: pipeline.download.items.single,
        relativePath: 'mods/a.jar',
      );
      final plan = pipeline.service.planContentMaterialization(
        pipeline.download,
        installation,
        <MtnMinecraftContentMaterializationTarget>[target],
      );

      expect(() => plan.installs.clear(), throwsUnsupportedError);
      expect(() => plan.retains.clear(), throwsUnsupportedError);
      expect(() => plan.replacements.clear(), throwsUnsupportedError);
      expect(() => plan.removals.clear(), throwsUnsupportedError);
    });
  });
}

class _Pipeline {
  _Pipeline({
    required this.service,
    required this.download,
  });

  final MtnMinecraftContentService service;
  final MtnMinecraftContentDownloadPlan download;
}

Future<_Pipeline> _pipeline(
  MtnMinecraftContentInstallationState installation,
  List<MtnMinecraftContentVersion> desiredVersions,
) async {
  final service = MtnMinecraftContentService();
  final desired = desiredVersions.isEmpty
      ? service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[])
      : service.composeDependencyInstallPlans(
          <MtnMinecraftContentDependencyInstallPlan>[
            _installPlan(desiredVersions.first, desiredVersions),
          ],
        );
  final reconciliation = service.reconcileDependencyState(installation.dependencyInstalledState, desired);
  final selection = service.selectReconciliationFiles(reconciliation);
  final download = await service.planSelectedFileDownloads(selection);
  return _Pipeline(service: service, download: download);
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentFile _file(
  String fileName, {
  String downloadUrl = 'https://cdn.example/file.jar',
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
    downloadUrl: downloadUrl,
  );
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content,
  MtnMinecraftContentFile file,
) {
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

MtnMinecraftContentInstallationArtifact _artifact(
  MtnMinecraftContentVersion version,
  MtnMinecraftContentFile file,
  String relativePath,
) {
  return MtnMinecraftContentInstallationArtifact(
    version: version,
    file: file,
    relativePath: relativePath,
  );
}

MtnMinecraftContentDependencyInstallPlan _installPlan(
  MtnMinecraftContentVersion root,
  List<MtnMinecraftContentVersion> installVersions,
) {
  return MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: installVersions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
  );
}
