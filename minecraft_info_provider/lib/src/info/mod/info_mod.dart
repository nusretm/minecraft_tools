import 'dart:io';

import 'package:path/path.dart' as p;

/// One normalized Minecraft mod discovered from an installed or embedded JAR.
final class MtnMinecraftInfoMod {
  MtnMinecraftInfoMod({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    Iterable<String> authors = const <String>[],
    Iterable<String> modTypes = const <String>[],
    Iterable<MtnMinecraftInfoMod> parentMods =
        const <MtnMinecraftInfoMod>[],
    Iterable<File> installedFiles = const <File>[],
  })  : _authors = List<String>.of(authors),
        _modTypes = List<String>.of(modTypes),
        _parentMods = List<MtnMinecraftInfoMod>.of(parentMods),
        _installedFiles = List<File>.of(installedFiles);

  final String id;
  final String name;
  final String version;
  final String description;

  final List<String> _authors;
  final List<String> _modTypes;
  final List<MtnMinecraftInfoMod> _parentMods;
  final List<File> _installedFiles;

  List<String> get authors => List<String>.unmodifiable(_authors);

  /// Registered provider names that recognized this logical mod.
  List<String> get modTypes => List<String>.unmodifiable(_modTypes);

  /// Logical mods that embed this mod.
  List<MtnMinecraftInfoMod> get parentMods =>
      List<MtnMinecraftInfoMod>.unmodifiable(_parentMods);

  /// Root JAR files under the game directory that directly provide this mod.
  List<File> get installedFiles => List<File>.unmodifiable(_installedFiles);

  bool get isInstalled => _installedFiles.isNotEmpty;

  bool get isEmbedded => _parentMods.isNotEmpty;

  void addAuthor(String author) {
    if (!_authors.contains(author)) _authors.add(author);
  }

  void addAuthors(Iterable<String> authors) {
    for (final String author in authors) {
      addAuthor(author);
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
}
