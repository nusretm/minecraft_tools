import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_remvibe.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentDownloadAdapterRemVibe', () {
    test('maps one materialization plan to one RemVibe job in canonical download order', () async {
      final contentA = _content('a');
      final contentB = _content('b');
      final contentC = _content('c');

      final aOldFile = _file('a-old.jar', size: 10);
      final aNewFile = _file('a-source.jar', size: 20);
      final bFile = _file('b.jar', size: 30);
      final cFile = _file('c-source.jar', size: 40);

      final aOld = _version('a:v1', contentA, aOldFile);
      final aNew = _version('a:v2', contentA, aNewFile);
      final b = _version('b:v1', contentB, bFile);
      final c = _version('c:v1', contentC, cFile);

      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(aOld, aOldFile, 'mods/a.jar'),
          _artifact(b, bFile, 'mods/b.jar'),
        ],
      );

      final plan = await _materialization(
        installation: installation,
        desiredVersions: <MtnMinecraftContentVersion>[aNew, b, c],
        pathForVersion: <String, String>{
          'a:v2': 'mods/renamed-a.jar',
          'c:v1': 'mods/libraries/c.jar',
        },
      );

      final stagingRoot = Directory(p.join('tmp', 'content-stage'));
      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: stagingRoot,
        key: 'content-install-1',
        title: 'Install content',
        maxConcurrentItems: 3,
        maxErrorCount: 4,
      );

      expect(batch.plan, same(plan));
      expect(batch.stagingRoot, same(stagingRoot));
      expect(batch.job.key, 'content-install-1');
      expect(batch.job.title, 'Install content');
      expect(batch.job.maxConcurrentItems, 3);
      expect(batch.job.maxErrorCount, 4);
      expect(batch.job.items, hasLength(2));
      expect(batch.items, hasLength(2));

      expect(
        batch.items.map((item) => item.target.download),
        orderedEquals(plan.download.items),
      );
      expect(
        batch.job.items,
        orderedEquals(batch.items.map((item) => item.item)),
      );

      final replacement = batch.items[0];
      expect(replacement.target.download.selection.desired.version, same(aNew));
      expect(replacement.item.url, Uri.parse('https://cdn.example/a-source.jar'));
      expect(replacement.item.directory.path, p.join(stagingRoot.path, 'mods'));
      expect(replacement.item.filename, 'renamed-a.jar');
      expect(replacement.item.size, 20);
      expect(replacement.item.validator, isNull);

      final install = batch.items[1];
      expect(install.target.download.selection.desired.version, same(c));
      expect(install.item.url, Uri.parse('https://cdn.example/c-source.jar'));
      expect(install.item.directory.path, p.join(stagingRoot.path, 'mods', 'libraries'));
      expect(install.item.filename, 'c.jar');
      expect(install.item.size, 40);
      expect(install.item.validator, isNull);
    });

    test('does not create download items for retained or removed artifacts', () async {
      final keepContent = _content('keep');
      final removeContent = _content('remove');
      final installContent = _content('install');

      final keepFile = _file('keep.jar');
      final removeFile = _file('remove.jar');
      final installFile = _file('install.jar');

      final keep = _version('keep:v1', keepContent, keepFile);
      final remove = _version('remove:v1', removeContent, removeFile);
      final install = _version('install:v1', installContent, installFile);

      final installation = MtnMinecraftContentInstallationState(
        artifacts: <MtnMinecraftContentInstallationArtifact>[
          _artifact(keep, keepFile, 'mods/keep.jar'),
          _artifact(remove, removeFile, 'mods/remove.jar'),
        ],
      );

      final plan = await _materialization(
        installation: installation,
        desiredVersions: <MtnMinecraftContentVersion>[keep, install],
        pathForVersion: <String, String>{
          'install:v1': 'mods/install.jar',
        },
      );

      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: Directory('stage'),
        key: 'content-install-2',
        title: 'Install content',
      );

      expect(plan.retains, hasLength(1));
      expect(plan.removals, hasLength(1));
      expect(batch.items, hasLength(1));
      expect(batch.items.single.target.download.selection.desired.version, same(install));
    });

    test('uses the materialization target basename instead of the provider filename', () async {
      final content = _content('a');
      final file = _file('provider-name.jar');
      final version = _version('a:v1', content, file);
      final plan = await _materialization(
        installation: MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
        desiredVersions: <MtnMinecraftContentVersion>[version],
        pathForVersion: <String, String>{
          'a:v1': 'mods/caller-name.jar',
        },
      );

      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: Directory('stage'),
        key: 'content-install-3',
        title: 'Install content',
      );

      expect(batch.items.single.item.filename, 'caller-name.jar');
      expect(batch.items.single.target.artifact.file.fileName, 'provider-name.jar');
    });

    test('preserves unknown expected size as null', () async {
      final file = _file('a.jar', size: null);
      final version = _version('a:v1', _content('a'), file);
      final plan = await _materialization(
        installation: MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
        desiredVersions: <MtnMinecraftContentVersion>[version],
        pathForVersion: <String, String>{'a:v1': 'mods/a.jar'},
      );

      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: Directory('stage'),
        key: 'content-install-4',
        title: 'Install content',
      );

      expect(batch.items.single.item.size, isNull);
    });

    test('forwards the RemVibe job status callback contract', () async {
      final file = _file('a.jar');
      final version = _version('a:v1', _content('a'), file);
      final plan = await _materialization(
        installation: MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
        desiredVersions: <MtnMinecraftContentVersion>[version],
        pathForVersion: <String, String>{'a:v1': 'mods/a.jar'},
      );

      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: Directory('stage'),
        key: 'content-install-5',
        title: 'Install content',
        onStatus: _noopStatus,
      );

      expect(batch.job.onStatus, same(_noopStatus));
    });

    test('rejects a no-download materialization plan instead of creating an empty job', () async {
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

      expect(
        () => const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
          plan: plan,
          stagingRoot: Directory('stage'),
          key: 'content-install-empty',
          title: 'Install content',
        ),
        throwsArgumentError,
      );
    });

    test('keeps batch associations immutable', () async {
      final file = _file('a.jar');
      final version = _version('a:v1', _content('a'), file);
      final plan = await _materialization(
        installation: MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
        desiredVersions: <MtnMinecraftContentVersion>[version],
        pathForVersion: <String, String>{'a:v1': 'mods/a.jar'},
      );

      final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
        plan: plan,
        stagingRoot: Directory('stage'),
        key: 'content-install-6',
        title: 'Install content',
      );

      expect(() => batch.items.clear(), throwsUnsupportedError);
      expect(() => batch.job.items.clear(), throwsUnsupportedError);
    });
  });
}

void _noopStatus(RemVibeDownloadJob job) {}

Future<MtnMinecraftContentMaterializationPlan> _materialization({
  required MtnMinecraftContentInstallationState installation,
  required List<MtnMinecraftContentVersion> desiredVersions,
  required Map<String, String> pathForVersion,
}) async {
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
  final targets = download.items
      .map(
        (item) => MtnMinecraftContentMaterializationTarget(
          download: item,
          relativePath: pathForVersion[item.selection.desired.version.key]!,
        ),
      )
      .toList(growable: false);

  return service.planContentMaterialization(download, installation, targets);
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentFile _file(
  String fileName, {
  int? size = 64,
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
    downloadUrl: 'https://cdn.example/$fileName',
    size: size,
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
