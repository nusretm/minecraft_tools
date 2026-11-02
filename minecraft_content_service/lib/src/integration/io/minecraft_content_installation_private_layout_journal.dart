part of 'minecraft_content_materialization_file_system.dart';

/// On-disk phases for the Content Service private-layout migration.
/// An encoded journal is evidence, never permission to mutate files.
enum MtnMinecraftContentInstallationManifestFileSystemJournalPhase {
  prepared,
  copying,
  staged,
  cutoverPending,
  switched,
  cleaning,
  complete,
}

final class MtnMinecraftContentInstallationManifestFileSystemJournalMove {
  MtnMinecraftContentInstallationManifestFileSystemJournalMove({
    required this.sourceRelativePath,
    required this.destinationRelativePath,
    required this.sourceLength,
    required this.sourceSha256,
  }) {
    _validate();
  }

  factory MtnMinecraftContentInstallationManifestFileSystemJournalMove.fromMap(Map<String, dynamic> data) {
    _journalRequireKeys(data, const <String>{
      'sourceRelativePath', 'destinationRelativePath', 'sourceLength', 'sourceSha256',
    });
    return MtnMinecraftContentInstallationManifestFileSystemJournalMove(
      sourceRelativePath: _journalString(data, 'sourceRelativePath'),
      destinationRelativePath: _journalString(data, 'destinationRelativePath'),
      sourceLength: _journalNonnegativeInt(data, 'sourceLength'),
      sourceSha256: _journalDigest(data, 'sourceSha256'),
    );
  }

  final String sourceRelativePath;
  final String destinationRelativePath;
  final int sourceLength;
  final String sourceSha256;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'sourceRelativePath': sourceRelativePath,
    'destinationRelativePath': destinationRelativePath,
    'sourceLength': sourceLength,
    'sourceSha256': sourceSha256,
  };

  void _validate() {
    final src = sourceRelativePath.split('/');
    final dst = destinationRelativePath.split('/');
    if (src.length != 3 || dst.length != 4 ||
        src[0] != '.mtn-disabled' || dst[0] != '.mtn' || dst[1] != 'disabled' ||
        src[1] != dst[2] || src[2] != dst[3] ||
        !const <String>['mods', 'resourcepacks', 'shaderpacks'].contains(src[1]) ||
        !_journalSafeFileName(src[2]) || sourceLength < 0 || !_journalValidDigest(sourceSha256)) {
      throw const FormatException('Invalid private-layout journal artifact move.');
    }
  }
}

/// Immutable, versioned JSON journal record with a deterministic SHA256 over
/// its canonical payload. No on-disk mutation methods exist in PRIVATE-1C0.
final class MtnMinecraftContentInstallationManifestFileSystemJournal {
  MtnMinecraftContentInstallationManifestFileSystemJournal({
    required this.migrationId,
    required this.rootIdentitySha256,
    required this.generation,
    required this.phase,
    required this.legacyManifestLength,
    required this.legacyManifestSha256,
    required this.modernManifestLength,
    required this.modernManifestSha256,
    required List<MtnMinecraftContentInstallationManifestFileSystemJournalMove> moves,
    required List<String> copiedSourcePaths,
  }) : moves = List<MtnMinecraftContentInstallationManifestFileSystemJournalMove>.unmodifiable(moves),
       copiedSourcePaths = List<String>.unmodifiable(copiedSourcePaths) {
    _validate();
  }

  factory MtnMinecraftContentInstallationManifestFileSystemJournal.fromJson(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Private-layout journal must be a JSON object.');
    }
    _journalRequireKeys(decoded, const <String>{
      'schemaVersion', 'migrationId', 'rootIdentitySha256', 'generation',
      'phase', 'legacyManifestLength', 'legacyManifestSha256',
      'modernManifestLength', 'modernManifestSha256', 'moves',
      'copiedSourcePaths', 'journalSha256',
    });
    if (decoded['schemaVersion'] != currentSchemaVersion) {
      throw const FormatException('Unsupported private-layout migration journal schema.');
    }
    final checksum = _journalDigest(decoded, 'journalSha256');
    final withoutChecksum = Map<String, dynamic>.of(decoded)..remove('journalSha256');
    if (sha256.convert(utf8.encode(jsonEncode(withoutChecksum))).toString() != checksum) {
      throw const FormatException('Private-layout journal checksum mismatch.');
    }
    final phaseValue = _journalString(decoded, 'phase');
    final matchedPhase = MtnMinecraftContentInstallationManifestFileSystemJournalPhase.values
        .where((value) => value.name == phaseValue).toList();
    if (matchedPhase.length != 1) {
      throw const FormatException('Unknown private-layout migration phase.');
    }
    final rawMoves = decoded['moves'];
    final rawCopied = decoded['copiedSourcePaths'];
    if (rawMoves is! List || rawCopied is! List) {
      throw const FormatException('Invalid private-layout journal inventory.');
    }
    final moves = <MtnMinecraftContentInstallationManifestFileSystemJournalMove>[];
    for (final entry in rawMoves) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid private-layout journal move.');
      }
      moves.add(MtnMinecraftContentInstallationManifestFileSystemJournalMove.fromMap(entry));
    }
    if (rawCopied.any((element) => element is! String)) {
      throw const FormatException('Invalid copied source path.');
    }
    return MtnMinecraftContentInstallationManifestFileSystemJournal(
      migrationId: _journalString(decoded, 'migrationId'),
      rootIdentitySha256: _journalDigest(decoded, 'rootIdentitySha256'),
      generation: _journalPositiveInt(decoded, 'generation'),
      phase: matchedPhase.single,
      legacyManifestLength: _journalPositiveInt(decoded, 'legacyManifestLength'),
      legacyManifestSha256: _journalDigest(decoded, 'legacyManifestSha256'),
      modernManifestLength: _journalPositiveInt(decoded, 'modernManifestLength'),
      modernManifestSha256: _journalDigest(decoded, 'modernManifestSha256'),
      moves: moves,
      copiedSourcePaths: List<String>.from(rawCopied),
    );
  }

  static const int currentSchemaVersion = 1;
  static const int maxJournalBytes = 1024 * 1024;
  static const String directoryName = 'migration';
  static const String fileName = 'journal.json';

  final String migrationId;
  final String rootIdentitySha256;
  final int generation;
  final MtnMinecraftContentInstallationManifestFileSystemJournalPhase phase;
  final int legacyManifestLength;
  final String legacyManifestSha256;
  final int modernManifestLength;
  final String modernManifestSha256;
  final List<MtnMinecraftContentInstallationManifestFileSystemJournalMove> moves;
  final List<String> copiedSourcePaths;

  String toJson() {
    final payload = <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'migrationId': migrationId,
      'rootIdentitySha256': rootIdentitySha256,
      'generation': generation,
      'phase': phase.name,
      'legacyManifestLength': legacyManifestLength,
      'legacyManifestSha256': legacyManifestSha256,
      'modernManifestLength': modernManifestLength,
      'modernManifestSha256': modernManifestSha256,
      'moves': moves.map((move) => move.toMap()).toList(growable: false),
      'copiedSourcePaths': copiedSourcePaths,
    };
    final digest = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    return jsonEncode(<String, dynamic>{...payload, 'journalSha256': digest});
  }

  void _validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(migrationId) ||
        generation < 1 || legacyManifestLength < 1 || modernManifestLength < 1 ||
        !_journalValidDigest(rootIdentitySha256) ||
        !_journalValidDigest(legacyManifestSha256) ||
        !_journalValidDigest(modernManifestSha256) ||
        moves.length > 4096) {
      throw const FormatException('Invalid private-layout migration journal header.');
    }
    final sources = <String>{};
    final targets = <String>{};
    for (final move in moves) {
      move._validate();
      if (!sources.add(move.sourceRelativePath.toLowerCase()) ||
          !targets.add(move.destinationRelativePath.toLowerCase())) {
        throw const FormatException('Duplicate or case-colliding journal move.');
      }
    }
    final copied = <String>{};
    for (final source in copiedSourcePaths) {
      if (!sources.contains(source.toLowerCase()) || !copied.add(source.toLowerCase())) {
        throw const FormatException('Copied source is unknown or duplicated.');
      }
    }
    if (phase == MtnMinecraftContentInstallationManifestFileSystemJournalPhase.prepared &&
        copiedSourcePaths.isNotEmpty) {
      throw const FormatException('Prepared migration cannot claim completed copies.');
    }
  }
}

bool _journalValidDigest(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _journalSafeFileName(String name) =>
    name.isNotEmpty && name != '.' && name != '..' && !name.endsWith(' ') &&
    !name.endsWith('.') && !name.contains(String.fromCharCode(92)) && !name.contains(':') &&
    !name.codeUnits.any((unit) => unit < 32) &&
    !RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$', caseSensitive: false).hasMatch(name);

void _journalRequireKeys(Map<String, dynamic> data, Set<String> keys) {
  if (data.keys.toSet().difference(keys).isNotEmpty || keys.difference(data.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unexpected private-layout journal fields.');
  }
}

String _journalString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) throw FormatException('Invalid journal $key.');
  return value;
}

String _journalDigest(Map<String, dynamic> data, String key) {
  final value = _journalString(data, key);
  if (!_journalValidDigest(value)) throw FormatException('Invalid journal $key digest.');
  return value;
}

int _journalNonnegativeInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! int || value < 0) throw FormatException('Invalid journal $key.');
  return value;
}

int _journalPositiveInt(Map<String, dynamic> data, String key) {
  final value = _journalNonnegativeInt(data, key);
  if (value == 0) throw FormatException('Invalid journal $key.');
  return value;
}
