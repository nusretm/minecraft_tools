import 'dart:convert';
import 'dart:typed_data';

import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_service.dart';
import 'minecraft_content_package_item.dart';
import 'minecraft_content_package_lock.dart';

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
    required Iterable<MtnMinecraftContentPackageItem> items,
    this.description,
    this.iconUrl,
    this.revision = 1,
    this.mutationPolicy = MtnMinecraftContentPackageMutationPolicy.none,
    this.lock,
  }) : items = List<MtnMinecraftContentPackageItem>.unmodifiable(items) {
    if (id.trim().isEmpty || title.trim().isEmpty || minecraftVersion.trim().isEmpty) throw ArgumentError('Package ID, title and Minecraft version cannot be empty.');
    if (revision < 1) throw ArgumentError.value(revision, 'revision', 'Revision must be positive.');
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

  factory MtnMinecraftContentPackage.fromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != currentSchemaVersion) throw FormatException('Unsupported Content Package schema: ${map['schemaVersion']}');
    final id = map['id'];
    final title = map['title'];
    final minecraftVersion = map['minecraftVersion'];
    if (id is! String || title is! String || minecraftVersion is! String) throw const FormatException('Invalid Content Package identity or Minecraft version.');
    if (map['revision'] is! int) throw const FormatException('Package revision must be an integer.');
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
    if (contents is! List || locked is! Map) throw const FormatException('Published Content Package requires item metadata and locked graph.');
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
      revision: map['revision'] as int,
      mutationPolicy: policy,
      items: contents.map((value) {
        if (value is! Map) throw const FormatException('Invalid package item.');
        return MtnMinecraftContentPackageItem.fromMap(Map<String, dynamic>.from(value));
      }),
      lock: MtnMinecraftContentPackageLock.fromMap(Map<String, dynamic>.from(locked)),
    );
  }

  factory MtnMinecraftContentPackage.fromJson(String value) {
    final parsed = jsonDecode(value);
    if (parsed is! Map) throw const FormatException('Content Package must be a JSON object.');
    return MtnMinecraftContentPackage.fromMap(Map<String, dynamic>.from(parsed));
  }

  factory MtnMinecraftContentPackage.decode(Uint8List bytes) => MtnMinecraftContentPackage.fromJson(utf8.decode(bytes));

  static const int currentSchemaVersion = 1;

  final String id;
  final String title;
  final String? description;
  final String? iconUrl;
  final String minecraftVersion;
  final MtnMinecraftModLoaderType modLoader;
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
  bool canRemove(MtnMinecraftContentPackageItem item) => mutationPolicy == MtnMinecraftContentPackageMutationPolicy.none && items.any((candidate) => identical(candidate, item)) && item.canRemove;
  bool canUpdate(MtnMinecraftContentPackageItem item) => items.any((candidate) => identical(candidate, item)) && item.canUpdate;

  void setDirectEnabled(MtnMinecraftContentPackageItem item, bool enabled) {
    if (!items.any((candidate) => identical(candidate, item))) throw ArgumentError.value(item, 'item', 'Item does not belong to this package.');
    item.setDirectEnabled(enabled);
  }

  /// Metadata hydration is sequential; one failed provider request does not hide other items.
  Future<void> hydrateSequential(MtnMinecraftContentService service) async {
    for (final item in items) {
      try {
        await item.hydrate(service);
      } catch (_) {
        // Item owns and exposes its own error state; continue loading remaining items.
      }
    }
  }

  Map<String, dynamic> toMap() {
    final graph = lock;
    if (graph == null) throw StateError('Cannot export a Content Package without a complete locked graph.');
    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'revision': revision,
      'minecraftVersion': minecraftVersion,
      'modLoader': modLoader.name,
      'mutationPolicy': mutationPolicy.name,
      'items': (items.toList()..sort((a, b) => a.key.compareTo(b.key))).map((item) => item.toMap()).toList(growable: false),
      'lock': graph.toMap(),
    };
  }

  String toJson() => jsonEncode(toMap());
  Uint8List encode() => Uint8List.fromList(utf8.encode(toJson()));
}
