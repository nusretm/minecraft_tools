import 'dart:io';

import 'package:path/path.dart' as p;

import '../list_event.dart';
import 'info_mod.dart';
import 'info_mod_asset_source.dart';
import 'info_mod_dependency.dart';
import 'provider/minecraft_mod_info_provider.dart';

typedef MtnMinecraftModListItemCallback = void Function(
  MtnMinecraftModList list,
  MtnMinecraftInfoMod mod,
  MtnListEvent event,
);

/// Registry and normalized graph authority for discovered Minecraft mods.
final class MtnMinecraftModList {
  MtnMinecraftModList({
    Iterable<MtnMinecraftModInfoProvider> providers =
        const <MtnMinecraftModInfoProvider>[],
    this.onItem,
  }) {
    for (final MtnMinecraftModInfoProvider provider in providers) {
      register(provider);
    }
  }

  final MtnMinecraftModListItemCallback? onItem;

  final List<MtnMinecraftModInfoProvider> _providers =
      <MtnMinecraftModInfoProvider>[];
  final List<MtnMinecraftInfoMod> _mods = <MtnMinecraftInfoMod>[];
  final Map<String, _MtnMinecraftModRootSnapshot> _roots =
      <String, _MtnMinecraftModRootSnapshot>{};

  List<MtnMinecraftModInfoProvider> get providers =>
      List<MtnMinecraftModInfoProvider>.unmodifiable(_providers);

  List<MtnMinecraftInfoMod> get mods =>
      List<MtnMinecraftInfoMod>.unmodifiable(_mods);

  List<MtnMinecraftInfoModAssetSource> get assetSources {
    final List<MtnMinecraftInfoModAssetSource> result =
        <MtnMinecraftInfoModAssetSource>[];
    for (final MtnMinecraftInfoMod mod in _mods) {
      for (final MtnMinecraftInfoModAssetSource source in mod.assetSources) {
        if (result.any(
          (MtnMinecraftInfoModAssetSource current) =>
              current.sameArchive(source),
        )) {
          continue;
        }
        result.add(source);
      }
    }
    return List<MtnMinecraftInfoModAssetSource>.unmodifiable(result);
  }

  List<String> get assetNamespaces {
    final Set<String> namespaces = <String>{};
    for (final MtnMinecraftInfoModAssetSource source in assetSources) {
      namespaces.addAll(source.namespaces);
    }
    final List<String> result = namespaces.toList()..sort();
    return List<String>.unmodifiable(result);
  }

  List<MtnMinecraftInfoModAssetSource> getAssetSources(
    String namespace,
  ) {
    final List<MtnMinecraftInfoModAssetSource> result =
        <MtnMinecraftInfoModAssetSource>[];
    for (final MtnMinecraftInfoModAssetSource source in assetSources) {
      if (source.containsNamespace(namespace)) {
        result.add(source);
      }
    }
    return List<MtnMinecraftInfoModAssetSource>.unmodifiable(result);
  }

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

  /// Removes the directly installed source(s) that provide [mod].
  ///
  /// Embedded-only mods cannot be removed directly. If [mod] is also embedded
  /// by another installed mod, it remains in the list as an embedded mod.
  bool remove(MtnMinecraftInfoMod mod) {
    final MtnMinecraftInfoMod? current = _findMod(mod.id, mod.version);
    if (current == null || !current.isInstalled) return false;

    bool removed = false;
    for (final File file in current.installedFiles) {
      final String path = p.normalize(p.absolute(file.path));
      removed = _roots.remove(path) != null || removed;
    }

    if (removed) _rebuild();
    return removed;
  }

  void clear() {
    if (_roots.isEmpty && _mods.isEmpty) return;
    _roots.clear();
    _rebuild();
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
    final List<MtnMinecraftInfoMod> previous =
        List<MtnMinecraftInfoMod>.of(_mods);
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
              contributors: parsed.contributors,
              licenses: parsed.licenses,
              urls: parsed.urls,
              clientSide: parsed.clientSide,
              serverSide: parsed.serverSide,
              dependencies: parsed.dependencies,
              providedIds: parsed.providedIds,
              assetSources: parsed.assetSources,
            ),
          );

          normalized.addModType(provider.name);
          normalized.addAuthors(parsed.authors);
          normalized.addContributors(parsed.contributors);
          normalized.addLicenses(parsed.licenses);
          normalized.mergeUrls(parsed.urls);
          normalized.addSideSupport(
            clientSide: parsed.clientSide,
            serverSide: parsed.serverSide,
          );
          normalized.addDependencies(parsed.dependencies);
          normalized.addProvidedIds(parsed.providedIds);
          normalized.addAssetSources(parsed.assetSources);
          if (parsed.hasIcon) {
            normalized.addIconLoader(
              (int size) => parsed.getIcon(size: size),
            );
          }
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

    _mods
      ..clear()
      ..addAll(canonical.values);

    _emitChanges(previous);
  }

  void _emitChanges(List<MtnMinecraftInfoMod> previous) {
    final MtnMinecraftModListItemCallback? callback = onItem;
    if (callback == null) return;

    final Map<(String, String), MtnMinecraftInfoMod> oldByKey =
        <(String, String), MtnMinecraftInfoMod>{
      for (final MtnMinecraftInfoMod mod in previous)
        (mod.id, mod.version): mod,
    };
    final Map<(String, String), MtnMinecraftInfoMod> newByKey =
        <(String, String), MtnMinecraftInfoMod>{
      for (final MtnMinecraftInfoMod mod in _mods)
        (mod.id, mod.version): mod,
    };

    for (final MtnMinecraftInfoMod oldMod in previous) {
      if (!newByKey.containsKey((oldMod.id, oldMod.version))) {
        callback(this, oldMod, MtnListEvent.remove);
      }
    }

    for (final MtnMinecraftInfoMod newMod in _mods) {
      final MtnMinecraftInfoMod? oldMod =
          oldByKey[(newMod.id, newMod.version)];
      if (oldMod == null) {
        callback(this, newMod, MtnListEvent.add);
      } else if (!_sameModState(oldMod, newMod)) {
        callback(this, newMod, MtnListEvent.update);
      }
    }
  }

  bool _sameModState(
    MtnMinecraftInfoMod left,
    MtnMinecraftInfoMod right,
  ) {
    if (left.name != right.name ||
        left.description != right.description ||
        left.urls != right.urls ||
        left.clientSide != right.clientSide ||
        left.serverSide != right.serverSide ||
        left.hasIcon != right.hasIcon ||
        !_sameStrings(left.authors, right.authors) ||
        !_sameStrings(left.contributors, right.contributors) ||
        !_sameStrings(left.licenses, right.licenses) ||
        !_sameDependencies(left.dependencies, right.dependencies) ||
        !_sameStrings(left.providedIds, right.providedIds) ||
        !_sameStrings(left.modTypes, right.modTypes) ||
        !_sameAssetSources(left.assetSources, right.assetSources)) {
      return false;
    }

    final List<String> leftParents = left.parentMods
        .map((MtnMinecraftInfoMod mod) => '${mod.id}@${mod.version}')
        .toList();
    final List<String> rightParents = right.parentMods
        .map((MtnMinecraftInfoMod mod) => '${mod.id}@${mod.version}')
        .toList();
    if (!_sameStrings(leftParents, rightParents)) return false;

    final List<String> leftFiles = left.installedFiles
        .map((File file) => p.normalize(p.absolute(file.path)))
        .toList();
    final List<String> rightFiles = right.installedFiles
        .map((File file) => p.normalize(p.absolute(file.path)))
        .toList();
    return _sameStrings(leftFiles, rightFiles);
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameAssetSources(
    List<MtnMinecraftInfoModAssetSource> left,
    List<MtnMinecraftInfoModAssetSource> right,
  ) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      final MtnMinecraftInfoModAssetSource leftSource = left[index];
      final MtnMinecraftInfoModAssetSource rightSource = right[index];
      if (!leftSource.sameArchive(rightSource) ||
          !_sameStrings(leftSource.namespaces, rightSource.namespaces)) {
        return false;
      }
    }
    return true;
  }

  bool _sameDependencies(
    List<MtnMinecraftInfoModDependency> left,
    List<MtnMinecraftInfoModDependency> right,
  ) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
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
