import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../resource/src/mtn_minecraft_resource_archive_reader.dart';
import '../info_mod_asset_source.dart';
import 'minecraft_mod_info_provider.dart';

final class MtnMinecraftModInfoProviderArchive {
  const MtnMinecraftModInfoProviderArchive._();

  static ArchiveFile? findFile(Archive archive, String name) =>
      MtnMinecraftResourceArchiveReader.findFile(archive, name);

  static bool hasZipSignature(List<int> bytes) =>
      MtnMinecraftResourceArchiveReader.hasZipSignature(bytes);

  static List<String> assetNamespaces(Archive archive) =>
      MtnMinecraftResourceArchiveReader.assetNamespaces(archive);

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
    try {
      return await MtnMinecraftResourceArchiveReader.readEntry(
        path: path,
        file: _file,
        content: _content,
        embeddedArchivePaths: _embeddedPaths,
      );
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
    }
  }
}
