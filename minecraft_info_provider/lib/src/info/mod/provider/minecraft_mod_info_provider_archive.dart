import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../info_mod_asset_source.dart';
import 'minecraft_mod_info_provider.dart';

final class MtnMinecraftModInfoProviderArchive {
  const MtnMinecraftModInfoProviderArchive._();

  static ArchiveFile? findFile(
    Archive archive,
    String name,
  ) {
    for (final ArchiveFile file in archive) {
      if (file.name == name) return file;
    }
    return null;
  }

  static bool hasZipSignature(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      return false;
    }

    return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08);
  }

  static List<String> assetNamespaces(Archive archive) {
    final Set<String> namespaces = <String>{};
    final RegExp namespacePattern = RegExp(r'^[a-z0-9_.-]+
    late final RandomAccessFile input;
    try {
      input = await jarFile.open();
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    }

    late final Uint8List signature;
    try {
      signature = await input.read(4);
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    } finally {
      await input.close();
    }

    if (!hasZipSignature(signature)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
  }
}

final class MtnMinecraftModInfoProviderArchiveSource {
  MtnMinecraftModInfoProviderArchiveSource.file(File file)
      : _file = File(file.absolute.path),
        _content = null,
        _embeddedPaths = const <String>[];

  MtnMinecraftModInfoProviderArchiveSource.memory(Uint8List content)
      : _file = null,
        _content = Uint8List.fromList(content),
        _embeddedPaths = const <String>[];

  MtnMinecraftModInfoProviderArchiveSource._({
    required File? file,
    required Uint8List? content,
    required List<String> embeddedPaths,
  })  : _file = file,
        _content = content,
        _embeddedPaths = List<String>.unmodifiable(embeddedPaths);

  final File? _file;
  final Uint8List? _content;
  final List<String> _embeddedPaths;

  File? get rootFile => _file == null ? null : File(_file.path);

  List<String> get embeddedPaths =>
      List<String>.unmodifiable(_embeddedPaths);

  MtnMinecraftInfoModAssetSource? assetSource(Archive archive) {
    final List<String> namespaces =
        MtnMinecraftModInfoProviderArchive.assetNamespaces(
      archive,
    );
    if (namespaces.isEmpty) return null;

    return MtnMinecraftInfoModAssetSource(
      rootFile: rootFile,
      embeddedArchivePaths: _embeddedPaths,
      namespaces: namespaces,
      loader: readEntry,
    );
  }

  MtnMinecraftModInfoProviderArchiveSource embedded(String path) =>
      MtnMinecraftModInfoProviderArchiveSource._(
        file: _file,
        content: _content,
        embeddedPaths: <String>[
          ..._embeddedPaths,
          path,
        ],
      );

  Future<Uint8List?> readEntry(String path) async {
    InputFileStream? input;
    Archive? rootArchive;
    final List<Archive> nestedArchives = <Archive>[];

    try {
      final File? file = _file;
      if (file != null) {
        input = InputFileStream(file.path);
        rootArchive = ZipDecoder().decodeStream(input, verify: true);
      } else {
        rootArchive = ZipDecoder().decodeBytes(_content!, verify: true);
      }

      Archive currentArchive = rootArchive;
      for (final String embeddedPath in _embeddedPaths) {
        final ArchiveFile? embeddedFile =
            MtnMinecraftModInfoProviderArchive.findFile(
          currentArchive,
          embeddedPath,
        );
        if (embeddedFile == null || !embeddedFile.isFile) return null;

        final Uint8List? embeddedBytes = embeddedFile.readBytes();
        if (embeddedBytes == null ||
            !MtnMinecraftModInfoProviderArchive.hasZipSignature(
              embeddedBytes,
            )) {
          return null;
        }

        final Archive nestedArchive = ZipDecoder().decodeBytes(
          embeddedBytes,
          verify: true,
        );
        nestedArchives.add(nestedArchive);
        currentArchive = nestedArchive;
      }

      final ArchiveFile? target = MtnMinecraftModInfoProviderArchive.findFile(
        currentArchive,
        path,
      );
      if (target == null || !target.isFile) return null;

      final Uint8List? bytes = target.readBytes();
      return bytes == null ? null : Uint8List.fromList(bytes);
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    } on ArchiveException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } finally {
      for (final Archive archive in nestedArchives.reversed) {
        archive.clearSync();
      }
      rootArchive?.clearSync();
      input?.closeSync();
    }
  }
}
);

    for (final ArchiveFile file in archive) {
      if (!file.isFile || !file.name.startsWith('assets/')) continue;
      final List<String> parts = file.name.split('/');
      if (parts.length < 3) continue;

      final String namespace = parts[1];
      if (namespacePattern.hasMatch(namespace)) {
        namespaces.add(namespace);
      }
    }

    final List<String> result = namespaces.toList()..sort();
    return result;
  }

  static Future<void> validateFile(File jarFile) async {
    late final RandomAccessFile input;
    try {
      input = await jarFile.open();
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    }

    late final Uint8List signature;
    try {
      signature = await input.read(4);
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    } finally {
      await input.close();
    }

    if (!hasZipSignature(signature)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
  }
}

final class MtnMinecraftModInfoProviderArchiveSource {
  MtnMinecraftModInfoProviderArchiveSource.file(File file)
      : _file = File(file.absolute.path),
        _content = null,
        _embeddedPaths = const <String>[];

  MtnMinecraftModInfoProviderArchiveSource.memory(Uint8List content)
      : _file = null,
        _content = Uint8List.fromList(content),
        _embeddedPaths = const <String>[];

  MtnMinecraftModInfoProviderArchiveSource._({
    required File? file,
    required Uint8List? content,
    required List<String> embeddedPaths,
  })  : _file = file,
        _content = content,
        _embeddedPaths = List<String>.unmodifiable(embeddedPaths);

  final File? _file;
  final Uint8List? _content;
  final List<String> _embeddedPaths;

  File? get rootFile => _file == null ? null : File(_file.path);

  List<String> get embeddedPaths =>
      List<String>.unmodifiable(_embeddedPaths);

  MtnMinecraftInfoModAssetSource? assetSource(Archive archive) {
    final List<String> namespaces =
        MtnMinecraftModInfoProviderArchive.assetNamespaces(
      archive,
    );
    if (namespaces.isEmpty) return null;

    return MtnMinecraftInfoModAssetSource(
      rootFile: rootFile,
      embeddedArchivePaths: _embeddedPaths,
      namespaces: namespaces,
      loader: readEntry,
    );
  }

  MtnMinecraftModInfoProviderArchiveSource embedded(String path) =>
      MtnMinecraftModInfoProviderArchiveSource._(
        file: _file,
        content: _content,
        embeddedPaths: <String>[
          ..._embeddedPaths,
          path,
        ],
      );

  Future<Uint8List?> readEntry(String path) async {
    InputFileStream? input;
    Archive? rootArchive;
    final List<Archive> nestedArchives = <Archive>[];

    try {
      final File? file = _file;
      if (file != null) {
        input = InputFileStream(file.path);
        rootArchive = ZipDecoder().decodeStream(input, verify: true);
      } else {
        rootArchive = ZipDecoder().decodeBytes(_content!, verify: true);
      }

      Archive currentArchive = rootArchive;
      for (final String embeddedPath in _embeddedPaths) {
        final ArchiveFile? embeddedFile =
            MtnMinecraftModInfoProviderArchive.findFile(
          currentArchive,
          embeddedPath,
        );
        if (embeddedFile == null || !embeddedFile.isFile) return null;

        final Uint8List? embeddedBytes = embeddedFile.readBytes();
        if (embeddedBytes == null ||
            !MtnMinecraftModInfoProviderArchive.hasZipSignature(
              embeddedBytes,
            )) {
          return null;
        }

        final Archive nestedArchive = ZipDecoder().decodeBytes(
          embeddedBytes,
          verify: true,
        );
        nestedArchives.add(nestedArchive);
        currentArchive = nestedArchive;
      }

      final ArchiveFile? target = MtnMinecraftModInfoProviderArchive.findFile(
        currentArchive,
        path,
      );
      if (target == null || !target.isFile) return null;

      final Uint8List? bytes = target.readBytes();
      return bytes == null ? null : Uint8List.fromList(bytes);
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    } on ArchiveException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } finally {
      for (final Archive archive in nestedArchives.reversed) {
        archive.clearSync();
      }
      rootArchive?.clearSync();
      input?.closeSync();
    }
  }
}
