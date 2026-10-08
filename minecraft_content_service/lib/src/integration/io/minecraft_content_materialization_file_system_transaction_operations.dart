part of 'minecraft_content_materialization_file_system.dart';

extension MtnMinecraftContentMaterializationFileSystemTransactionOperations on MtnMinecraftContentMaterializationFileSystem {
  Future<MtnMinecraftContentMaterializationFileSystemTransaction> beginTransaction({
    required MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    required Iterable<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources,
  }) async {
    if (!preflight.safe) {
      throw StateError('Whole-plan transaction requires safe filesystem preflight.');
    }
    if (preflight.policy.platform != policy.platform || preflight.policy.caseSensitive != policy.caseSensitive) {
      throw ArgumentError.value(preflight, 'preflight', 'Whole-plan transaction requires the same filesystem policy.');
    }

    final sourceList = List<MtnMinecraftContentMaterializationFileSystemTransactionSource>.unmodifiable(sources);
    final expectedTargets = <MtnMinecraftContentMaterializationTarget>[
      ...preflight.plan.installs.map((action) => action.target),
      ...preflight.plan.replacements.map((action) => action.target),
    ];
    final canonicalTargets = expectedTargets.toSet();
    final seen = <MtnMinecraftContentMaterializationTarget>{};

    if (sourceList.length != expectedTargets.length) {
      throw ArgumentError.value(sourceList, 'sources', 'Every canonical publication target requires exactly one source.');
    }
    for (final entry in sourceList) {
      if (!canonicalTargets.contains(entry.target) || !seen.add(entry.target)) {
        throw ArgumentError.value(entry, 'sources', 'Source mappings must be unique canonical plan targets.');
      }
    }

    final sortedSources = sourceList.toList()
      ..sort((a, b) {
        final first = _pathIdentity(a.target.relativePath);
        final second = _pathIdentity(b.target.relativePath);
        return first.compareTo(second);
      });

    final release = await _acquireMaterializationRoot(preflight, exclusive: true);
    final transaction = MtnMinecraftContentMaterializationFileSystemTransaction._(
      preflight: preflight,
      sources: sortedSources,
      authorityToken: _publicationAuthorityToken(this),
      release: release,
    );
    try {
      await _assertInstallationRootStable(preflight);
      final refreshed = await this.preflight(plan: preflight.plan, installationRoot: preflight.installationRoot);
      if (!refreshed.safe || !_sameTransactionPreflight(preflight, refreshed)) {
        throw StateError('Whole-plan preflight became stale before transaction mutation.');
      }

      final ownedPaths = <String>{
        ...preflight.currentArtifacts.map((entry) => _absolutePathIdentity(entry.physicalPath)),
        ...preflight.resultingArtifacts.map((entry) => _absolutePathIdentity(entry.physicalPath)),
      };
      for (final entry in sortedSources) {
        if (await FileSystemEntity.type(entry.source.path, followLinks: false) != FileSystemEntityType.file) {
          throw ArgumentError.value(entry.source.path, 'sources', 'Transaction sources must be regular files.');
        }
        final resolvedSource = await entry.source.resolveSymbolicLinks();
        if (ownedPaths.contains(_absolutePathIdentity(resolvedSource))) {
          throw ArgumentError.value(entry.source.path, 'sources', 'Caller-owned source aliases a managed transaction path.');
        }
      }

      for (final retained in preflight.plan.retains) {
        final state = preflight.currentArtifacts.singleWhere((entry) => identical(entry.artifact, retained.artifact));
        if (state.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
          throw StateError('Retained artifact was not a regular file at preflight.');
        }
        final file = File(state.physicalPath);
        final length = await file.length();
        final sha256 = await MtnMinecraftContentFileIntegrity.calculateSha256(file);
        final integrity = MtnMinecraftContentFileIntegrity.fromFile(retained.artifact.file);
        if (integrity != null) {
          await integrity.validate(file, subject: 'Retained artifact');
        }
        transaction._retained.add(
          _MaterializationRetainedSnapshot(
            artifact: retained.artifact,
            physicalPath: state.physicalPath,
            length: length,
            sha256: sha256,
          ),
        );
      }

      for (final entry in sortedSources) {
        final publication = await publish(
          preflight: preflight,
          target: entry.target,
          source: entry.source,
          _withinTransaction: true,
        );
        transaction._ledger.add(_MaterializationTransactionPublication(publication));
      }

      final resultingPaths = <String>{
        for (final state in preflight.resultingArtifacts) _pathIdentity(state.artifact.relativePath),
      };
      final obsolete = preflight.currentArtifacts.where(
        (entry) => !resultingPaths.contains(_pathIdentity(entry.artifact.relativePath)),
      ).toList()
        ..sort((a, b) => _pathIdentity(a.artifact.relativePath).compareTo(_pathIdentity(b.artifact.relativePath)));

      for (final state in obsolete) {
        transaction._ledger.add(await _stageTransactionRemoval(preflight, state));
      }

      await _assertTransactionRetainsStable(transaction);
      return transaction;
    } catch (error) {
      if (error is MtnMinecraftContentMaterializationFileSystemPublicationException &&
          error.failure == MtnMinecraftContentMaterializationFileSystemPublicationFailure.recoveryFailure) {
        if (error.backup != null) {
          transaction._recoveryCandidates.add(error.backup!);
        }
        if (error.staging != null) {
          transaction._recoveryCandidates.add(error.staging!);
        }
      }
      if (error is MtnMinecraftContentMaterializationFileSystemTransactionException) {
        transaction._recoveryCandidates.addAll(error.recoveryCandidates);
      }
      try {
        await rollbackTransaction(transaction);
      } catch (rollbackError) {
        throw MtnMinecraftContentMaterializationFileSystemTransactionException(
          failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.recoveryFailure,
          message: 'Transaction application failed and full restoration could not be confirmed.',
          cause: error,
          transaction: transaction,
          recoveryCandidates: transaction.recoveryCandidates,
        );
      }
      throw MtnMinecraftContentMaterializationFileSystemTransactionException(
        failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.applicationFailure,
        message: 'Transaction application failed; all applied operations were rolled back.',
        cause: error,
        transaction: transaction,
      );
    }
  }

  Future<void> commitTransaction(
    MtnMinecraftContentMaterializationFileSystemTransaction transaction,
  ) async {
    _validateTransactionOwner(transaction);
    if (transaction.state == MtnMinecraftContentMaterializationFileSystemTransactionState.committed) {
      return;
    }
    if (transaction.state != MtnMinecraftContentMaterializationFileSystemTransactionState.pending &&
        transaction.state != MtnMinecraftContentMaterializationFileSystemTransactionState.commitIncomplete) {
      throw StateError('Transaction cannot be committed after rollback or recovery failure.');
    }

    try {
      await _assertInstallationRootStable(transaction.preflight);
      await _assertTransactionRetainsStable(transaction);
      for (final step in transaction._ledger) {
        if (!step.finalized) {
          await step.validate(this);
        }
      }
    } catch (error) {
      throw MtnMinecraftContentMaterializationFileSystemTransactionException(
        failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.commitFailure,
        message: 'Transaction commit prevalidation failed; recovery state was retained.',
        cause: error,
        transaction: transaction,
      );
    }

    transaction._state = MtnMinecraftContentMaterializationFileSystemTransactionState.commitIncomplete;
    try {
      for (final step in transaction._ledger.reversed) {
        if (!step.finalized) {
          await step.commit(this);
        }
      }
    } catch (error) {
      throw MtnMinecraftContentMaterializationFileSystemTransactionException(
        failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.commitFailure,
        message: 'Commit cleanup was interrupted; rollback is no longer permitted. Retry commit.',
        cause: error,
        transaction: transaction,
      );
    }
    transaction._state = MtnMinecraftContentMaterializationFileSystemTransactionState.committed;
    transaction._releaseOnce();
  }

  Future<void> rollbackTransaction(
    MtnMinecraftContentMaterializationFileSystemTransaction transaction,
  ) async {
    _validateTransactionOwner(transaction);
    if (transaction.state == MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack) {
      return;
    }
    if (transaction.state != MtnMinecraftContentMaterializationFileSystemTransactionState.pending &&
        transaction.state != MtnMinecraftContentMaterializationFileSystemTransactionState.rollbackIncomplete) {
      throw StateError('Transaction cannot be rolled back after commit or commit cleanup.');
    }

    try {
      await _assertInstallationRootStable(transaction.preflight);
      await _assertTransactionRetainsStable(transaction);
      for (final step in transaction._ledger.reversed) {
        if (!step.finalized) {
          await step.validate(this);
        }
      }
    } catch (error) {
      throw MtnMinecraftContentMaterializationFileSystemTransactionException(
        failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.rollbackFailure,
        message: 'Rollback prevalidation failed; no additional recovery files were mutated.',
        cause: error,
        transaction: transaction,
        recoveryCandidates: transaction.recoveryCandidates,
      );
    }

    transaction._state = MtnMinecraftContentMaterializationFileSystemTransactionState.rollbackIncomplete;
    Object? firstFailure;
    for (final step in transaction._ledger.reversed) {
      if (step.finalized) {
        continue;
      }
      try {
        await step.rollback(this);
      } catch (error) {
        firstFailure ??= error;
      }
    }

    if (firstFailure != null || transaction._recoveryCandidates.isNotEmpty) {
      throw MtnMinecraftContentMaterializationFileSystemTransactionException(
        failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.recoveryFailure,
        message: 'Transaction rollback was incomplete; recovery state was retained.',
        cause: firstFailure,
        transaction: transaction,
        recoveryCandidates: transaction.recoveryCandidates,
      );
    }

    transaction._state = MtnMinecraftContentMaterializationFileSystemTransactionState.rolledBack;
    transaction._releaseOnce();
  }

  bool _sameTransactionPreflight(
    MtnMinecraftContentMaterializationFileSystemPreflight expected,
    MtnMinecraftContentMaterializationFileSystemPreflight observed,
  ) {
    if (expected.currentArtifacts.length != observed.currentArtifacts.length ||
        expected.resultingArtifacts.length != observed.resultingArtifacts.length) {
      return false;
    }
    bool equal(
      List<MtnMinecraftContentMaterializationFileSystemArtifactState> first,
      List<MtnMinecraftContentMaterializationFileSystemArtifactState> second,
    ) {
      for (var i = 0; i < first.length; i++) {
        if (!identical(first[i].artifact, second[i].artifact) ||
            first[i].entityType != second[i].entityType ||
            _absolutePathIdentity(first[i].physicalPath) != _absolutePathIdentity(second[i].physicalPath)) {
          return false;
        }
      }
      return true;
    }
    return equal(expected.currentArtifacts, observed.currentArtifacts) &&
        equal(expected.resultingArtifacts, observed.resultingArtifacts);
  }

  Future<void> _assertTransactionRetainsStable(
    MtnMinecraftContentMaterializationFileSystemTransaction transaction,
  ) async {
    for (final snapshot in transaction._retained) {
      final issues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];
      final current = await _inspectArtifact(
        transaction.preflight.resolvedInstallationRoot,
        snapshot.artifact,
        MtnMinecraftContentMaterializationFileSystemStateScope.current,
        issues,
      );
      if (issues.isNotEmpty ||
          current.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file ||
          _absolutePathIdentity(current.physicalPath) != _absolutePathIdentity(snapshot.physicalPath)) {
        throw StateError('Retained artifact path changed: ' + snapshot.artifact.relativePath);
      }
      final file = File(current.physicalPath);
      if (await file.length() != snapshot.length ||
          await MtnMinecraftContentFileIntegrity.calculateSha256(file) != snapshot.sha256) {
        throw StateError('Retained artifact contents changed: ' + snapshot.artifact.relativePath);
      }
    }
  }

  Future<_MaterializationTransactionRemoval> _stageTransactionRemoval(
    MtnMinecraftContentMaterializationFileSystemPreflight preflight,
    MtnMinecraftContentMaterializationFileSystemArtifactState expected,
  ) async {
    await _assertInstallationRootStable(preflight);
    final issues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];
    final observed = await _inspectArtifact(
      preflight.resolvedInstallationRoot,
      expected.artifact,
      MtnMinecraftContentMaterializationFileSystemStateScope.current,
      issues,
    );
    if (issues.isNotEmpty ||
        observed.entityType != expected.entityType ||
        _absolutePathIdentity(observed.physicalPath) != _absolutePathIdentity(expected.physicalPath)) {
      throw StateError('Managed removal state changed after preflight: ' + expected.artifact.relativePath);
    }
    if (observed.entityType == MtnMinecraftContentMaterializationFileSystemEntityType.missing) {
      return _MaterializationTransactionRemoval(
        original: File(observed.physicalPath),
        expectedMissing: true,
        backup: null,
        length: null,
        sha256: null,
      );
    }
    if (observed.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.file) {
      throw StateError('Only managed regular files may be removed.');
    }

    final original = File(observed.physicalPath);
    final length = await original.length();
    final sha256 = await MtnMinecraftContentFileIntegrity.calculateSha256(original);
    final backup = await _reservePublicationSibling(original, 'removal');
    try {
      await backup.delete();
      if (await FileSystemEntity.type(original.path, followLinks: false) != FileSystemEntityType.file ||
          await original.length() != length ||
          await MtnMinecraftContentFileIntegrity.calculateSha256(original) != sha256) {
        throw StateError('Managed removal source changed before reversible rename.');
      }
      await original.rename(backup.path);
    } catch (_) {
      await _deletePublicationFileBestEffort(backup);
      rethrow;
    }

    if (await backup.length() != length ||
        await MtnMinecraftContentFileIntegrity.calculateSha256(backup) != sha256) {
      try {
        await backup.rename(original.path);
      } catch (error) {
        throw MtnMinecraftContentMaterializationFileSystemTransactionException(
          failure: MtnMinecraftContentMaterializationFileSystemTransactionFailure.recoveryFailure,
          message: 'Managed removal backup verification and restoration failed.',
          cause: error,
          recoveryCandidates: <File>[backup],
        );
      }
      throw StateError('Managed removal backup changed during rename; original was restored.');
    }
    return _MaterializationTransactionRemoval(
      original: original,
      expectedMissing: false,
      backup: backup,
      length: length,
      sha256: sha256,
    );
  }

  void _validateTransactionOwner(
    MtnMinecraftContentMaterializationFileSystemTransaction transaction,
  ) {
    if (!identical(transaction._authorityToken, _publicationAuthorityToken(this))) {
      throw ArgumentError.value(transaction, 'transaction', 'Transaction belongs to another filesystem authority.');
    }
  }
}
