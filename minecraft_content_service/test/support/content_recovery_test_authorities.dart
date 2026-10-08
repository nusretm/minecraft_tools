import 'dart:async';

import 'package:minecraft_content_service/minecraft_content_service_io.dart';

/// Real manifest filesystem authority with a one-shot operation interruption.
/// Its normal publish/read behavior and underlying file bytes are unchanged.
class InterruptedManifestIO extends MtnMinecraftContentInstallationManifestFileSystem {
  bool interruptCommitOnce = false;
  bool interruptRollbackOnce = false;
  int commitAttempts = 0;
  int rollbackAttempts = 0;

  @override
  Future<void> commit(MtnMinecraftContentInstallationManifestFileSystemPublication publication) async {
    commitAttempts++;
    if (interruptCommitOnce) {
      interruptCommitOnce = false;
      throw StateError('One-shot manifest commit interruption');
    }
    await super.commit(publication);
  }

  @override
  Future<void> rollback(MtnMinecraftContentInstallationManifestFileSystemPublication publication) async {
    rollbackAttempts++;
    if (interruptRollbackOnce) {
      interruptRollbackOnce = false;
      throw StateError('One-shot manifest rollback interruption');
    }
    await super.rollback(publication);
  }
}

/// Allows the caller to cancel precisely after a real pending transaction has
/// been created, before the executor receives the completed begin() future.
class PausedBeginCoordinator extends MtnMinecraftContentMaterializationFileSystemCoordinator {
  final Completer<void> createdPending = Completer<void>();
  final Completer<void> resumeBegin = Completer<void>();

  @override
  Future<MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction> begin({
    required MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    required Iterable<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources,
  }) async {
    final tx = await super.begin(preflight: preflight, sources: sources);
    createdPending.complete();
    await resumeBegin.future;
    return tx;
  }
}

/// Blocks the normal commit call before any irreversible cleanup begins.
class PausedCommitCoordinator extends MtnMinecraftContentMaterializationFileSystemCoordinator {
  final Completer<void> reachedCommit = Completer<void>();
  final Completer<void> resumeCommit = Completer<void>();

  @override
  Future<void> commit(MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction) async {
    reachedCommit.complete();
    await resumeCommit.future;
    await super.commit(transaction);
  }
}

/// Simulates a reversible precommit rejection without changing the normal
/// pending transaction / rollback implementation.
class RejectedPrecommitCoordinator extends MtnMinecraftContentMaterializationFileSystemCoordinator {
  RejectedPrecommitCoordinator({
    required MtnMinecraftContentInstallationManifestFileSystem manifestFileSystem,
  }) : super(manifestFileSystem: manifestFileSystem);

  @override
  Future<void> commit(MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction) async {
    throw StateError('One-shot reversible precommit rejection');
  }
}
