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
      return await _parseArchive(
        archive,
        source: _FabricJarSource.file(jarFile),
      );
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
    return _parseJarContentWithSource(
      content,
      source: _FabricJarSource.memory(content),
      parentMod: parentMod,
    );
  }

  Future<List<MtnMinecraftInfoMod>?> _parseJarContentWithSource(
    Uint8List content, {
    required _FabricJarSource source,
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
        source: source,
        parentMod: parentMod,
      );
    } finally {
      archive.clearSync();
    }
  }

  Future<List<MtnMinecraftInfoMod>?> _parseArchive(
    Archive archive, {
    required _FabricJarSource source,
    MtnMinecraftInfoMod? parentMod,
  }) async {
    final ArchiveFile? metadataFile = _findArchiveFile(
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
      archive: archive,
      source: source,
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

      final ArchiveFile? embeddedFile = _findArchiveFile(archive, rawFile);
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
          await _parseJarContentWithSource(
        embeddedBytes,
        source: source.embedded(rawFile),
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
    required Archive archive,
    required _FabricJarSource source,
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

    final _FabricIcon? icon = _fabricIconFromJson(
      json['icon'],
      archive,
    );

    return MtnMinecraftInfoMod(
      id: rawId,
      name: rawName is String ? rawName : rawId,
      version: rawVersion,
      description: rawDescription is String ? rawDescription : '',
      authors: authors,
      parentMods: parentMod == null
          ? const <MtnMinecraftInfoMod>[]
          : <MtnMinecraftInfoMod>[parentMod],
      iconLoaders: icon == null
          ? const <MtnMinecraftInfoModIconLoader>[]
          : <MtnMinecraftInfoModIconLoader>[
              (int size) => source.readEntry(icon.pathForSize(size)),
            ],
    );
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
}

final class _FabricIcon {
  _FabricIcon.single(String path)
      : _singlePath = path,
        _paths = const <int, String>{};

  _FabricIcon.sized(Map<int, String> paths)
      : _singlePath = null,
        _paths = Map<int, String>.unmodifiable(paths);

  final String? _singlePath;
  final Map<int, String> _paths;

  String pathForSize(int size) {
    final String? singlePath = _singlePath;
    if (singlePath != null) return singlePath;

    final List<int> widths = _paths.keys.toList()..sort();
    for (final int width in widths) {
      if (width >= size) return _paths[width]!;
    }
    return _paths[widths.last]!;
  }
}

_FabricIcon? _fabricIconFromJson(
  Object? rawIcon,
  Archive archive,
) {
  if (rawIcon == null) return null;

  if (rawIcon is String) {
    if (rawIcon.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    final ArchiveFile? file = _findArchiveFile(archive, rawIcon);
    return file != null && file.isFile
        ? _FabricIcon.single(rawIcon)
        : null;
  }

  if (rawIcon is! Map<String, dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final Map<int, String> paths = <int, String>{};
  for (final MapEntry<String, dynamic> entry in rawIcon.entries) {
    final int? width = int.tryParse(entry.key);
    final Object? rawPath = entry.value;
    if (width == null ||
        width <= 0 ||
        rawPath is! String ||
        rawPath.isEmpty ||
        paths.containsKey(width)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final ArchiveFile? file = _findArchiveFile(archive, rawPath);
    if (file != null && file.isFile) {
      paths[width] = rawPath;
    }
  }

  return paths.isEmpty ? null : _FabricIcon.sized(paths);
}

final class _FabricJarSource {
  _FabricJarSource.file(File file)
      : _file = File(file.absolute.path),
        _content = null,
        _embeddedPaths = const <String>[];

  _FabricJarSource.memory(Uint8List content)
      : _file = null,
        _content = Uint8List.fromList(content),
        _embeddedPaths = const <String>[];

  _FabricJarSource._({
    required File? file,
    required Uint8List? content,
    required List<String> embeddedPaths,
  })  : _file = file,
        _content = content,
        _embeddedPaths = List<String>.unmodifiable(embeddedPaths);

  final File? _file;
  final Uint8List? _content;
  final List<String> _embeddedPaths;

  _FabricJarSource embedded(String path) => _FabricJarSource._(
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
        final ArchiveFile? embeddedFile = _findArchiveFile(
          currentArchive,
          embeddedPath,
        );
        if (embeddedFile == null || !embeddedFile.isFile) return null;

        final Uint8List? embeddedBytes = embeddedFile.readBytes();
        if (embeddedBytes == null || !_hasZipSignature(embeddedBytes)) {
          return null;
        }

        final Archive nestedArchive = ZipDecoder().decodeBytes(
          embeddedBytes,
          verify: true,
        );
        nestedArchives.add(nestedArchive);
        currentArchive = nestedArchive;
      }

      final ArchiveFile? target = _findArchiveFile(currentArchive, path);
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

ArchiveFile? _findArchiveFile(Archive archive, String name) {
  for (final ArchiveFile file in archive) {
    if (file.name == name) return file;
  }
  return null;
}

bool _hasZipSignature(List<int> bytes) {
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
    return false;
  }

  return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
      (bytes[2] == 0x05 && bytes[3] == 0x06) ||
      (bytes[2] == 0x07 && bytes[3] == 0x08);
}
