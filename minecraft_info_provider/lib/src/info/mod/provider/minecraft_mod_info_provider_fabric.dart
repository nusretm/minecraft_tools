import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../info_mod.dart';
import '../info_mod_asset_source.dart';
import '../info_mod_dependency.dart';
import '../info_mod_urls.dart';
import 'minecraft_mod_info_provider.dart';
import 'minecraft_mod_info_provider_archive.dart';

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
      parentMod: parentMod,
    );
  }

  Future<List<MtnMinecraftInfoMod>?> _parseJarContentWithSource(
    Uint8List content, {
    required MtnMinecraftModInfoProviderArchiveSource source,
    MtnMinecraftInfoMod? parentMod,
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
        parentMod: parentMod,
      );
    } finally {
      archive.clearSync();
    }
  }

  Future<List<MtnMinecraftInfoMod>?> _parseArchive(
    Archive archive, {
    required MtnMinecraftModInfoProviderArchiveSource source,
    MtnMinecraftInfoMod? parentMod,
  }) async {
    final ArchiveFile? metadataFile = MtnMinecraftModInfoProviderArchive.findFile(
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

      final ArchiveFile? embeddedFile = MtnMinecraftModInfoProviderArchive.findFile(archive, rawFile);
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
    required MtnMinecraftModInfoProviderArchiveSource source,
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

    final List<String> authors = _fabricPeopleFromJson(
      json['authors'],
    );
    final List<String> contributors = _fabricPeopleFromJson(
      json['contributors'],
    );
    final List<String> licenses = _fabricLicensesFromJson(
      json['license'],
    );
    final MtnMinecraftInfoModUrls urls = _fabricUrlsFromJson(
      json['contact'],
    );
    final ({bool clientSide, bool serverSide}) sideSupport =
        _fabricSideSupportFromJson(
      json['environment'],
    );
    final List<MtnMinecraftInfoModDependency> dependencies =
        _fabricDependenciesFromJson(
      json,
      clientSide: sideSupport.clientSide,
      serverSide: sideSupport.serverSide,
    );
    final List<String> providedIds = _fabricProvidedIdsFromJson(
      json['provides'],
    );
    final _FabricIcon? icon = _fabricIconFromJson(
      json['icon'],
      archive,
    );
    final assetSource = source.assetSource(archive);

    return MtnMinecraftInfoMod(
      id: rawId,
      name: rawName is String ? rawName : rawId,
      version: rawVersion,
      description: rawDescription is String ? rawDescription : '',
      authors: authors,
      contributors: contributors,
      licenses: licenses,
      urls: urls,
      clientSide: sideSupport.clientSide,
      serverSide: sideSupport.serverSide,
      dependencies: dependencies,
      providedIds: providedIds,
      parentMods: parentMod == null
          ? const <MtnMinecraftInfoMod>[]
          : <MtnMinecraftInfoMod>[parentMod],
      iconLoaders: icon == null
          ? const <MtnMinecraftInfoModIconLoader>[]
          : <MtnMinecraftInfoModIconLoader>[
              (int size) => source.readEntry(icon.pathForSize(size)),
            ],
      assetSources: assetSource == null
          ? const <MtnMinecraftInfoModAssetSource>[]
          : <MtnMinecraftInfoModAssetSource>[assetSource],
    );
  }
}

List<String> _fabricPeopleFromJson(Object? rawPeople) {
  if (rawPeople == null) return const <String>[];
  if (rawPeople is! List<dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<String> people = <String>[];
  for (final Object? rawPerson in rawPeople) {
    String? name;
    if (rawPerson is String) {
      name = rawPerson;
    } else if (rawPerson is Map<String, dynamic>) {
      final Object? rawName = rawPerson['name'];
      if (rawName is String) name = rawName;
    }

    if (name == null || name.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    if (!people.contains(name)) people.add(name);
  }
  return people;
}

List<String> _fabricLicensesFromJson(Object? rawLicense) {
  if (rawLicense == null) return const <String>[];

  if (rawLicense is String) {
    return rawLicense.isEmpty
        ? const <String>[]
        : <String>[rawLicense];
  }

  if (rawLicense is! List<dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<String> licenses = <String>[];
  for (final Object? value in rawLicense) {
    if (value is! String) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    if (value.isNotEmpty && !licenses.contains(value)) licenses.add(value);
  }
  return licenses;
}

MtnMinecraftInfoModUrls _fabricUrlsFromJson(Object? rawContact) {
  if (rawContact == null) return const MtnMinecraftInfoModUrls();
  if (rawContact is! Map<String, dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  String? read(String key) {
    final Object? value = rawContact[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    return value;
  }

  return MtnMinecraftInfoModUrls(
    homepage: read('homepage'),
    source: read('sources'),
    issues: read('issues'),
  );
}

({bool clientSide, bool serverSide}) _fabricSideSupportFromJson(
  Object? rawEnvironment,
) {
  if (rawEnvironment == null || rawEnvironment == '*') {
    return (clientSide: true, serverSide: true);
  }
  if (rawEnvironment == 'client') {
    return (clientSide: true, serverSide: false);
  }
  if (rawEnvironment == 'server') {
    return (clientSide: false, serverSide: true);
  }

  if (rawEnvironment is List<dynamic> && rawEnvironment.isNotEmpty) {
    bool clientSide = false;
    bool serverSide = false;
    for (final Object? value in rawEnvironment) {
      if (value == '*') {
        clientSide = true;
        serverSide = true;
        continue;
      }
      if (value == 'client') {
        clientSide = true;
        continue;
      }
      if (value == 'server') {
        serverSide = true;
        continue;
      }
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    return (
      clientSide: clientSide,
      serverSide: serverSide,
    );
  }

  throw const MtnMinecraftModInfoProviderException(
    MtnMinecraftModInfoProviderError.invalidData,
  );
}

List<MtnMinecraftInfoModDependency> _fabricDependenciesFromJson(
  Map<String, dynamic> json, {
  required bool clientSide,
  required bool serverSide,
}) {
  final List<MtnMinecraftInfoModDependency> dependencies =
      <MtnMinecraftInfoModDependency>[];

  void addGroup(
    String field,
    MtnMinecraftInfoModDependencyType type,
  ) {
    final Object? rawGroup = json[field];
    if (rawGroup == null) return;
    if (rawGroup is! Map<String, dynamic>) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }

    for (final MapEntry<String, dynamic> entry in rawGroup.entries) {
      if (entry.key.isEmpty) {
        throw const MtnMinecraftModInfoProviderException(
          MtnMinecraftModInfoProviderError.invalidData,
        );
      }

      dependencies.add(
        MtnMinecraftInfoModDependency(
          id: entry.key,
          type: type,
          versionConstraints: _fabricVersionConstraintsFromJson(entry.value),
          clientSide: clientSide,
          serverSide: serverSide,
        ),
      );
    }
  }

  addGroup(
    'depends',
    MtnMinecraftInfoModDependencyType.required,
  );
  addGroup(
    'recommends',
    MtnMinecraftInfoModDependencyType.recommended,
  );
  addGroup(
    'suggests',
    MtnMinecraftInfoModDependencyType.suggested,
  );
  addGroup(
    'conflicts',
    MtnMinecraftInfoModDependencyType.conflict,
  );
  addGroup(
    'breaks',
    MtnMinecraftInfoModDependencyType.incompatible,
  );

  return dependencies;
}

List<String> _fabricVersionConstraintsFromJson(Object? rawConstraint) {
  if (rawConstraint is String) {
    if (rawConstraint.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    return <String>[rawConstraint];
  }

  if (rawConstraint is! List<dynamic> || rawConstraint.isEmpty) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<String> constraints = <String>[];
  for (final Object? value in rawConstraint) {
    if (value is! String || value.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    if (!constraints.contains(value)) constraints.add(value);
  }
  return constraints;
}

List<String> _fabricProvidedIdsFromJson(Object? rawProvides) {
  if (rawProvides == null) return const <String>[];
  if (rawProvides is! List<dynamic>) {
    throw const MtnMinecraftModInfoProviderException(
      MtnMinecraftModInfoProviderError.invalidData,
    );
  }

  final List<String> providedIds = <String>[];
  for (final Object? value in rawProvides) {
    if (value is! String || value.isEmpty) {
      throw const MtnMinecraftModInfoProviderException(
        MtnMinecraftModInfoProviderError.invalidData,
      );
    }
    if (!providedIds.contains(value)) providedIds.add(value);
  }
  return providedIds;
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
    final ArchiveFile? file = MtnMinecraftModInfoProviderArchive.findFile(archive, rawIcon);
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

    final ArchiveFile? file = MtnMinecraftModInfoProviderArchive.findFile(archive, rawPath);
    if (file != null && file.isFile) {
      paths[width] = rawPath;
    }
  }

  return paths.isEmpty ? null : _FabricIcon.sized(paths);
}
