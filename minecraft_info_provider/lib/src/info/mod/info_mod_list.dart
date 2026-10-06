import 'dart:io';

import 'package:path/path.dart' as p;

import 'info_mod.dart';
import 'provider/minecraft_mod_info_provider.dart';

/// Registry and normalized graph authority for discovered Minecraft mods.
final class MtnMinecraftModList {
  MtnMinecraftModList({
    Iterable<MtnMinecraftModInfoProvider> providers =
        const <MtnMinecraftModInfoProvider>[],
  }) {
    for (final MtnMinecraftModInfoProvider provider in providers) {
      register(provider);
    }
  }

  final List<MtnMinecraftModInfoProvider> _providers =
      <MtnMinecraftModInfoProvider>[];
  final List<MtnMinecraftInfoMod> _mods = <MtnMinecraftInfoMod>[];
  final Map<String, _MtnMinecraftModRootSnapshot> _roots =
      <String, _MtnMinecraftModRootSnapshot>{};

  List<MtnMinecraftModInfoProvider> get providers =>
      List<MtnMinecraftModInfoProvider>.unmodifiable(_providers);

  List<MtnMinecraftInfoMod> get mods =>
      List<MtnMinecraftInfoMod>.unmodifiable(_mods);

  void register(MtnMinecraftModInfoProvider provider) {
    if (provider.name.isEmpty || provider.name.trim() != provider.name) {
      throw ArgumentError.value(provider.name, 'provider.name');
    }
    if (_providers.any(
      (MtnMinecraftModInfoProvider item) => item.name == provider.name,
    )) {
      throw StateError(
        'A mod info provider named "${provider.name}" is already registered.',
      );
    }
    _providers.add(provider);
  }

  bool unregister(MtnMinecraftModInfoProvider provider) {
    final int index = _providers.indexWhere(
      (MtnMinecraftModInfoProvider item) => item.name == provider.name,
    );
    if (index < 0) return false;

    _providers.removeAt(index);
    for (final _MtnMinecraftModRootSnapshot root in _roots.values) {
      root.providerMods.remove(provider.name);
    }
    _rebuild();
    return true;
  }

  /// Parses [jarFile] through every registered provider and refreshes this root.
  Future<void> add(File jarFile) async {
    final File file = File(p.normalize(p.absolute(jarFile.path)));
    final Map<String, List<MtnMinecraftInfoMod>> providerMods =
        <String, List<MtnMinecraftInfoMod>>{};

    for (final MtnMinecraftModInfoProvider provider in _providers) {
      final List<MtnMinecraftInfoMod>? parsed = await provider.parse(file);
      if (parsed == null) continue;
      providerMods[provider.name] = parsed;
    }

    _roots[file.path] = _MtnMinecraftModRootSnapshot(
      file: file,
      providerMods: providerMods,
    );
    _rebuild();
  }

  /// Removes one directly installed JAR and every now-unreferenced embedded mod.
  bool remove(File jarFile) {
    final String path = p.normalize(p.absolute(jarFile.path));
    final bool removed = _roots.remove(path) != null;
    if (removed) _rebuild();
    return removed;
  }

  void clear() {
    _roots.clear();
    _mods.clear();
  }

  /// Returns mods embedded directly or recursively by [mod].
  List<MtnMinecraftInfoMod> getDependencyList(
    MtnMinecraftInfoMod mod, {
    bool recursive = true,
  }) {
    final MtnMinecraftInfoMod? root = _findMod(mod.id, mod.version);
    if (root == null) return const <MtnMinecraftInfoMod>[];

    final List<MtnMinecraftInfoMod> result = <MtnMinecraftInfoMod>[];
    final Set<MtnMinecraftInfoMod> visited = <MtnMinecraftInfoMod>{root};

    void collect(MtnMinecraftInfoMod parent) {
      for (final MtnMinecraftInfoMod candidate in _mods) {
        if (!candidate.parentMods.contains(parent) || !visited.add(candidate)) {
          continue;
        }
        result.add(candidate);
        if (recursive) collect(candidate);
      }
    }

    collect(root);
    return List<MtnMinecraftInfoMod>.unmodifiable(result);
  }

  MtnMinecraftInfoMod? _findMod(String id, String version) {
    for (final MtnMinecraftInfoMod mod in _mods) {
      if (mod.id == id && mod.version == version) return mod;
    }
    return null;
  }

  void _rebuild() {
    _mods.clear();

    final Map<(String, String), MtnMinecraftInfoMod> canonical =
        <(String, String), MtnMinecraftInfoMod>{};
    final Map<MtnMinecraftInfoMod, MtnMinecraftInfoMod> parsedToCanonical =
        <MtnMinecraftInfoMod, MtnMinecraftInfoMod>{};

    for (final MtnMinecraftModInfoProvider provider in _providers) {
      for (final _MtnMinecraftModRootSnapshot root in _roots.values) {
        final List<MtnMinecraftInfoMod>? parsedMods =
            root.providerMods[provider.name];
        if (parsedMods == null) continue;

        for (final MtnMinecraftInfoMod parsed in parsedMods) {
          final (String, String) key = (parsed.id, parsed.version);
          final MtnMinecraftInfoMod normalized = canonical.putIfAbsent(
            key,
            () => MtnMinecraftInfoMod(
              id: parsed.id,
              name: parsed.name,
              version: parsed.version,
              description: parsed.description,
              authors: parsed.authors,
            ),
          );

          normalized.addModType(provider.name);
          normalized.addAuthors(parsed.authors);
          if (parsed.parentMods.isEmpty) {
            normalized.addInstalledFile(root.file);
          }
          parsedToCanonical[parsed] = normalized;
        }
      }
    }

    for (final MtnMinecraftModInfoProvider provider in _providers) {
      for (final _MtnMinecraftModRootSnapshot root in _roots.values) {
        final List<MtnMinecraftInfoMod>? parsedMods =
            root.providerMods[provider.name];
        if (parsedMods == null) continue;

        for (final MtnMinecraftInfoMod parsed in parsedMods) {
          final MtnMinecraftInfoMod child = parsedToCanonical[parsed]!;
          for (final MtnMinecraftInfoMod parsedParent in parsed.parentMods) {
            final MtnMinecraftInfoMod? parent =
                parsedToCanonical[parsedParent] ??
                canonical[(parsedParent.id, parsedParent.version)];
            if (parent != null && !identical(parent, child)) {
              child.addParentMod(parent);
            }
          }
        }
      }
    }

    _mods.addAll(canonical.values);
  }
}

final class _MtnMinecraftModRootSnapshot {
  _MtnMinecraftModRootSnapshot({
    required this.file,
    required this.providerMods,
  });

  final File file;
  final Map<String, List<MtnMinecraftInfoMod>> providerMods;
}
