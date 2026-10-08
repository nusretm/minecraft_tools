import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentMaterializationFileSystem publication', () {
    test('publishes a missing target through sibling staging and commits without consuming source', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('published content');
      final fixture = await _installFixture(
        relativePath: 'mods/nested/a.jar',
        bytes: bytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      expect(preflight.safe, isTrue);

      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );

      expect(publication.state, MtnMinecraftContentMaterializationFileSystemPublicationState.pending);
      expect(publication.previousTargetExisted, isFalse);
      expect(publication.backup, isNull);
      expect(publication.target.parent.path, p.join(root.path, 'mods', 'nested'));
      expect(await publication.target.readAsBytes(), bytes);
      expect(await source.readAsBytes(), bytes);
      expect(
        await _temporarySiblings(publication.target),
        isEmpty,
      );

      await fileSystem.commit(publication);
      expect(publication.state, MtnMinecraftContentMaterializationFileSystemPublicationState.committed);
      await fileSystem.commit(publication);
      expect(await publication.target.readAsBytes(), bytes);
      expect(await source.readAsBytes(), bytes);
    });

    test('rollback of a newly published target removes the target and publication-created empty parents', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('rollback new target');
      final fixture = await _installFixture(
        relativePath: 'mods/generated/a.jar',
        bytes: bytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );
      expect(await publication.target.exists(), isTrue);
      expect(publication.createdDirectories.map((item) => p.basename(item.path)), orderedEquals(<String>['mods', 'generated']));

      await fileSystem.rollback(publication);
      expect(publication.state, MtnMinecraftContentMaterializationFileSystemPublicationState.rolledBack);
      await fileSystem.rollback(publication);
      expect(await publication.target.exists(), isFalse);
      expect(await Directory(p.join(root.path, 'mods')).exists(), isFalse);
      expect(await source.readAsBytes(), bytes);
      await expectLater(fileSystem.commit(publication), throwsStateError);
    });

    test('replacement publication keeps the previous managed file as backup until rollback restores it', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final oldBytes = utf8.encode('old managed bytes');
      final newBytes = utf8.encode('new managed bytes');
      final fixture = await _replacementFixture(
        root: root,
        relativePath: 'mods/a.jar',
        oldBytes: oldBytes,
        newBytes: newBytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      expect(preflight.safe, isTrue);

      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(newBytes);
      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );

      expect(publication.previousTargetExisted, isTrue);
      expect(publication.backup, isNotNull);
      expect(await publication.target.readAsBytes(), newBytes);
      expect(await publication.backup!.readAsBytes(), oldBytes);

      await fileSystem.rollback(publication);
      expect(await publication.target.readAsBytes(), oldBytes);
      expect(await publication.backup!.exists(), isFalse);
      expect(await source.readAsBytes(), newBytes);
    });

    test('replacement commit discards the owned backup and keeps the published file', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final oldBytes = utf8.encode('old');
      final newBytes = utf8.encode('replacement');
      final fixture = await _replacementFixture(
        root: root,
        relativePath: 'mods/a.jar',
        oldBytes: oldBytes,
        newBytes: newBytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(newBytes);

      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );
      final backup = publication.backup!;

      await fileSystem.commit(publication);
      expect(await publication.target.readAsBytes(), newBytes);
      expect(await backup.exists(), isFalse);
      expect(await source.readAsBytes(), newBytes);
      await expectLater(fileSystem.rollback(publication), throwsStateError);
    });

    test('integrity failure preserves target state, source and cleans owned staging and parents', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final expected = utf8.encode('expected bytes');
      final wrong = utf8.encode('wrong bytes---');
      expect(wrong.length, expected.length);

      final fixture = await _installFixture(
        relativePath: 'mods/nested/a.jar',
        bytes: expected,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(wrong);

      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: fixture.target,
          source: source,
        ),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.integrityFailure,
          ),
        ),
      );

      expect(await File(p.join(root.path, 'mods', 'nested', 'a.jar')).exists(), isFalse);
      expect(await Directory(p.join(root.path, 'mods')).exists(), isFalse);
      expect(await source.readAsBytes(), wrong);
    });

    test('rejects a stale preflight when a previously missing target becomes occupied', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('desired');
      final fixture = await _installFixture(
        relativePath: 'mods/a.jar',
        bytes: bytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );

      final mods = Directory(p.join(root.path, 'mods'));
      await mods.create();
      final manual = File(p.join(mods.path, 'a.jar'));
      await manual.writeAsString('manual');

      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: fixture.target,
          source: source,
        ),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          ),
        ),
      );
      expect(await manual.readAsString(), 'manual');
      expect(await source.readAsBytes(), bytes);
    });

    test('rejects a stale preflight when a parent becomes a non-directory', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('desired');
      final fixture = await _installFixture(
        relativePath: 'mods/nested/a.jar',
        bytes: bytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final blocker = File(p.join(root.path, 'mods'));
      await blocker.writeAsString('not a directory');
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: fixture.target,
          source: source,
        ),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          ),
        ),
      );
      expect(await blocker.readAsString(), 'not a directory');
    });

    test('rejects missing and symbolic-link publication sources without mutating the target', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('desired');
      final fixture = await _installFixture(
        relativePath: 'mods/a.jar',
        bytes: bytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );

      final missing = File(p.join(sourceRoot.path, 'missing.jar'));
      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: fixture.target,
          source: missing,
        ),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceNotRegularFile,
          ),
        ),
      );

      if (!Platform.isWindows) {
        final real = File(p.join(sourceRoot.path, 'real.jar'));
        await real.writeAsBytes(bytes);
        final link = Link(p.join(sourceRoot.path, 'link.jar'));
        await link.create(real.path);
        await expectLater(
          fileSystem.publish(
            preflight: preflight,
            target: fixture.target,
            source: File(link.path),
          ),
          throwsA(
            isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
              (error) => error.failure,
              'failure',
              MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceNotRegularFile,
            ),
          ),
        );
      }

      expect(await File(p.join(root.path, 'mods', 'a.jar')).exists(), isFalse);
    });

    test('rejects a publication source that aliases the managed target', () async {
      final root = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));

      final oldBytes = utf8.encode('old');
      final newBytes = utf8.encode('new');
      final fixture = await _replacementFixture(
        root: root,
        relativePath: 'mods/a.jar',
        oldBytes: oldBytes,
        newBytes: newBytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final target = File(p.join(root.path, 'mods', 'a.jar'));

      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: fixture.target,
          source: target,
        ),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.sourceAliasesTarget,
          ),
        ),
      );
      expect(await target.readAsBytes(), oldBytes);
    });

    test('requires the exact canonical target represented by the preflight plan', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('desired');
      final first = await _installFixture(relativePath: 'mods/a.jar', bytes: bytes);
      final second = await _installFixture(relativePath: 'mods/a.jar', bytes: bytes);
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: first.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      await expectLater(
        fileSystem.publish(
          preflight: preflight,
          target: second.target,
          source: source,
        ),
        throwsArgumentError,
      );
    });

    test('same-target publications serialize until the first handle is finalized', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('serialized publication');
      final fixture = await _installFixture(
        relativePath: 'mods/a.jar',
        bytes: bytes,
      );
      final firstAuthority = _posix();
      final secondAuthority = _posix();
      final preflight = await firstAuthority.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final firstSource = File(p.join(sourceRoot.path, 'first.jar'));
      final secondSource = File(p.join(sourceRoot.path, 'second.jar'));
      await firstSource.writeAsBytes(bytes);
      await secondSource.writeAsBytes(bytes);

      final first = await firstAuthority.publish(
        preflight: preflight,
        target: fixture.target,
        source: firstSource,
      );

      bool secondSettled = false;
      final secondFuture = secondAuthority.publish(
        preflight: preflight,
        target: fixture.target,
        source: secondSource,
      );
      secondFuture.then<void>(
        (_) => secondSettled = true,
        onError: (_) => secondSettled = true,
      );

      await Future<void>.delayed(Duration.zero);
      expect(secondSettled, isFalse);

      await firstAuthority.commit(first);

      await expectLater(
        secondFuture,
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.stalePreflight,
          ),
        ),
      );
      expect(secondSettled, isTrue);
      expect(await File(p.join(root.path, 'mods', 'a.jar')).readAsBytes(), bytes);
    });

    test('finalization refuses to destroy recovery state after the published target changes externally', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final oldBytes = utf8.encode('old managed');
      final newBytes = utf8.encode('new managed');
      final fixture = await _replacementFixture(
        root: root,
        relativePath: 'mods/a.jar',
        oldBytes: oldBytes,
        newBytes: newBytes,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(newBytes);
      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );

      await publication.target.writeAsString('externally changed');

      await expectLater(
        fileSystem.commit(publication),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
          ),
        ),
      );
      expect(publication.state, MtnMinecraftContentMaterializationFileSystemPublicationState.pending);
      expect(await publication.backup!.readAsBytes(), oldBytes);

      await expectLater(
        fileSystem.rollback(publication),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
          ),
        ),
      );
      expect(await publication.backup!.readAsBytes(), oldBytes);

      await publication.target.writeAsBytes(newBytes);
      await fileSystem.rollback(publication);
      expect(await publication.target.readAsBytes(), oldBytes);
    });

    test('only the authority that created a publication may finalize it', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('authority');
      final fixture = await _installFixture(
        relativePath: 'mods/a.jar',
        bytes: bytes,
      );
      final owner = _posix();
      final other = _posix();
      final preflight = await owner.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      final publication = await owner.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );

      await expectLater(other.commit(publication), throwsArgumentError);
      expect(publication.state, MtnMinecraftContentMaterializationFileSystemPublicationState.pending);
      await owner.commit(publication);
    });

    test('metadata-less publication still requires a stable regular source copy', () async {
      final root = await Directory.systemTemp.createTemp();
      final sourceRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => sourceRoot.delete(recursive: true));

      final bytes = utf8.encode('no canonical metadata');
      final fixture = await _installFixture(
        relativePath: 'mods/a.jar',
        bytes: bytes,
        integrityMetadata: false,
      );
      final fileSystem = _posix();
      final preflight = await fileSystem.preflight(
        plan: fixture.plan,
        installationRoot: root.absolute,
      );
      final source = File(p.join(sourceRoot.path, 'a.jar'));
      await source.writeAsBytes(bytes);

      final publication = await fileSystem.publish(
        preflight: preflight,
        target: fixture.target,
        source: source,
      );
      expect(await publication.target.readAsBytes(), bytes);

      final changed = List<int>.from(bytes);
      changed[0] = changed[0] == 0 ? 1 : 0;
      await publication.target.writeAsBytes(changed);
      await expectLater(
        fileSystem.commit(publication),
        throwsA(
          isA<MtnMinecraftContentMaterializationFileSystemPublicationException>().having(
            (error) => error.failure,
            'failure',
            MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure,
          ),
        ),
      );

      await publication.target.writeAsBytes(bytes);
      await fileSystem.commit(publication);
    });
  });
}

MtnMinecraftContentMaterializationFileSystem _posix() {
  return MtnMinecraftContentMaterializationFileSystem(
    policy: const MtnMinecraftContentMaterializationFileSystemPolicy(
      platform: MtnMinecraftContentMaterializationFileSystemPlatform.posix,
      caseSensitive: true,
    ),
  );
}

Future<List<String>> _temporarySiblings(File target) async {
  if (!await target.parent.exists()) {
    return <String>[];
  }
  return target.parent
      .list(followLinks: false)
      .map((entity) => p.basename(entity.path))
      .where((name) => name.startsWith('.mtn-content-'))
      .toList();
}

class _Fixture {
  const _Fixture({
    required this.plan,
    required this.target,
  });

  final MtnMinecraftContentMaterializationPlan plan;
  final MtnMinecraftContentMaterializationTarget target;
}

Future<_Fixture> _installFixture({
  required String relativePath,
  required List<int> bytes,
  bool integrityMetadata = true,
}) async {
  final content = _content('install');
  final file = _file('source.jar', bytes, integrityMetadata: integrityMetadata);
  final version = _version('install:v1', content, file);
  final plan = await _materialization(
    installation: MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]),
    desiredVersions: <MtnMinecraftContentVersion>[version],
    pathForVersion: <String, String>{version.key: relativePath},
  );
  return _Fixture(
    plan: plan,
    target: plan.installs.single.target,
  );
}

Future<_Fixture> _replacementFixture({
  required Directory root,
  required String relativePath,
  required List<int> oldBytes,
  required List<int> newBytes,
}) async {
  final content = _content('replace');
  final oldFile = _file('old.jar', oldBytes);
  final newFile = _file('new.jar', newBytes);
  final oldVersion = _version('replace:v1', content, oldFile);
  final newVersion = _version('replace:v2', content, newFile);
  final oldArtifact = MtnMinecraftContentInstallationArtifact(
    version: oldVersion,
    file: oldFile,
    relativePath: relativePath,
  );

  final physical = File(p.joinAll(<String>[root.path, ...relativePath.split('/')]));
  await physical.parent.create(recursive: true);
  await physical.writeAsBytes(oldBytes);

  final plan = await _materialization(
    installation: MtnMinecraftContentInstallationState(
      artifacts: <MtnMinecraftContentInstallationArtifact>[oldArtifact],
    ),
    desiredVersions: <MtnMinecraftContentVersion>[newVersion],
    pathForVersion: <String, String>{newVersion.key: relativePath},
  );
  return _Fixture(
    plan: plan,
    target: plan.replacements.single.target,
  );
}

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
  final reconciliation = service.reconcileDependencyState(
    installation.dependencyInstalledState,
    desired,
  );
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
  return service.planContentMaterialization(
    download,
    installation,
    targets,
  );
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(
    key: key,
    name: key,
  );
}

MtnMinecraftContentFile _file(
  String fileName,
  List<int> bytes, {
  bool integrityMetadata = true,
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: true,
    available: true,
    downloadUrl: 'https://cdn.example/$fileName',
    size: integrityMetadata ? bytes.length : null,
    hashes: integrityMetadata
        ? <MtnMinecraftContentFileHash>[
            MtnMinecraftContentFileHash(
              algorithm: 'sha256',
              value: sha256.convert(bytes).toString(),
            ),
          ]
        : null,
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
