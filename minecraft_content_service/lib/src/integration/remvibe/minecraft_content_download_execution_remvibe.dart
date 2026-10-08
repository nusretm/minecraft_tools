import 'dart:async';

import 'package:remvibe_download_service/remvibe_download_service.dart';

import 'minecraft_content_download_adapter_remvibe.dart';

class MtnMinecraftContentDownloadExecutionRemVibeException implements Exception {
  const MtnMinecraftContentDownloadExecutionRemVibeException({
    required this.batch,
    required this.status,
    required this.message,
  });

  final MtnMinecraftContentDownloadAdapterRemVibeBatch batch;
  final RemVibeDownloadStatus status;
  final String message;

  bool get cancelled => status == RemVibeDownloadStatus.cancelled;
  bool get error => status == RemVibeDownloadStatus.error;

  @override
  String toString() => 'MtnMinecraftContentDownloadExecutionRemVibeException(status=${status.name}, message=$message)';
}

class MtnMinecraftContentDownloadExecutionRemVibe {
  MtnMinecraftContentDownloadExecutionRemVibe({
    required this.batch,
  });

  final MtnMinecraftContentDownloadAdapterRemVibeBatch batch;

  final RemVibeDownloadService _service = RemVibeDownloadService();

  Future<MtnMinecraftContentDownloadAdapterRemVibeBatch>? _executeFuture;
  Future<void>? _cancelFuture;
  Completer<MtnMinecraftContentDownloadAdapterRemVibeBatch>? _completion;
  RemVibeDownloadHandler? _handler;
  bool _cancelRequested = false;
  bool _submitted = false;
  bool _finished = false;

  Future<MtnMinecraftContentDownloadAdapterRemVibeBatch> execute() {
    return _executeFuture ??= _execute();
  }

  Future<void> cancel() {
    _cancelRequested = true;
    return _cancelFuture ??= _cancel();
  }

  Future<MtnMinecraftContentDownloadAdapterRemVibeBatch> _execute() async {
    try {
      _validateFreshBatch();

      final completion = Completer<MtnMinecraftContentDownloadAdapterRemVibeBatch>();
      _completion = completion;

      final handler = RemVibeDownloadHandler(onJob: _onJob);
      _handler = handler;
      handler.start();

      _ensureUniqueJobKey();
      if (_cancelRequested) {
        throw _cancelledException('Download execution was cancelled before submission.');
      }

      if (!_service.active) {
        await _service.start();
      }

      if (_cancelRequested) {
        throw _cancelledException('Download execution was cancelled before submission.');
      }

      _ensureUniqueJobKey();
      if (_cancelRequested) {
        throw _cancelledException('Download execution was cancelled before submission.');
      }

      final registered = _service.addJob(batch.job);
      if (!identical(registered, batch.job)) {
        throw StateError('RemVibe download service did not register the exact content batch job.');
      }
      _submitted = true;

      if (_cancelRequested) {
        await _service.cancelJob(batch.job);
      }

      return await completion.future;
    } finally {
      _finished = true;
      _handler?.dispose();
      _handler = null;
    }
  }

  Future<void> _cancel() async {
    if (_finished) {
      return;
    }

    final executeFuture = _executeFuture;
    if (executeFuture == null) {
      return;
    }

    if (!_submitted) {
      try {
        await executeFuture;
      } on MtnMinecraftContentDownloadExecutionRemVibeException catch (error) {
        if (error.cancelled) {
          return;
        }
        rethrow;
      }
      return;
    }

    final completion = _completion;
    if (completion != null && completion.isCompleted) {
      return;
    }

    await _service.cancelJob(batch.job);
  }

  void _onJob(RemVibeDownloadJob job, RemVibeListEventType event) {
    if (!identical(job, batch.job)) {
      return;
    }

    final completion = _completion;
    if (completion == null || completion.isCompleted) {
      return;
    }

    if (event == RemVibeListEventType.remove) {
      switch (job.status) {
        case RemVibeDownloadStatus.completed:
          completion.complete(batch);
        case RemVibeDownloadStatus.cancelled:
          completion.completeError(
            _cancelledException('Download execution was cancelled.'),
            StackTrace.current,
          );
        case RemVibeDownloadStatus.error:
          completion.completeError(
            _errorException(),
            StackTrace.current,
          );
        case RemVibeDownloadStatus.idle:
        case RemVibeDownloadStatus.downloading:
          completion.completeError(
            StateError('RemVibe removed the content batch before it reached a terminal status.'),
            StackTrace.current,
          );
      }
      return;
    }

    switch (job.status) {
      case RemVibeDownloadStatus.completed:
        completion.complete(batch);
      case RemVibeDownloadStatus.error:
        completion.completeError(
          _errorException(),
          StackTrace.current,
        );
      case RemVibeDownloadStatus.cancelled:
      case RemVibeDownloadStatus.idle:
      case RemVibeDownloadStatus.downloading:
        break;
    }
  }

  void _validateFreshBatch() {
    final job = batch.job;
    if (job.status != RemVibeDownloadStatus.idle) {
      throw StateError('Content download execution requires an idle batch job.');
    }
    if (job.activeItems.isNotEmpty) {
      throw StateError('Content download execution requires a batch with no active items.');
    }

    for (final item in job.items) {
      if (item.status != RemVibeDownloadStatus.idle ||
          item.downloadedSize != 0 ||
          item.errorCount != 0) {
        throw StateError('Content download execution requires fresh idle download items.');
      }
    }
  }

  void _ensureUniqueJobKey() {
    for (final existing in _service.jobs) {
      if (existing.key == batch.job.key) {
        throw StateError('A RemVibe download job with key "${batch.job.key}" is already registered.');
      }
    }
  }

  MtnMinecraftContentDownloadExecutionRemVibeException _cancelledException(String message) {
    return MtnMinecraftContentDownloadExecutionRemVibeException(
      batch: batch,
      status: RemVibeDownloadStatus.cancelled,
      message: message,
    );
  }

  MtnMinecraftContentDownloadExecutionRemVibeException _errorException() {
    RemVibeDownloadItem? failedItem;
    for (final item in batch.job.items) {
      if (item.status == RemVibeDownloadStatus.error) {
        failedItem = item;
        break;
      }
    }

    final detail = failedItem?.errorMessage;
    return MtnMinecraftContentDownloadExecutionRemVibeException(
      batch: batch,
      status: RemVibeDownloadStatus.error,
      message: detail == null || detail.isEmpty
          ? 'Content download batch "${batch.job.key}" failed.'
          : 'Content download batch "${batch.job.key}" failed: $detail',
    );
  }
}
