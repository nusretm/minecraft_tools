import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'info_mod_dependency.dart';
import 'info_mod_urls.dart';

typedef MtnMinecraftInfoModIconLoader = Future<Uint8List?> Function(
  int size,
);

/// One normalized Minecraft mod discovered from an installed or embedded JAR.
final class MtnMinecraftInfoMod {
  MtnMinecraftInfoMod({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    Iterable<String> authors = const <String>[],
    Iterable<String> contributors = const <String>[],
    Iterable<String> licenses = const <String>[],
    this.urls = const MtnMinecraftInfoModUrls(),
    bool clientSide = true,
    bool serverSide = true,
    Iterable<MtnMinecraftInfoModDependency> dependencies =
        const <MtnMinecraftInfoModDependency>[],
    Iterable<String> providedIds = const <String>[],
    Iterable<String> modTypes = const <String>[],
    Iterable<MtnMinecraftInfoMod> parentMods =
        const <MtnMinecraftInfoMod>[],
    Iterable<File> installedFiles = const <File>[],
    Iterable<MtnMinecraftInfoModIconLoader> iconLoaders =
        const <MtnMinecraftInfoModIconLoader>[],
  })  : _authors = List<String>.of(authors),
        _contributors = List<String>.of(contributors),
        _licenses = List<String>.of(licenses),
        _clientSide = clientSide,
        _serverSide = serverSide,
        _dependencies = List<MtnMinecraftInfoModDependency>.of(dependencies),
        _providedIds = List<String>.of(providedIds),
        _modTypes = List<String>.of(modTypes),
        _parentMods = List<MtnMinecraftInfoMod>.of(parentMods),
        _installedFiles = List<File>.of(installedFiles),
        _iconLoaders = List<MtnMinecraftInfoModIconLoader>.of(iconLoaders);

  final String id;
  final String name;
  final String version;
  final String description;

  final List<String> _authors;
  final List<String> _contributors;
  final List<String> _licenses;
  MtnMinecraftInfoModUrls urls;
  bool _clientSide;
  bool _serverSide;
  final List<MtnMinecraftInfoModDependency> _dependencies;
  final List<String> _providedIds;
  final List<String> _modTypes;
  final List<MtnMinecraftInfoMod> _parentMods;
  final List<File> _installedFiles;
  final List<MtnMinecraftInfoModIconLoader> _iconLoaders;

  List<String> get authors => List<String>.unmodifiable(_authors);

  List<String> get contributors => List<String>.unmodifiable(_contributors);

  List<String> get licenses => List<String>.unmodifiable(_licenses);

  bool get clientSide => _clientSide;

  bool get serverSide => _serverSide;

  List<MtnMinecraftInfoModDependency> get dependencies =>
      List<MtnMinecraftInfoModDependency>.unmodifiable(_dependencies);

  /// Other mod IDs that this logical mod declares it provides.
  List<String> get providedIds => List<String>.unmodifiable(_providedIds);

  /// Registered provider names that recognized this logical mod.
  List<String> get modTypes => List<String>.unmodifiable(_modTypes);

  /// Logical mods that embed this mod.
  List<MtnMinecraftInfoMod> get parentMods =>
      List<MtnMinecraftInfoMod>.unmodifiable(_parentMods);

  /// Root JAR files under the game directory that directly provide this mod.
  List<File> get installedFiles => List<File>.unmodifiable(_installedFiles);

  bool get isInstalled => _installedFiles.isNotEmpty;

  bool get isEmbedded => _parentMods.isNotEmpty;

  bool get hasIcon => _iconLoaders.isNotEmpty;

  /// Reads this mod's icon bytes lazily.
  ///
  /// [size] is the preferred square icon width. Providers may expose multiple
  /// icon sizes and choose the closest suitable source for the request.
  Future<Uint8List?> getIcon({
    int size = 128,
  }) async {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be greater than zero');
    }

    for (final MtnMinecraftInfoModIconLoader loader in _iconLoaders) {
      final Uint8List? icon = await loader(size);
      if (icon != null) return Uint8List.fromList(icon);
    }
    return null;
  }

  void addAuthor(String author) {
    if (!_authors.contains(author)) _authors.add(author);
  }

  void addAuthors(Iterable<String> authors) {
    for (final String author in authors) {
      addAuthor(author);
    }
  }

  void addContributor(String contributor) {
    if (!_contributors.contains(contributor)) _contributors.add(contributor);
  }

  void addContributors(Iterable<String> contributors) {
    for (final String contributor in contributors) {
      addContributor(contributor);
    }
  }

  void addLicense(String license) {
    if (!_licenses.contains(license)) _licenses.add(license);
  }

  void addLicenses(Iterable<String> licenses) {
    for (final String license in licenses) {
      addLicense(license);
    }
  }

  void mergeUrls(MtnMinecraftInfoModUrls other) {
    urls = urls.mergeMissing(other);
  }

  void addSideSupport({
    required bool clientSide,
    required bool serverSide,
  }) {
    _clientSide = _clientSide || clientSide;
    _serverSide = _serverSide || serverSide;
  }

  void addDependency(MtnMinecraftInfoModDependency dependency) {
    if (!_dependencies.contains(dependency)) _dependencies.add(dependency);
  }

  void addDependencies(
    Iterable<MtnMinecraftInfoModDependency> dependencies,
  ) {
    for (final MtnMinecraftInfoModDependency dependency in dependencies) {
      addDependency(dependency);
    }
  }

  void addProvidedId(String providedId) {
    if (!_providedIds.contains(providedId)) _providedIds.add(providedId);
  }

  void addProvidedIds(Iterable<String> providedIds) {
    for (final String providedId in providedIds) {
      addProvidedId(providedId);
    }
  }

  void addModType(String modType) {
    if (!_modTypes.contains(modType)) _modTypes.add(modType);
  }

  void addParentMod(MtnMinecraftInfoMod parentMod) {
    if (!_parentMods.contains(parentMod)) _parentMods.add(parentMod);
  }

  bool removeParentMod(MtnMinecraftInfoMod parentMod) =>
      _parentMods.remove(parentMod);

  void addInstalledFile(File file) {
    final String path = p.normalize(p.absolute(file.path));
    if (_installedFiles.any(
      (File current) => p.equals(
        p.normalize(p.absolute(current.path)),
        path,
      ),
    )) {
      return;
    }
    _installedFiles.add(File(path));
  }

  bool removeInstalledFile(File file) {
    final String path = p.normalize(p.absolute(file.path));
    final int index = _installedFiles.indexWhere(
      (File current) => p.equals(
        p.normalize(p.absolute(current.path)),
        path,
      ),
    );
    if (index < 0) return false;
    _installedFiles.removeAt(index);
    return true;
  }

  void addIconLoader(MtnMinecraftInfoModIconLoader loader) {
    _iconLoaders.add(loader);
  }
}
