import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../model/minecraft_content_models.dart';
import '../provider/minecraft_content_provider_models.dart';
import '../service/minecraft_content_dependency_desired_state.dart';
import '../service/minecraft_content_dependency_install_plan.dart';
import '../service/minecraft_content_http_service.dart';
import '../service/minecraft_content_service.dart';
import 'minecraft_content_package_builder.dart';
import 'minecraft_content_package_item.dart';
import 'minecraft_content_package_lock.dart';
import 'minecraft_content_package_metadata_cache.dart';
import 'minecraft_content_package_record.dart';
import 'minecraft_content_package_source.dart';

enum MtnMinecraftContentPackageMutationPolicy { none, readOnly, appendOnly }

/// Portable presentation of a game's logo.
enum MtnMinecraftContentPackageLogoImageMode { fit, center }

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
    this.logoImageFileName,
    this.logoImageMode = MtnMinecraftContentPackageLogoImageMode.fit,
    this.revision = 1,
    this.mutationPolicy = MtnMinecraftContentPackageMutationPolicy.none,
    MtnMinecraftContentPackageLock? lock,
    Iterable<MtnMinecraftContentPackageLockedEdge>? dependencyEdges,
  }) : _items = List<MtnMinecraftContentPackageItem>.of(items),
       _lock = lock,
       _dependencyEdges = List<MtnMinecraftContentPackageLockedEdge>.of(dependencyEdges ?? lock?.edges ?? const <MtnMinecraftContentPackageLockedEdge>[]) {
    if (id.trim().isEmpty || title.trim().isEmpty || minecraftVersion.trim().isEmpty) throw ArgumentError('Package ID, title and Minecraft version cannot be empty.');
    if (revision < 1) throw ArgumentError.value(revision, 'revision', 'Revision must be positive.');
    if (logoImageFileName != null && !RegExp(r'^[a-f0-9]{64}\.(png|jpg|webp)$').hasMatch(logoImageFileName!)) {
      throw ArgumentError.value(logoImageFileName, 'logoImageFileName', 'Logo must use a canonical lowercase SHA-256 basename.');
    }
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
    final keys = byKey.keys.toSet();
    if (_dependencyEdges.any((edge) => !keys.contains(edge.sourceKey) || !keys.contains(edge.targetKey))) {
      throw ArgumentError('Dependency edges must refer to package items.');
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
    // Bind only after validating the complete graph. An Item already used by
    // another Package is copied rather than reassigned to this Package.
    for (var index = 0; index < _items.length; index++) {
      _items[index] = _items[index].attachToPackage(this);
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
    final draftEdges = map['dependencyEdges'];
    if (requireLock && map.containsKey('dependencyEdges')) throw const FormatException('Portable package cannot contain local dependency edges.');
    if (draftEdges != null && (draftEdges is! List || locked != null)) throw const FormatException('Draft edges require an unlocked local package.');
    if (contents is! List || (requireLock ? locked is! Map : locked != null && locked is! Map)) throw const FormatException('Invalid Content Package item metadata or locked graph.');
    final description = map['description'];
    final iconUrl = map['iconUrl'];
    final logoImageFileName = map['logoImageFileName'];
    if (logoImageFileName != null && logoImageFileName is! String) throw const FormatException('Logo file name must be text.');
    final rawImageMode = map['logoImageMode'];
    if (rawImageMode != null && rawImageMode is! String) throw const FormatException('Logo image mode must be text.');
    final logoImageMode = MtnMinecraftContentPackageLogoImageMode.values.where((value) => value.name == (rawImageMode ?? 'fit')).firstOrNull;
    if (logoImageMode == null) throw const FormatException('Unsupported package logo image mode.');
    if (description != null && description is! String) throw const FormatException('Package description must be text.');
    if (iconUrl != null && iconUrl is! String) throw const FormatException('Package iconUrl must be text.');
    final package = MtnMinecraftContentPackage(
      id: id,
      title: title,
      description: description as String?,
      iconUrl: iconUrl as String?,
      logoImageFileName: logoImageFileName as String?,
      logoImageMode: logoImageMode,
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
        return requireLock ? MtnMinecraftContentPackageItem.fromMap(Map<String, dynamic>.from(value)) : MtnMinecraftContentPackageItem.fromLocalMap(Map<String, dynamic>.from(value));
      }),
      lock: locked == null ? null : MtnMinecraftContentPackageLock.fromMap(Map<String, dynamic>.from(locked as Map)),
      dependencyEdges: draftEdges == null ? null : (draftEdges as List).map((value) {
        if (value is! Map) throw const FormatException('Invalid local dependency edge.');
        return MtnMinecraftContentPackageLockedEdge.fromMap(Map<String, dynamic>.from(value));
      }),
    );
    if (!requireLock) package._restoreLocalUpdateCheck(map['localUpdateCheck']);
    return package;
  }

  static const int currentSchemaVersion = 2;

  final String id;
  final String title;
  final String? description;
  final String? iconUrl;
  final String? logoImageFileName;
  final MtnMinecraftContentPackageLogoImageMode logoImageMode;
  final String minecraftVersion;
  final MtnMinecraftModLoaderType modLoader;
  final String? loaderVersion;
  final int ramMiB;
  final String? serverAddress;
  final String ownerName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  /// Alias for the existing portable revision; no second revision authority.
  int get revisionNum => revision;

  int? _newRevisionNum;

  /// A newer remote published revision last observed for a downloaded package.
  /// Transient only: the Content Server client owns polling and persistence.
  int? get newRevisionNum => _newRevisionNum;
  set newRevisionNum(int? value) {
    if (_record?.source != MtnMinecraftContentPackageSource.downloaded) return;
    _newRevisionNum = value != null && value > revisionNum ? value : null;
  }

  bool get updateAvail => revisionNum != (newRevisionNum ?? revisionNum);

  final MtnMinecraftContentPackageMutationPolicy mutationPolicy;
  final List<MtnMinecraftContentPackageItem> _items;
  List<MtnMinecraftContentPackageItem> get items => List<MtnMinecraftContentPackageItem>.unmodifiable(_items);
  MtnMinecraftContentPackageLock? _lock;
  MtnMinecraftContentPackageLock? get lock => _lock;
  final List<MtnMinecraftContentPackageLockedEdge> _dependencyEdges;
  List<MtnMinecraftContentPackageLockedEdge> get dependencyEdges => List<MtnMinecraftContentPackageLockedEdge>.unmodifiable(_dependencyEdges);
  MtnMinecraftContentPackageRecord? _record;
  MtnMinecraftContentPackageRecord? get record => _record;

  void attachRecord(MtnMinecraftContentPackageRecord value) {
    if (_record != null && !identical(_record, value)) throw StateError('Package is already attached to a different record.');
    _record = value;
  }

  /// Service context is attached by RecordStorage when a package is loaded.
  /// Manually constructed packages may still pass the service explicitly.
  MtnMinecraftContentService? _contentService;
  void attachContentService(MtnMinecraftContentService service) => _contentService = service;

  final Map<MtnMinecraftContentPackageItem, MtnMinecraftContentVersion> _updateList = <MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>{};
  DateTime? _lastSuccessfulUpdateCheckAt;
  String? _updateSelectionFingerprint;

  /// This is a local scan result, not the HTTP cache's receipt time.
  /// Invalidated whenever the exact package content/permissions change.
  DateTime? get lastSuccessfulUpdateCheckAt =>
      _updateSelectionFingerprint == _updateFingerprint() ? _lastSuccessfulUpdateCheckAt : null;

  bool get hasUpdateEligibleItems => items.any(_mayUpdate);

  bool needsUpdateCheck({DateTime? now, Duration interval = const Duration(hours: 6)}) {
    if (interval.isNegative) throw ArgumentError.value(interval, 'interval', 'Update check interval cannot be negative.');
    if (!hasUpdateEligibleItems) return false;
    final checkedAt = lastSuccessfulUpdateCheckAt;
    if (checkedAt == null) return true;
    final current = (now ?? DateTime.now()).toUtc();
    return current.isBefore(checkedAt) || !current.isBefore(checkedAt.add(interval));
  }

  Map<MtnMinecraftContentPackageItem, MtnMinecraftContentVersion> get updateList {
    if (_updateSelectionFingerprint != null && _updateSelectionFingerprint != _updateFingerprint()) {
      return const <MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>{};
    }
    return Map<MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>.unmodifiable(<MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>{
      for (final entry in _updateList.entries)
        if (_mayUpdate(entry.key)) entry.key: entry.value,
    });
  }


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

  List<MtnMinecraftContentPackageTreeNode> get treeItems {
    if (_dependencyEdges.isEmpty) return List<MtnMinecraftContentPackageTreeNode>.unmodifiable(directItems.map((item) => MtnMinecraftContentPackageTreeNode(item: item, children: const [])));
    final byKey = <String, MtnMinecraftContentPackageItem>{for (final item in items) item.key: item};
    final children = <String, Set<String>>{};
    for (final edge in _dependencyEdges) {
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

  bool _protectedItem(MtnMinecraftContentPackageItem item) =>
      _record?.source == MtnMinecraftContentPackageSource.downloaded &&
      item.source == MtnMinecraftContentPackageSource.downloaded &&
      mutationPolicy == MtnMinecraftContentPackageMutationPolicy.appendOnly;

  bool canSetEnabled(MtnMinecraftContentPackageItem item, bool value) =>
      mutationPolicy != MtnMinecraftContentPackageMutationPolicy.readOnly &&
      !_protectedItem(item) &&
      _items.any((candidate) => identical(candidate, item)) &&
      (value ? item.canEnable : item.canDisable);

  bool canRemove(MtnMinecraftContentPackageItem item) =>
      _items.any((candidate) => identical(candidate, item)) && item.direct &&
      mutationPolicy != MtnMinecraftContentPackageMutationPolicy.readOnly &&
      !_protectedItem(item) && item.canRemove &&
      (mutationPolicy == MtnMinecraftContentPackageMutationPolicy.none || item.source == MtnMinecraftContentPackageSource.local);

  bool _mayUpdate(MtnMinecraftContentPackageItem item) =>
      mutationPolicy != MtnMinecraftContentPackageMutationPolicy.readOnly &&
      !_protectedItem(item) &&
      _items.any((candidate) => identical(candidate, item)) &&
      item.permissions.contains(MtnMinecraftContentItemPermission.update);

  bool _compatible(MtnMinecraftContentVersion version) =>
      version.gameVersions.contains(minecraftVersion) &&
      (version.content.type != MtnMinecraftContentType.mod || version.modLoaders.contains(modLoader));

  (String, String)? _providerIdentity(MtnMinecraftContentVersion version) {
    final matches = <(String, String)>[];
    for (final candidate in version.providers) {
      if (candidate.id == null || candidate.id!.isEmpty) continue;
      for (final content in version.content.providers) {
        if (candidate.provider == content.provider && content.id != null && content.id!.isNotEmpty) {
          matches.add((candidate.provider, content.id!));
        }
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  void _invalidateLock() {
    final old = _lock;
    if (old != null) {
      for (final entry in old.versions) {
        getItem(entry.itemKey)?.preserveVersionId(entry.versionId);
      }
      _lock = null;
    }
    _updateList.clear();
    _lastSuccessfulUpdateCheckAt = null;
    _updateSelectionFingerprint = null;
  }

  /// Adds one provider-selected version, or promotes an existing dependency.
  /// Unknown dependencies are not invented; the draft must be resolved and
  /// rebuilt with a complete lock before portable publication.
  bool add(MtnMinecraftContentVersion version) {
    if (!canAdd || !_compatible(version)) return false;
    final identity = _providerIdentity(version);
    if (identity == null) return false;
    final provider = identity.$1, projectId = identity.$2;
    final key = '$provider:$projectId';
    final existing = getItem(key);
    final versionId = version.providers.firstWhere((metadata) => metadata.provider == provider).id!;
    if (existing != null) {
      if (existing.direct || _protectedItem(existing) ||
          (existing.selectedVersionId != null && existing.selectedVersionId != versionId) ||
          (_lock != null && _lock!.versions.any((entry) => entry.itemKey == key && entry.versionId != versionId))) {
        return false;
      }
      _invalidateLock();
      existing.setDirect(true);
      existing.selectVersion(version, versionId);
      return true;
    }
    final item = MtnMinecraftContentPackageItem(
      provider: provider, projectId: projectId, type: version.content.type, title: version.content.name,
      description: version.content.summary ?? version.content.description, iconUrl: version.content.icon?.url,
      direct: true, source: MtnMinecraftContentPackageSource.local,
      permissions: MtnMinecraftContentItemPermission.values, selectedVersionId: versionId,
    );
    _invalidateLock();
    _items.add(item);
    item.attachToPackage(this);
    item.selectVersion(version, versionId);
    for (final dependency in version.dependencies) {
      if (dependency.type != MtnMinecraftContentDependencyType.required &&
          dependency.type != MtnMinecraftContentDependencyType.embeddedLibrary) {
        continue;
      }
      final depProvider = dependency.provider;
      final depProject = dependency.providerContentId;
      if (depProvider == null || depProject == null || getItem('$depProvider:$depProject') == null) continue;
      if (!_dependencyEdges.any((edge) => edge.sourceKey == key && edge.targetKey == '$depProvider:$depProject')) {
        _dependencyEdges.add(MtnMinecraftContentPackageLockedEdge(sourceKey: key, targetKey: '$depProvider:$depProject', type: dependency.type));
      }
    }
    return true;
  }

  /// Removes a direct root; a dependency still used by another item stays.
  bool remove(MtnMinecraftContentPackageItem item) {
    if (!canRemove(item)) return false;
    _invalidateLock();
    if (_dependencyEdges.any((edge) => edge.targetKey == item.key && edge.sourceKey != item.key)) {
      item.setDirect(false);
    } else {
      _items.remove(item);
      _dependencyEdges.removeWhere((edge) => edge.sourceKey == item.key || edge.targetKey == item.key);
      item.detachFromPackage(this);
    }
    return true;
  }

  /// Resolves the exact selected direct-root versions through the existing
  /// provider graph resolver and multi-root install planner. Does not mutate
  /// package membership or its lock; unresolved dependencies stay in the result.
  Future<MtnMinecraftContentDependencyDesiredState> resolveDependencies(
    MtnMinecraftContentService service, {
    Map<String, List<String>> selectedOptionalVersionKeysByRoot = const <String, List<String>>{},
  }) async {
    final plans = <MtnMinecraftContentDependencyInstallPlan>[];
    final currentLocks = <String, MtnMinecraftContentPackageLockedVersion>{
      for (final entry in _lock?.versions ?? const <MtnMinecraftContentPackageLockedVersion>[]) entry.itemKey: entry,
    };

    for (final root in directItems) {
      await root.hydrate(service, lock: currentLocks[root.key]);
      final version = root.version;
      if (version == null || !_compatible(version)) {
        throw StateError('Cannot resolve dependencies without a compatible selected version for ${root.key}.');
      }
      final identity = _providerIdentity(version);
      if (identity == null || '${identity.$1}:${identity.$2}' != root.key) {
        throw StateError('Selected version identity does not match direct package item ${root.key}.');
      }
      final versionId = version.providers.firstWhere((entry) => entry.provider == root.provider).id!;
      final pinned = root.selectedVersionId ?? currentLocks[root.key]?.versionId;
      if (pinned != null && pinned != versionId) {
        throw StateError('Direct root ${root.key} changed its selected provider version.');
      }

      final graph = await service.resolveDependencyGraph(
        version,
        MtnMinecraftContentVersionSelectionRequest(
          gameVersions: <String>[minecraftVersion],
          modLoaders: <MtnMinecraftModLoaderType>[modLoader],
        ),
      );
      plans.add(service.planDependencyInstall(
        graph,
        MtnMinecraftContentDependencyInstallRequest(
          selectedOptionalVersionKeys: selectedOptionalVersionKeysByRoot[version.key] ?? const <String>[],
        ),
      ));
    }

    final result = service.composeDependencyInstallPlans(plans);
    if (!result.installable) return result;

    for (final entry in result.versions) {
      final version = entry.version;
      if (!_compatible(version)) {
        throw StateError('Dependency resolution selected an incompatible version: ${version.key}.');
      }
      final identity = _providerIdentity(version);
      if (identity == null) throw StateError('Resolved version has ambiguous provider identity: ${version.key}.');
      final key = '${identity.$1}:${identity.$2}';
      final current = getItem(key);
      if (current == null) continue;
      final selected = current.selectedVersionId ?? currentLocks[key]?.versionId;
      final resolvedId = version.providers.firstWhere((metadata) => metadata.provider == identity.$1).id!;
      if (selected != null && selected != resolvedId) {
        throw StateError('Dependency ${current.key} conflicts with the selected exact provider version $selected.');
      }
    }
    return result;
  }

  /// Validates a full exact-lock candidate with the existing Package Builder
  /// before changing this package. Existing item objects and their origin,
  /// enabled preference and permissions survive; orphan dependencies are removed.
  bool rebuildLock(
    MtnMinecraftContentDependencyDesiredState desired, {
    required Map<String, MtnMinecraftContentFile> selectedFilesByVersionKey,
  }) {
    if (!desired.installable || desired.directVersions.isEmpty) return false;

    final previousRoots = directItems.map((item) => item.key).toSet();
    final candidateRoots = <String>{};
    for (final version in desired.directVersions) {
      final identity = _providerIdentity(version);
      if (identity == null) return false;
      candidateRoots.add('${identity.$1}:${identity.$2}');
    }
    if (previousRoots.length != candidateRoots.length || !previousRoots.containsAll(candidateRoots)) return false;

    final previous = <String, MtnMinecraftContentPackageItem>{for (final item in _items) item.key: item};
    final desiredItemKeys = <String>{};
    final currentLocks = <String, MtnMinecraftContentPackageLockedVersion>{
      for (final entry in _lock?.versions ?? const <MtnMinecraftContentPackageLockedVersion>[]) entry.itemKey: entry,
    };
    for (final entry in desired.versions) {
      final version = entry.version;
      if (!_compatible(version)) return false;
      final identity = _providerIdentity(version);
      if (identity == null) return false;
      final key = '${identity.$1}:${identity.$2}';
      desiredItemKeys.add(key);
      final old = previous[key];
      if (old == null) continue;
      final selected = old.selectedVersionId ?? currentLocks[key]?.versionId;
      final resolvedId = version.providers.firstWhere((metadata) => metadata.provider == identity.$1).id!;
      if (selected != null && selected != resolvedId) return false;
    }

    // Any validation error from the existing exact-file/graph builder leaves
    // the original package completely unchanged.
    final built = const MtnMinecraftContentPackageBuilder().build(
      id: id, title: title, description: description, iconUrl: iconUrl,
      logoImageFileName: logoImageFileName, logoImageMode: logoImageMode,
      minecraftVersion: minecraftVersion, modLoader: modLoader, loaderVersion: loaderVersion,
      ramMiB: ramMiB, serverAddress: serverAddress, ownerName: ownerName,
      createdAt: createdAt, updatedAt: updatedAt, revision: revision, mutationPolicy: mutationPolicy,
      desired: desired, selectedFilesByVersionKey: selectedFilesByVersionKey,
      permissionsByItemKey: <String, List<MtnMinecraftContentItemPermission>>{
        for (final item in _items)
          if (desiredItemKeys.contains(item.key)) item.key: item.permissions,
      },
    );

    final nextItems = <MtnMinecraftContentPackageItem>[];
    for (final item in built.items) {
      final retained = previous[item.key];
      final next = retained ?? item.attachToPackage(this);
      nextItems.add(next);
    }
    for (final item in _items) {
      if (!nextItems.contains(item)) item.detachFromPackage(this);
    }
    _items
      ..clear()
      ..addAll(nextItems);
    _dependencyEdges
      ..clear()
      ..addAll(built.lock!.edges);
    _lock = built.lock;
    for (final entry in _lock!.versions) {
      getItem(entry.itemKey)?.preserveVersionId(entry.versionId);
    }
    _updateList.clear();
    return true;
  }

  /// Checks for newer compatible published versions without changing the lock.
  /// Provider HTTP results use the single Content Service cache for six hours
  /// by default; a forced check bypasses that cache once per unique request.
  /// Errors leave the previous updateList unchanged instead of claiming no updates.
  Future<void> checkUpdates({
    MtnMinecraftContentService? service,
    bool force = false,
    Duration cacheDuration = const Duration(hours: 6),
  }) async {
    final source = service ?? _contentService;
    if (source == null) throw StateError('A Content Service must be supplied or attached before checking updates.');
    _contentService = source;
    if (!hasUpdateEligibleItems) return;
    final initialSelection = _updateFingerprint();
    final found = await source.providers.httpService.withCacheOptions(
      cacheDuration: cacheDuration,
      forceRefresh: force,
      action: () => _findUpdates(source, refresh: force),
    );
    if (_updateFingerprint() != initialSelection) throw StateError('Content Package changed during its update scan.');
    _updateList
      ..clear()
      ..addAll(found);
    _lastSuccessfulUpdateCheckAt = DateTime.now().toUtc();
    _updateSelectionFingerprint = initialSelection;
  }

  /// Rebuilds updateList only if every required HTTP response remains in cache.
  /// The detached snapshot prevents a cache miss from changing item hydration,
  /// provider pins or previously shown update information on this package.
  Future<void> restoreCachedUpdates(MtnMinecraftContentService service, {
    Duration cacheDuration = const Duration(hours: 6),
  }) async {
    _contentService = service;
    if (lastSuccessfulUpdateCheckAt != null || !hasUpdateEligibleItems) return;
    final detached = MtnMinecraftContentPackage.fromLocalMap(toLocalMap());
    try {
      final cached = await service.providers.httpService.withCacheOptions(
        cacheDuration: cacheDuration,
        cachedOnly: true,
        action: () => detached._findUpdates(service, refresh: false),
      );
      detached._updateList.addAll(cached);
    } on MtnMinecraftContentHttpCacheMissException {
      return;
    }
    _updateList.clear();
    for (final entry in detached.updateList.entries) {
      final item = getItem(entry.key.key);
      if (item != null && _mayUpdate(item)) _updateList[item] = entry.value;
    }
    _updateSelectionFingerprint = _updateFingerprint();
  }

  Future<Map<MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>> _findUpdates(
    MtnMinecraftContentService service, {required bool refresh}
  ) async {
    final found = <MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>{};
    for (final item in items) {
      if (!_mayUpdate(item)) continue;
      final selectedLock = _lock?.versions.where((entry) => entry.itemKey == item.key).firstOrNull;
      await item.hydrate(service, lock: selectedLock, refresh: refresh);
      final current = item.version;
      final published = current?.publishedAt;
      final content = item.content;
      if (current == null || published == null || content == null) continue;
      final filter = MtnMinecraftContentVersionListRequest(
        gameVersions: <String>[minecraftVersion],
        modLoaders: item.type == MtnMinecraftContentType.mod ? <MtnMinecraftModLoaderType>[modLoader] : const <MtnMinecraftModLoaderType>[],
      );
      MtnMinecraftContentVersion? next;
      var offset = 0;
      while (true) {
        final result = await service.getVersions(item.provider, content, MtnMinecraftContentVersionListRequest(
          gameVersions: filter.gameVersions, modLoaders: filter.modLoaders,
          offset: offset, limit: 50,
        ));
        for (final version in result.versions) {
          if (!_compatible(version) || version.publishedAt == null || !version.publishedAt!.isAfter(published)) continue;
          final identity = _providerIdentity(version);
          if (identity == null || '${identity.$1}:${identity.$2}' != item.key) continue;
          if (next == null || version.publishedAt!.isAfter(next.publishedAt!)) next = version;
        }
        if (!result.hasMore) break;
        if (result.versions.isEmpty) throw StateError('Provider returned an empty version page while reporting further results for ${item.key}.');
        offset += result.versions.length;
      }
      if (next != null) found[item] = next;
    }
    return found;
  }

  /// A deterministic digest of the selection, permissions and exact lock.
  /// Presentation-only edits do not invalidate scan results.
  String _updateFingerprint() {
    final selection = <String, dynamic>{
      'id': id,
      'revision': revision,
      'minecraftVersion': minecraftVersion,
      'modLoader': modLoader.name,
      'loaderVersion': loaderVersion,
      'mutationPolicy': mutationPolicy.name,
      'lock': lock?.toMap(),
      'items': (items.toList()..sort((a, b) => a.key.compareTo(b.key))).map((item) => <String, dynamic>{
        'key': item.key,
        'type': item.type.name,
        'selectedVersionId': item.selectedVersionId,
        'source': item.source.name,
        'direct': item.direct,
        'enabled': item.direct ? item.enabled : null,
        'permissions': item.permissions.map((value) => value.name).toList(growable: false),
      }).toList(growable: false),
    };
    return sha256.convert(utf8.encode(jsonEncode(selection))).toString();
  }

  /// The update snapshot belongs to the encrypted local record only; neither
  /// portable Content Packages nor the HTTP response cache include this state.
  Map<String, dynamic>? _localUpdateCheckMap() {
    final checkedAt = lastSuccessfulUpdateCheckAt;
    if (checkedAt == null) return null;
    return <String, dynamic>{
      'schemaVersion': 1,
      'selectionFingerprint': _updateSelectionFingerprint,
      'checkedAt': checkedAt.toIso8601String(),
      'updates': <Map<String, dynamic>>[
        for (final entry in updateList.entries)
          <String, dynamic>{
            'itemKey': entry.key.key,
            'content': MtnMinecraftContentModel.jsonDecode(MtnMinecraftContentModel.jsonEncode(entry.value.content.toMap())),
            'version': MtnMinecraftContentModel.jsonDecode(MtnMinecraftContentModel.jsonEncode(entry.value.toMap())),
          },
      ],
    };
  }

  void _restoreLocalUpdateCheck(Object? raw) {
    if (raw is! Map) return;
    try {
      if (raw['schemaVersion'] != 1 || raw['selectionFingerprint'] != _updateFingerprint()) return;
      final text = raw['checkedAt'];
      if (text is! String || !text.endsWith('Z')) return;
      final checkedAt = DateTime.tryParse(text);
      if (checkedAt == null || !checkedAt.isUtc) return;
      final updates = raw['updates'];
      if (updates is! List) return;
      final restored = <MtnMinecraftContentPackageItem, MtnMinecraftContentVersion>{};
      for (final value in updates) {
        if (value is! Map || value['itemKey'] is! String || value['content'] is! Map || value['version'] is! Map) return;
        final item = getItem(value['itemKey'] as String);
        if (item == null || !_mayUpdate(item) || restored.containsKey(item)) return;
        final content = MtnMinecraftContent.fromMap(Map<String, dynamic>.from(value['content'] as Map));
        final versionMap = Map<String, dynamic>.from(value['version'] as Map);
        if (versionMap['content'] != content.key) return;
        final version = MtnMinecraftContentVersion.fromMap(versionMap, content);
        final identity = _providerIdentity(version);
        if (identity == null || identity.$1 != item.provider || identity.$2 != item.projectId ||
            content.type != item.type || !_compatible(version) || version.publishedAt == null) {
          return;
        }
        restored[item] = version;
      }
      _updateList
        ..clear()
        ..addAll(restored);
      _lastSuccessfulUpdateCheckAt = checkedAt;
      _updateSelectionFingerprint = raw['selectionFingerprint'] as String;
    } catch (_) {
      // Optional stale or malformed update metadata must not block a valid
      // encrypted game record. Missing results trigger a new check when due.
    }
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
    final localUpdateCheck = requireLock ? null : _localUpdateCheckMap();
    if (requireLock && graph == null) throw StateError('Cannot export a Content Package without a complete locked graph.');
    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      if (logoImageFileName != null) 'logoImageFileName': logoImageFileName,
      'logoImageMode': logoImageMode.name,
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
      'items': (items.toList()..sort((a, b) => a.key.compareTo(b.key))).map((item) => requireLock ? item.toMap() : item.toLocalMap()).toList(growable: false),
      if (!requireLock && graph == null && _dependencyEdges.isNotEmpty) 'dependencyEdges': _dependencyEdges.map((edge) => edge.toMap()).toList(growable: false),
      if (graph != null) 'lock': graph.toMap(),
      if (localUpdateCheck != null) 'localUpdateCheck': localUpdateCheck,
    };
  }

  String toJson() => jsonEncode(toMap());
  Uint8List encode() => Uint8List.fromList(utf8.encode(toJson()));
}
