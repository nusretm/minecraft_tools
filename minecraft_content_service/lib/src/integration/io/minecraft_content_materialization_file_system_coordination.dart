part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState {
  pending,
  committed,
  rolledBack,
  commitIncomplete,
  rollbackIncomplete,
}

enum MtnMinecraftContentMaterializationFileSystemCoordinationFailure {
  applicationFailure,
  commitFailure,
  rollbackFailure,
  recoveryFailure,
}

class MtnMinecraftContentMaterializationFileSystemCoordinationException implements Exception {
  const MtnMinecraftContentMaterializationFileSystemCoordinationException({
    required this.failure,
    required this.message,
    this.cause,
    this.transaction,
    this.recoveryCandidates = const <File>[],
  });

  final MtnMinecraftContentMaterializationFileSystemCoordinationFailure failure;
  final String message;
  final Object? cause;
  final MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction? transaction;
  final List<File> recoveryCandidates;

  @override
  String toString() => 'MtnMinecraftContentMaterializationFileSystemCoordinationException: $message';
}

class MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction {
  MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction._({
    required this.preflight,
    required MtnMinecraftContentMaterializationFileSystemTransaction materialization,
    required MtnMinecraftContentInstallationManifestFileSystemPublication? manifestPublication,
    required MtnMinecraftContentMaterializationFileSystemCoordinator authority,
    required _MaterializationCoordinatedRootLease lease,
    List<File> recoveryCandidates = const <File>[],
  }) : _materialization = materialization,
       _manifestPublication = manifestPublication,
       _authority = authority,
       _lease = lease,
       _recoveryCandidates = List<File>.unmodifiable(recoveryCandidates);

  final MtnMinecraftContentMaterializationFileSystemPreflight preflight;
  final MtnMinecraftContentMaterializationFileSystemTransaction _materialization;
  final MtnMinecraftContentInstallationManifestFileSystemPublication? _manifestPublication;

  final MtnMinecraftContentMaterializationFileSystemCoordinator _authority;
  final _MaterializationCoordinatedRootLease _lease;
  final List<File> _recoveryCandidates;
  bool _finalizing = false;

  MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState _state =
      MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending;

  MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState get state => _state;
  MtnMinecraftContentInstallationState get resultingInstallationState => preflight.plan.resultingInstallationState;

  List<File> get recoveryCandidates => List<File>.unmodifiable(<File>[
    ..._recoveryCandidates,
    ..._materialization.recoveryCandidates,
  ]);
}

class MtnMinecraftContentMaterializationFileSystemCoordinator {
  MtnMinecraftContentMaterializationFileSystemCoordinator({
    MtnMinecraftContentMaterializationFileSystemPolicy? policy,
    MtnMinecraftContentInstallationManifestFileSystem? manifestFileSystem,
  }) : policy = policy ?? manifestFileSystem?.policy ?? MtnMinecraftContentMaterializationFileSystemPolicy.host() {
    if (manifestFileSystem != null &&
        (manifestFileSystem.policy.platform != this.policy.platform ||
         manifestFileSystem.policy.caseSensitive != this.policy.caseSensitive)) {
      throw ArgumentError.value(manifestFileSystem, 'manifestFileSystem', 'The injected manifest filesystem must use the coordinator policy.');
    }
    _materialization = MtnMinecraftContentMaterializationFileSystem(policy: this.policy);
    _manifest = manifestFileSystem ?? MtnMinecraftContentInstallationManifestFileSystem(policy: this.policy);
  }

  final MtnMinecraftContentMaterializationFileSystemPolicy policy;
  late final MtnMinecraftContentMaterializationFileSystem _materialization;
  late final MtnMinecraftContentInstallationManifestFileSystem _manifest;

  Future<MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction> begin({
    required MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    required Iterable<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources,
  }) async {
    if (!preflight.safe ||
        preflight.policy.platform != policy.platform ||
        preflight.policy.caseSensitive != policy.caseSensitive) {
      throw StateError('Coordinated transaction requires a safe preflight with the coordinator filesystem policy.');
    }

    final root = await _manifest._resolveRoot(preflight.installationRoot);
    if (_materializationRootKeyFor(root, policy) != _materializationRootKeyFor(preflight.resolvedInstallationRoot, policy)) {
      throw StateError('Installation root changed after coordinated preflight.');
    }
    final lease = await _acquireMaterializationCoordinatedRootLease(root, policy);
    MtnMinecraftContentMaterializationFileSystemTransaction? materialization;
    MtnMinecraftContentInstallationManifestFileSystemPublication? manifestPublication;
    List<File> manualRecovery = const <File>[];

    try {
      await _manifest._assertRootStable(preflight.installationRoot, root);
      final current = await _manifest._readSnapshotWithinCoordinator(
        installationRoot: preflight.installationRoot,
        lease: lease,
      );

      final persisted = current.manifest;
      if (persisted == null) {
        if (preflight.plan.installation.artifacts.isNotEmpty) {
          throw StateError('A missing manifest cannot authorize a nonempty managed installation state.');
        }
      } else {
        final intended = MtnMinecraftContentInstallationManifest.fromInstallationState(preflight.plan.installation);
        if (persisted.toJson() != intended.toJson()) {
          throw StateError('Installation plan does not match the persisted current manifest state.');
        }
      }

      materialization = await _materialization._beginTransactionWithinCoordinator(
        preflight: preflight,
        sources: sources,
        lease: lease,
      );

      await _manifest._assertSnapshotWithinCoordinator(
        installationRoot: preflight.installationRoot,
        lease: lease,
        expected: current,
      );

      manifestPublication = await _manifest._publishWithinCoordinator(
        installationRoot: preflight.installationRoot,
        manifest: MtnMinecraftContentInstallationManifest.fromInstallationState(preflight.plan.resultingInstallationState),
        lease: lease,
        expected: current,
      );

      return MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction._(
        preflight: preflight,
        materialization: materialization,
        manifestPublication: manifestPublication,
        authority: this,
        lease: lease,
      );
    } catch (error) {
      if (error is MtnMinecraftContentMaterializationFileSystemTransactionException) {
        materialization ??= error.transaction;
        manualRecovery = error.recoveryCandidates;
      }
      if (error is MtnMinecraftContentInstallationManifestFileSystemException) {
        manualRecovery = <File>[...manualRecovery, ...error.recoveryCandidates];
      }

      Object? rollbackFailure;
      if (materialization != null &&
          materialization.state != MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack) {
        try {
          await _materialization.rollbackTransaction(materialization);
        } catch (caught) {
          rollbackFailure = caught;
        }
      }

      final recoverable = materialization != null &&
          (materialization.state != MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack ||
           manualRecovery.isNotEmpty);

      if (!recoverable && manualRecovery.isEmpty) {
        lease.release();
        throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
          failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.applicationFailure,
          message: 'Coordinated application failed; previous managed and manifest state was preserved.',
          cause: error,
        );
      }

      final incomplete = materialization == null ? null : MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction._(
        preflight: preflight,
        materialization: materialization,
        manifestPublication: manifestPublication,
        authority: this,
        lease: lease,
        recoveryCandidates: manualRecovery,
      );
      if (incomplete != null) {
        incomplete._state = MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete;
      }
      throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
        failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.recoveryFailure,
        message: 'Coordinated application failed and safe recovery was not confirmed; the root lease remains held.',
        cause: rollbackFailure ?? error,
        transaction: incomplete,
        recoveryCandidates: manualRecovery,
      );
    }
  }

  Future<void> commit(
    MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction,
  ) async {
    _assertOwner(transaction);
    if (transaction._finalizing) throw StateError('Coordinated finalization is already in progress.');
    transaction._finalizing = true;
    try {
      if (transaction.state == MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed) return;
      if (transaction.state != MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending &&
          transaction.state != MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.commitIncomplete) {
        throw StateError('Coordinated commit is unavailable after rollback or interrupted rollback.');
      }
      transaction._lease.assertOwns(transaction.preflight.resolvedInstallationRoot, policy);
      final manifestPublication = transaction._manifestPublication;
      if (manifestPublication == null || transaction.recoveryCandidates.isNotEmpty) {
        throw StateError('Coordinated transaction has unresolved recovery candidates.');
      }

      // The first cleanup is irreversible: validate BOTH sets before crossing that boundary.
      if (transaction.state == MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending) {
        try {
          await _materialization._validateTransactionRecovery(transaction._materialization);
          await _manifest._validatePublished(manifestPublication);
          await _manifest._validateBackup(manifestPublication);
        } catch (error) {
          throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
            failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.commitFailure,
            message: 'Coordinated precommit validation failed; no backup was discarded.',
            cause: error,
            transaction: transaction,
          );
        }
      }

      transaction._state = MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.commitIncomplete;
      try {
        await _materialization.commitTransaction(transaction._materialization);
        await _manifest.commit(manifestPublication);
      } catch (error) {
        throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
          failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.commitFailure,
          message: 'Coordinated cleanup was interrupted; only commit retry is permitted.',
          cause: error,
          transaction: transaction,
        );
      }

      transaction._state = MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.committed;
      transaction._lease.release();
    } finally {
      transaction._finalizing = false;
    }
  }

  Future<void> rollback(
    MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction,
  ) async {
    _assertOwner(transaction);
    if (transaction._finalizing) throw StateError('Coordinated finalization is already in progress.');
    transaction._finalizing = true;
    try {
      if (transaction.state == MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack) return;
      if (transaction.state != MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.pending &&
          transaction.state != MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete) {
        throw StateError('Coordinated rollback is unavailable after commit or commit cleanup.');
      }
      transaction._lease.assertOwns(transaction.preflight.resolvedInstallationRoot, policy);
      if (transaction._recoveryCandidates.isNotEmpty) {
        throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
          failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.recoveryFailure,
          message: 'Unowned manifest recovery candidates require manual intervention before rollback.',
          transaction: transaction,
          recoveryCandidates: transaction.recoveryCandidates,
        );
      }

      transaction._state = MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rollbackIncomplete;
      Object? firstFailure;
      final publication = transaction._manifestPublication;
      if (publication != null) {
        try {
          await _manifest.rollback(publication);
        } catch (error) {
          firstFailure ??= error;
        }
      }
      try {
        await _materialization.rollbackTransaction(transaction._materialization);
      } catch (error) {
        firstFailure ??= error;
      }

      if (firstFailure != null) {
        throw MtnMinecraftContentMaterializationFileSystemCoordinationException(
          failure: MtnMinecraftContentMaterializationFileSystemCoordinationFailure.rollbackFailure,
          message: 'Coordinated rollback is incomplete; the root lease is retained for retry.',
          cause: firstFailure,
          transaction: transaction,
          recoveryCandidates: transaction.recoveryCandidates,
        );
      }

      transaction._state = MtnMinecraftContentMaterializationFileSystemCoordinatedTransactionState.rolledBack;
      transaction._lease.release();
    } finally {
      transaction._finalizing = false;
    }
  }

  void _assertOwner(MtnMinecraftContentMaterializationFileSystemCoordinatedTransaction transaction) {
    if (!identical(transaction._authority, this)) {
      throw ArgumentError.value(transaction, 'transaction', 'Coordinated transaction belongs to another coordinator.');
    }
  }
}
