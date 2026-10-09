import 'dart:convert';
import 'dart:io';

import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';

/// This belongs to the example/providers, not the generic VersionList.
MtnLauncherGameVersionType minecraftTypeFromId(String version, {String? manifestType}) {
  final id = version.toLowerCase();
  if (id.contains('experimental')) return MtnLauncherGameVersionType.experimental;
  if (RegExp(r'(?:-pre\d+|[ -]pre-release[ -]?\d+)$').hasMatch(id)) return MtnLauncherGameVersionType.preRelease;
  if (RegExp(r'(?:-rc\d+|[ -]release candidate[ -]?\d+)$').hasMatch(id)) return MtnLauncherGameVersionType.releaseCandidate;
  switch (manifestType) {
    case 'release': return MtnLauncherGameVersionType.release;
    case 'old_alpha': return MtnLauncherGameVersionType.alpha;
    case 'old_beta': return MtnLauncherGameVersionType.beta;
    case 'snapshot': return MtnLauncherGameVersionType.snapshot;
  }
  if (RegExp(r'^a\d').hasMatch(id)) return MtnLauncherGameVersionType.alpha;
  if (RegExp(r'^b\d').hasMatch(id)) return MtnLauncherGameVersionType.beta;
  if (RegExp(r'^(?:\d{2}w\d{2}[a-z]|.+-snapshot[-.]\d+)$').hasMatch(id)) return MtnLauncherGameVersionType.snapshot;
  if (RegExp(r'^\d+\.\d+(?:\.\d+)?$').hasMatch(id)) return MtnLauncherGameVersionType.release;
  return MtnLauncherGameVersionType.unknown;
}

/// Never infer the release targeted by a week-numbered snapshot.
String minecraftVersionGroupFromId(String version) {
  final preview = RegExp(r'^(\d+\.\d+(?:\.\d+)?)(?:-(?:pre|rc)\d+| (?:Pre-Release|Release Candidate) \d+)$', caseSensitive: false).firstMatch(version);
  if (preview != null) return preview.group(1)!;
  final snapshot = RegExp(r'^(\d+\.\d+(?:\.\d+)?)-snapshot[-.]\d+$').firstMatch(version);
  return snapshot?.group(1) ?? version;
}

List<String> readMavenVersions(String xml) {
  final versions = RegExp(r'<version>\s*([^<]+?)\s*</version>').allMatches(xml).map((match) => match.group(1)!.trim()).where((value) => value.isNotEmpty).toList();
  if (versions.isEmpty) throw const FormatException('Maven XML contains no versions');
  return versions;
}

/// Best-effort inference for net.neoforged:neoforge; not its legacy forge group.
String? minecraftVersionFromNeoForge(String version) {
  final numeric = version.split('-').first.split('+').first.split('.');
  if (numeric.length < 3 || numeric.any((part) => int.tryParse(part) == null)) return null;
  final first = int.parse(numeric[0]);
  if (first >= 20 && first <= 25) {
    return numeric[1] == '0' ? '1.$first' : '1.$first.${numeric[1]}';
  }
  if (first >= 26 && numeric.length >= 4) {
    final snapshot = RegExp(r'\+snapshot-(\d+)').firstMatch(version);
    if (snapshot != null) return '$first.${numeric[1]}-snapshot-${snapshot.group(1)}';
    return numeric[2] == '0' ? '$first.${numeric[1]}' : '$first.${numeric[1]}.${numeric[2]}';
  }
  return null;
}

Future<void> printLoader(String title, MtnLauncherGameLoaderVersionList list, String mcVersion) async {
  await list.load();
  stdout.writeln('\n$title: ${list.minecraftVersions.length} supported Minecraft entries');
  stdout.writeln('  Supports $mcVersion: ${list.supportsMinecraftVersion(mcVersion)}');
  if (!list.hasMinecraftVersionCatalog) stdout.writeln('  Warning: catalog unavailable; support is UNKNOWN');
  if (list.errorCode != 0) stdout.writeln('  Warning [${list.errorCode}]: ${list.errorMessage}');
  if (!list.supportsMinecraftVersion(mcVersion)) return;

  // Real launcher UI only does this after the loader has been selected.
  final versions = await list.loadMinecraftVersion(mcVersion);
  stdout.writeln('  Compatible loader builds: ${versions.length}');
  if (list.errorCode != 0) stdout.writeln('  Warning [${list.errorCode}]: ${list.errorMessage}');
  for (final version in versions.take(3)) {
    stdout.writeln('  [${version.type.name}] ${version.text} | ${version.version}');
    stdout.writeln('    ${version.url}');
  }
}

Future<void> main(List<String> args) async {
  final mcVersion = args.isEmpty ? '1.21.1' : args.first;
  final cacheDirectory = '${Directory.current.path}${Platform.pathSeparator}.mtn_loader_cache';

  // Reuse remote metadata in memory within this one example run.
  List<dynamic>? vanillaEntries;
  Future<List<dynamic>> vanillaManifest(MtnLauncherGameLoaderVersionList list) async {
    if (vanillaEntries != null) return vanillaEntries!;
    final body = await list.downloadUrl('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json');
    vanillaEntries = (jsonDecode(body) as Map<String, dynamic>)['versions'] as List<dynamic>;
    return vanillaEntries!;
  }

  final versionListVanilla = MtnLauncherGameLoaderVersionList(
    cacheDirectory: cacheDirectory,
    filename: 'vanilla-version-list.json',
    onLoadFromWeb: (list) async {
      final entries = await vanillaManifest(list);
      return entries.map((raw) {
        final entry = raw as Map<String, dynamic>;
        final id = entry['id'] as String;
        return (
          mcVersion: minecraftVersionGroupFromId(id),
          versionId: id,
          type: minecraftTypeFromId(id, manifestType: entry['type'] as String?),
        );
      }).toList();
    },
    onGenerateMinecraftVersionList: (list, game) async {
      final entries = await vanillaManifest(list);
      final entry = entries.cast<Map<String, dynamic>>().firstWhere((entry) => entry['id'] == game.versionId);
      return [MtnLauncherGameLoaderVersion(
        mcVersion: game.mcVersion,
        version: game.versionId,
        url: entry['url'] as String,
        type: game.type,
      )];
    },
  );

  final versionListFabric = MtnLauncherGameLoaderVersionList(
    cacheDirectory: cacheDirectory,
    filename: 'fabric-version-list.json',
    onLoadFromWeb: (list) async {
      final body = await list.downloadUrl('https://meta.fabricmc.net/v2/versions/game');
      return (jsonDecode(body) as List<dynamic>).map((raw) {
        final id = (raw as Map<String, dynamic>)['version'] as String;
        return (
          mcVersion: minecraftVersionGroupFromId(id),
          versionId: id,
          type: minecraftTypeFromId(id),
        );
      }).toList();
    },
    onGenerateMinecraftVersionList: (list, game) async {
      final base = 'https://meta.fabricmc.net/v2/versions/loader/${Uri.encodeComponent(game.versionId)}';
      final body = await list.downloadUrl(base);
      return (jsonDecode(body) as List<dynamic>).map((raw) {
        final version = ((raw as Map<String, dynamic>)['loader'] as Map<String, dynamic>)['version'] as String;
        return MtnLauncherGameLoaderVersion(
          mcVersion: game.mcVersion,
          version: version,
          url: '$base/${Uri.encodeComponent(version)}/profile/json',
          type: game.type,
        );
      }).toList();
    },
  );

  final versionListQuilt = MtnLauncherGameLoaderVersionList(
    cacheDirectory: cacheDirectory,
    filename: 'quilt-version-list.json',
    onLoadFromWeb: (list) async {
      final body = await list.downloadUrl('https://meta.quiltmc.org/v3/versions/game');
      return (jsonDecode(body) as List<dynamic>).map((raw) {
        final id = (raw as Map<String, dynamic>)['version'] as String;
        return (
          mcVersion: minecraftVersionGroupFromId(id),
          versionId: id,
          type: minecraftTypeFromId(id),
        );
      }).toList();
    },
    onGenerateMinecraftVersionList: (list, game) async {
      final base = 'https://meta.quiltmc.org/v3/versions/loader/${Uri.encodeComponent(game.versionId)}';
      final body = await list.downloadUrl(base);
      return (jsonDecode(body) as List<dynamic>).map((raw) {
        final version = ((raw as Map<String, dynamic>)['loader'] as Map<String, dynamic>)['version'] as String;
        return MtnLauncherGameLoaderVersion(
          mcVersion: game.mcVersion,
          version: version,
          url: '$base/${Uri.encodeComponent(version)}/profile/json',
          type: game.type,
        );
      }).toList();
    },
  );

  const forgeBase = 'https://maven.minecraftforge.net/net/minecraftforge/forge';
  List<String>? forgeTags;
  Future<List<String>> fetchForge(MtnLauncherGameLoaderVersionList list) async {
    if (forgeTags != null) return forgeTags!;
    forgeTags = readMavenVersions(await list.downloadUrl('$forgeBase/maven-metadata.xml'));
    return forgeTags!;
  }

  final versionListForge = MtnLauncherGameLoaderVersionList(
    cacheDirectory: cacheDirectory,
    filename: 'forge-version-list.json',
    onLoadFromWeb: (list) async {
      final tags = await fetchForge(list);
      final supported = <MtnLauncherGameLoaderMinecraftVersion>[];
      for (final tag in tags) {
        final match = RegExp(r'^(\d+(?:\.\d+){1,2})-').firstMatch(tag);
        if (match == null) continue;
        final id = match.group(1)!;
        supported.add((mcVersion: id, versionId: id, type: minecraftTypeFromId(id)));
      }
      if (supported.isEmpty) throw const FormatException('Forge metadata contains no supported Minecraft versions');
      return supported;
    },
    onGenerateMinecraftVersionList: (list, game) async {
      final tags = await fetchForge(list);
      return tags.where((tag) => tag.startsWith('${game.versionId}-')).map((version) {
        final escaped = Uri.encodeComponent(version);
        return MtnLauncherGameLoaderVersion(
          mcVersion: game.mcVersion,
          version: version,
          url: '$forgeBase/$escaped/forge-$escaped-installer.jar',
          type: game.type,
        );
      }).toList();
    },
  );

  const neoForgeBase = 'https://maven.neoforged.net/releases/net/neoforged/neoforge';
  List<String>? neoForgeTags;
  Future<List<String>> fetchNeoForge(MtnLauncherGameLoaderVersionList list) async {
    if (neoForgeTags != null) return neoForgeTags!;
    neoForgeTags = readMavenVersions(await list.downloadUrl('$neoForgeBase/maven-metadata.xml'));
    return neoForgeTags!;
  }

  final versionListNeoForge = MtnLauncherGameLoaderVersionList(
    cacheDirectory: cacheDirectory,
    filename: 'neoforge-version-list.json',
    onLoadFromWeb: (list) async {
      final tags = await fetchNeoForge(list);
      final supported = <MtnLauncherGameLoaderMinecraftVersion>[];
      for (final tag in tags) {
        final id = minecraftVersionFromNeoForge(tag);
        if (id == null) continue;
        supported.add((mcVersion: minecraftVersionGroupFromId(id), versionId: id, type: minecraftTypeFromId(id)));
      }
      if (supported.isEmpty) throw const FormatException('NeoForge metadata contains no supported Minecraft versions');
      return supported;
    },
    onGenerateMinecraftVersionList: (list, game) async {
      final tags = await fetchNeoForge(list);
      final result = <MtnLauncherGameLoaderVersion>[];
      for (final version in tags) {
        if (minecraftVersionFromNeoForge(version) != game.versionId) continue;
        final escaped = Uri.encodeComponent(version);
        result.add(MtnLauncherGameLoaderVersion(
          mcVersion: game.mcVersion,
          version: version,
          url: '$neoForgeBase/$escaped/neoforge-$escaped-installer.jar',
          type: game.type,
        ));
      }
      return result;
    },
  );

  await printLoader('Vanilla', versionListVanilla, mcVersion);
  await printLoader('Fabric', versionListFabric, mcVersion);
  await printLoader('Quilt', versionListQuilt, mcVersion);
  await printLoader('Forge', versionListForge, mcVersion);
  await printLoader('NeoForge', versionListNeoForge, mcVersion);
}