import 'dart:convert';
import 'dart:typed_data';

import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_service.dart';
import 'minecraft_content_package_item.dart';
import 'minecraft_content_package_lock.dart';
import 'minecraft_content_package_metadata_cache.dart';

enum MtnMinecraftContentPackageMutationPolicy { none, readOnly, appendOnly }

/// A tree presentation node. Shared dependencies may occur under multiple roots.
class MtnMinecraftContentPackageTreeNode {
  MtnMinecraftContentPackageTreeNode({
    required this.item,
    required Iterable<MtnMinecraftContentPackageTreeNode> children,
    this.cyclic = false,
  }) : children = List<MtnMinecraftContentPackageTreeNode>.unmodifiable(children);

  final MtnMinecraftContentPackageItem item;
  final List<MtnMinecraftContentPackageTreeNode> children;
  final bool cyclic;
}

/// Portable content definition with an immutable exact lock and transient item hydration.
/// Package revision publication and installer execution are separate, later operations.
class MtnMinecraftContentPackage {
  MtnMinecraftContentPackage({
    required this.id,
    required this.title,
    required this.minecraftVersion,
    required this.modLoader,
    required this.ramMiB,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerName,
    required Iterable<MtnMinecraftContentPackageItem> items,
    this.loaderVersion,
    this.serverAddress,
    this.description,
    this.iconUrl,
    this.revision = 1,
    this.mutationPolicy = MtnMinecraftContentPackageMutationPolicy.none,
    this.lock,
  }) : items = List<MtnMinecraftContentPackageItem>.unmodifiable(items) {
    if (id.trim().isEmpty || title.trim().isEmpty || minecraftVersion.trim().isEmpty) throw ArgumentError('Package ID, title and Minecraft version cannot be empty.');
    if (revision < 1) throw ArgumentError.value(revision, 'revision', 'Revision must be positive.');
    if (ramMiB < 1) throw ArgumentError.value(ramMiB, 'ramMiB', 'RAM must be positive MiB.');
    if (ownerName.trim().isEmpty) throw ArgumentError.value(ownerName, 'ownerName', 'Owner name cannot be blank.');
    if (!createdAt.isUtc || !updatedAt.isUtc) throw ArgumentError('Package timestamps must be UTC.');
    if (updatedAt.isBefore(createdAt)) throw ArgumentError('updatedAt cannot be earlier than createdAt.');
    if (modLoader == MtnMinecraftModLoaderType.vanilla) {
      if (loaderVersion != null) throw ArgumentError.value(loaderVersion, 'loaderVersion', 'Vanilla must not have a loader version.');
    } else if (loaderVersion == null || loaderVersion!.trim().isEmpty || loaderVersion!.trim() != loaderVersion) {
      throw ArgumentError.value(loaderVersion, 'loaderVersion', 'Modded packages require a nonempty, trimmed loader version.');
    }
    if (serverAddress != null && (serverAddress!.trim().isEmpty || serverAddress!.trim() != serverAddress || serverAddress!.contains(RegExp(r'\s')))) {
      throw ArgumentError.value(serverAddress, 'serverAddress', 'Server address must be nonempty and contain no whitespace.');
    }
    final byKey = <String, MtnMinecraftContentPackageItem>{};
    for (final item in this.items) {
      if (byKey.containsKey(item.key)) throw ArgumentError.value(item.key, 'items', 'Duplicate provider/project identity.');
      byKey[item.key] = item;
    }
    final graph = lock;
    if (graph != null) {
      final lockedKeys = graph.versions.map((version) => version.itemKey).toSet();
      if (lockedKeys.length != byKey.length || !byKey.keys.every(lockedKeys.contains)) throw ArgumentError('Locked versions must match all package items exactly.');
      final active = <String>{for (final item in this.items) if (item.direct) item.key};
      final edgesBySource = <String, List<String>>{};
      for (final edge in graph.edges) {
        edgesBySource.putIfAbsent(edge.sourceKey, () => <String>[]).add(edge.targetKey);
      }
      final queue = active.toList();
      for (var index = 0; index < queue.length; index++) {
        for (final target in edgesBySource[queue[index]] ?? const <String>[]) {
          if (active.add(target)) queue.add(target);
        }
      }
      if (!byKey.keys.every(active.contains)) throw ArgumentError('Locked dependencies must be reachable from a direct root.');
    }
  }

  /// Local draft persistence may omit the lock; portable import may not.
  factory MtnMinecraftContentPackage.fromLocalMap(Map<String, dynamic> map) => MtnMinecraftContentPackage._fromMap(map, requireLock: false);

  factory MtnMinecraftContentPackage.fromMap(Map<String, dynamic> map) => MtnMinecraftContentPackage._fromMap(map, requireLock: true);

  factory MtnMinecraftContentPackage.fromJson(String value) {
    final parsed = jsonDecode(value);
    if (parsed is! Map) throw const FormatException('Content Package must be a JSON object.');
    return MtnMinecraftContentPackage.fromMap(Map<String, dynamic>.from(parsed));
  }

  factory MtnMinecraftContentPackage.decode(Uint8List bytes) => MtnMinecraftContentPackage.fromJson(utf8.decode(bytes));

  static MtnMinecraftContentPackage _fromMap(Map<String, dynamic> map, {required bool requireLock}) {
    if (map['schemaVersion'] != currentSchemaVersion) throw FormatException('Unsupported Content Package schema: ${map['schemaVersion']}');
    final id = map['id'];
    final title = map['title'];
    final minecraftVersion = map['minecraftVersion'];
    if (id is! String || title is! String || minecraftVersion is! String) throw const FormatException('Invalid Content Package identity or Minecraft version.');
    if (map['revision'] is! int) throw const FormatException('Package revision must be an integer.');
    if (map['ramMiB'] is! int || map['ownerName'] is! String || map['createdAt'] is! String || map['updatedAt'] is! String) {
      throw const FormatException('Package owner, RAM and UTC lifecycle timestamps are required.');
    }
    if (map['loaderVersion'] != null && map['loaderVersion'] is! String) throw const FormatException('Invalid loader version.');
    if (map['serverAddress'] != null && map['serverAddress'] is! String) throw const FormatException('Invalid server address.');
    DateTime parseUtc(String key) {
      final raw = map[key] as String;
      final value = DateTime.tryParse(raw);
      if (value == null || !value.isUtc || !raw.endsWith('Z')) throw FormatException('Package $key must be an ISO-8601 UTC date ending in Z.');
      return value.toUtc();
    }
    MtnMinecraftModLoaderType? modLoader;
    for (final candidate in MtnMinecraftModLoaderType.values) {
      if (candidate.name == map['modLoader']) modLoader = candidate;
    }
    if (modLoader == null) throw FormatException('Unknown package loader: ${map['modLoader']}');
    MtnMinecraftContentPackageMutationPolicy? policy;
    for (final candidate in MtnMinecraftContentPackageMutationPolicy.values) {
      if (candidate.name == map['mutationPolicy']) policy = candidate;
    }
    if (policy == null) throw FormatException('Unknown package mutation policy: ${map['mutationPolicy']}');
    final contents = map['items'];
    final locked = map['lock'];
    if (contents is! List || (requireLock ? locked is! Map : locked != null && locked is! Map)) throw const FormatException('Invalid Content Package item metadata or locked graph.');
    final description = map['description'];
    final iconUrl = map['iconUrl'];
    if (description != null && description is! String) throw const FormatException('Package description must be text.');
    if (iconUrl != null && iconUrl is! String) throw const FormatException('Package iconUrl must be text.');
    return MtnMinecraftContentPackage(
      id: id,
      title: title,
      description: description as String?,
      iconUrl: iconUrl as String?,
      minecraftVersion: minecraftVersion,
      modLoader: modLoader,
      loaderVersion: map['loaderVersion'] as String?,
      ramMiB: map['ramMiB'] as int,
      serverAddress: map['serverAddress'] as String?,
      ownerName: map['ownerName'] as String,
      createdAt: parseUtc('createdAt'),
      updatedAt: parseUtc('updatedAt'),
      revision: map['revision'] as int,
      mutationPolicy: policy,
      items: contents.map((value) {
        if (value is! Map) throw const FormatException('Invalid package item.');
        return MtnMinecraftContentPackageItem.fromMap(Map<String, dynamic>.from(value));
      }),
      lock: locked == null ? null : MtnMinecraftContentPackageLock.fromMap(Map<String, dynamic>.from(locked as Map)),
    );
  }

  static const int currentSchemaVersion = 2;

  final String id;
  final String title;
  final String? description;
  final String? iconUrl;
  final String minecraftVersion;
  final MtnMinecraftModLoaderType modLoader;
  final String? loaderVersion;
  final int ramMiB;
  final String? serverAddress;
  final String ownerName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final MtnMinecraftContentPackageMutationPolicy mutationPolicy;
  final List<MtnMinecraftContentPackageItem> items;
  final MtnMinecraftContentPackageLock? lock;

  MtnMinecraftContentPackageItem? getItem(String key) {
    for (final item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  static int compareItems(MtnMinecraftContentPackageItem left, MtnMinecraftContentPackageItem right) {
    final titleOrder = left.title.toLowerCase().compareTo(right.title.toLowerCase());
    return titleOrder != 0 ? titleOrder : left.key.compareTo(right.key);
  }

  List<MtnMinecraftContentPackageItem> get directItems {
    final snapshot = items.where((item) => item.direct).toList()..sort(compareItems);
    return List<MtnMinecraftContentPackageItem>.unmodifiable(snapshot);
  }

  List<MtnMinecraftContentPackageItem> get allItems {
    final snapshot = items.toList()..sort(compareItems);
    return List<MtnMinecraftContentPackageItem>.unmodifiable(snapshot);
  }

  List<MtnMinecraftContentPackageItem> get sortedItems => allItems;

  /// Activity is a graph projection, not an independently mutable dependency flag.
  Set<String> get effectiveEnabledKeys {
    final active = <String>{for (final item in items) if (item.directEnabled) item.key};
    final graph = lock;
    if (graph == null) return Set<String>.unmodifiable(active);
    final edgesBySource = <String, List<String>>{};
    for (final edge in graph.edges) {
      edgesBySource.putIfAbsent(edge.sourceKey, () => <String>[]).add(edge.targetKey);
    }
    final queue = active.toList();
    for (var index = 0; index < queue.length; index++) {
      for (final target in edgesBySource[queue[index]] ?? const <String>[]) {
        if (active.add(target)) queue.add(target);
      }
    }
    return Set<String>.unmodifiable(active);
  }

  bool effectiveEnabled(MtnMinecraftContentPackageItem item) {
    if (!items.any((candidate) => identical(candidate, item))) throw ArgumentError.value(item, 'item', 'Item does not belong to this package.');
    return effectiveEnabledKeys.contains(item.key);
  }

  List<MtnMinecraftContentPackageTreeNode> get treeItems {
    final graph = lock;
    if (graph == null) return List<MtnMinecraftContentPackageTreeNode>.unmodifiable(directItems.map((item) => MtnMinecraftContentPackageTreeNode(item: item, children: const [])));
    final byKey = <String, MtnMinecraftContentPackageItem>{for (final item in items) item.key: item};
    final children = <String, Set<String>>{};
    for (final edge in graph.edges) {
      children.putIfAbsent(edge.sourceKey, () => <String>{}).add(edge.targetKey);
    }

    MtnMinecraftContentPackageTreeNode build(String key, Set<String> path) {
      final item = byKey[key]!;
      if (path.contains(key)) return MtnMinecraftContentPackageTreeNode(item: item, children: const [], cyclic: true);
      final nextPath = <String>{...path, key};
      final targets = (children[key] ?? const <String>{}).map((target) => byKey[target]!).toList()..sort(compareItems);
      return MtnMinecraftContentPackageTreeNode(item: item, children: targets.map((target) => build(target.key, nextPath)));
    }

    return List<MtnMinecraftContentPackageTreeNode>.unmodifiable(directItems.map((item) => build(item.key, const <String>{})));
  }

  bool get canAdd => mutationPolicy != MtnMinecraftContentPackageMutationPolicy.readOnly;
  bool canRemove(MtnMinecraftContentPackageItem item) => mutationPolicy == MtnMinecraftContentPackageMutationPolicy.none && items.any((candidate) => identical(candidate, item)) && item.direct && item.canRemove;
  bool canUpdate(MtnMinecraftContentPackageItem item) => items.any((candidate) => identical(candidate, item)) && item.canUpdate;

  void setDirectEnabled(MtnMinecraftContentPackageItem item, bool enabled) {
    if (!items.any((candidate) => identical(candidate, item))) throw ArgumentError.value(item, 'item', 'Item does not belong to this package.');
    item.setDirectEnabled(enabled);
  }

  /// Hydrates each item sequentially, verifying the imported exact lock when
  /// available. Failures stay on their item; remaining items still load.
  ///
  /// Callers may pass a shared service-scoped cache to reuse provider results
  /// between packages. Without one, this call shares an ephemeral cache.
  Future<void> hydrateSequential(
    MtnMinecraftContentService service, {
    MtnMinecraftContentPackageMetadataCache? cache,
    bool refresh = false,
  }) async {
    final metadata = cache ?? MtnMinecraftContentPackageMetadataCache(service);
    if (!identical(metadata.service, service)) throw ArgumentError.value(cache, 'cache', 'Cache belongs to another Content Service.');
    final locks = <String, MtnMinecraftContentPackageLockedVersion>{
      for (final version in lock?.versions ?? const <MtnMinecraftContentPackageLockedVersion>[]) version.itemKey: version,
    };
    for (final item in items) {
      try {
        await item.hydrate(service, cache: metadata, lock: locks[item.key], refresh: refresh);
      } catch (_) {
        // The item exposes the failure for UI/retry; unrelated items continue.
      }
    }
  }

  /// Only encrypted local records may persist an unlocked draft.
  Map<String, dynamic> toLocalMap() => _toMap(requireLock: false);

  Map<String, dynamic> toMap() => _toMap(requireLock: true);

  Map<String, dynamic> _toMap({required bool requireLock}) {
    final graph = lock;
    if (requireLock && graph == null) throw StateError('Cannot export a Content Package without a complete locked graph.');
    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'revision': revision,
      'minecraftVersion': minecraftVersion,
      'modLoader': modLoader.name,
      if (loaderVersion != null) 'loaderVersion': loaderVersion,
      'ramMiB': ramMiB,
      if (serverAddress != null) 'serverAddress': serverAddress,
      'ownerName': ownerName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mutationPolicy': mutationPolicy.name,
      'items': (items.toList()..sort((a, b) => a.key.compareTo(b.key))).map((item) => item.toMap()).toList(growable: false),
      if (graph != null) 'lock': graph.toMap(),
    };
  }

  String toJson() => jsonEncode(toMap());
  Uint8List encode() => Uint8List.fromList(utf8.encode(toJson()));
}
