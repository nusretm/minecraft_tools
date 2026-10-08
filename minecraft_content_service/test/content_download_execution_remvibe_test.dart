import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:minecraft_content_service/minecraft_content_service_remvibe.dart';
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

  group('MtnMinecraftContentDownloadExecutionRemVibe', () {
    test('starts an inactive service, submits the exact batch once, and completes staged download', () async {
      final bytes = <int>[1, 2, 3, 4, 5];
      final server = await _server((request) async {
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));

      var onStatusCount = 0;
      void onStatus(RemVibeDownloadJob job) {
        onStatusCount++;
      }

      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:${server.port}/file.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-success',
        size: bytes.length,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(
            algorithm: 'sha256',
            value: sha256.convert(bytes).toString(),
          ),
        ],
        onStatus: onStatus,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);

      expect(service.active, isFalse);
      expect(batch.job.onStatus, same(onStatus));

      final first = execution.execute();
      final second = execution.execute();
      expect(identical(first, second), isTrue);

      final result = await first.timeout(const Duration(seconds: 5));

      expect(result, same(batch));
      expect(service.active, isTrue);
      expect(service.clearPolicy, RemVibeClearPolicy.manual);
      expect(service.jobs.where((job) => identical(job, batch.job)), hasLength(1));
      expect(batch.job.status, RemVibeDownloadStatus.completed);
      expect(batch.job.items.single.status, RemVibeDownloadStatus.completed);
      expect(onStatusCount, greaterThan(0));

      final stagedFile = batch.job.items.single.file!;
      expect(await stagedFile.readAsBytes(), bytes);
    });

    test('rejects a duplicate job key before starting or mutating the service', () async {
      final existingDirectory = await Directory.systemTemp.createTemp();
      addTearDown(() => existingDirectory.delete(recursive: true));
      final existingItem = RemVibeDownloadItem(
        url: Uri.parse('http://127.0.0.1:1/existing.jar'),
        directory: existingDirectory,
        filename: 'existing.jar',
      );
      final existingJob = RemVibeDownloadJob(
        key: 'duplicate-key',
        title: 'Existing',
        items: <RemVibeDownloadItem>[existingItem],
      );
      service.addJob(existingJob);

      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:1/new.jar'),
        stagingRoot: stagingRoot,
        key: 'duplicate-key',
        size: null,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);

      await expectLater(
        execution.execute(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('already registered'),
          ),
        ),
      );

      expect(service.active, isFalse);
      expect(service.jobs, <RemVibeDownloadJob>[existingJob]);
      expect(existingJob.items, <RemVibeDownloadItem>[existingItem]);
      expect(existingJob.status, RemVibeDownloadStatus.idle);
      expect(existingItem.status, RemVibeDownloadStatus.idle);
      expect(batch.job.status, RemVibeDownloadStatus.idle);
    });

    test('turns exhausted integrity retries into a typed execution error', () async {
      var requests = 0;
      final server = await _server((request) async {
        requests++;
        request.response.add(<int>[1, 2, 3]);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:${server.port}/invalid.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-integrity-error',
        size: 4,
        maxErrorCount: 2,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);

      await expectLater(
        execution.execute().timeout(const Duration(seconds: 5)),
        throwsA(
          isA<MtnMinecraftContentDownloadExecutionRemVibeException>()
              .having((error) => error.status, 'status', RemVibeDownloadStatus.error)
              .having((error) => error.message, 'message', contains('size mismatch')),
        ),
      );

      expect(requests, 2);
      expect(batch.job.status, RemVibeDownloadStatus.error);
      expect(batch.job.items.single.errorCount, 2);
      expect(batch.job.items.single.status, RemVibeDownloadStatus.error);
      expect(await batch.job.items.single.file!.exists(), isFalse);
      expect(await File('${batch.job.items.single.file!.path}.download').exists(), isFalse);
    });

    test('cancels an in-flight batch only after RemVibe cleanup and job removal', () async {
      final requestStarted = Completer<void>();
      final releaseServer = Completer<void>();
      final server = await _server((request) async {
        request.response.add(<int>[1, 2, 3]);
        await request.response.flush();
        if (!requestStarted.isCompleted) {
          requestStarted.complete();
        }
        await releaseServer.future;
        try {
          request.response.add(<int>[4, 5, 6]);
          await request.response.close();
        } catch (_) {}
      });
      addTearDown(() async {
        if (!releaseServer.isCompleted) {
          releaseServer.complete();
        }
        await server.close(force: true);
      });

      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:${server.port}/cancel.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-cancel',
        size: null,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);
      final executeFuture = execution.execute();

      await requestStarted.future.timeout(const Duration(seconds: 5));

      final firstCancel = execution.cancel();
      final secondCancel = execution.cancel();
      expect(identical(firstCancel, secondCancel), isTrue);
      await firstCancel.timeout(const Duration(seconds: 5));

      await expectLater(
        executeFuture,
        throwsA(
          isA<MtnMinecraftContentDownloadExecutionRemVibeException>()
              .having((error) => error.status, 'status', RemVibeDownloadStatus.cancelled)
              .having((error) => error.cancelled, 'cancelled', isTrue),
        ),
      );

      expect(batch.job.status, RemVibeDownloadStatus.cancelled);
      expect(service.jobs.where((job) => identical(job, batch.job)), isEmpty);
      expect(await batch.job.items.single.file!.exists(), isFalse);
      expect(await File('${batch.job.items.single.file!.path}.download').exists(), isFalse);
    });

    test('waits through an external service stop and resumes only after the service is started again', () async {
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      var requests = 0;
      final bytes = <int>[7, 8, 9];

      final server = await _server((request) async {
        requests++;
        if (requests == 1) {
          request.response.add(<int>[0]);
          await request.response.flush();
          if (!firstRequestStarted.isCompleted) {
            firstRequestStarted.complete();
          }
          await releaseFirstRequest.future;
          try {
            await request.response.close();
          } catch (_) {}
          return;
        }

        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() async {
        if (!releaseFirstRequest.isCompleted) {
          releaseFirstRequest.complete();
        }
        await server.close(force: true);
      });

      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:${server.port}/pause-resume.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-pause-resume',
        size: bytes.length,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);

      var settled = false;
      final executeFuture = execution.execute();
      unawaited(
        executeFuture.then<void>(
          (_) {
            settled = true;
          },
          onError: (_) {
            settled = true;
          },
        ),
      );

      await firstRequestStarted.future.timeout(const Duration(seconds: 5));
      await service.stop().timeout(const Duration(seconds: 5));

      expect(service.active, isFalse);
      expect(batch.job.status, RemVibeDownloadStatus.idle);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(settled, isFalse);

      await service.start();
      final result = await executeFuture.timeout(const Duration(seconds: 5));

      expect(result, same(batch));
      expect(requests, 2);
      expect(batch.job.status, RemVibeDownloadStatus.completed);
      expect(await batch.job.items.single.file!.readAsBytes(), bytes);
    });

    test('cancel before execute prevents service start and job submission', () async {
      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:1/not-submitted.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-cancel-before-submit',
        size: null,
      );
      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);

      await execution.cancel();
      await expectLater(
        execution.execute(),
        throwsA(
          isA<MtnMinecraftContentDownloadExecutionRemVibeException>()
              .having((error) => error.status, 'status', RemVibeDownloadStatus.cancelled),
        ),
      );

      expect(service.active, isFalse);
      expect(service.jobs, isEmpty);
      expect(batch.job.status, RemVibeDownloadStatus.idle);
      expect(batch.job.items.single.status, RemVibeDownloadStatus.idle);
    });

    test('rejects a non-fresh batch before touching the service', () async {
      final stagingRoot = await Directory.systemTemp.createTemp();
      addTearDown(() => stagingRoot.delete(recursive: true));
      final batch = await _batch(
        url: Uri.parse('http://127.0.0.1:1/non-fresh.jar'),
        stagingRoot: stagingRoot,
        key: 'execution-non-fresh',
        size: null,
      );

      service.addJob(batch.job);
      await service.cancelJob(batch.job);

      final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);
      await expectLater(
        execution.execute(),
        throwsA(isA<StateError>()),
      );

      expect(service.active, isFalse);
      expect(service.jobs, isEmpty);
      expect(batch.job.status, RemVibeDownloadStatus.cancelled);
    });
  });
}

Future<void> _resetService(RemVibeDownloadService service) async {
  await service.stop();
  for (final job in List<RemVibeDownloadJob>.of(service.jobs)) {
    await service.cancelJob(job);
  }
}

Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    unawaited(handler(request));
  });
  return server;
}

Future<MtnMinecraftContentDownloadAdapterRemVibeBatch> _batch({
  required Uri url,
  required Directory stagingRoot,
  required String key,
  required int? size,
  List<MtnMinecraftContentFileHash>? hashes,
  int maxErrorCount = 3,
  RemVibeDownloadJobStatusCallback? onStatus,
}) async {
  final content = MtnMinecraftContentMod(
    key: 'content:$key',
    name: key,
  );
  final file = MtnMinecraftContentFile(
    fileName: 'source.jar',
    primary: true,
    available: true,
    downloadUrl: url.toString(),
    size: size,
    hashes: hashes,
  );
  final version = MtnMinecraftContentVersion(
    key: 'version:$key',
    content: content,
    name: key,
    version: '1.0.0',
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[
      MtnMinecraftModLoaderType.fabric,
    ],
    files: <MtnMinecraftContentFile>[file],
  );

  final service = MtnMinecraftContentService();
  final desired = service.composeDependencyInstallPlans(
    <MtnMinecraftContentDependencyInstallPlan>[
      MtnMinecraftContentDependencyInstallPlan(
        root: version,
        installVersions: <MtnMinecraftContentVersion>[version],
        installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
        conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
      ),
    ],
  );
  final installation = MtnMinecraftContentInstallationState(
    artifacts: const <MtnMinecraftContentInstallationArtifact>[],
  );
  final reconciliation = service.reconcileDependencyState(
    installation.dependencyInstalledState,
    desired,
  );
  final selection = service.selectReconciliationFiles(reconciliation);
  final download = await service.planSelectedFileDownloads(selection);
  final plan = service.planContentMaterialization(
    download,
    installation,
    <MtnMinecraftContentMaterializationTarget>[
      MtnMinecraftContentMaterializationTarget(
        download: download.items.single,
        relativePath: 'mods/example.jar',
      ),
    ],
  );

  return const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
    plan: plan,
    stagingRoot: stagingRoot,
    key: key,
    title: 'Content download',
    maxConcurrentItems: 1,
    maxErrorCount: maxErrorCount,
    onStatus: onStatus,
  );
}
