import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../mtn_minecraft_resource_source_abs.dart';

/// Shared ZIP/JAR storage reads for Vanilla resources and mod archives.
///
/// Entries stay compressed until readBytes() is requested. Each read owns and
/// closes its archive/stream; no caller needs to manage a long-lived ZIP handle.
final class MtnMinecraftResourceArchiveReader {
  const MtnMinecraftResourceArchiveReader._();

  static ArchiveFile? findFile(Archive archive, String name) {
    for (final ArchiveFile entry in archive) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  static bool hasZipSignature(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) return false;
    return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08);
  }

  /// Discovers namespaces without interpreting mod ownership from ZIP names.
  static List<String> assetNamespaces(Archive archive) {
    final Set<String> result = <String>{};
    final RegExp validNamespace = RegExp(r'^[a-z0-9_.-]+$');
    for (final ArchiveFile file in archive) {
      if (!file.isFile || !file.name.startsWith('assets/')) continue;
      final List<String> parts = file.name.split('/');
      if (parts.length < 3) continue;
      if (validNamespace.hasMatch(parts[1])) result.add(parts[1]);
    }
    return result.toList()..sort();
  }

  /// One-time inventory of safe asset entries from a file-backed client JAR.
  ///
  /// The scan reads ZIP metadata, not every uncompressed PNG or JSON.
  static Future<Set<String>> scanAssetPaths(File file) async {
    final RandomAccessFile probe = await file.open();
    try {
      if (!hasZipSignature(await probe.read(4))) {
        throw const FormatException('Invalid ZIP/JAR signature.');
      }
    } finally {
      await probe.close();
    }

    InputFileStream? input;
    Archive? archive;
    try {
      input = InputFileStream(file.path);
      archive = ZipDecoder().decodeStream(input, verify: true);
      final Set<String> result = <String>{};
      for (final ArchiveFile entry in archive) {
        if (!entry.isFile || !entry.name.startsWith('assets/')) continue;
        final List<String> parts = entry.name.split('/');
        if (parts.length < 3) continue;
        final String namespace = parts[1];
        final String resourcePath = entry.name.substring('assets/$namespace/'.length);
        if (resourcePath.isEmpty ||
            resourcePath.split('/').any((String part) => part.isEmpty || part == '.')) {
          continue;
        }
        try {
          MtnMinecraftResourceSourceAbs.validateResource(namespace, resourcePath);
        } on ArgumentError {
          continue;
        }
        result.add('assets/$namespace/$resourcePath');
      }
      return Set<String>.unmodifiable(result);
    } finally {
      archive?.clearSync();
      input?.closeSync();
    }
  }

  /// Reads one file entry, optionally descending embedded ZIP/JAR archives.
  ///
  /// A missing nested or target entry is null. Storage/ZIP failures propagate.
  static Future<Uint8List?> readEntry({
    required String path,
    File? file,
    Uint8List? content,
    List<String> embeddedArchivePaths = const <String>[],
  }) async {
    if ((file == null) == (content == null)) {
      throw ArgumentError('Exactly one ZIP file or ZIP content is required.');
    }

    InputFileStream? input;
    Archive? root;
    final List<Archive> nestedArchives = <Archive>[];
    try {
      if (file != null) {
        input = InputFileStream(file.path);
        root = ZipDecoder().decodeStream(input, verify: true);
      } else {
        root = ZipDecoder().decodeBytes(content!, verify: true);
      }

      Archive current = root;
      for (final String nestedPath in embeddedArchivePaths) {
        final ArchiveFile? nestedFile = findFile(current, nestedPath);
        if (nestedFile == null || !nestedFile.isFile) return null;
        final Uint8List? nestedBytes = nestedFile.readBytes();
        if (nestedBytes == null || !hasZipSignature(nestedBytes)) return null;
        final Archive next = ZipDecoder().decodeBytes(nestedBytes, verify: true);
        nestedArchives.add(next);
        current = next;
      }

      final ArchiveFile? target = findFile(current, path);
      if (target == null || !target.isFile) return null;
      final Uint8List? bytes = target.readBytes();
      return bytes == null ? null : Uint8List.fromList(bytes);
    } finally {
      for (final Archive archive in nestedArchives.reversed) {
        archive.clearSync();
      }
      root?.clearSync();
      input?.closeSync();
    }
  }
}
