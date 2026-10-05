import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../nbt/minecraft_nbt.dart';
import 'info_player.dart';
import 'info_player_advancements.dart';
import 'info_player_nbt_parser.dart';
import 'info_player_stats.dart';
import 'info_server.dart';
import 'info_world.dart';

const String _serversFileName = 'servers.dat';
const String _serversTagName = 'servers';
const String _savesDirectoryName = 'saves';
const String _legacyPlayerDataDirectoryName = 'playerdata';
const String _modernPlayersDirectoryName = 'players';
const String _modernPlayerDataDirectoryName = 'data';
const String _playerStatsDirectoryName = 'stats';
const String _playerAdvancementsDirectoryName = 'advancements';

enum MtnMinecraftInfoProviderError {
  invalidPath(8101),
  readFailed(8102),
  writeFailed(8103),
  replaceFailed(8104),
  invalidData(8105);

  const MtnMinecraftInfoProviderError(this.code);

  final int code;
}

final class MtnMinecraftInfoProviderException implements Exception {
  const MtnMinecraftInfoProviderException(this.error);

  final MtnMinecraftInfoProviderError error;

  @override
  String toString() => 'MtnMinecraftInfoProviderException(${error.name})';
}

/// Reads local information from one Java Edition game directory.
final class MtnMinecraftInfoProvider {
  MtnMinecraftInfoProvider({
    required Directory gameDirectory,
  }) : gameDirectory = Directory(
          p.normalize(p.absolute(gameDirectory.path)),
        );

  static final Map<String, Future<void>> _targetLanes =
      <String, Future<void>>{};

  final Directory gameDirectory;

  File get serversFile => File(
        p.join(gameDirectory.path, _serversFileName),
      );

  Directory get savesDirectory => Directory(
        p.join(gameDirectory.path, _savesDirectoryName),
      );

  /// Discovers direct Java Edition world directories under `saves`.
  ///
  /// A missing `saves` directory is equivalent to an empty world list.
  /// Invalid/corrupt `level.dat` files are represented as world-local invalid
  /// snapshots and do not fail discovery of sibling worlds.
  Future<List<MtnMinecraftInfoWorld>> readWorlds() async {
    final FileSystemEntityType gameDirectoryType =
        await _entityType(gameDirectory.path, forWrite: false);
    if (gameDirectoryType != FileSystemEntityType.directory) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    final FileSystemEntityType savesType =
        await _entityType(savesDirectory.path, forWrite: false);
    if (savesType == FileSystemEntityType.notFound) {
      return const <MtnMinecraftInfoWorld>[];
    }
    if (savesType != FileSystemEntityType.directory) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    late final List<FileSystemEntity> children;
    try {
      children = await savesDirectory.list(followLinks: false).toList();
    } on FileSystemException {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.readFailed,
      );
    }

    final List<Directory> directories = children.whereType<Directory>().toList()
      ..sort(
        (Directory left, Directory right) =>
            p.basename(left.path).compareTo(p.basename(right.path)),
      );
    final List<MtnMinecraftInfoWorld> worlds = <MtnMinecraftInfoWorld>[];
    for (final Directory directory in directories) {
      final String directoryName = p.basename(directory.path);
      final File levelFile = File(p.join(directory.path, 'level.dat'));
      late final FileSystemEntityType levelType;
      try {
        levelType = await FileSystemEntity.type(
          levelFile.path,
          followLinks: false,
        );
      } on FileSystemException {
        worlds.add(
          MtnMinecraftInfoWorld.invalid(
            directory: directory,
            directoryName: directoryName,
            error: MtnMinecraftInfoWorldError.readFailed,
          ),
        );
        continue;
      }
      if (levelType != FileSystemEntityType.file) continue;
      worlds.add(await _readWorld(directory));
    }
    return List<MtnMinecraftInfoWorld>.unmodifiable(worlds);
  }

  /// Discovers Java Edition player-data files belonging to [world].
  ///
  /// Both the pre-26.1 `playerdata/<uuid>.dat` layout and the 26.1+
  /// `players/data/<uuid>.dat` layout are supported. If the same UUID exists
  /// in both locations, the modern file is authoritative.
  ///
  /// Missing player-data directories are equivalent to an empty list.
  /// Invalid/corrupt player files are returned as player-local invalid
  /// snapshots and do not fail discovery of sibling players.
  Future<List<MtnMinecraftInfoPlayer>> readPlayers(
    MtnMinecraftInfoWorld world,
  ) async {
    await _validateWorldDirectory(world, forWrite: false);
    return _readPlayersFromDirectory(world.directory);
  }

  /// Reads the statistics snapshot belonging to [player] in [world].
  ///
  /// Both the pre-26.1 `stats/<uuid>.json` layout and the 26.1+
  /// `players/stats/<uuid>.json` layout are supported. If the same UUID
  /// exists in both locations, the modern file is authoritative.
  ///
  /// A missing stats file is represented by null. A present but unreadable,
  /// malformed or schema-invalid stats file is returned as an invalid
  /// [MtnMinecraftInfoPlayerStats] snapshot.
  Future<MtnMinecraftInfoPlayerStats?> readPlayerStats(
    MtnMinecraftInfoWorld world,
    MtnMinecraftInfoPlayer player,
  ) async {
    final _PlayerJsonResource? resource = await _readPlayerJsonResource(
      world,
      player,
      resourceDirectoryName: _playerStatsDirectoryName,
    );
    if (resource == null) return null;

    final MtnMinecraftInfoPlayerStatsStorageLayout storageLayout =
        switch (resource.storageLayout) {
      _PlayerJsonResourceStorageLayout.legacy =>
        MtnMinecraftInfoPlayerStatsStorageLayout.legacy,
      _PlayerJsonResourceStorageLayout.modern =>
        MtnMinecraftInfoPlayerStatsStorageLayout.modern,
    };

    final _PlayerJsonResourceError? resourceError = resource.error;
    if (resourceError != null) {
      return MtnMinecraftInfoPlayerStats.invalid(
        uuid: resource.uuid,
        file: resource.file,
        storageLayout: storageLayout,
        error: switch (resourceError) {
          _PlayerJsonResourceError.readFailed =>
            MtnMinecraftInfoPlayerStatsError.readFailed,
          _PlayerJsonResourceError.invalidJson =>
            MtnMinecraftInfoPlayerStatsError.invalidJson,
        },
      );
    }

    try {
      return _playerStatsFromJson(
        resource: resource,
        storageLayout: storageLayout,
      );
    } on _InvalidPlayerStatsData {
      return MtnMinecraftInfoPlayerStats.invalid(
        uuid: resource.uuid,
        file: resource.file,
        storageLayout: storageLayout,
        error: MtnMinecraftInfoPlayerStatsError.invalidData,
      );
    }
  }

  /// Reads the advancement progress snapshot belonging to [player] in [world].
  ///
  /// Both the pre-26.1 `advancements/<uuid>.json` layout and the 26.1+
  /// `players/advancements/<uuid>.json` layout are supported. If the same
  /// UUID exists in both locations, the modern file is authoritative.
  ///
  /// A missing advancements file is represented by null. A present but
  /// unreadable, malformed or schema-invalid file is returned as an invalid
  /// [MtnMinecraftInfoPlayerAdvancements] snapshot.
  Future<MtnMinecraftInfoPlayerAdvancements?> readPlayerAdvancements(
    MtnMinecraftInfoWorld world,
    MtnMinecraftInfoPlayer player,
  ) async {
    final _PlayerJsonResource? resource = await _readPlayerJsonResource(
      world,
      player,
      resourceDirectoryName: _playerAdvancementsDirectoryName,
    );
    if (resource == null) return null;

    final MtnMinecraftInfoPlayerAdvancementsStorageLayout storageLayout =
        switch (resource.storageLayout) {
      _PlayerJsonResourceStorageLayout.legacy =>
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.legacy,
      _PlayerJsonResourceStorageLayout.modern =>
        MtnMinecraftInfoPlayerAdvancementsStorageLayout.modern,
    };

    final _PlayerJsonResourceError? resourceError = resource.error;
    if (resourceError != null) {
      return MtnMinecraftInfoPlayerAdvancements.invalid(
        uuid: resource.uuid,
        file: resource.file,
        storageLayout: storageLayout,
        error: switch (resourceError) {
          _PlayerJsonResourceError.readFailed =>
            MtnMinecraftInfoPlayerAdvancementsError.readFailed,
          _PlayerJsonResourceError.invalidJson =>
            MtnMinecraftInfoPlayerAdvancementsError.invalidJson,
        },
      );
    }

    try {
      return _playerAdvancementsFromJson(
        resource: resource,
        storageLayout: storageLayout,
      );
    } on _InvalidPlayerAdvancementsData {
      return MtnMinecraftInfoPlayerAdvancements.invalid(
        uuid: resource.uuid,
        file: resource.file,
        storageLayout: storageLayout,
        error: MtnMinecraftInfoPlayerAdvancementsError.invalidData,
      );
    }
  }

  /// Atomically replaces the Java Edition `icon.png` for [world].
  ///
  /// The provider persists the supplied bytes as-is. PNG decoding, resizing
  /// and image editing remain caller/UI responsibilities.
  Future<void> writeWorldIcon(
    MtnMinecraftInfoWorld world,
    Uint8List icon,
  ) {
    final Uint8List bytes = Uint8List.fromList(icon);
    return _inTargetLane<void>(world.iconFile.path, () async {
      await _validateWorldDirectory(world, forWrite: true);
      await _writeFileAtomic(world.iconFile, bytes);
    });
  }

  Future<List<MtnMinecraftInfoPlayer>> _readPlayersFromDirectory(
    Directory worldDirectory,
  ) async {
    final Map<String, _PlayerDataCandidate> candidates =
        <String, _PlayerDataCandidate>{};

    await _collectPlayerDataCandidates(
      directory: Directory(
        p.join(worldDirectory.path, _legacyPlayerDataDirectoryName),
      ),
      storageLayout: MtnMinecraftInfoPlayerStorageLayout.legacy,
      candidates: candidates,
      replaceExisting: false,
    );

    await _collectPlayerDataCandidates(
      directory: Directory(
        p.join(
          worldDirectory.path,
          _modernPlayersDirectoryName,
          _modernPlayerDataDirectoryName,
        ),
      ),
      storageLayout: MtnMinecraftInfoPlayerStorageLayout.modern,
      candidates: candidates,
      replaceExisting: true,
    );

    final List<_PlayerDataCandidate> ordered = candidates.values.toList()
      ..sort(
        (_PlayerDataCandidate left, _PlayerDataCandidate right) =>
            left.uuid.compareTo(right.uuid),
      );

    final List<MtnMinecraftInfoPlayer> players = <MtnMinecraftInfoPlayer>[];
    for (final _PlayerDataCandidate candidate in ordered) {
      players.add(await _readPlayer(candidate));
    }
    return List<MtnMinecraftInfoPlayer>.unmodifiable(players);
  }

  /// Reads the current Java Edition saved-server list.
  ///
  /// A missing `servers.dat` is equivalent to an empty saved-server list.
  Future<List<MtnMinecraftInfoServer>> readServers() =>
      _inTargetLane<List<MtnMinecraftInfoServer>>(
        serversFile.path,
        _readServersUnlocked,
      );

  /// Appends one server while preserving every existing NBT tag.
  ///
  /// This operation intentionally does not deduplicate addresses; matching and
  /// known-network policy belong to the later context/rules checkpoint.
  Future<void> addServer(MtnMinecraftInfoServer server) =>
      _inTargetLane<void>(serversFile.path, () async {
        final MtnMinecraftNbtDocument document = await _loadDocumentForWrite();
        final Map<String, MtnMinecraftNbtValue> root =
            Map<String, MtnMinecraftNbtValue>.from(document.root.asCompound);
        final MtnMinecraftNbtValue? servers = root[_serversTagName];
        final MtnMinecraftNbtList list;
        if (servers == null) {
          list = MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.compound,
            values: const <MtnMinecraftNbtValue>[],
          );
        } else {
          if (servers.type != MtnMinecraftNbtType.list ||
              servers.asList.elementType != MtnMinecraftNbtType.compound) {
            throw const MtnMinecraftInfoProviderException(
              MtnMinecraftInfoProviderError.invalidData,
            );
          }
          list = servers.asList;
        }

        final List<MtnMinecraftNbtValue> values =
            List<MtnMinecraftNbtValue>.of(list.values)
              ..add(_serverToNbt(server));
        root[_serversTagName] = MtnMinecraftNbtValue.list(
          MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.compound,
            values: values,
          ),
        );

        final MtnMinecraftNbtDocument updated = MtnMinecraftNbtDocument(
          name: document.name,
          root: MtnMinecraftNbtValue.compound(root),
        );
        final Uint8List encoded = const MtnMinecraftNbtCodec().encode(updated);
        await _writeUnlocked(encoded);
      });

  Future<List<MtnMinecraftInfoServer>> _readServersUnlocked() async {
    await _validatePath(forWrite: false);
    final FileStat stat = await _stat(forWrite: false);
    if (stat.type == FileSystemEntityType.notFound) {
      return const <MtnMinecraftInfoServer>[];
    }
    if (stat.type != FileSystemEntityType.file) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    final MtnMinecraftNbtDocument document = await _readDocument();
    final MtnMinecraftNbtValue? servers =
        document.root.asCompound[_serversTagName];
    if (servers == null) return const <MtnMinecraftInfoServer>[];
    if (servers.type != MtnMinecraftNbtType.list ||
        servers.asList.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidData,
      );
    }

    final List<MtnMinecraftInfoServer> result = <MtnMinecraftInfoServer>[];
    for (final MtnMinecraftNbtValue value in servers.asList.values) {
      result.add(_serverFromNbt(value));
    }
    return List<MtnMinecraftInfoServer>.unmodifiable(result);
  }

  Future<MtnMinecraftInfoWorld> _readWorld(Directory directory) async {
    final String directoryName = p.basename(directory.path);

    List<MtnMinecraftInfoPlayer> players = const <MtnMinecraftInfoPlayer>[];
    MtnMinecraftInfoWorldPlayersState playersState =
        MtnMinecraftInfoWorldPlayersState.available;
    MtnMinecraftInfoWorldPlayersError? playersError;
    try {
      players = await _readPlayersFromDirectory(directory);
    } on MtnMinecraftInfoProviderException catch (exception) {
      playersState = MtnMinecraftInfoWorldPlayersState.invalid;
      if (exception.error == MtnMinecraftInfoProviderError.invalidPath) {
        playersError = MtnMinecraftInfoWorldPlayersError.invalidPath;
      } else if (exception.error == MtnMinecraftInfoProviderError.readFailed) {
        playersError = MtnMinecraftInfoWorldPlayersError.readFailed;
      } else {
        rethrow;
      }
    }

    final Uint8List? icon = await _readWorldIcon(directory);
    final File levelFile = File(p.join(directory.path, 'level.dat'));
    late final List<int> compressed;
    try {
      compressed = await levelFile.readAsBytes();
    } on FileSystemException {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
        error: MtnMinecraftInfoWorldError.readFailed,
      );
    }

    late final List<int> decoded;
    try {
      decoded = gzip.decode(compressed);
    } on FormatException {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
        error: MtnMinecraftInfoWorldError.invalidCompression,
      );
    }

    late final MtnMinecraftNbtDocument document;
    try {
      document = const MtnMinecraftNbtCodec().decode(decoded);
    } on MtnMinecraftNbtException {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
        error: MtnMinecraftInfoWorldError.invalidNbt,
      );
    }

    try {
      return _worldFromNbt(
        directory: directory,
        directoryName: directoryName,
        document: document,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
      );
    } on _InvalidWorldData {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
        players: players,
        playersState: playersState,
        playersError: playersError,
        icon: icon,
        error: MtnMinecraftInfoWorldError.invalidData,
      );
    }
  }

  Future<Uint8List?> _readWorldIcon(Directory directory) async {
    final File iconFile = File(
      p.join(directory.path, MtnMinecraftInfoWorld.iconFileName),
    );
    try {
      final FileSystemEntityType type = await FileSystemEntity.type(
        iconFile.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.file) return null;
      return await iconFile.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _validateWorldDirectory(
    MtnMinecraftInfoWorld world, {
    required bool forWrite,
  }) async {
    final FileSystemEntityType gameDirectoryType =
        await _entityType(gameDirectory.path, forWrite: forWrite);
    final FileSystemEntityType savesType =
        await _entityType(savesDirectory.path, forWrite: forWrite);
    final String savesPath = p.normalize(p.absolute(savesDirectory.path));
    final String worldPath = p.normalize(p.absolute(world.directory.path));

    if (gameDirectoryType != FileSystemEntityType.directory ||
        savesType != FileSystemEntityType.directory ||
        !p.equals(p.dirname(worldPath), savesPath)) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    final FileSystemEntityType worldType =
        await _entityType(worldPath, forWrite: forWrite);
    if (worldType != FileSystemEntityType.directory) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }
  }

  Future<void> _validatePlayerForWorld(
    MtnMinecraftInfoWorld world,
    MtnMinecraftInfoPlayer player,
  ) async {
    await _validateWorldDirectory(world, forWrite: false);

    final String worldPath = p.normalize(p.absolute(world.directory.path));
    final String expectedDirectoryPath = switch (player.storageLayout) {
      MtnMinecraftInfoPlayerStorageLayout.legacy => p.join(
          worldPath,
          _legacyPlayerDataDirectoryName,
        ),
      MtnMinecraftInfoPlayerStorageLayout.modern => p.join(
          worldPath,
          _modernPlayersDirectoryName,
          _modernPlayerDataDirectoryName,
        ),
    };
    final String playerFilePath = p.normalize(p.absolute(player.dataFile.path));
    final RegExpMatch? match = _playerDataFilePattern.firstMatch(
      p.basename(playerFilePath),
    );

    if (!p.equals(p.dirname(playerFilePath), expectedDirectoryPath) ||
        match == null ||
        match.group(1)!.toLowerCase() != player.uuid) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }
  }

  Future<_PlayerJsonResource?> _readPlayerJsonResource(
    MtnMinecraftInfoWorld world,
    MtnMinecraftInfoPlayer player, {
    required String resourceDirectoryName,
  }) async {
    await _validatePlayerForWorld(world, player);

    final _PlayerJsonResourceCandidate? modern =
        await _findPlayerJsonResourceCandidate(
      directory: Directory(
        p.join(
          world.directory.path,
          _modernPlayersDirectoryName,
          resourceDirectoryName,
        ),
      ),
      uuid: player.uuid,
      storageLayout: _PlayerJsonResourceStorageLayout.modern,
    );
    if (modern != null) return _decodePlayerJsonResource(modern);

    final _PlayerJsonResourceCandidate? legacy =
        await _findPlayerJsonResourceCandidate(
      directory: Directory(
        p.join(world.directory.path, resourceDirectoryName),
      ),
      uuid: player.uuid,
      storageLayout: _PlayerJsonResourceStorageLayout.legacy,
    );
    if (legacy == null) return null;
    return _decodePlayerJsonResource(legacy);
  }

  Future<_PlayerJsonResourceCandidate?> _findPlayerJsonResourceCandidate({
    required Directory directory,
    required String uuid,
    required _PlayerJsonResourceStorageLayout storageLayout,
  }) async {
    final FileSystemEntityType directoryType =
        await _entityType(directory.path, forWrite: false);
    if (directoryType == FileSystemEntityType.notFound) return null;
    if (directoryType != FileSystemEntityType.directory) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    late final List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList()
        ..sort(
          (FileSystemEntity left, FileSystemEntity right) =>
              p.basename(left.path).compareTo(p.basename(right.path)),
        );
    } on FileSystemException {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.readFailed,
      );
    }

    for (final FileSystemEntity entry in entries) {
      if (entry is! File) continue;
      final RegExpMatch? match =
          _playerJsonFilePattern.firstMatch(p.basename(entry.path));
      if (match == null || match.group(1)!.toLowerCase() != uuid) continue;
      return _PlayerJsonResourceCandidate(
        uuid: uuid,
        file: entry,
        storageLayout: storageLayout,
      );
    }
    return null;
  }

  Future<_PlayerJsonResource> _decodePlayerJsonResource(
    _PlayerJsonResourceCandidate candidate,
  ) async {
    late final String source;
    try {
      source = await candidate.file.readAsString();
    } on FileSystemException {
      return candidate.error(_PlayerJsonResourceError.readFailed);
    } on FormatException {
      return candidate.error(_PlayerJsonResourceError.invalidJson);
    }

    try {
      return candidate.available(jsonDecode(source));
    } on FormatException {
      return candidate.error(_PlayerJsonResourceError.invalidJson);
    }
  }

  Future<void> _collectPlayerDataCandidates({
    required Directory directory,
    required MtnMinecraftInfoPlayerStorageLayout storageLayout,
    required Map<String, _PlayerDataCandidate> candidates,
    required bool replaceExisting,
  }) async {
    final FileSystemEntityType directoryType =
        await _entityType(directory.path, forWrite: false);
    if (directoryType == FileSystemEntityType.notFound) return;
    if (directoryType != FileSystemEntityType.directory) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    late final List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList()
        ..sort(
          (FileSystemEntity left, FileSystemEntity right) =>
              p.basename(left.path).compareTo(p.basename(right.path)),
        );
    } on FileSystemException {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.readFailed,
      );
    }

    for (final FileSystemEntity entry in entries) {
      if (entry is! File) continue;

      final RegExpMatch? match =
          _playerDataFilePattern.firstMatch(p.basename(entry.path));
      if (match == null) continue;

      final String uuid = match.group(1)!.toLowerCase();
      final _PlayerDataCandidate candidate = _PlayerDataCandidate(
        uuid: uuid,
        file: entry,
        storageLayout: storageLayout,
      );

      if (replaceExisting) {
        candidates[uuid] = candidate;
      } else {
        candidates.putIfAbsent(uuid, () => candidate);
      }
    }
  }

  Future<MtnMinecraftInfoPlayer> _readPlayer(
    _PlayerDataCandidate candidate,
  ) async {
    late final List<int> compressed;
    try {
      compressed = await candidate.file.readAsBytes();
    } on FileSystemException {
      return candidate.invalid(MtnMinecraftInfoPlayerError.readFailed);
    }

    late final List<int> decoded;
    try {
      decoded = gzip.decode(compressed);
    } on FormatException {
      return candidate.invalid(
        MtnMinecraftInfoPlayerError.invalidCompression,
      );
    }

    late final MtnMinecraftNbtDocument document;
    try {
      document = const MtnMinecraftNbtCodec().decode(decoded);
    } on MtnMinecraftNbtException {
      return candidate.invalid(MtnMinecraftInfoPlayerError.invalidNbt);
    }

    try {
      return const MtnMinecraftInfoPlayerNbtParser().parse(
        uuid: candidate.uuid,
        dataFile: candidate.file,
        storageLayout: candidate.storageLayout,
        document: document,
      );
    } on MtnMinecraftInfoPlayerNbtParserException {
      return candidate.invalid(MtnMinecraftInfoPlayerError.invalidData);
    }
  }

  Future<MtnMinecraftNbtDocument> _loadDocumentForWrite() async {
    await _validatePath(forWrite: true);
    final FileStat stat = await _stat(forWrite: true);
    if (stat.type == FileSystemEntityType.notFound) {
      return MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{},
        ),
      );
    }
    if (stat.type != FileSystemEntityType.file) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }
    return _readDocument();
  }

  Future<MtnMinecraftNbtDocument> _readDocument() async {
    late final Uint8List bytes;
    try {
      bytes = await serversFile.readAsBytes();
    } on FileSystemException {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.readFailed,
      );
    }
    try {
      final MtnMinecraftNbtDocument document =
          const MtnMinecraftNbtCodec().decode(bytes);
      if (document.root.type != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoProviderException(
          MtnMinecraftInfoProviderError.invalidData,
        );
      }
      return document;
    } on MtnMinecraftNbtException {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidData,
      );
    }
  }

  Future<void> _writeUnlocked(Uint8List bytes) async {
    await _validatePath(forWrite: true);
    await _writeFileAtomic(serversFile, bytes);
  }

  Future<void> _writeFileAtomic(File target, Uint8List bytes) async {
    final String suffix = await _uniqueSuffix(target);
    final File temporary = File('${target.path}.tmp-$suffix');
    final File displaced = File('${target.path}.old-$suffix');
    RandomAccessFile? writer;
    try {
      try {
        writer = await temporary.open(mode: FileMode.write);
        await writer.writeFrom(bytes);
        await writer.flush();
        await writer.close();
        writer = null;
      } on FileSystemException {
        throw const MtnMinecraftInfoProviderException(
          MtnMinecraftInfoProviderError.writeFailed,
        );
      }
      await _replace(
        target: target,
        temporary: temporary,
        displaced: displaced,
      );
    } finally {
      if (writer != null) await _closeBestEffort(writer);
      await _deleteBestEffort(temporary);
    }
  }

  Future<void> _replace({
    required File target,
    required File temporary,
    required File displaced,
  }) async {
    final FileSystemEntityType targetType =
        await _entityType(target.path, forWrite: true);
    if (targetType != FileSystemEntityType.notFound &&
        targetType != FileSystemEntityType.file) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    var movedExisting = false;
    try {
      if (targetType == FileSystemEntityType.file) {
        await target.rename(displaced.path);
        movedExisting = true;
      }
      await temporary.rename(target.path);
      await _deleteBestEffort(displaced);
    } on FileSystemException {
      if (movedExisting &&
          await displaced.exists() &&
          !await target.exists()) {
        try {
          await displaced.rename(target.path);
        } on FileSystemException {
          throw const MtnMinecraftInfoProviderException(
            MtnMinecraftInfoProviderError.replaceFailed,
          );
        }
      }
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.replaceFailed,
      );
    }
  }

  Future<void> _validatePath({required bool forWrite}) async {
    final FileSystemEntityType directoryType =
        await _entityType(gameDirectory.path, forWrite: forWrite);
    final FileSystemEntityType fileType =
        await _entityType(serversFile.path, forWrite: forWrite);
    if (directoryType != FileSystemEntityType.directory ||
        (fileType != FileSystemEntityType.file &&
            fileType != FileSystemEntityType.notFound)) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }
  }

  Future<FileStat> _stat({required bool forWrite}) async {
    try {
      return await serversFile.stat();
    } on FileSystemException {
      throw MtnMinecraftInfoProviderException(
        forWrite
            ? MtnMinecraftInfoProviderError.writeFailed
            : MtnMinecraftInfoProviderError.readFailed,
      );
    }
  }

  Future<FileSystemEntityType> _entityType(
    String path, {
    required bool forWrite,
  }) async {
    try {
      return await FileSystemEntity.type(path, followLinks: false);
    } on FileSystemException {
      throw MtnMinecraftInfoProviderException(
        forWrite
            ? MtnMinecraftInfoProviderError.writeFailed
            : MtnMinecraftInfoProviderError.readFailed,
      );
    }
  }

  Future<String> _uniqueSuffix(File target) async {
    final Random random = Random.secure();
    while (true) {
      final String suffix = List<int>.generate(
        16,
        (_) => random.nextInt(256),
        growable: false,
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      if (!await File('${target.path}.tmp-$suffix').exists() &&
          !await File('${target.path}.old-$suffix').exists()) {
        return suffix;
      }
    }
  }
}

const String _playerUuidPattern =
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

final RegExp _playerDataFilePattern = RegExp(
  '^($_playerUuidPattern)[.]dat' r'$',
  caseSensitive: false,
);

final RegExp _playerJsonFilePattern = RegExp(
  '^($_playerUuidPattern)[.]json' r'$',
  caseSensitive: false,
);

final class _PlayerDataCandidate {
  const _PlayerDataCandidate({
    required this.uuid,
    required this.file,
    required this.storageLayout,
  });

  final String uuid;
  final File file;
  final MtnMinecraftInfoPlayerStorageLayout storageLayout;

  MtnMinecraftInfoPlayer invalid(MtnMinecraftInfoPlayerError error) =>
      MtnMinecraftInfoPlayer.invalid(
        uuid: uuid,
        dataFile: file,
        storageLayout: storageLayout,
        error: error,
      );
}

enum _PlayerJsonResourceStorageLayout {
  legacy,
  modern,
}

enum _PlayerJsonResourceError {
  readFailed,
  invalidJson,
}

final class _PlayerJsonResourceCandidate {
  const _PlayerJsonResourceCandidate({
    required this.uuid,
    required this.file,
    required this.storageLayout,
  });

  final String uuid;
  final File file;
  final _PlayerJsonResourceStorageLayout storageLayout;

  _PlayerJsonResource available(Object? value) => _PlayerJsonResource(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        value: value,
        error: null,
      );

  _PlayerJsonResource error(_PlayerJsonResourceError error) =>
      _PlayerJsonResource(
        uuid: uuid,
        file: file,
        storageLayout: storageLayout,
        value: null,
        error: error,
      );
}

final class _PlayerJsonResource {
  const _PlayerJsonResource({
    required this.uuid,
    required this.file,
    required this.storageLayout,
    required this.value,
    required this.error,
  });

  final String uuid;
  final File file;
  final _PlayerJsonResourceStorageLayout storageLayout;
  final Object? value;
  final _PlayerJsonResourceError? error;
}

final class _InvalidPlayerStatsData implements Exception {
  const _InvalidPlayerStatsData();
}

MtnMinecraftInfoPlayerStats _playerStatsFromJson({
  required _PlayerJsonResource resource,
  required MtnMinecraftInfoPlayerStatsStorageLayout storageLayout,
}) {
  final Object? value = resource.value;
  if (value is! Map<String, dynamic>) {
    throw const _InvalidPlayerStatsData();
  }

  int? dataVersion;
  if (value.containsKey('DataVersion')) {
    final Object? rawDataVersion = value['DataVersion'];
    if (rawDataVersion is! int) {
      throw const _InvalidPlayerStatsData();
    }
    dataVersion = rawDataVersion;
  }

  final Object? rawStats = value['stats'];
  if (rawStats is! Map<String, dynamic>) {
    throw const _InvalidPlayerStatsData();
  }

  final Map<String, Map<String, int>> values =
      <String, Map<String, int>>{};
  for (final MapEntry<String, dynamic> category in rawStats.entries) {
    final Object? rawEntries = category.value;
    if (rawEntries is! Map<String, dynamic>) {
      throw const _InvalidPlayerStatsData();
    }

    final Map<String, int> entries = <String, int>{};
    for (final MapEntry<String, dynamic> stat in rawEntries.entries) {
      final Object? rawValue = stat.value;
      if (rawValue is! int) {
        throw const _InvalidPlayerStatsData();
      }
      entries[stat.key] = rawValue;
    }
    values[category.key] = entries;
  }

  return MtnMinecraftInfoPlayerStats.available(
    uuid: resource.uuid,
    file: resource.file,
    storageLayout: storageLayout,
    dataVersion: dataVersion,
    values: values,
  );
}

final class _InvalidPlayerAdvancementsData implements Exception {
  const _InvalidPlayerAdvancementsData();
}

final RegExp _advancementTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$',
);

MtnMinecraftInfoPlayerAdvancements _playerAdvancementsFromJson({
  required _PlayerJsonResource resource,
  required MtnMinecraftInfoPlayerAdvancementsStorageLayout storageLayout,
}) {
  final Object? value = resource.value;
  if (value is! Map<String, dynamic>) {
    throw const _InvalidPlayerAdvancementsData();
  }

  int? dataVersion;
  final Map<String, MtnMinecraftInfoPlayerAdvancement> advancements =
      <String, MtnMinecraftInfoPlayerAdvancement>{};

  for (final MapEntry<String, dynamic> entry in value.entries) {
    if (entry.key == 'DataVersion') {
      if (entry.value is! int) {
        throw const _InvalidPlayerAdvancementsData();
      }
      dataVersion = entry.value as int;
      continue;
    }

    final Object? rawProgress = entry.value;
    if (rawProgress is! Map<String, dynamic>) {
      throw const _InvalidPlayerAdvancementsData();
    }

    final Object? rawDone = rawProgress['done'];
    final Object? rawCriteria = rawProgress['criteria'];
    if (rawDone is! bool || rawCriteria is! Map<String, dynamic>) {
      throw const _InvalidPlayerAdvancementsData();
    }

    final Map<String, DateTime> criteria = <String, DateTime>{};
    for (final MapEntry<String, dynamic> criterion in rawCriteria.entries) {
      final Object? rawTimestamp = criterion.value;
      if (rawTimestamp is! String) {
        throw const _InvalidPlayerAdvancementsData();
      }
      criteria[criterion.key] = _parseAdvancementTimestamp(rawTimestamp);
    }

    advancements[entry.key] = MtnMinecraftInfoPlayerAdvancement(
      id: entry.key,
      done: rawDone,
      criteria: criteria,
    );
  }

  return MtnMinecraftInfoPlayerAdvancements.available(
    uuid: resource.uuid,
    file: resource.file,
    storageLayout: storageLayout,
    dataVersion: dataVersion,
    advancements: advancements,
  );
}

DateTime _parseAdvancementTimestamp(String source) {
  final RegExpMatch? match = _advancementTimestampPattern.firstMatch(source);
  if (match == null) {
    throw const _InvalidPlayerAdvancementsData();
  }

  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  final int hour = int.parse(match.group(4)!);
  final int minute = int.parse(match.group(5)!);
  final int second = int.parse(match.group(6)!);
  final int offsetHour = int.parse(match.group(8)!);
  final int offsetMinute = int.parse(match.group(9)!);

  if (offsetHour > 23 || offsetMinute > 59) {
    throw const _InvalidPlayerAdvancementsData();
  }

  final DateTime local = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  );
  if (local.year != year ||
      local.month != month ||
      local.day != day ||
      local.hour != hour ||
      local.minute != minute ||
      local.second != second) {
    throw const _InvalidPlayerAdvancementsData();
  }

  final Duration offset = Duration(
    hours: offsetHour,
    minutes: offsetMinute,
  );
  return match.group(7) == '+'
      ? local.subtract(offset)
      : local.add(offset);
}

final class _InvalidWorldData implements Exception {
  const _InvalidWorldData();
}

MtnMinecraftInfoWorld _worldFromNbt({
  required Directory directory,
  required String directoryName,
  required MtnMinecraftNbtDocument document,
  required List<MtnMinecraftInfoPlayer> players,
  required MtnMinecraftInfoWorldPlayersState playersState,
  required MtnMinecraftInfoWorldPlayersError? playersError,
  required Uint8List? icon,
}) {
  if (document.root.type != MtnMinecraftNbtType.compound) {
    throw const _InvalidWorldData();
  }
  final MtnMinecraftNbtValue? dataValue = document.root.asCompound['Data'];
  if (dataValue?.type != MtnMinecraftNbtType.compound) {
    throw const _InvalidWorldData();
  }
  final Map<String, MtnMinecraftNbtValue> data = dataValue!.asCompound;

  final String? name = _optionalWorldString(data, 'LevelName');
  final int? dataVersion = _optionalWorldInt(data, 'DataVersion');
  final int? lastPlayedMilliseconds = _optionalWorldLong(data, 'LastPlayed');
  final MtnMinecraftInfoWorldVersion? version = _optionalWorldVersion(data);
  final String? singleplayerUuid =
      _optionalWorldUuid(data, 'singleplayer_uuid');

  DateTime? lastPlayed;
  if (lastPlayedMilliseconds != null) {
    const int maximumDateTimeMilliseconds = 8640000000000000;
    if (lastPlayedMilliseconds < -maximumDateTimeMilliseconds ||
        lastPlayedMilliseconds > maximumDateTimeMilliseconds) {
      throw const _InvalidWorldData();
    }
    lastPlayed = DateTime.fromMillisecondsSinceEpoch(
      lastPlayedMilliseconds,
      isUtc: true,
    );
  }

  return MtnMinecraftInfoWorld.available(
    directory: directory,
    directoryName: directoryName,
    name: name,
    dataVersion: dataVersion,
    version: version,
    lastPlayed: lastPlayed,
    singleplayerUuid: singleplayerUuid,
    players: players,
    playersState: playersState,
    playersError: playersError,
    icon: icon,
  );
}

String? _optionalWorldString(
  Map<String, MtnMinecraftNbtValue> data,
  String name,
) {
  final MtnMinecraftNbtValue? value = data[name];
  if (value == null) return null;
  if (value.type != MtnMinecraftNbtType.string) {
    throw const _InvalidWorldData();
  }
  return value.asString;
}

int? _optionalWorldInt(
  Map<String, MtnMinecraftNbtValue> data,
  String name,
) {
  final MtnMinecraftNbtValue? value = data[name];
  if (value == null) return null;
  if (value.type != MtnMinecraftNbtType.intValue) {
    throw const _InvalidWorldData();
  }
  return value.asInt;
}

int? _optionalWorldLong(
  Map<String, MtnMinecraftNbtValue> data,
  String name,
) {
  final MtnMinecraftNbtValue? value = data[name];
  if (value == null) return null;
  if (value.type != MtnMinecraftNbtType.long) {
    throw const _InvalidWorldData();
  }
  return value.asLong;
}

String? _optionalWorldUuid(
  Map<String, MtnMinecraftNbtValue> data,
  String name,
) {
  final MtnMinecraftNbtValue? value = data[name];
  if (value == null) return null;
  if (value.type != MtnMinecraftNbtType.intArray ||
      value.asIntArray.length != 4) {
    throw const _InvalidWorldData();
  }

  final String digits = value.asIntArray
      .map(
        (int part) =>
            (part & 0xffffffff).toRadixString(16).padLeft(8, '0'),
      )
      .join();
  return '${digits.substring(0, 8)}-'
      '${digits.substring(8, 12)}-'
      '${digits.substring(12, 16)}-'
      '${digits.substring(16, 20)}-'
      '${digits.substring(20)}';
}

MtnMinecraftInfoWorldVersion? _optionalWorldVersion(
  Map<String, MtnMinecraftNbtValue> data,
) {
  final MtnMinecraftNbtValue? value = data['Version'];
  if (value == null) return null;
  if (value.type != MtnMinecraftNbtType.compound) {
    throw const _InvalidWorldData();
  }
  final Map<String, MtnMinecraftNbtValue> version = value.asCompound;
  final MtnMinecraftNbtValue? snapshotValue = version['Snapshot'];
  bool? snapshot;
  if (snapshotValue != null) {
    if (snapshotValue.type != MtnMinecraftNbtType.byte ||
        (snapshotValue.asByte != 0 && snapshotValue.asByte != 1)) {
      throw const _InvalidWorldData();
    }
    snapshot = snapshotValue.asByte == 1;
  }
  return MtnMinecraftInfoWorldVersion(
    id: _optionalWorldInt(version, 'Id'),
    name: _optionalWorldString(version, 'Name'),
    snapshot: snapshot,
    series: _optionalWorldString(version, 'Series'),
  );
}

MtnMinecraftInfoServer _serverFromNbt(MtnMinecraftNbtValue value) {
  if (value.type != MtnMinecraftNbtType.compound) {
    throw const MtnMinecraftInfoProviderException(
      MtnMinecraftInfoProviderError.invalidData,
    );
  }
  final Map<String, MtnMinecraftNbtValue> map = value.asCompound;
  final MtnMinecraftNbtValue? name = map['name'];
  final MtnMinecraftNbtValue? address = map['ip'];
  final MtnMinecraftNbtValue? icon = map['icon'];
  final MtnMinecraftNbtValue? hidden = map['hidden'];
  final MtnMinecraftNbtValue? acceptTextures = map['acceptTextures'];
  if (name?.type != MtnMinecraftNbtType.string ||
      address?.type != MtnMinecraftNbtType.string ||
      (icon != null && icon.type != MtnMinecraftNbtType.string) ||
      (hidden != null && hidden.type != MtnMinecraftNbtType.byte) ||
      (acceptTextures != null &&
          acceptTextures.type != MtnMinecraftNbtType.byte)) {
    throw const MtnMinecraftInfoProviderException(
      MtnMinecraftInfoProviderError.invalidData,
    );
  }
  final int? rawHidden = hidden?.asByte;
  final int? rawAcceptTextures = acceptTextures?.asByte;
  if (rawHidden != null && rawHidden != 0 && rawHidden != 1) {
    throw const MtnMinecraftInfoProviderException(
      MtnMinecraftInfoProviderError.invalidData,
    );
  }
  if (rawAcceptTextures != null &&
      rawAcceptTextures != 0 &&
      rawAcceptTextures != 1) {
    throw const MtnMinecraftInfoProviderException(
      MtnMinecraftInfoProviderError.invalidData,
    );
  }
  return MtnMinecraftInfoServer(
    name: name!.asString,
    address: address!.asString,
    icon: icon?.asString,
    hidden: rawHidden == 1,
    acceptServerResourcePacks: rawAcceptTextures == null
        ? null
        : rawAcceptTextures == 1
            ? true
            : rawAcceptTextures == 0
                ? false
                : null,
  );
}

MtnMinecraftNbtValue _serverToNbt(MtnMinecraftInfoServer server) {
  return MtnMinecraftNbtValue.compound(
    <String, MtnMinecraftNbtValue>{
      'name': MtnMinecraftNbtValue.string(server.name),
      'ip': MtnMinecraftNbtValue.string(server.address),
      if (server.icon != null)
        'icon': MtnMinecraftNbtValue.string(server.icon!),
      'hidden': MtnMinecraftNbtValue.byte(server.hidden ? 1 : 0),
      if (server.acceptServerResourcePacks != null)
        'acceptTextures': MtnMinecraftNbtValue.byte(
          server.acceptServerResourcePacks! ? 1 : 0,
        ),
    },
  );
}

Future<T> _inTargetLane<T>(
  String path,
  Future<T> Function() action,
) async {
  final String key = p.normalize(p.absolute(path)).toLowerCase();
  final Future<void> previous =
      MtnMinecraftInfoProvider._targetLanes[key] ?? Future<void>.value();
  final Completer<void> release = Completer<void>();
  MtnMinecraftInfoProvider._targetLanes[key] = release.future;
  try {
    try {
      await previous;
    } on Object {
      // A previous read/write failure cannot poison this file lane.
    }
    return await action();
  } finally {
    release.complete();
    if (identical(
      MtnMinecraftInfoProvider._targetLanes[key],
      release.future,
    )) {
      final Future<void>? removed =
          MtnMinecraftInfoProvider._targetLanes.remove(key);
      assert(identical(removed, release.future));
    }
  }
}

Future<void> _closeBestEffort(RandomAccessFile file) async {
  try {
    await file.close();
  } on FileSystemException {
    // Preserve the primary write result/error.
  }
}

Future<void> _deleteBestEffort(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Temporary/displaced siblings are never authoritative.
  }
}
