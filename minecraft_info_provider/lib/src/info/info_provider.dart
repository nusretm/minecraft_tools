import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../nbt/minecraft_nbt.dart';
import 'info_server.dart';
import 'info_world.dart';

const String _serversFileName = 'servers.dat';
const String _serversTagName = 'servers';
const String _savesDirectoryName = 'saves';

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

/// Reads launcher-facing information from one Java Edition game directory.
///
/// Phase 1 deliberately owns only `servers.dat`. World/player/stat providers
/// can be added behind the same root object without changing the NBT codec.
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
    final File levelFile = File(p.join(directory.path, 'level.dat'));
    late final List<int> compressed;
    try {
      compressed = await levelFile.readAsBytes();
    } on FileSystemException {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
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
        error: MtnMinecraftInfoWorldError.invalidNbt,
      );
    }

    try {
      return _worldFromNbt(
        directory: directory,
        directoryName: directoryName,
        document: document,
      );
    } on _InvalidWorldData {
      return MtnMinecraftInfoWorld.invalid(
        directory: directory,
        directoryName: directoryName,
        error: MtnMinecraftInfoWorldError.invalidData,
      );
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
    final String suffix = await _uniqueSuffix();
    final File temporary = File('${serversFile.path}.tmp-$suffix');
    final File displaced = File('${serversFile.path}.old-$suffix');
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
      await _replace(temporary: temporary, displaced: displaced);
    } finally {
      if (writer != null) await _closeBestEffort(writer);
      await _deleteBestEffort(temporary);
    }
  }

  Future<void> _replace({
    required File temporary,
    required File displaced,
  }) async {
    final FileStat targetStat = await _stat(forWrite: true);
    if (targetStat.type != FileSystemEntityType.notFound &&
        targetStat.type != FileSystemEntityType.file) {
      throw const MtnMinecraftInfoProviderException(
        MtnMinecraftInfoProviderError.invalidPath,
      );
    }

    var movedExisting = false;
    try {
      if (targetStat.type == FileSystemEntityType.file) {
        await serversFile.rename(displaced.path);
        movedExisting = true;
      }
      await temporary.rename(serversFile.path);
      await _deleteBestEffort(displaced);
    } on FileSystemException {
      if (movedExisting &&
          await displaced.exists() &&
          !await serversFile.exists()) {
        try {
          await displaced.rename(serversFile.path);
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

  Future<String> _uniqueSuffix() async {
    final Random random = Random.secure();
    while (true) {
      final String suffix = List<int>.generate(
        16,
        (_) => random.nextInt(256),
        growable: false,
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      if (!await File('${serversFile.path}.tmp-$suffix').exists() &&
          !await File('${serversFile.path}.old-$suffix').exists()) {
        return suffix;
      }
    }
  }
}

final class _InvalidWorldData implements Exception {
  const _InvalidWorldData();
}

MtnMinecraftInfoWorld _worldFromNbt({
  required Directory directory,
  required String directoryName,
  required MtnMinecraftNbtDocument document,
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
