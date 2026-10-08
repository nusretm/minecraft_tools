import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../model/minecraft_content_models.dart';

class MtnMinecraftContentFileIntegrityException implements Exception {
  const MtnMinecraftContentFileIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'MtnMinecraftContentFileIntegrityException: $message';
}

class MtnMinecraftContentFileIntegrity {
  MtnMinecraftContentFileIntegrity._({
    required this.expectedSize,
    required Map<String, String> checksums,
  }) : checksums = Map<String, String>.unmodifiable(checksums);

  static MtnMinecraftContentFileIntegrity? fromFile(
    MtnMinecraftContentFile file,
  ) {
    final checksums = _parseChecksums(file.hashes);
    if (file.size == null && checksums.isEmpty) {
      return null;
    }
    return MtnMinecraftContentFileIntegrity._(
      expectedSize: file.size,
      checksums: checksums,
    );
  }

  final int? expectedSize;
  final Map<String, String> checksums;

  Future<void> validate(
    File file, {
    String subject = 'File',
  }) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
      throw MtnMinecraftContentFileIntegrityException(
        '$subject is missing or is not a regular file: "${file.path}".',
      );
    }

    final actualSize = await file.length();
    final expectedSize = this.expectedSize;
    if (expectedSize != null && actualSize != expectedSize) {
      throw MtnMinecraftContentFileIntegrityException(
        '$subject size mismatch for "${file.path}": expected $expectedSize bytes, received $actualSize.',
      );
    }

    if (checksums.isEmpty) {
      return;
    }

    final actual = await _calculateChecksums(file, checksums.keys);
    for (final expected in checksums.entries) {
      final actualDigest = actual[expected.key];
      if (actualDigest != expected.value) {
        throw MtnMinecraftContentFileIntegrityException(
          '$subject checksum mismatch for "${file.path}" using ${expected.key}: expected ${expected.value}, received $actualDigest.',
        );
      }
    }
  }
}

Map<String, String> _parseChecksums(
  List<MtnMinecraftContentFileHash> hashes,
) {
  final supported = <String, String>{};

  for (final hash in hashes) {
    final algorithm = _canonicalAlgorithm(hash.algorithm);
    if (algorithm == null) {
      continue;
    }

    final digest = _validatedDigest(algorithm, hash.value);
    final existing = supported[algorithm];
    if (existing != null && existing != digest) {
      throw FormatException(
        'Conflicting checksum aliases declare different $algorithm digests.',
      );
    }
    supported[algorithm] = digest;
  }

  return Map<String, String>.unmodifiable(supported);
}

String? _canonicalAlgorithm(String value) {
  return switch (value.toLowerCase()) {
    'md5' => 'md5',
    'sha1' || 'sha-1' => 'sha1',
    'sha256' || 'sha-256' => 'sha256',
    'sha512' || 'sha-512' => 'sha512',
    _ => null,
  };
}

String _validatedDigest(String algorithm, String value) {
  final expectedLength = switch (algorithm) {
    'md5' => 32,
    'sha1' => 40,
    'sha256' => 64,
    'sha512' => 128,
    _ => throw UnsupportedError('Unsupported checksum algorithm "$algorithm".'),
  };

  if (value.length != expectedLength ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw FormatException(
      'Invalid $algorithm checksum digest; expected exactly $expectedLength hexadecimal characters.',
      value,
    );
  }

  return value.toLowerCase();
}

Future<Map<String, String>> _calculateChecksums(
  File file,
  Iterable<String> algorithms,
) async {
  final captures = <String, _DigestCapture>{};
  final sinks = <String, ByteConversionSink>{};

  for (final algorithm in algorithms) {
    final capture = _DigestCapture();
    captures[algorithm] = capture;
    sinks[algorithm] = _hashFor(algorithm).startChunkedConversion(capture);
  }

  try {
    await for (final bytes in file.openRead()) {
      for (final sink in sinks.values) {
        sink.add(bytes);
      }
    }
    for (final sink in sinks.values) {
      sink.close();
    }
  } catch (_) {
    for (final sink in sinks.values) {
      try {
        sink.close();
      } catch (_) {}
    }
    rethrow;
  }

  return <String, String>{
    for (final entry in captures.entries)
      entry.key: entry.value.digest!.toString(),
  };
}

Hash _hashFor(String algorithm) {
  return switch (algorithm) {
    'md5' => md5,
    'sha1' => sha1,
    'sha256' => sha256,
    'sha512' => sha512,
    _ => throw UnsupportedError('Unsupported checksum algorithm "$algorithm".'),
  };
}

class _DigestCapture implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}
