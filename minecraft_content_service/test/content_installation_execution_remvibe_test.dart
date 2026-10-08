import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_remvibe_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final service = RemVibeDownloadService();
  setUp(() async {
    await _resetService(service);
    service.clearPolicy = RemVibeClearPolicy.manual;
  });
  tearDown(() async {
    await _resetService(service);
    service.clearPolicy = RemVibeClearPolicy.beforeNextAdd;
  });

  group('RemVibe coordinated installation execution', () {
    test('two downloads use one job; commits both managed files and manifest, retains staged originals', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final downloads = <String, List<int>>{
        '/alpha': <int>[1, 2, 3, 4],
        '/beta': <int>[5, 6, 7],
      };
      final server = await _server((request) async {
        request.response.add(downloads[request.uri.path]!);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final a = _version('a:v1', 'a', 'provider-a.jar', 'http://127.0.0.1:${server.port}/alpha', bytes: downloads['/alpha']);
      final b = _version('b:v1', 'b', 'provider-b.jar', 'http://127.0.0.1:${server.port}/beta', bytes: downloads['/beta']);
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[a, b], <String, String>{
        'a:v1': 'mods/a.jar',
        'b:v1': 'mods/nested/b.jar',
      });
      final execution = fixture.execution(plan);
      final first = execution.execute();
      final second = execution.execute();
      expect(identical(first, second), isTrue);
      final result = await first.timeout(const Duration(seconds: 10));

      expect(identical(result, plan.resultingInstallationState), isTrue);
      expect(execution.state, MtnMinecraftContentInstallationExecutionRemVibeState.completed);
      expect(service.jobs.where((job) => identical(job, execution.batch!.job)), hasLength(1));
      expect(execution.batch!.job.items, hasLength(2));
      expect(execution.batch!.job.status, RemVibeDownloadStatus.completed);
      expect(await fixture.read('mods/a.jar'), downloads['/alpha']);
      expect(await fixture.read('mods/nested/b.jar'), downloads['/beta']);
      expect(await File(p.join(fixture.stage.path, 'mods', 'a.jar')).readAsBytes(), downloads['/alpha']);
      expect(await File(p.join(fixture.stage.path, 'mods', 'nested', 'b.jar')).readAsBytes(), downloads['/beta']);
      final saved = await fixture.manifests.read(installationRoot: fixture.root);
      expect(saved!.installationState.artifacts.map((a) => a.version.key), containsAll(<String>['a:v1', 'b:v1']));
      await execution.cancel(); // Already finalized; no side effects.
      expect(execution.state, MtnMinecraftContentInstallationExecutionRemVibeState.completed);
    });

    test('remove-only plan uses no RemVibe job but commits empty persisted manifest', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar', 'https://cdn.example/a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.existing(state, <String, List<int>>{'mods/a.jar': <int>[1]});
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      final executor = fixture.execution(plan, withoutStage: true);
      final result = await executor.execute();

      expect(result.artifacts, isEmpty);
      expect(executor.batch, isNull);
      expect(service.jobs, isEmpty);
      expect(await File(p.join(fixture.root.path, 'mods', 'a.jar')).exists(), isFalse);
      expect((await fixture.manifests.read(installationRoot: fixture.root))!.installationState.artifacts, isEmpty);
    });

    test('retain-only plan avoids download and preserves retained bytes', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final version = _version('a:v1', 'a', 'a.jar', 'https://cdn.example/a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(version, 'mods/a.jar')]);
      await fixture.existing(state, <String, List<int>>{'mods/a.jar': <int>[8]});
      final plan = await _plan(state, <MtnMinecraftContentVersion>[version], const <String, String>{});
      final executor = fixture.execution(plan, withoutStage: true);
      await executor.execute();
      expect(service.jobs, isEmpty);
      expect(await fixture.read('mods/a.jar'), <int>[8]);
      expect((await fixture.manifests.read(installationRoot: fixture.root))!.installationState.artifacts.single.version.key, 'a:v1');
    });

    test('empty materialization plan publishes empty manifest without a download job', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final plan = await _plan(_empty(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final executor = fixture.execution(plan, withoutStage: true);
      await executor.execute();
      expect(executor.batch, isNull);
      expect(service.jobs, isEmpty);
      expect((await fixture.manifests.read(installationRoot: fixture.root))!.installationState.artifacts, isEmpty);
    });

    test('one replacement downloads renamed provider file and persists new manifest snapshot', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'old.jar', 'https://cdn.example/old.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/custom.jar')]);
      await fixture.existing(state, <String, List<int>>{'mods/custom.jar': <int>[9]});
      final bytes = <int>[3, 3, 3];
      final server = await _server((request) async { request.response.add(bytes); await request.response.close(); });
      addTearDown(() => server.close(force: true));
      final next = _version('a:v2', 'a', 'provider-different.jar', 'http://127.0.0.1:${server.port}/update', bytes: bytes);
      final plan = await _plan(state, <MtnMinecraftContentVersion>[next], <String, String>{'a:v2': 'mods/custom.jar'});
      final executor = fixture.execution(plan);
      await executor.execute();
      expect(await fixture.read('mods/custom.jar'), bytes);
      expect(await File(p.join(fixture.stage.path, 'mods', 'custom.jar')).readAsBytes(), bytes);
      expect((await fixture.manifests.read(installationRoot: fixture.root))!.installationState.artifacts.single.version.key, 'a:v2');
    });

    test('download retry exhaustion leaves managed filesystem and manifest untouched', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      var requests = 0;
      final server = await _server((request) async {
        requests++;
        request.response.add(<int>[1, 2]);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:${server.port}/wrong', bytes: <int>[1, 2, 3]);
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = fixture.execution(plan, maxErrorCount: 2);
      await expectLater(executor.execute().timeout(const Duration(seconds: 10)),
          throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>()
              .having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.download)));
      expect(requests, 2);
      expect(executor.state, MtnMinecraftContentInstallationExecutionRemVibeState.failed);
      expect(await File(p.join(fixture.root.path, 'mods', 'a.jar')).exists(), isFalse);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
    });

    test('cancel before execute never creates a batch, starts service or mutates files', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:1/unreachable');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = fixture.execution(plan);
      final cancel1 = executor.cancel();
      final cancel2 = executor.cancel();
      expect(identical(cancel1, cancel2), isTrue);
      await cancel1;
      await expectLater(executor.execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.cancelled, 'cancelled', isTrue)));
      expect(executor.batch, isNull);
      expect(service.jobs, isEmpty);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
    });

    test('inflight cancellation delegates to the exact RemVibe job and never publishes', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final started = Completer<void>();
      final release = Completer<void>();
      final server = await _server((request) async {
        request.response.add(<int>[1]);
        await request.response.flush();
        if (!started.isCompleted) started.complete();
        await release.future;
        try { await request.response.close(); } catch (_) {}
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await server.close(force: true);
      });
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:${server.port}/slow');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = fixture.execution(plan);
      final running = executor.execute();
      await started.future.timeout(const Duration(seconds: 8));
      await executor.cancel().timeout(const Duration(seconds: 8));
      await expectLater(running, throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.cancelled, 'cancelled', isTrue)));
      expect(service.jobs.where((job) => identical(job, executor.batch!.job)), isEmpty);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
      expect(await File(p.join(fixture.root.path, 'mods', 'a.jar')).exists(), isFalse);
    });

    test('staging root within the installation is rejected before RemVibe submission', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:1/file');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = MtnMinecraftContentInstallationExecutionRemVibe(
        plan: plan, installationRoot: fixture.root, stagingRoot: fixture.root,
        key: 'overlap', title: 'Overlap',
      );
      await expectLater(executor.execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.validation)));
      expect(service.jobs, isEmpty);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
    });

    test('existing staged file is not overwritten by the new executor', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final stageFile = File(p.join(fixture.stage.path, 'mods', 'a.jar'));
      await stageFile.parent.create(recursive: true);
      await stageFile.writeAsBytes(<int>[77]);
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:1/unreachable');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      await expectLater(fixture.execution(plan).execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.validation)));
      expect(await stageFile.readAsBytes(), <int>[77]);
      expect(service.jobs, isEmpty);
    });

    test('staging symlinked ancestor is rejected before downloading', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final outside = await Directory.systemTemp.createTemp('mtn-stage-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final link = Link(p.join(fixture.stage.path, 'mods'));
      try { await link.create(outside.path); } on FileSystemException { return; }
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:1/unreachable');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      await expectLater(fixture.execution(plan).execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.validation)));
      expect(await outside.list().toList(), isEmpty);
      expect(service.jobs, isEmpty);
    });

    test('case-colliding staging ancestor is refused under Windows policy', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      await Directory(p.join(fixture.stage.path, 'MODS')).create();
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:1/unreachable');
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final policy = const MtnMinecraftContentMaterializationFileSystemPolicy(
        platform: MtnMinecraftContentMaterializationFileSystemPlatform.windows,
        caseSensitive: false,
      );
      await expectLater(fixture.execution(plan, policy: policy).execute(),
          throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.validation)));
      expect(service.jobs, isEmpty);
    });

    test('corrupt persisted manifest stops zero-download transaction', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      await fixture.write('.mtn-content/installation.json', <int>[123, 125, 1]);
      final plan = await _plan(_empty(), const <MtnMinecraftContentVersion>[], const <String, String>{});
      final executor = fixture.execution(plan, withoutStage: true);
      await expectLater(executor.execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>()
          .having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.publication)));
      expect(await fixture.read('.mtn-content/installation.json'), <int>[123, 125, 1]);
    });

    test('missing-current-manifest mismatch rejects removal and preserves owned files', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final old = _version('a:v1', 'a', 'a.jar', 'https://cdn.example/a.jar');
      final state = _state(<MtnMinecraftContentInstallationArtifact>[_artifact(old, 'mods/a.jar')]);
      await fixture.write('mods/a.jar', <int>[4]);
      final plan = await _plan(state, const <MtnMinecraftContentVersion>[], const <String, String>{});
      await expectLater(fixture.execution(plan, withoutStage: true).execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.publication)));
      expect(await fixture.read('mods/a.jar'), <int>[4]);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
    });

    test('stage bytes changed by terminal callback fail post-download integrity before publication', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final bytes = <int>[1, 2, 3, 4];
      final server = await _server((request) async {request.response.add(bytes); await request.response.close();});
      addTearDown(() => server.close(force: true));
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:${server.port}/tamper', bytes: bytes);
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = MtnMinecraftContentInstallationExecutionRemVibe(
        plan: plan,
        installationRoot: fixture.root,
        stagingRoot: fixture.stage,
        key: 'terminal-tamper',
        title: 'Terminal tamper',
        onStatus: (job) {
          if (job.status == RemVibeDownloadStatus.completed) {
            job.items.single.file!.writeAsBytesSync(<int>[9, 9, 9, 9]);
          }
        },
      );
      await expectLater(executor.execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>()));
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
      expect(await File(p.join(fixture.root.path, 'mods', 'a.jar')).exists(), isFalse);
    });

    test('managed target occupied while batch downloads causes post-transfer preflight rejection', () async {
      final fixture = await _fixture();
      addTearDown(fixture.dispose);
      final bytes = <int>[1, 2, 3];
      final server = await _server((request) async {request.response.add(bytes); await request.response.close();});
      addTearDown(() => server.close(force: true));
      final version = _version('a:v1', 'a', 'a.jar', 'http://127.0.0.1:${server.port}/late', bytes: bytes);
      final plan = await _plan(_empty(), <MtnMinecraftContentVersion>[version], <String, String>{'a:v1': 'mods/a.jar'});
      final executor = MtnMinecraftContentInstallationExecutionRemVibe(
        plan: plan, installationRoot: fixture.root, stagingRoot: fixture.stage, key: 'stale-target', title: 'Stale target',
        onStatus: (job) {
          if (job.status == RemVibeDownloadStatus.downloading) {
            final file = File(p.join(fixture.root.path, 'mods', 'a.jar'));
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(<int>[9]);
          }
        },
      );
      await expectLater(executor.execute(), throwsA(isA<MtnMinecraftContentInstallationExecutionRemVibeException>().having((e) => e.failure, 'failure', MtnMinecraftContentInstallationExecutionRemVibeFailure.validation)));
      expect(await fixture.read('mods/a.jar'), <int>[9]);
      expect(await fixture.manifests.read(installationRoot: fixture.root), isNull);
    });
  });
}

class _Fixture {
  _Fixture(this.root, this.stage);
  final Directory root;
  final Directory stage;
  final MtnMinecraftContentInstallationManifestFileSystem manifests = MtnMinecraftContentInstallationManifestFileSystem();

  MtnMinecraftContentInstallationExecutionRemVibe execution(
    MtnMinecraftContentMaterializationPlan plan, {
    bool withoutStage = false,
    int maxErrorCount = 3,
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
  }) => MtnMinecraftContentInstallationExecutionRemVibe(
    plan: plan,
    installationRoot: root,
    stagingRoot: withoutStage ? null : stage,
    key: 'test-job',
    title: 'Content test job',
    maxErrorCount: maxErrorCount,
    policy: policy,
  );

  Future<void> dispose() async {
    await root.delete(recursive: true);
    await stage.delete(recursive: true);
  }

  Future<void> write(String relative, List<int> bytes) async {
    final file = File(p.joinAll(<String>[root.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<List<int>> read(String relative) => File(p.joinAll(<String>[root.path, ...relative.split('/')])).readAsBytes();

  Future<void> existing(MtnMinecraftContentInstallationState state, Map<String, List<int>> contents) async {
    for (final entry in contents.entries) await write(entry.key, entry.value);
    final publication = await manifests.publish(
      installationRoot: root,
      manifest: MtnMinecraftContentInstallationManifest.fromInstallationState(state),
    );
    await manifests.commit(publication);
  }
}

Future<_Fixture> _fixture() async {
  final root = await Directory.systemTemp.createTemp('mtn-execution-install-');
  final stage = await Directory.systemTemp.createTemp('mtn-execution-stage-');
  return _Fixture(root, stage);
}

Future<void> _resetService(RemVibeDownloadService service) async {
  await service.stop();
  for (final job in List<RemVibeDownloadJob>.of(service.jobs)) await service.cancelJob(job);
}

Future<HttpServer> _server(Future<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) { unawaited(handler(request)); });
  return server;
}

MtnMinecraftContentInstallationState _empty() => MtnMinecraftContentInstallationState(artifacts: const <MtnMinecraftContentInstallationArtifact>[]);

MtnMinecraftContentInstallationState _state(List<MtnMinecraftContentInstallationArtifact> artifacts) =>
    MtnMinecraftContentInstallationState(artifacts: artifacts);

MtnMinecraftContentInstallationArtifact _artifact(MtnMinecraftContentVersion version, String relativePath) =>
    MtnMinecraftContentInstallationArtifact(version: version, file: version.files.single, relativePath: relativePath);

MtnMinecraftContentVersion _version(String key, String contentKey, String fileName, String url, {List<int>? bytes}) {
  final file = MtnMinecraftContentFile(
    fileName: fileName,
    size: bytes?.length,
    hashes: bytes == null ? const <MtnMinecraftContentFileHash>[] : <MtnMinecraftContentFileHash>[
      MtnMinecraftContentFileHash(algorithm: 'sha256', value: sha256.convert(bytes).toString()),
    ],
    primary: true,
    available: true,
    downloadUrl: url,
  );
  return MtnMinecraftContentVersion(
    key: key,
    content: MtnMinecraftContentMod(key: contentKey, name: contentKey),
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: <MtnMinecraftContentFile>[file],
  );
}

Future<MtnMinecraftContentMaterializationPlan> _plan(
  MtnMinecraftContentInstallationState installation,
  List<MtnMinecraftContentVersion> desiredVersions,
  Map<String, String> paths,
) async {
  final service = MtnMinecraftContentService();
  final desired = desiredVersions.isEmpty
      ? service.composeDependencyInstallPlans(const <MtnMinecraftContentDependencyInstallPlan>[])
      : service.composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[
          MtnMinecraftContentDependencyInstallPlan(
            root: desiredVersions.first,
            installVersions: desiredVersions,
            installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
            conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
          ),
        ]);
  final reconciliation = service.reconcileDependencyState(installation.dependencyInstalledState, desired);
  final selection = service.selectReconciliationFiles(reconciliation);
  final downloads = await service.planSelectedFileDownloads(selection);
  final targets = downloads.items.map((item) => MtnMinecraftContentMaterializationTarget(
    download: item,
    relativePath: paths[item.selection.desired.version.key]!,
  ));
  return service.planContentMaterialization(downloads, installation, targets);
}
