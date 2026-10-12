import '../model/minecraft_content_models.dart';

/// Exact version and selected artifact identity; never replaced by provider "latest".
class MtnMinecraftContentPackageLockedVersion {
  MtnMinecraftContentPackageLockedVersion({
    required this.itemKey,
    required this.versionId,
    required this.fileName,
    this.fileId,
    this.hashAlgorithm,
    this.hashValue,
    this.size,
  }) {
    if (itemKey.isEmpty || versionId.isEmpty || fileName.isEmpty) throw ArgumentError('Locked version requires itemKey, versionId and fileName.');
    if ((fileId == null || fileId!.isEmpty) && (hashValue == null || hashValue!.isEmpty)) throw ArgumentError('Exact artifact requires provider file ID or file hash.');
    if ((hashAlgorithm == null) != (hashValue == null)) throw ArgumentError('File hash algorithm and value must be supplied together.');
    if (hashAlgorithm != null && !const <String>{'md5', 'sha1', 'sha256', 'sha512'}.contains(hashAlgorithm)) throw ArgumentError.value(hashAlgorithm, 'hashAlgorithm', 'Unsupported portable integrity algorithm.');
    if (hashValue != null && (hashValue!.isEmpty || !RegExp(r'^[a-fA-F0-9]+
    if (size != null && size! < 0) throw ArgumentError.value(size, 'size', 'File size cannot be negative.');
  }

  factory MtnMinecraftContentPackageLockedVersion.fromMap(Map<String, dynamic> map) {
    if (map['itemKey'] is! String || map['versionId'] is! String || map['fileName'] is! String) throw const FormatException('Invalid locked version identity.');
    if (map['fileId'] != null && map['fileId'] is! String) throw const FormatException('Invalid locked fileId.');
    if (map['hashAlgorithm'] != null && map['hashAlgorithm'] is! String) throw const FormatException('Invalid locked hash algorithm.');
    if (map['hashValue'] != null && map['hashValue'] is! String) throw const FormatException('Invalid locked hash value.');
    if (map['size'] != null && map['size'] is! int) throw const FormatException('Invalid locked file size.');
    return MtnMinecraftContentPackageLockedVersion(
      itemKey: map['itemKey'] as String,
      versionId: map['versionId'] as String,
      fileName: map['fileName'] as String,
      fileId: map['fileId'] as String?,
      hashAlgorithm: map['hashAlgorithm'] as String?,
      hashValue: map['hashValue'] as String?,
      size: map['size'] as int?,
    );
  }

  final String itemKey;
  final String versionId;
  final String fileName;
  final String? fileId;
  final String? hashAlgorithm;
  final String? hashValue;
  final int? size;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'itemKey': itemKey,
    'versionId': versionId,
    'fileName': fileName,
    if (fileId != null) 'fileId': fileId,
    if (hashAlgorithm != null) 'hashAlgorithm': hashAlgorithm,
    if (hashValue != null) 'hashValue': hashValue,
    if (size != null) 'size': size,
  };
}

/// Only installed graph edges are locked: required/embedded and selected optional.
/// Incompatible/tool/bundled declarations are not installed artifact edges.
class MtnMinecraftContentPackageLockedEdge {
  MtnMinecraftContentPackageLockedEdge({
    required this.sourceKey,
    required this.targetKey,
    required this.type,
  }) {
    if (sourceKey.isEmpty || targetKey.isEmpty) throw ArgumentError('Locked edge endpoints cannot be empty.');
    if (type != MtnMinecraftContentDependencyType.required && type != MtnMinecraftContentDependencyType.optional && type != MtnMinecraftContentDependencyType.embeddedLibrary) {
      throw ArgumentError.value(type, 'type', 'Only active install dependencies belong in a locked edge.');
    }
  }

  factory MtnMinecraftContentPackageLockedEdge.fromMap(Map<String, dynamic> map) {
    final source = map['source'];
    final target = map['target'];
    if (source is! String || target is! String) throw const FormatException('Invalid locked edge endpoints.');
    MtnMinecraftContentDependencyType? type;
    for (final candidate in MtnMinecraftContentDependencyType.values) {
      if (candidate.name == map['type']) type = candidate;
    }
    if (type == null) throw FormatException('Unknown locked dependency type: ${map['type']}');
    return MtnMinecraftContentPackageLockedEdge(sourceKey: source, targetKey: target, type: type);
  }

  final String sourceKey;
  final String targetKey;
  final MtnMinecraftContentDependencyType type;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'source': sourceKey,
    'target': targetKey,
    'type': type.name,
  };
}

class MtnMinecraftContentPackageLock {
  MtnMinecraftContentPackageLock({
    required Iterable<MtnMinecraftContentPackageLockedVersion> versions,
    required Iterable<MtnMinecraftContentPackageLockedEdge> edges,
  }) : versions = List<MtnMinecraftContentPackageLockedVersion>.unmodifiable(versions),
       edges = List<MtnMinecraftContentPackageLockedEdge>.unmodifiable(edges) {
    final keys = this.versions.map((version) => version.itemKey).toSet();
    if (keys.length != this.versions.length) throw ArgumentError('A locked graph cannot contain two versions of the same item.');
    final edgeIdentities = <String>{};
    for (final edge in this.edges) {
      if (!keys.contains(edge.sourceKey) || !keys.contains(edge.targetKey)) throw ArgumentError('Locked dependency references an unknown item.');
      if (!edgeIdentities.add('${edge.sourceKey}|\u0000|${edge.targetKey}|\u0000|${edge.type.name}')) throw ArgumentError('Duplicate locked dependency edge.');
    }
  }

  factory MtnMinecraftContentPackageLock.fromMap(Map<String, dynamic> map) {
    final versions = map['versions'];
    final edges = map['edges'];
    if (versions is! List || edges is! List) throw const FormatException('Locked graph must contain versions and edges lists.');
    return MtnMinecraftContentPackageLock(
      versions: versions.map((value) {
        if (value is! Map) throw const FormatException('Invalid locked version entry.');
        return MtnMinecraftContentPackageLockedVersion.fromMap(Map<String, dynamic>.from(value));
      }),
      edges: edges.map((value) {
        if (value is! Map) throw const FormatException('Invalid locked edge entry.');
        return MtnMinecraftContentPackageLockedEdge.fromMap(Map<String, dynamic>.from(value));
      }),
    );
  }

  final List<MtnMinecraftContentPackageLockedVersion> versions;
  final List<MtnMinecraftContentPackageLockedEdge> edges;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'versions': (versions.toList()..sort((a, b) => a.itemKey.compareTo(b.itemKey))).map((version) => version.toMap()).toList(growable: false),
    'edges': (edges.toList()..sort((a, b) {
      final source = a.sourceKey.compareTo(b.sourceKey);
      if (source != 0) return source;
      final target = a.targetKey.compareTo(b.targetKey);
      return target != 0 ? target : a.type.name.compareTo(b.type.name);
    })).map((edge) => edge.toMap()).toList(growable: false),
  };
}
).hasMatch(hashValue!))) throw ArgumentError.value(hashValue, 'hashValue', 'File hash must be hexadecimal.');
    if (size != null && size! < 0) throw ArgumentError.value(size, 'size', 'File size cannot be negative.');
    if (sha256 != null && !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256!)) throw ArgumentError.value(sha256, 'sha256', 'Expected 64 hexadecimal characters.');
  }

  factory MtnMinecraftContentPackageLockedVersion.fromMap(Map<String, dynamic> map) {
    if (map['itemKey'] is! String || map['versionId'] is! String || map['fileName'] is! String) throw const FormatException('Invalid locked version identity.');
    if (map['fileId'] != null && map['fileId'] is! String) throw const FormatException('Invalid locked fileId.');
    if (map['sha256'] != null && map['sha256'] is! String) throw const FormatException('Invalid locked SHA-256.');
    if (map['size'] != null && map['size'] is! int) throw const FormatException('Invalid locked file size.');
    return MtnMinecraftContentPackageLockedVersion(
      itemKey: map['itemKey'] as String,
      versionId: map['versionId'] as String,
      fileName: map['fileName'] as String,
      fileId: map['fileId'] as String?,
      sha256: map['sha256'] as String?,
      size: map['size'] as int?,
    );
  }

  final String itemKey;
  final String versionId;
  final String fileName;
  final String? fileId;
  final String? sha256;
  final int? size;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'itemKey': itemKey,
    'versionId': versionId,
    'fileName': fileName,
    if (fileId != null) 'fileId': fileId,
    if (sha256 != null) 'sha256': sha256,
    if (size != null) 'size': size,
  };
}

/// Only installed graph edges are locked: required/embedded and selected optional.
/// Incompatible/tool/bundled declarations are not installed artifact edges.
class MtnMinecraftContentPackageLockedEdge {
  MtnMinecraftContentPackageLockedEdge({
    required this.sourceKey,
    required this.targetKey,
    required this.type,
  }) {
    if (sourceKey.isEmpty || targetKey.isEmpty) throw ArgumentError('Locked edge endpoints cannot be empty.');
    if (type != MtnMinecraftContentDependencyType.required && type != MtnMinecraftContentDependencyType.optional && type != MtnMinecraftContentDependencyType.embeddedLibrary) {
      throw ArgumentError.value(type, 'type', 'Only active install dependencies belong in a locked edge.');
    }
  }

  factory MtnMinecraftContentPackageLockedEdge.fromMap(Map<String, dynamic> map) {
    final source = map['source'];
    final target = map['target'];
    if (source is! String || target is! String) throw const FormatException('Invalid locked edge endpoints.');
    MtnMinecraftContentDependencyType? type;
    for (final candidate in MtnMinecraftContentDependencyType.values) {
      if (candidate.name == map['type']) type = candidate;
    }
    if (type == null) throw FormatException('Unknown locked dependency type: ${map['type']}');
    return MtnMinecraftContentPackageLockedEdge(sourceKey: source, targetKey: target, type: type);
  }

  final String sourceKey;
  final String targetKey;
  final MtnMinecraftContentDependencyType type;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'source': sourceKey,
    'target': targetKey,
    'type': type.name,
  };
}

class MtnMinecraftContentPackageLock {
  MtnMinecraftContentPackageLock({
    required Iterable<MtnMinecraftContentPackageLockedVersion> versions,
    required Iterable<MtnMinecraftContentPackageLockedEdge> edges,
  }) : versions = List<MtnMinecraftContentPackageLockedVersion>.unmodifiable(versions),
       edges = List<MtnMinecraftContentPackageLockedEdge>.unmodifiable(edges) {
    final keys = this.versions.map((version) => version.itemKey).toSet();
    if (keys.length != this.versions.length) throw ArgumentError('A locked graph cannot contain two versions of the same item.');
    final edgeIdentities = <String>{};
    for (final edge in this.edges) {
      if (!keys.contains(edge.sourceKey) || !keys.contains(edge.targetKey)) throw ArgumentError('Locked dependency references an unknown item.');
      if (!edgeIdentities.add('${edge.sourceKey}|\u0000|${edge.targetKey}|\u0000|${edge.type.name}')) throw ArgumentError('Duplicate locked dependency edge.');
    }
  }

  factory MtnMinecraftContentPackageLock.fromMap(Map<String, dynamic> map) {
    final versions = map['versions'];
    final edges = map['edges'];
    if (versions is! List || edges is! List) throw const FormatException('Locked graph must contain versions and edges lists.');
    return MtnMinecraftContentPackageLock(
      versions: versions.map((value) {
        if (value is! Map) throw const FormatException('Invalid locked version entry.');
        return MtnMinecraftContentPackageLockedVersion.fromMap(Map<String, dynamic>.from(value));
      }),
      edges: edges.map((value) {
        if (value is! Map) throw const FormatException('Invalid locked edge entry.');
        return MtnMinecraftContentPackageLockedEdge.fromMap(Map<String, dynamic>.from(value));
      }),
    );
  }

  final List<MtnMinecraftContentPackageLockedVersion> versions;
  final List<MtnMinecraftContentPackageLockedEdge> edges;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'versions': versions.map((version) => version.toMap()).toList(growable: false),
    'edges': edges.map((edge) => edge.toMap()).toList(growable: false),
  };
}
