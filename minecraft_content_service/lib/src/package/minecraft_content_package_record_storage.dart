import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'minecraft_content_package_record.dart';
import 'minecraft_content_package_record_codec.dart';

/// Filesystem persistence for AES-GCM encrypted records, with no key provider.
///
/// Layout: directory/<canonical-uuid>/000000000001.mtncr and later generations.
/// A new generation is staged and flushed under a temporary name and renamed
/// to a previously unused name. Older completed generations are preserved.
/// Interrupted temporary files are ignored on reads.
///
/// Concurrent writes through the same instance are serialized per record ID.
/// Multi-process writers, external filesystem mutation and power-loss durability
/// beyond the platform's flush/rename guarantees are not supported.
class MtnMinecraftContentPackageRecordStorage {
  MtnMinecraftContentPackageRecordStorage({
    required this.directory,
    MtnMinecraftContentPackageRecordCodec? codec,
  }) : codec = codec ?? MtnMinecraftContentPackageRecordCodec();

  final Directory directory;
  final MtnMinecraftContentPackageRecordCodec codec;

  static final RegExp _idPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  static final RegExp _generationPattern = RegExp(r'^[0-9]{12}\.mtncr
  final Map<String, Future<void>> _writeTails = <String, Future<void>>{};

  Future<void> save(
    String recordId,
    MtnMinecraftContentPackageRecord record, {
    required Uint8List key,
    required String keyId,
  }) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final payload = await codec.encrypt(record, key: key, keyId: keyId);
      final target = await _recordDirectory(recordId, create: true);
      final existing = await _completedGenerations(target!);
      final last = existing.isEmpty ? 0 : existing.last.$1;
      if (last == 999999999999) throw StateError('Encrypted record generation limit reached.');
      final nextName = '${(last + 1).toString().padLeft(12, '0')}.mtncr';
      final published = File(p.join(target.path, nextName));
      if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
        throw StateError('The next encrypted record generation already exists.');
      }

      final nonce = Random.secure();
      final suffix = List<int>.generate(16, (_) => nonce.nextInt(256)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final staging = File(p.join(target.path, '.$nextName.$suffix.tmp'));
      try {
        if (await FileSystemEntity.type(staging.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Temporary record path already exists.');
        }
        await staging.writeAsBytes(payload, flush: true);
        if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Record was concurrently published by another writer.');
        }
        await staging.rename(published.path);
      } finally {
        if (await FileSystemEntity.type(staging.path, followLinks: false) == FileSystemEntityType.file) {
          await staging.delete();
        }
      }
    });
  }

  Future<MtnMinecraftContentPackageRecord?> load(
    String recordId, {
    required Uint8List key,
  }) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    final payload = await file.readAsBytes();
    return codec.decrypt(payload, key: key);
  }

  /// Parses the unauthenticated key ID of the newest completed generation.
  /// Its integrity is established only after authenticated load() succeeds.
  Future<String?> getKeyId(String recordId) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    return codec.readKeyId(await file.readAsBytes());
  }

  /// Returns canonical UUIDs with at least one completed generation.
  Future<List<String>> listRecordIds() async {
    final root = await _rootDirectory();
    if (root == null) return const <String>[];
    final ids = <String>[];
    await for (final entry in root.list(followLinks: false)) {
      final id = p.basename(entry.path);
      if (!_idPattern.hasMatch(id)) continue;
      if (entry is! Directory) throw FileSystemException('Record identity points to a non-directory.', entry.path);
      if ((await _completedGenerations(entry)).isNotEmpty) ids.add(id);
    }
    ids.sort();
    return List<String>.unmodifiable(ids);
  }

  Future<bool> delete(String recordId) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final target = await _recordDirectory(recordId);
      if (target == null) return false;

      // Delete only known record generations and staging files, never unknown
      // files or directories accidentally placed alongside them.
      final files = <File>[];
      await for (final entry in target.list(followLinks: false)) {
        final name = p.basename(entry.path);
        final staging = _stagingPattern.hasMatch(name);
        if (entry is! File || (!_generationPattern.hasMatch(name) && !staging)) {
          throw FileSystemException('Record directory contains an unexpected entry; refusing recursive deletion.', entry.path);
        }
        files.add(entry);
      }
      for (final file in files) {
        await file.delete();
      }
      await target.delete(recursive: false);
      return true;
    });
  }

  Future<File?> _latestFile(String recordId) async {
    final target = await _recordDirectory(recordId);
    if (target == null) return null;
    final generations = await _completedGenerations(target);
    return generations.isEmpty ? null : generations.last.$2;
  }

  Future<List<(int, File)>> _completedGenerations(Directory target) async {
    final results = <(int, File)>[];
    await for (final entry in target.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (!_generationPattern.hasMatch(name)) continue;
      if (entry is! File) throw FileSystemException('Encrypted generation is not a regular file.', entry.path);
      final generation = int.parse(name.substring(0, 12));
      if (generation == 0) throw FileSystemException('Invalid zero record generation.', entry.path);
      results.add((generation, entry));
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results;
  }

  Future<Directory?> _rootDirectory({bool create = false}) async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await directory.create(recursive: true);
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record storage root must be a real directory, not a file or link.', directory.path);
    return directory;
  }

  Future<Directory?> _recordDirectory(String recordId, {bool create = false}) async {
    final root = await _rootDirectory(create: create);
    if (root == null) return null;
    final target = Directory(p.join(root.path, recordId));
    var type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await target.create();
      type = await FileSystemEntity.type(target.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record identity must point to a real directory, not a file or link.', target.path);
    return target;
  }

  void _checkId(String id) {
    if (!_idPattern.hasMatch(id)) throw ArgumentError.value(id, 'recordId', 'Record ID must be a canonical lowercase UUID.');
  }

  Future<T> _exclusive<T>(String recordId, Future<T> Function() action) async {
    final previous = _writeTails[recordId];
    final ready = Completer<void>();
    final tail = ready.future;
    _writeTails[recordId] = tail;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      if (identical(_writeTails[recordId], tail)) _writeTails.remove(recordId);
      ready.complete();
    }
  }
}
);
  static final RegExp _stagingPattern = RegExp(r'^\.[0-9]{12}\.mtncr\.[a-f0-9]{32}\.tmp
  final Map<String, Future<void>> _writeTails = <String, Future<void>>{};

  Future<void> save(
    String recordId,
    MtnMinecraftContentPackageRecord record, {
    required Uint8List key,
    required String keyId,
  }) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final payload = await codec.encrypt(record, key: key, keyId: keyId);
      final target = await _recordDirectory(recordId, create: true);
      final existing = await _completedGenerations(target!);
      final last = existing.isEmpty ? 0 : existing.last.$1;
      if (last == 999999999999) throw StateError('Encrypted record generation limit reached.');
      final nextName = '${(last + 1).toString().padLeft(12, '0')}.mtncr';
      final published = File(p.join(target.path, nextName));
      if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
        throw StateError('The next encrypted record generation already exists.');
      }

      final nonce = Random.secure();
      final suffix = List<int>.generate(16, (_) => nonce.nextInt(256)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final staging = File(p.join(target.path, '.$nextName.$suffix.tmp'));
      try {
        if (await FileSystemEntity.type(staging.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Temporary record path already exists.');
        }
        await staging.writeAsBytes(payload, flush: true);
        if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Record was concurrently published by another writer.');
        }
        await staging.rename(published.path);
      } finally {
        if (await FileSystemEntity.type(staging.path, followLinks: false) == FileSystemEntityType.file) {
          await staging.delete();
        }
      }
    });
  }

  Future<MtnMinecraftContentPackageRecord?> load(
    String recordId, {
    required Uint8List key,
  }) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    final payload = await file.readAsBytes();
    return codec.decrypt(payload, key: key);
  }

  /// Parses the unauthenticated key ID of the newest completed generation.
  /// Its integrity is established only after authenticated load() succeeds.
  Future<String?> getKeyId(String recordId) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    return codec.readKeyId(await file.readAsBytes());
  }

  /// Returns canonical UUIDs with at least one completed generation.
  Future<List<String>> listRecordIds() async {
    final root = await _rootDirectory();
    if (root == null) return const <String>[];
    final ids = <String>[];
    await for (final entry in root.list(followLinks: false)) {
      final id = p.basename(entry.path);
      if (!_idPattern.hasMatch(id)) continue;
      if (entry is! Directory) throw FileSystemException('Record identity points to a non-directory.', entry.path);
      if ((await _completedGenerations(entry)).isNotEmpty) ids.add(id);
    }
    ids.sort();
    return List<String>.unmodifiable(ids);
  }

  Future<bool> delete(String recordId) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final target = await _recordDirectory(recordId);
      if (target == null) return false;

      // Delete only known record generations and staging files, never unknown
      // files or directories accidentally placed alongside them.
      final files = <File>[];
      await for (final entry in target.list(followLinks: false)) {
        final name = p.basename(entry.path);
        final staging = name.startsWith('.') && name.endsWith('.tmp');
        if (entry is! File || (!_generationPattern.hasMatch(name) && !staging)) {
          throw FileSystemException('Record directory contains an unexpected entry; refusing recursive deletion.', entry.path);
        }
        files.add(entry);
      }
      for (final file in files) {
        await file.delete();
      }
      await target.delete(recursive: false);
      return true;
    });
  }

  Future<File?> _latestFile(String recordId) async {
    final target = await _recordDirectory(recordId);
    if (target == null) return null;
    final generations = await _completedGenerations(target);
    return generations.isEmpty ? null : generations.last.$2;
  }

  Future<List<(int, File)>> _completedGenerations(Directory target) async {
    final results = <(int, File)>[];
    await for (final entry in target.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (!_generationPattern.hasMatch(name)) continue;
      if (entry is! File) throw FileSystemException('Encrypted generation is not a regular file.', entry.path);
      final generation = int.parse(name.substring(0, 12));
      if (generation == 0) throw FileSystemException('Invalid zero record generation.', entry.path);
      results.add((generation, entry));
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results;
  }

  Future<Directory?> _rootDirectory({bool create = false}) async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await directory.create(recursive: true);
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record storage root must be a real directory, not a file or link.', directory.path);
    return directory;
  }

  Future<Directory?> _recordDirectory(String recordId, {bool create = false}) async {
    final root = await _rootDirectory(create: create);
    if (root == null) return null;
    final target = Directory(p.join(root.path, recordId));
    var type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await target.create();
      type = await FileSystemEntity.type(target.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record identity must point to a real directory, not a file or link.', target.path);
    return target;
  }

  void _checkId(String id) {
    if (!_idPattern.hasMatch(id)) throw ArgumentError.value(id, 'recordId', 'Record ID must be a canonical lowercase UUID.');
  }

  Future<T> _exclusive<T>(String recordId, Future<T> Function() action) async {
    final previous = _writeTails[recordId];
    final ready = Completer<void>();
    final tail = ready.future;
    _writeTails[recordId] = tail;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      if (identical(_writeTails[recordId], tail)) _writeTails.remove(recordId);
      ready.complete();
    }
  }
}
);
  final Map<String, Future<void>> _writeTails = <String, Future<void>>{};

  Future<void> save(
    String recordId,
    MtnMinecraftContentPackageRecord record, {
    required Uint8List key,
    required String keyId,
  }) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final payload = await codec.encrypt(record, key: key, keyId: keyId);
      final target = await _recordDirectory(recordId, create: true);
      final existing = await _completedGenerations(target!);
      final last = existing.isEmpty ? 0 : existing.last.$1;
      if (last == 999999999999) throw StateError('Encrypted record generation limit reached.');
      final nextName = '${(last + 1).toString().padLeft(12, '0')}.mtncr';
      final published = File(p.join(target.path, nextName));
      if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
        throw StateError('The next encrypted record generation already exists.');
      }

      final nonce = Random.secure();
      final suffix = List<int>.generate(16, (_) => nonce.nextInt(256)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final staging = File(p.join(target.path, '.$nextName.$suffix.tmp'));
      try {
        if (await FileSystemEntity.type(staging.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Temporary record path already exists.');
        }
        await staging.writeAsBytes(payload, flush: true);
        if (await FileSystemEntity.type(published.path, followLinks: false) != FileSystemEntityType.notFound) {
          throw StateError('Record was concurrently published by another writer.');
        }
        await staging.rename(published.path);
      } finally {
        if (await FileSystemEntity.type(staging.path, followLinks: false) == FileSystemEntityType.file) {
          await staging.delete();
        }
      }
    });
  }

  Future<MtnMinecraftContentPackageRecord?> load(
    String recordId, {
    required Uint8List key,
  }) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    final payload = await file.readAsBytes();
    return codec.decrypt(payload, key: key);
  }

  /// Parses the unauthenticated key ID of the newest completed generation.
  /// Its integrity is established only after authenticated load() succeeds.
  Future<String?> getKeyId(String recordId) async {
    _checkId(recordId);
    final file = await _latestFile(recordId);
    if (file == null) return null;
    return codec.readKeyId(await file.readAsBytes());
  }

  /// Returns canonical UUIDs with at least one completed generation.
  Future<List<String>> listRecordIds() async {
    final root = await _rootDirectory();
    if (root == null) return const <String>[];
    final ids = <String>[];
    await for (final entry in root.list(followLinks: false)) {
      final id = p.basename(entry.path);
      if (!_idPattern.hasMatch(id)) continue;
      if (entry is! Directory) throw FileSystemException('Record identity points to a non-directory.', entry.path);
      if ((await _completedGenerations(entry)).isNotEmpty) ids.add(id);
    }
    ids.sort();
    return List<String>.unmodifiable(ids);
  }

  Future<bool> delete(String recordId) {
    _checkId(recordId);
    return _exclusive(recordId, () async {
      final target = await _recordDirectory(recordId);
      if (target == null) return false;

      // Delete only known record generations and staging files, never unknown
      // files or directories accidentally placed alongside them.
      final files = <File>[];
      await for (final entry in target.list(followLinks: false)) {
        final name = p.basename(entry.path);
        final staging = name.startsWith('.') && name.endsWith('.tmp');
        if (entry is! File || (!_generationPattern.hasMatch(name) && !staging)) {
          throw FileSystemException('Record directory contains an unexpected entry; refusing recursive deletion.', entry.path);
        }
        files.add(entry);
      }
      for (final file in files) {
        await file.delete();
      }
      await target.delete(recursive: false);
      return true;
    });
  }

  Future<File?> _latestFile(String recordId) async {
    final target = await _recordDirectory(recordId);
    if (target == null) return null;
    final generations = await _completedGenerations(target);
    return generations.isEmpty ? null : generations.last.$2;
  }

  Future<List<(int, File)>> _completedGenerations(Directory target) async {
    final results = <(int, File)>[];
    await for (final entry in target.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (!_generationPattern.hasMatch(name)) continue;
      if (entry is! File) throw FileSystemException('Encrypted generation is not a regular file.', entry.path);
      final generation = int.parse(name.substring(0, 12));
      if (generation == 0) throw FileSystemException('Invalid zero record generation.', entry.path);
      results.add((generation, entry));
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results;
  }

  Future<Directory?> _rootDirectory({bool create = false}) async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await directory.create(recursive: true);
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record storage root must be a real directory, not a file or link.', directory.path);
    return directory;
  }

  Future<Directory?> _recordDirectory(String recordId, {bool create = false}) async {
    final root = await _rootDirectory(create: create);
    if (root == null) return null;
    final target = Directory(p.join(root.path, recordId));
    var type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await target.create();
      type = await FileSystemEntity.type(target.path, followLinks: false);
    }
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) throw FileSystemException('Record identity must point to a real directory, not a file or link.', target.path);
    return target;
  }

  void _checkId(String id) {
    if (!_idPattern.hasMatch(id)) throw ArgumentError.value(id, 'recordId', 'Record ID must be a canonical lowercase UUID.');
  }

  Future<T> _exclusive<T>(String recordId, Future<T> Function() action) async {
    final previous = _writeTails[recordId];
    final ready = Completer<void>();
    final tail = ready.future;
    _writeTails[recordId] = tail;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      if (identical(_writeTails[recordId], tail)) _writeTails.remove(recordId);
      ready.complete();
    }
  }
}
