import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentMaterializationFileSystem preflight', () {
    test('requires an absolute existing installation root', () async {
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: const <MtnMinecraftContentVersion>[],
        targets: const <String, String>{},
      );
      final fileSystem = MtnMinecraftContentMaterializationFileSystem();

      await expectLater(
        fileSystem.preflight(
          plan: plan,
          installationRoot: Directory('relative-root'),
        ),
        throwsArgumentError,
      );

      final missing = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}minecraft-content-missing-root-${DateTime.now().microsecondsSinceEpoch}');
      await expectLater(
        fileSystem.preflight(
          plan: plan,
          installationRoot: missing.absolute,
        ),
        throwsArgumentError,
      );
    });

    test('detects Windows case-insensitive final-state collisions without mutating the root', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final a = _version('a:v1', _content('a'), _file('A.jar'));
      final b = _version('b:v1', _content('b'), _file('a.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a, b],
        targets: <String, String>{
          'a:v1': 'mods/A.jar',
          'b:v1': 'mods/a.jar',
        },
      );

      final before = await root.list().toList();
      final preflight = await _windows().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );
      final after = await root.list().toList();

      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision>(),
        hasLength(1),
      );
      expect(before, isEmpty);
      expect(after, isEmpty);
    });

    test('detects case-insensitive collisions already present in the current managed state', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final aFile = _file('A.jar');
      final bFile = _file('a.jar');
      final a = _version('a:v1', _content('a'), aFile);
      final b = _version('b:v1', _content('b'), bFile);
      final installation = _installation(
        <MtnMinecraftContentInstallationArtifact>[
          _artifact(a, aFile, 'mods/A.jar'),
          _artifact(b, bFile, 'mods/a.jar'),
        ],
      );
      final plan = await _plan(
        installation: installation,
        desiredVersions: const <MtnMinecraftContentVersion>[],
        targets: const <String, String>{},
      );

      final preflight = await _windows().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      final collisions = preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssuePathCollision>().toList();
      expect(collisions, hasLength(1));
      expect(collisions.single.scope, MtnMinecraftContentMaterializationFileSystemStateScope.current);
    });

    test('allows case-distinct final targets under a case-sensitive POSIX policy', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final a = _version('a:v1', _content('a'), _file('A.jar'));
      final b = _version('b:v1', _content('b'), _file('a.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a, b],
        targets: <String, String>{
          'a:v1': 'mods/A.jar',
          'b:v1': 'mods/a.jar',
        },
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isTrue);
      expect(preflight.resultingArtifacts, hasLength(2));
      expect(
        preflight.resultingArtifacts.every(
          (state) => state.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing,
        ),
        isTrue,
      );
    });

    test('detects file hierarchy collisions in the resulting managed state', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final a = _version('a:v1', _content('a'), _file('a.jar'));
      final b = _version('b:v1', _content('b'), _file('b.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a, b],
        targets: <String, String>{
          'a:v1': 'mods/a.jar',
          'b:v1': 'mods/a.jar/config.json',
        },
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssuePathHierarchyCollision>(),
        hasLength(1),
      );
    });

    test('blocks unmanaged final occupancy and does not adopt an existing file', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      final mods = Directory('${root.path}${Platform.pathSeparator}mods');
      await mods.create();
      final unmanaged = File('${mods.path}${Platform.pathSeparator}a.jar');
      await unmanaged.writeAsString('manual');

      final a = _version('a:v1', _content('a'), _file('a.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a],
        targets: <String, String>{'a:v1': 'mods/a.jar'},
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy>(),
        hasLength(1),
      );
      expect(await unmanaged.readAsString(), 'manual');
    });

    test('detects differently-cased unmanaged occupancy under a case-insensitive policy', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      final mods = Directory('${root.path}${Platform.pathSeparator}mods');
      await mods.create();
      final unmanaged = File('${mods.path}${Platform.pathSeparator}Manual.JAR');
      await unmanaged.writeAsString('manual');

      final version = _version('manual:v1', _content('manual'), _file('manual.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[version],
        targets: <String, String>{'manual:v1': 'mods/manual.jar'},
      );

      final preflight = await _windows().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      final issues = preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueUnmanagedOccupancy>().toList();
      expect(issues, hasLength(1));
      expect(issues.single.physicalPath, unmanaged.path);
      expect(await unmanaged.readAsString(), 'manual');
    });

    test('allows a new install to reuse a path owned by a managed removal', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      final mods = Directory('${root.path}${Platform.pathSeparator}mods');
      await mods.create();

      final oldFile = _file('old.jar');
      final oldVersion = _version('old:v1', _content('old'), oldFile);
      final current = _artifact(oldVersion, oldFile, 'mods/shared.jar');
      final installation = _installation(<MtnMinecraftContentInstallationArtifact>[current]);
      final managedFile = File('${mods.path}${Platform.pathSeparator}shared.jar');
      await managedFile.writeAsString('old');

      final next = _version('next:v1', _content('next'), _file('next.jar'));
      final plan = await _plan(
        installation: installation,
        desiredVersions: <MtnMinecraftContentVersion>[next],
        targets: <String, String>{'next:v1': 'mods/shared.jar'},
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isTrue);
      expect(preflight.currentArtifacts.single.entityType, MtnMinecraftContentMaterializationFileSystemEntityType.file);
      expect(preflight.resultingArtifacts.single.entityType, MtnMinecraftContentMaterializationFileSystemEntityType.file);
      expect(await managedFile.readAsString(), 'old');
    });

    test('requires retained managed files to exist but allows missing replace/remove sources', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final keepFile = _file('keep.jar');
      final replaceOldFile = _file('replace-old.jar');
      final removeFile = _file('remove.jar');
      final keep = _version('keep:v1', _content('keep'), keepFile);
      final replaceOld = _version('replace:v1', _content('replace'), replaceOldFile);
      final remove = _version('remove:v1', _content('remove'), removeFile);
      final installation = _installation(
        <MtnMinecraftContentInstallationArtifact>[
          _artifact(keep, keepFile, 'mods/keep.jar'),
          _artifact(replaceOld, replaceOldFile, 'mods/replace.jar'),
          _artifact(remove, removeFile, 'mods/remove.jar'),
        ],
      );

      final replaceNew = _version('replace:v2', replaceOld.content, _file('replace-new.jar'));
      final plan = await _plan(
        installation: installation,
        desiredVersions: <MtnMinecraftContentVersion>[keep, replaceNew],
        targets: <String, String>{'replace:v2': 'mods/replace.jar'},
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      final managedIssues = preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueManagedArtifact>().toList();
      expect(managedIssues, hasLength(1));
      expect(managedIssues.single.artifact, same(installation.artifacts[0]));
      expect(managedIssues.single.reason, MtnMinecraftContentMaterializationFileSystemManagedArtifactReason.retainedArtifactMissing);
    });

    test('blocks a regular file in the target ancestor chain', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      final mods = Directory('${root.path}${Platform.pathSeparator}mods');
      await mods.create();
      final blocker = File('${mods.path}${Platform.pathSeparator}libraries');
      await blocker.writeAsString('not a directory');

      final a = _version('a:v1', _content('a'), _file('a.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a],
        targets: <String, String>{'a:v1': 'mods/libraries/a.jar'},
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath>().any(
          (issue) => issue.reason == MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.ancestorNotDirectory,
        ),
        isTrue,
      );
      expect(await blocker.readAsString(), 'not a directory');
    });

    test('rejects Windows-illegal target segments before publication', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final values = <String>['CON.jar', 'trailing.', 'bad<name.jar'];
      for (var index = 0; index < values.length; index++) {
        final version = _version('v$index', _content('c$index'), _file('f$index.jar'));
        final plan = await _plan(
          installation: _installation(),
          desiredVersions: <MtnMinecraftContentVersion>[version],
          targets: <String, String>{'v$index': 'mods/${values[index]}'},
        );
        final preflight = await _windows().preflight(
          plan: plan,
          installationRoot: root.absolute,
        );

        expect(
          preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueInvalidTargetPath>().any(
            (issue) => issue.reason == MtnMinecraftContentMaterializationFileSystemInvalidTargetPathReason.windowsInvalidSegment,
          ),
          isTrue,
          reason: values[index],
        );
      }
    });

    test('blocks symbolic-link indirection below the installation root', () async {
      if (Platform.isWindows) {
        return;
      }

      final root = await Directory.systemTemp.createTemp();
      final outside = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => outside.delete(recursive: true));

      final link = Link('${root.path}${Platform.pathSeparator}mods');
      await link.create(outside.path);

      final a = _version('a:v1', _content('a'), _file('a.jar'));
      final plan = await _plan(
        installation: _installation(),
        desiredVersions: <MtnMinecraftContentVersion>[a],
        targets: <String, String>{'a:v1': 'mods/a.jar'},
      );

      final preflight = await _posix().preflight(
        plan: plan,
        installationRoot: root.absolute,
      );

      expect(preflight.safe, isFalse);
      expect(
        preflight.issues.whereType<MtnMinecraftContentMaterializationFileSystemPreflightIssueSymbolicLink>(),
        isNotEmpty,
      );
      expect(await outside.list().toList(), isEmpty);
    });
  });
}

MtnMinecraftContentMaterializationFileSystem _windows() {
  return MtnMinecraftContentMaterializationFileSystem(
    policy: const MtnMinecraftContentMaterializationFileSystemPolicy(
      platform: MtnMinecraftContentMaterializationFileSystemPlatform.windows,
      caseSensitive: false,
    ),
  );
}

MtnMinecraftContentMaterializationFileSystem _posix() {
  return MtnMinecraftContentMaterializationFileSystem(
    policy: const MtnMinecraftContentMaterializationFileSystemPolicy(
      platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
      caseSensitive: true,
    ),
  );
}

MtnMinecraftContentInstallationState _installation([
  List<MtnMinecraftContentInstallationArtifact> artifacts = const <MtnMinecraftContentInstallationArtifact>[],
]) {
  return MtnMinecraftContentInstallationState(artifacts: artifacts);
}

Future<MtnMinecraftContentMaterializationPlan> _plan({
  required MtnMinecraftContentInstallationState installation,
  required List<MtnMinecraftContentVersion> desiredVersions,
  required Map<String, String> targets,
}) async {
  final service = MtnMinecraftContentService();
  final desired = desiredVersions.isEmpty
      ? service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[])
      : service.composeDependencyInstallPlans(
          <MtnMinecraftContentDependencyInstallPlan>[
            _installPlan(desiredVersions.first, desiredVersions),
          ],
        );
  final reconciliation = service.reconcileDependencyState(
    installation.dependencyInstalledState,
    desired,
  );
  final selection = service.selectReconciliationFiles(reconciliation);
  final download = await service.planSelectedFileDownloads(selection);
  final materializationTargets = download.items.map(
    (item) => MtnMinecraftContentMaterializationTarget(
      download: item,
      relativePath: targets[item.selection.desired.version.key]!,
    ),
  );

  return service.planContentMaterialization(
    download,
    installation,
    materializationTargets,
  );
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentFile _file(String fileName) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
    downloadUrl: 'https://cdn.example/$fileName',
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
