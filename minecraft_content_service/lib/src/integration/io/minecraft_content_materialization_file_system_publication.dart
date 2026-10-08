part of 'minecraft_content_materialization_file_system.dart';

enum MtnMinecraftContentMaterializationFileSystemPublicationState {
  pending,
  committed,
  rolledBack,
}

enum MtnMinecraftContentMaterializationFileSystemPublicationFailure {
  sourceNotRegularFile,
  sourceAliasesTarget,
  sourceChangedDuringCopy,
  stalePreflight,
  integrityFailure,
  fileSystemFailure,
  recoveryFailure,
}

class MtnMinecraftContentMaterializationFileSystemPublicationException implements Exception {
  const MtnMinecraftContentMaterializationFileSystemPublicationException({
    required this.failure,
    required this.message,
    this.cause,
    this.backup,
    this.staging,
  });

  final MtnMinecraftContentMaterializationFileSystemPublicationFailure failure;
  final String message;
  final Object? cause;
  final File? backup;
  final File? staging;

  @override
  String toString() => 'MtnMinecraftContentMaterializationFileSystemPublicationException: $message';
}

class MtnMinecraftContentMaterializationFileSystemPublication {
  MtnMinecraftContentMaterializationFileSystemPublication._({
    required this.preflight,
    required this.materializationTarget,
    required this.source,
    required this.target,
    required this.previousTargetExisted,
    required this.previousPhysicalPath,
    required this.previousLength,
    required this.previousSha256,
    required this.publishedLength,
    required this.publishedSha256,
    required this.backup,
    required List<Directory> createdDirectories,
    required Object authorityToken,
    required void Function() release,
  }) : createdDirectories = List<Directory>.unmodifiable(createdDirectories),
       _authorityToken = authorityToken,
       _release = release;

  final MtnMinecraftContentMaterializationFileSystemPreflight preflight;
  final MtnMinecraftContentMaterializationTarget materializationTarget;
  final File source;
  final File target;
  final bool previousTargetExisted;
  final String? previousPhysicalPath;
  final int? previousLength;
  final String? previousSha256;
  final int publishedLength;
  final String? publishedSha256;
  final File? backup;
  final List<Directory> createdDirectories;
  final Object _authorityToken;
  final void Function() _release;

  MtnMinecraftContentMaterializationFileSystemPublicationState _state = MtnMinecraftContentMaterializationFileSystemPublicationState.pending;
  bool _released = false;

  MtnMinecraftContentMaterializationFileSystemPublicationState get state => _state;

  void _releaseOnce() {
    if (_released) {
      return;
    }
    _released = true;
    _release();
  }
}
