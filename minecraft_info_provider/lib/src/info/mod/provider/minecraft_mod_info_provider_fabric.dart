import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../info_mod.dart';
import 'minecraft_mod_info_provider.dart';

/// Fabric `fabric.mod.json` implementation of [MtnMinecraftModInfoProvider].
final class MtnMinecraftModInfoProviderFabric
    extends MtnMinecraftModInfoProvider {
  const MtnMinecraftModInfoProviderFabric();

  static const String providerName = 'fabric';
  static const String _metadataFileName = 'fabric.mod.json';

  @override
  String get name => providerName;

  @override
  Future<List<MtnMinecraftInfoMod>?> parse(File jarFile) async {
    await _validateJarFile(jarFile);

    late final InputFileStream input;
    try {
      input = InputFileStream(jarFile.path);
    } on FileSystemException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.readFailed,
      );
    }

    Archive? archive;
    try {
      archive = ZipDecoder().decodeStream(input, verify: true);
      return await _parseArchive(archive);
    } on MtnMinecraftModInfoProviderException {
      rethrow;
    } on ArchiveException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } finally {
      archive?.clearSync();
      input.closeSync();
    }
  }

  @override
  Future<List<MtnMinecraftInfoMod>?> parseJarContent(
    Uint8List content, {
    MtnMinecraftInfoMod? parentMod,
  }) async {
    if (!_hasZipSignature(content)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(content, verify: true);
    } on ArchiveException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    try {
      return await _parseArchive(
        archive,
        parentMod: parentMod,
      );
    } finally {
      archive.clearSync();
    }
  }

  Future<List<MtnMinecraftInfoMod>?> _parseArchive(
    Archive archive, {
    MtnMinecraftInfoMod? parentMod,
  }) async {
    final ArchiveFile? metadataFile = _findFile(
      archive,
      _metadataFileName,
    );
    if (metadataFile == null) return null;
    if (!metadataFile.isFile) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Uint8List? metadataBytes = metadataFile.readBytes();
    if (metadataBytes == null) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(metadataBytes));
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final MtnMinecraftInfoMod mod = _modFromJson(
      decoded,
      parentMod: parentMod,
    );
    final List<MtnMinecraftInfoMod> result = <MtnMinecraftInfoMod>[mod];

    final Object? rawJars = decoded['jars'];
    if (rawJars == null) return result;
    if (rawJars is! List<dynamic>) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Set<String> parsedPaths = <String>{};
    for (final Object? rawJar in rawJars) {
      if (rawJar is! Map<String, dynamic>) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      final Object? rawFile = rawJar['file'];
      if (rawFile is! String || rawFile.isEmpty || !parsedPaths.add(rawFile)) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      final ArchiveFile? embeddedFile = _findFile(archive, rawFile);
      if (embeddedFile == null || !embeddedFile.isFile) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      final Uint8List? embeddedBytes = embeddedFile.readBytes();
      if (embeddedBytes == null) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      final List<MtnMinecraftInfoMod>? embeddedMods =
          await parseJarContent(
        embeddedBytes,
        parentMod: mod,
      );
      if (embeddedMods != null) {
        result.addAll(embeddedMods);
      }
    }

    return result;
  }

  MtnMinecraftInfoMod _modFromJson(
    Map<String, dynamic> json, {
    required MtnMinecraftInfoMod? parentMod,
  }) {
    if (json['schemaVersion'] != 1) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Object? rawId = json['id'];
    final Object? rawVersion = json['version'];
    if (rawId is! String ||
        rawId.isEmpty ||
        rawVersion is! String ||
        rawVersion.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Object? rawName = json['name'];
    if (rawName != null && (rawName is! String || rawName.isEmpty)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Object? rawDescription = json['description'];
    if (rawDescription != null && rawDescription is! String) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final List<String> authors = <String>[];
    final Object? rawAuthors = json['authors'];
    if (rawAuthors != null) {
      if (rawAuthors is! List<dynamic>) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }
      for (final Object? rawAuthor in rawAuthors) {
        if (rawAuthor is String && rawAuthor.isNotEmpty) {
          authors.add(rawAuthor);
          continue;
        }
        if (rawAuthor is Map<String, dynamic>) {
          final Object? rawAuthorName = rawAuthor['name'];
          if (rawAuthorName is String && rawAuthorName.isNotEmpty) {
            authors.add(rawAuthorName);
            continue;
          }
        }
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }
    }

    return MtnMinecraftInfoMod(
      id: rawId,
      name: rawName is String ? rawName : rawId,
      version: rawVersion,
      description: rawDescription is String ? rawDescription : '',
      authors: authors,
      parentMods: parentMod == null
          ? const <MtnMinecraftInfoMod>[]
          : <MtnMinecraftInfoMod>[parentMod],
    );
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final ArchiveFile file in archive) {
      if (file.name == name) return file;
    }
    return null;
  }

  Future<void> _validateJarFile(File jarFile) async {
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

    if (!_hasZipSignature(signature)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
  }

  bool _hasZipSignature(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      return false;
    }

    return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08);
  }
}
