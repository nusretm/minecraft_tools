part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemTransactionState {
  pending,
  committed,
  rolledBack,
  commitIncomplete,
  rollbackIncomplete,
}

enum MtnMinecraftContentMaterializationFileSystemTransactionFailure {
  invalidInput,
  stalePreflight,
  applicationFailure,
  commitFailure,
  rollbackFailure,
  recoveryFailure,
}

class MtnMinecraftContentMaterializationFileSystemTransactionSource {
  const MtnMinecraftContentMaterializationFileSystemTransactionSource({
    required this.target,
    required this.source,
  });

  final MtnMinecraftContentMaterializationTarget target;
  final File source;
}

class MtnMinecraftContentMaterializationFileSystemTransactionException implements Exception {
  const MtnMinecraftContentMaterializationFileSystemTransactionException({
    required this.failure,
    required this.message,
    this.cause,
    this.transaction,
    this.recoveryCandidates = const <File>[],
  });

  final MtnMinecraftContentMaterializationFileSystemTransactionFailure failure;
  final String message;
  final Object? cause;
  final MtnMinecraftContentMaterializationFileSystemTransaction? transaction;
  final List<File> recoveryCandidates;

  @override
  String toString() => 'MtnMinecraftContentMaterializationFileSystemTransactionException: $message';
}

class MtnMinecraftContentMaterializationFileSystemTransaction {
  MtnMinecraftContentMaterializationFileSystemTransaction._({
    required this.preflight,
    required List<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources,
    required Object authorityToken,
    required void Function() release,
  }) : sources = List<MtnMinecraftContentMaterializationFileSystemTransactionSource>.unmodifiable(sources),
       _authorityToken = authorityToken,
       _release = release;

  final MtnMinecraftContentMaterializationFileSystemPreflight preflight;
  final List<MtnMinecraftContentMaterializationFileSystemTransactionSource> sources;
  final Object _authorityToken;
  final void Function() _release;
  final List<_MaterializationTransactionStep> _ledger = <_MaterializationTransactionStep>[];
  final List<_MaterializationRetainedSnapshot> _retained = <_MaterializationRetainedSnapshot>[];
  final List<File> _recoveryCandidates = <File>[];
  bool _released = false;

  MtnMinecraftContentMaterializationFileSystemTransactionState _state = MtnMinecraftContentMaterializationFileSystemTransactionState.pending;

  MtnMinecraftContentMaterializationFileSystemTransactionState get state => _state;
  MtnMinecraftContentMaterializationPlan get plan => preflight.plan;
  MtnMinecraftContentInstallationState get resultingInstallationState => plan.resultingInstallationState;
  List<File> get recoveryCandidates => List<File>.unmodifiable(_recoveryCandidates);

  void _releaseOnce() {
    if (_released) {
      return;
    }
    _released = true;
    _release();
  }
}

abstract class _MaterializationTransactionStep {
  bool get finalized;
  Future<void> validate(MtnMinecraftContentMaterializationFileSystem fileSystem);
  Future<void> commit(MtnMinecraftContentMaterializationFileSystem fileSystem);
  Future<void> rollback(MtnMinecraftContentMaterializationFileSystem fileSystem);
}

class _MaterializationTransactionPublication extends _MaterializationTransactionStep {
  _MaterializationTransactionPublication(this.publication);

  final MtnMinecraftContentMaterializationFileSystemPublication publication;

  @override
  bool get finalized => publication.state != MtnMinecraftContentMaterializationFileSystemPublicationState.pending;

  @override
  Future<void> validate(MtnMinecraftContentMaterializationFileSystem fileSystem) async {
    if (finalized) {
      return;
    }
    await fileSystem._assertPublishedTargetStable(publication);
    await fileSystem._assertPublicationBackupStable(publication);
  }

  @override
  Future<void> commit(MtnMinecraftContentMaterializationFileSystem fileSystem) => fileSystem.commit(publication);

  @override
  Future<void> rollback(MtnMinecraftContentMaterializationFileSystem fileSystem) => fileSystem.rollback(publication);
}

class _MaterializationTransactionRemoval extends _MaterializationTransactionStep {
  _MaterializationTransactionRemoval({
    required this.preflight,
    required this.artifact,
    required this.original,
    required this.expectedMissing,
    required this.backup,
    required this.length,
    required this.sha256,
  });

  final MtnMinecraftContentMaterializationFileSystemPreflight preflight;
  final MtnMinecraftContentInstallationArtifact artifact;
  final File original;
  final bool expectedMissing;
  final File? backup;
  final int? length;
  final String? sha256;
  bool _finalized = false;

  @override
  bool get finalized => _finalized;

  @override
  Future<void> validate(MtnMinecraftContentMaterializationFileSystem fileSystem) async {
    if (finalized) {
      return;
    }
    final issues = <MtnMinecraftContentMaterializationFileSystemPreflightIssue>[];
    final observed = await fileSystem._inspectArtifact(
      preflight.resolvedInstallationRoot,
      artifact,
      MtnMinecraftContentMaterializationFileSystemStateScope.current,
      issues,
    );
    if (issues.isNotEmpty ||
        observed.entityType != MtnMinecraftContentMaterializationFileSystemEntityType.missing) {
      throw StateError('Managed removal target was externally recreated or changed: ' + original.path);
    }
    if (expectedMissing) {
      return;
    }
    final retainedBackup = backup;
    if (retainedBackup == null ||
        await FileSystemEntity.type(retainedBackup.path, followLinks: false) != FileSystemEntityType.file ||
        await retainedBackup.length() != length ||
        await MtnMinecraftContentFileIntegrity.calculateSha256(retainedBackup) != sha256) {
      throw StateError('Managed removal recovery backup is missing or changed: ' + original.path);
    }
  }

  @override
  Future<void> commit(MtnMinecraftContentMaterializationFileSystem fileSystem) async {
    if (finalized) {
      return;
    }
    await validate(fileSystem);
    if (backup != null) {
      await backup!.delete();
    }
    _finalized = true;
  }

  @override
  Future<void> rollback(MtnMinecraftContentMaterializationFileSystem fileSystem) async {
    if (finalized) {
      return;
    }
    await validate(fileSystem);
    if (backup != null) {
      await backup!.rename(original.path);
    }
    _finalized = true;
  }
}

class _MaterializationRetainedSnapshot {
  const _MaterializationRetainedSnapshot({
    required this.artifact,
    required this.physicalPath,
    required this.length,
    required this.sha256,
  });

  final MtnMinecraftContentInstallationArtifact artifact;
  final String physicalPath;
  final int length;
  final String sha256;
}
