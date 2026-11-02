part of 'minecraft_content_materialization_file_system.dart';

// Persistent, never unlinked: removing a held lock would split ownership
// between processes locking different file identities at the same path.
const String _materializationOsLockFileName = '.mtn-content.lock';
const Duration _materializationOsLockTimeout = Duration(seconds: 30);
const Duration _materializationOsLockPoll = Duration(milliseconds: 50);

Future<void Function()> _acquireMaterializationOsRootLock(
  Directory root,
  MtnMinecraftContentMaterializationFileSystemPolicy policy,
) async {
  await _validateMaterializationOsLockPath(root, policy, mustExist: false);
  // Append opens read/write without truncating an existing file.
  final handle = await File(p.join(root.path, _materializationOsLockFileName)).open(mode: FileMode.append);
  bool locked = false;
  try {
    final watch = Stopwatch()..start();
    while (true) {
      try {
        // Nonblocking attempts keep timeout deterministic. A timed-out
        // blocking lock Future might acquire ownership after its caller exits.
        await handle.lock(FileLock.exclusive);
        locked = true;
        break;
      } on FileSystemException catch (error) {
        if (!_isMaterializationOsLockConflict(error)) rethrow;
        if (watch.elapsed >= _materializationOsLockTimeout) {
          throw TimeoutException('Content Service OS writer ownership timed out.', _materializationOsLockTimeout);
        }
        await Future<void>.delayed(_materializationOsLockPoll);
      }
    }

    await _validateMaterializationOsLockPath(root, policy, mustExist: true);
    final resolvedAgain = Directory(await root.resolveSymbolicLinks());
    if (_materializationRootKeyFor(resolvedAgain, policy) != _materializationRootKeyFor(root, policy)) {
      throw StateError('Installation root changed while acquiring OS ownership.');
    }

    bool released = false;
    return () {
      if (released) return;
      released = true;
      try {
        handle.unlockSync();
      } finally {
        handle.closeSync();
      }
    };
  } catch (_) {
    try {
      if (locked) handle.unlockSync();
    } finally {
      handle.closeSync();
    }
    rethrow;
  }
}

bool _isMaterializationOsLockConflict(FileSystemException error) {
  final code = error.osError?.errorCode;
  // Windows ERROR_LOCK_VIOLATION / ERROR_SHARING_VIOLATION,
  // POSIX EAGAIN / EACCES for nonblocking advisory file locks.
  return Platform.isWindows ? code == 33 || code == 32 : code == 11 || code == 13;
}

Future<void> _validateMaterializationOsLockPath(
  Directory root,
  MtnMinecraftContentMaterializationFileSystemPolicy policy, {
  required bool mustExist,
}) async {
  final aliases = await root.list(followLinks: false).where((entity) {
    final name = p.basename(entity.path);
    return policy.caseSensitive ? name == _materializationOsLockFileName
        : name.toLowerCase() == _materializationOsLockFileName;
  }).toList();
  if (aliases.isEmpty && !mustExist) return;
  if (aliases.length != 1 ||
      p.basename(aliases.single.path) != _materializationOsLockFileName ||
      await FileSystemEntity.type(aliases.single.path, followLinks: false) != FileSystemEntityType.file) {
    throw StateError('Content Service OS lock path is missing, linked, occupied or case-ambiguous.');
  }
  if (await File(aliases.single.path).length() != 0) {
    throw StateError('Content Service OS lock file contains unexpected data.');
  }
}
