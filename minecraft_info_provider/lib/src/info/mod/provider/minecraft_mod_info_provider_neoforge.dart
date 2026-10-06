import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:toml/toml.dart';

import '../info_mod.dart';
import '../info_mod_dependency.dart';
import '../info_mod_urls.dart';
import 'minecraft_mod_info_provider.dart';
import 'minecraft_mod_info_provider_archive.dart';

/// NeoForge `META-INF/neoforge.mods.toml` implementation of
/// [MtnMinecraftModInfoProvider].
final class MtnMinecraftModInfoProviderNeoForge
    extends MtnMinecraftModInfoProvider {
  const MtnMinecraftModInfoProviderNeoForge();

  static const String providerName = 'neoforge';
  static const String _metadataFileName = 'META-INF/neoforge.mods.toml';
  static const String _jarJarMetadataFileName = 'META-INF/jarjar/metadata.json';

  @override
  String get name => providerName;

  @override
  Future<List<MtnMinecraftInfoMod>?> parse(File jarFile) async {
    await MtnMinecraftModInfoProviderArchive.validateFile(jarFile);

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
        source: MtnMinecraftModInfoProviderArchiveSource.file(jarFile),
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
      source: MtnMinecraftModInfoProviderArchiveSource.memory(content),
      parentMods: parentMod == null
          ? const <MtnMinecraftInfoMod>[]
          : <MtnMinecraftInfoMod>[parentMod],
    );
  }

  Future<List<MtnMinecraftInfoMod>?> _parseJarContentWithSource(
    Uint8List content, {
    required MtnMinecraftModInfoProviderArchiveSource source,
    required List<MtnMinecraftInfoMod> parentMods,
  }) async {
    if (!MtnMinecraftModInfoProviderArchive.hasZipSignature(content)) {
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
        parentMods: parentMods,
      );
    } finally {
      archive.clearSync();
    }
  }

  Future<List<MtnMinecraftInfoMod>?> _parseArchive(
    Archive archive, {
    required MtnMinecraftModInfoProviderArchiveSource source,
    List<MtnMinecraftInfoMod> parentMods =
        const <MtnMinecraftInfoMod>[],
  }) async {
    final ArchiveFile? metadataFile =
        MtnMinecraftModInfoProviderArchive.findFile(
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

    late final Map<String, dynamic> metadata;
    try {
      metadata = TomlDocument.parse(
        utf8.decode(metadataBytes),
      ).toMap();
    } on TomlException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    } on FormatException {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Object? rawModLoader = metadata['modLoader'];
    if (rawModLoader != null &&
        (rawModLoader is! String || rawModLoader.isEmpty)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final String license = _requiredNonEmptyString(
      metadata['license'],
    );

    final Object? rawMods = metadata['mods'];
    if (rawMods is! List<dynamic> || rawMods.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final String? issueTrackerUrl = _emptyToNull(
      _optionalString(
        metadata['issueTrackerURL'],
      ),
    );
    final Map<String, String> fileProperties = _filePropertiesFromToml(
      metadata['properties'],
    );
    final String? jarVersion = _implementationVersionFromArchive(
      archive,
    );
    final Map<String, dynamic> dependencyGroups =
        _optionalMap(metadata['dependencies']) ??
            const <String, dynamic>{};

    final String? fileIcon = _emptyToNull(
      _optionalString(
        metadata['iconFile'],
      ),
    );
    final String? fileLogo = _emptyToNull(
      _optionalString(
        metadata['logoFile'],
      ),
    );

    final List<MtnMinecraftInfoMod> mods = <MtnMinecraftInfoMod>[];
    final Set<String> ids = <String>{};

    for (final Object? rawMod in rawMods) {
      final Map<String, dynamic> modMetadata = _requiredMap(rawMod);
      final String id = _requiredNonEmptyString(modMetadata['modId']);
      if (!ids.add(id)) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      final String rawVersion = _emptyToNull(
            _optionalString(
              modMetadata['version'],
            ),
          ) ??
          '1';
      final String version = _substituteFileProperties(
        rawVersion,
        jarVersion: jarVersion,
        properties: fileProperties,
      );
      final String name = _emptyToNull(
            _optionalString(
              modMetadata['displayName'],
            ),
          ) ??
          id;
      final String description = _optionalString(
            modMetadata['description'],
          ) ??
          '';
      final String? authors = _emptyToNull(
        _optionalString(
          modMetadata['authors'],
        ),
      );
      final String? displayUrl = _emptyToNull(
        _optionalString(
          modMetadata['displayURL'],
        ),
      );
      final String? modUrl = _emptyToNull(
        _optionalString(
          modMetadata['modUrl'],
        ),
      );
      final String? iconFile = _emptyToNull(
            _optionalString(
              modMetadata['iconFile'],
            ),
          ) ??
          fileIcon ??
          _emptyToNull(
            _optionalString(
              modMetadata['logoFile'],
            ),
          ) ??
          fileLogo;
      final bool hasIcon = iconFile != null &&
          _archiveHasFile(
            archive,
            iconFile,
          );

      mods.add(
        MtnMinecraftInfoMod(
          id: id,
          name: name,
          version: version,
          description: description,
          authors: authors == null
              ? const <String>[]
              : <String>[authors],
          licenses: <String>[license],
          urls: MtnMinecraftInfoModUrls(
            homepage: displayUrl ?? modUrl,
            issues: issueTrackerUrl,
          ),
          clientSide: true,
          serverSide: true,
          dependencies: _neoForgeDependenciesFromToml(
            dependencyGroups[id],
          ),
          parentMods: parentMods,
          iconLoaders: !hasIcon
              ? const <MtnMinecraftInfoModIconLoader>[]
              : <MtnMinecraftInfoModIconLoader>[
                  (int size) => source.readEntry(iconFile),
                ],
        ),
      );
    }

    final List<String> embeddedPaths = _jarJarPathsFromArchive(archive);
    if (embeddedPaths.isEmpty) return mods;

    final List<MtnMinecraftInfoMod> result =
        List<MtnMinecraftInfoMod>.of(mods);
    for (final String path in embeddedPaths) {
      final ArchiveFile? embeddedFile =
          MtnMinecraftModInfoProviderArchive.findFile(
        archive,
        path,
      );
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
        source: source.embedded(path),
        parentMods: mods,
      );
      if (embeddedMods != null) result.addAll(embeddedMods);
    }

    return result;
  }
}

List<MtnMinecraftInfoModDependency> _neoForgeDependenciesFromToml(
  Object? rawDependencies,
) {
  if (rawDependencies == null) {
    return const <MtnMinecraftInfoModDependency>[];
  }
  if (rawDependencies is! List<dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<MtnMinecraftInfoModDependency> dependencies =
      <MtnMinecraftInfoModDependency>[];

  for (final Object? rawDependency in rawDependencies) {
    final Map<String, dynamic> dependency = _requiredMap(
      rawDependency,
    );
    final String id = _requiredNonEmptyString(
      dependency['modId'],
    );
    final MtnMinecraftInfoModDependencyType type =
        _neoForgeDependencyType(
      _emptyToNull(
        _optionalString(
          dependency['type'],
        ),
      ),
    );
    final String? versionRange = _optionalString(
      dependency['versionRange'],
    );
    final MtnMinecraftInfoModDependencyOrdering ordering =
        _neoForgeDependencyOrdering(
      _emptyToNull(
        _optionalString(
          dependency['ordering'],
        ),
      ),
    );
    final ({bool clientSide, bool serverSide}) side =
        _neoForgeDependencySide(
      _emptyToNull(
        _optionalString(
          dependency['side'],
        ),
      ),
    );

    dependencies.add(
      MtnMinecraftInfoModDependency(
        id: id,
        type: type,
        versionConstraints: versionRange == null || versionRange.isEmpty
            ? const <String>[]
            : <String>[versionRange],
        ordering: ordering,
        clientSide: side.clientSide,
        serverSide: side.serverSide,
      ),
    );
  }

  return dependencies;
}

MtnMinecraftInfoModDependencyType _neoForgeDependencyType(
  String? value,
) {
  switch (value ?? 'required') {
    case 'required':
      return MtnMinecraftInfoModDependencyType.required;
    case 'optional':
      return MtnMinecraftInfoModDependencyType.optional;
    case 'incompatible':
      return MtnMinecraftInfoModDependencyType.incompatible;
    case 'discouraged':
      return MtnMinecraftInfoModDependencyType.discouraged;
  }

  throw const MtnMinecraftModInfoProviderException(
    MtnMinecraftModInfoProviderError.invalidData,
  );
}

MtnMinecraftInfoModDependencyOrdering _neoForgeDependencyOrdering(
  String? value,
) {
  switch (value ?? 'NONE') {
    case 'NONE':
      return MtnMinecraftInfoModDependencyOrdering.none;
    case 'BEFORE':
      return MtnMinecraftInfoModDependencyOrdering.before;
    case 'AFTER':
      return MtnMinecraftInfoModDependencyOrdering.after;
  }

  throw const MtnMinecraftModInfoProviderException(
    MtnMinecraftModInfoProviderError.invalidData,
  );
}

({bool clientSide, bool serverSide}) _neoForgeDependencySide(
  String? value,
) {
  switch (value ?? 'BOTH') {
    case 'BOTH':
      return (clientSide: true, serverSide: true);
    case 'CLIENT':
      return (clientSide: true, serverSide: false);
    case 'SERVER':
      return (clientSide: false, serverSide: true);
  }

  throw const MtnMinecraftModInfoProviderException(
    MtnMinecraftModInfoProviderError.invalidData,
  );
}

List<String> _jarJarPathsFromArchive(Archive archive) {
  final ArchiveFile? metadataFile =
      MtnMinecraftModInfoProviderArchive.findFile(
    archive,
    MtnMinecraftModInfoProviderNeoForge._jarJarMetadataFileName,
  );
  if (metadataFile == null) return const <String>[];
  if (!metadataFile.isFile) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final Uint8List? bytes = metadataFile.readBytes();
  if (bytes == null) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  late final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
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

  final Object? rawJars = decoded['jars'];
  if (rawJars is! List<dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<String> paths = <String>[];
  for (final Object? rawJar in rawJars) {
    if (rawJar is! Map<String, dynamic>) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    final Object? rawPath = rawJar['path'];
    if (rawPath is! String ||
        rawPath.isEmpty ||
        paths.contains(rawPath)) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    paths.add(rawPath);
  }

  return paths;
}

String? _implementationVersionFromArchive(Archive archive) {
  final ArchiveFile? manifest =
      MtnMinecraftModInfoProviderArchive.findFile(
    archive,
    'META-INF/MANIFEST.MF',
  );
  if (manifest == null || !manifest.isFile) return null;

  final Uint8List? bytes = manifest.readBytes();
  if (bytes == null) return null;

  final String content = utf8.decode(
    bytes,
    allowMalformed: true,
  );
  final List<String> physicalLines = content.split(
    RegExp(r'\r?\n'),
  );
  final List<String> logicalLines = <String>[];

  for (final String line in physicalLines) {
    if (line.startsWith(' ') && logicalLines.isNotEmpty) {
      logicalLines[logicalLines.length - 1] += line.substring(1);
    } else {
      logicalLines.add(line);
    }
  }

  for (final String line in logicalLines) {
    final int separator = line.indexOf(':');
    if (separator <= 0) continue;
    if (line.substring(0, separator) != 'Implementation-Version') {
      continue;
    }
    final String value = line.substring(separator + 1).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

Map<String, String> _filePropertiesFromToml(Object? rawProperties) {
  if (rawProperties == null) return const <String, String>{};
  final Map<String, dynamic> properties = _requiredMap(
    rawProperties,
  );
  final Map<String, String> result = <String, String>{};
  for (final MapEntry<String, dynamic> entry in properties.entries) {
    final Object? value = entry.value;
    if (value is! String || value.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    result[entry.key] = value;
  }
  return result;
}

String _substituteFileProperties(
  String value, {
  required String? jarVersion,
  required Map<String, String> properties,
}) {
  return value.replaceAllMapped(
    RegExp(r'\$\{file\.([^}]+)\}'),
    (Match match) {
      final String key = match.group(1)!;
      if (key == 'jarVersion' && jarVersion != null) {
        return jarVersion;
      }
      return properties[key] ?? match.group(0)!;
    },
  );
}

bool _archiveHasFile(
  Archive archive,
  String path,
) {
  final ArchiveFile? file = MtnMinecraftModInfoProviderArchive.findFile(
    archive,
    path,
  );
  return file != null && file.isFile;
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }
  return value;
}

Map<String, dynamic>? _optionalMap(Object? value) {
  if (value == null) return null;
  return _requiredMap(value);
}

String _requiredNonEmptyString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }
  return value;
}

String? _emptyToNull(String? value) =>
    value == null || value.isEmpty ? null : value;

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }
  return value;
}
