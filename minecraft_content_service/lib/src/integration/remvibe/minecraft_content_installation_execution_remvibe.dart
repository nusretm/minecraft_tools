import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:remvibe_download_service/remvibe_download_service.dart';

import '../../service/minecraft_content_installation_state.dart';
import '../../service/minecraft_content_materialization_plan.dart';
import '../io/minecraft_content_materialization_file_system.dart';
import '../minecraft_content_file_integrity.dart';
import 'minecraft_content_download_adapter_remvibe.dart';
import 'minecraft_content_download_execution_remvibe.dart';

enum MtnMinecraftContentInstallationExecutionRemVibeState {
  idle,
  validating,
  downloading,
  publishing,
  committing,
  completed,
  cancelled,
  failed,
  recoveryRequired,
}

enum MtnMinecraftContentInstallationExecutionRemVibeFailure {
  validation,
  download,
  cancelled,
  publication,
  recoveryRequired,
}

class MtnMinecraftContentInstallationExecutionRemVibeException implements Exception {
  const MtnMinecraftContentInstallationExecutionRemVibeException({
    required this.failure,
    required this.message,
    this.cause,
    this.batch,
    this.transaction,
  });

  final MtnMinecraftContentInstallationExecutionRemVibeFailure failure;
  final String message;
  final Object? cause;
  final MtnMinecraftContentDownloadAdapterRemVibeBatch? batch;
  final MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction? transaction;

  bool get cancelled => failure == MtnMinecraftContentInstallationExecutionRemVibeFailure.cancelled;
  bool get recoveryRequired => failure == MtnMinecraftContentInstallationExecutionRemVibeFailure.recoveryRequired;

  @override
  String toString() => 'MtnMinecraftContentInstallationExecutionRemVibeException(${failure.name}): $message';
}

/// Runs one content plan through one RemVibe batch (if necessary), then commits
/// managed files and installation manifest with the dev.26 coordinator.
///
/// The caller owns both pre-existing directory roots and all staged files.
class MtnMinecraftContentInstallationExecutionRemVibe {
  MtnMinecraftContentInstallationExecutionRemVibe({
    required this.plan,
    required this.installationRoot,
    required this.key,
    required this.title,
    this.stagingRoot,
    this.maxConcurrentItems = 5,
    this.maxErrorCount = 3,
    this.onStatus,
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
  }) : policy = policy ?? MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    if (key.isEmpty || title.isEmpty) throw ArgumentError('Download job key and title cannot be empty.');
    if (maxConcurrentItems < 1 || maxErrorCount < 1) throw RangeError('RemVibe concurrency and retry limits must be at least one.');
    if (plan.download.items.isNotEmpty && stagingRoot == null) throw ArgumentError.notNull('stagingRoot');
    _fileSystem = MtnMinecraftContentMaterializationFileSystem(policy: this.policy);
    _coordinator = MtnMinecraftContentMaterializationFileSystemCoordinator(policy: this.policy);
  }

  final MtnMinecraftContentMaterializationPlan plan;
  final Directory installationRoot;
  final Directory? stagingRoot;
  final String key;
  final String title;
  final int maxConcurrentItems;
  final int maxErrorCount;
  final RemVibeDownloadJobStatusCallback? onStatus;
  final MtnMinecraftContentMaterializationFileSystemPolicy policy;

  late final MtnMinecraftContentMaterializationFileSystem _fileSystem;
  late final MtnMinecraftContentMaterializationFileSystemCoordinator _coordinator;

  MtnMinecraftContentInstallationExecutionRemVibeState _state = MtnMinecraftContentInstallationExecutionRemVibeState.idle;
  MtnMinecraftContentDownloadAdapterRemVibeBatch? _batch;
  MtnMinecraftContentDownloadExecutionRemVibe? _downloadExecution;
  Future<MtnMinecraftContentInstallationState>? _executeFuture;
  Future<void>? _cancelFuture;
  bool _cancelRequested = false;
  bool _finished = false;

  MtnMinecraftContentInstallationExecutionRemVibeState get state => _state;
  MtnMinecraftContentDownloadAdapterRemVibeBatch? get batch => _batch;

  Future<MtnMinecraftContentInstallationState> execute() => _executeFuture ??= _execute();

  Future<void> cancel() {
    if (_finished || _state == MtnMinecraftContentInstallationExecutionRemVibeState.committing) return Future<void>.value();
    _cancelRequested = true;
    return _cancelFuture ??= _cancelDownload();
  }

  Future<void> _cancelDownload() async {
    final execution = _downloadExecution;
    if (execution != null) await execution.cancel();
  }

  Future<MtnMinecraftContentInstallationState> _execute() async {
    try {
      _state = MtnMinecraftContentInstallationExecutionRemVibeState.validating;
      _checkCancellation();

      final first = await _fileSystem.preflight(plan: plan, installationRoot: installationRoot);
      if (!first.safe) throw StateError('Materialization filesystem preflight is unsafe before transfer.');
      _checkCancellation();

      final sources = <MtnMinecraftContentMaterializationFileSystemTransactionSource>[];
      if (plan.download.items.isNotEmpty) {
        final root = stagingRoot!;
        await _validateStagingRoot(first.resolvedInstallationRoot, root);
        final batch = const MtnMinecraftContentDownloadAdapterRemVibe().createBatch(
          plan: plan,
          stagingRoot: root,
          key: key,
          title: title,
          maxConcurrentItems: maxConcurrentItems,
          maxErrorCount: maxErrorCount,
          onStatus: onStatus,
        );
        _batch = batch;
        await _validateStagingTargets(batch, allowCompletedFiles: false);
        _checkCancellation();

        final execution = MtnMinecraftContentDownloadExecutionRemVibe(batch: batch);
        _downloadExecution = execution;
        _state = MtnMinecraftContentInstallationExecutionRemVibeState.downloading;
        _checkCancellation();
        await execution.execute();
        _checkCancellation();

        if (batch.job.status != RemVibeDownloadStatus.completed) {
          throw StateError('RemVibe download batch did not reach completed status.');
        }
        await _validateStagingTargets(batch, allowCompletedFiles: true);
        _checkCancellation();

        for (final entry in batch.items) {
          final file = entry.item.file;
          if (entry.item.status != RemVibeDownloadStatus.completed || file == null) {
            throw StateError('An exact RemVibe item did not complete with a file.');
          }
          final integrity = MtnMinecraftContentFileIntegrity.fromFile(entry.target.artifact.file);
          if (integrity != null) await integrity.validate(file, subject: 'Completed RemVibe staging file');
          sources.add(MtnMinecraftContentMaterializationFileSystemTransactionSource(target: entry.target, source: file));
        }
        _checkCancellation();
      }

      final refreshed = await _fileSystem.preflight(plan: plan, installationRoot: installationRoot);
      if (!refreshed.safe) throw StateError('Materialization filesystem preflight became unsafe after download.');
      _checkCancellation();

      _state = MtnMinecraftContentInstallationExecutionRemVibeState.publishing;
      final transaction = await _coordinator.begin(preflight: refreshed, sources: sources);
      if (_cancelRequested) {
        await _rollback(transaction, reason: 'Cancellation before coordinated commit');
        throw _cancelled();
      }
      _state = MtnMinecraftContentInstallationExecutionRemVibeState.committing;
      try {
        await _coordinator.commit(transaction);
      } catch (error) {
        if (transaction.state == MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending) {
          await _rollback(transaction, reason: 'Coordinated commit prevalidation failure');
        } else {
          _state = MtnMinecraftContentInstallationExecutionRemVibeState.recoveryRequired;
          throw MtnMinecraftContentInstallationExecutionRemVibeException(
            failure: MtnMinecraftContentInstallationExecutionRemVibeFailure.recoveryRequired,
            message: 'Coordinated commit is incomplete; forward-only recovery remains necessary.',
            cause: error,
            batch: _batch,
            transaction: transaction,
          );
        }
        rethrow;
      }
      _state = MtnMinecraftContentInstallationExecutionRemVibeState.completed;
      return plan.resultingInstallationState;
    } catch (error, stackTrace) {
      if (error is MtnMinecraftContentInstallationExecutionRemVibeException) {
        _state = error.cancelled
            ? MtnMinecraftContentInstallationExecutionRemVibeState.cancelled
            : error.recoveryRequired
                ? MtnMinecraftContentInstallationExecutionRemVibeState.recoveryRequired
                : MtnMinecraftContentInstallationExecutionRemVibeState.failed;
        Error.throwWithStackTrace(error, stackTrace);
      }

      final coordinatedError = error is MtnMinecraftContentMaterializationFileSystemCoordinationException ? error : null;
      final downloadedError = error is MtnMinecraftContentDownloadExecutionRemVibeException ? error : null;
      final failure = coordinatedError?.failure == MtnMinecraftContentMaterializationFileSystemCoordinationFailure.recoveryFailure
          ? MtnMinecraftContentInstallationExecutionRemVibeFailure.recoveryRequired
          : downloadedError?.cancelled == true || _cancelRequested && _state != MtnMinecraftContentInstallationExecutionRemVibeState.committing
              ? MtnMinecraftContentInstallationExecutionRemVibeFailure.cancelled
              : downloadedError != null
                  ? MtnMinecraftContentInstallationExecutionRemVibeFailure.download
                  : _state == MtnMinecraftContentInstallationExecutionRemVibeState.publishing ||
                    _state == MtnMinecraftContentInstallationExecutionRemVibeState.committing
                      ? MtnMinecraftContentInstallationExecutionRemVibeFailure.publication
                      : MtnMinecraftContentInstallationExecutionRemVibeFailure.validation;
      _state = switch (failure) {
        MtnMinecraftContentInstallationExecutionRemVibeFailure.cancelled => MtnMinecraftContentInstallationExecutionRemVibeState.cancelled,
        MtnMinecraftContentInstallationExecutionRemVibeFailure.recoveryRequired => MtnMinecraftContentInstallationExecutionRemVibeState.recoveryRequired,
        _ => MtnMinecraftContentInstallationExecutionRemVibeState.failed,
      };
      Error.throwWithStackTrace(
        MtnMinecraftContentInstallationExecutionRemVibeException(
          failure: failure,
          message: error.toString(),
          cause: error,
          batch: _batch,
          transaction: coordinatedError?.transaction,
        ),
        stackTrace,
      );
    } finally {
      _finished = true;
    }
  }

  Future<void> _rollback(
    MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction, {
    required String reason,
  }) async {
    try {
      await _coordinator.rollback(transaction);
    } catch (error, stackTrace) {
      _state = MtnMinecraftContentInstallationExecutionRemVibeState.recoveryRequired;
      Error.throwWithStackTrace(
        MtnMinecraftContentInstallationExecutionRemVibeException(
          failure: MtnMinecraftContentInstallationExecutionRemVibeFailure.recoveryRequired,
          message: '$reason could not restore the prior installation state.',
          cause: error,
          batch: _batch,
          transaction: transaction,
        ),
        stackTrace,
      );
    }
  }

  void _checkCancellation() {
    if (_cancelRequested) throw _cancelled();
  }

  MtnMinecraftContentInstallationExecutionRemVibeException _cancelled() =>
      MtnMinecraftContentInstallationExecutionRemVibeException(
        failure: MtnMinecraftContentInstallationExecutionRemVibeFailure.cancelled,
        message: 'Installation execution was cancelled before irreversible commit.',
        batch: _batch,
      );

  String _identity(String path) {
    final normalized = p.normalize(p.absolute(path));
    return policy.caseSensitive ? normalized : normalized.toLowerCase();
  }

  bool _containsPath(String ancestor, String descendant) {
    final a = _identity(ancestor);
    final d = _identity(descendant);
    return a == d || d.startsWith('$a${p.separator}');
  }

  Future<void> _validateStagingRoot(Directory resolvedInstallationRoot, Directory root) async {
    if (!p.isAbsolute(root.path) || await FileSystemEntity.type(root.path, followLinks: false) != FileSystemEntityType.directory) {
      throw StateError('Staging root must be an existing absolute, regular directory.');
    }
    final resolvedStage = await root.resolveSymbolicLinks();
    if (_containsPath(resolvedInstallationRoot.path, resolvedStage) ||
        _containsPath(resolvedStage, resolvedInstallationRoot.path)) {
      throw StateError('Staging root and managed installation root must not overlap.');
    }
  }

  Future<void> _validateStagingTargets(
    MtnMinecraftContentDownloadAdapterRemVibeBatch batch, {
    required bool allowCompletedFiles,
  }) async {
    final root = batch.stagingRoot;
    await _validateStagingRoot(Directory(await installationRoot.resolveSymbolicLinks()), root);
    final identities = <String>{};

    for (final entry in batch.items) {
      final segments = entry.target.relativePath.split('/');
      final identity = segments.map((segment) => policy.caseSensitive ? segment : segment.toLowerCase()).join('/');
      if (!identities.add(identity)) throw StateError('Two staged files have the same physical path identity.');

      final output = entry.item.file;
      if (output == null) throw StateError('Expected an explicit RemVibe staging filename.');
      final expectedPath = p.joinAll(<String>[root.path, ...segments]);
      if (_identity(output.path) != _identity(expectedPath)) {
        throw StateError('RemVibe staging output does not match its canonical materialization target.');
      }

      var parent = root;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final parentType = await FileSystemEntity.type(parent.path, followLinks: false);
        if (parentType == FileSystemEntityType.notFound && !allowCompletedFiles) break;
        if (parentType != FileSystemEntityType.directory) {
          throw StateError('Staging target parent is not a regular directory.');
        }
        final siblings = await parent.list(followLinks: false).where((entity) =>
            (policy.caseSensitive ? p.basename(entity.path) : p.basename(entity.path).toLowerCase()) ==
            (policy.caseSensitive ? segment : segment.toLowerCase())).toList();

        if (siblings.length > 1) throw StateError('Ambiguous staging path identity.');
        if (siblings.isNotEmpty) {
          final found = siblings.single;
          if (p.basename(found.path) != segment) throw StateError('Staging target collides with existing casing.');
          final kind = await FileSystemEntity.type(found.path, followLinks: false);
          if (i != segments.length - 1 && kind != FileSystemEntityType.directory) {
            throw StateError('Staging target ancestor must be a regular directory.');
          }
          if (i == segments.length - 1 &&
              (kind != FileSystemEntityType.file || !allowCompletedFiles)) {
            throw StateError('Staging destination is occupied by an unmanaged file or link.');
          }
        } else if (allowCompletedFiles) {
          throw StateError('Completed RemVibe staging output is missing.');
        }
        parent = Directory(p.join(parent.path, segment));
      }
      if (!allowCompletedFiles &&
          await FileSystemEntity.type('$expectedPath.download', followLinks: false) != FileSystemEntityType.notFound) {
        throw StateError('RemVibe temporary download path is occupied.');
      }
      if (allowCompletedFiles &&
          await FileSystemEntity.type(expectedPath, followLinks: false) != FileSystemEntityType.file) {
        throw StateError('Completed staging source must be a regular file.');
      }
    }
  }
}
