import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_service.dart';
import 'minecraft_content_package_lock.dart';
import 'minecraft_content_package_metadata_cache.dart';

enum MtnMinecraftContentItemPermission { enable, disable, remove, update }

enum MtnMinecraftContentItemState { notLoaded, loading, loaded, error }

/// Portable item identity and presentation metadata. Hydration state is never exported.
class MtnMinecraftContentPackageItem {
  MtnMinecraftContentPackageItem({
    required this.provider,
    required this.projectId,
    required this.type,
    required this.title,
    this.description,
    this.iconUrl,
    this.direct = false,
    bool enabled = true,
    Iterable<MtnMinecraftContentItemPermission> permissions = const <MtnMinecraftContentItemPermission>[],
  }) : permissions = List<MtnMinecraftContentItemPermission>.unmodifiable(permissions),
       _enabled = enabled {
    if (provider.isEmpty || provider.contains(':') || provider.trim() != provider) throw ArgumentError.value(provider, 'provider', 'Provider identity must be nonempty, trimmed and contain no colon.');
    if (projectId.isEmpty || projectId.trim() != projectId) throw ArgumentError.value(projectId, 'projectId', 'Project identity must be nonempty and trimmed.');
    if (title.trim().isEmpty) throw ArgumentError.value(title, 'title', 'Item title cannot be empty.');
    if (this.permissions.toSet().length != this.permissions.length) throw ArgumentError.value(this.permissions, 'permissions', 'Duplicate permissions.');
    if (!direct && !enabled) throw ArgumentError.value(enabled, 'enabled', 'Dependency activity is derived from active direct roots.');
    if (!direct && this.permissions.any((value) => value == MtnMinecraftContentItemPermission.enable || value == MtnMinecraftContentItemPermission.disable)) throw ArgumentError.value(this.permissions, 'permissions', 'Dependencies cannot have manual enable/disable permissions.');
  }

  factory MtnMinecraftContentPackageItem.fromMap(Map<String, dynamic> map) {
    final direct = map['direct'] == true;
    final rawPermissions = map['permissions'];
    if (rawPermissions is! List) throw const FormatException('Item permissions must be a list.');
    final permissions = rawPermissions.map((value) {
      for (final permission in MtnMinecraftContentItemPermission.values) {
        if (permission.name == value) return permission;
      }
      throw FormatException('Unknown item permission: $value');
    }).toList(growable: false);
    if (!direct && map.containsKey('enabled')) throw const FormatException('Dependency enabled state cannot be serialized.');
    final enabled = map['enabled'] ?? true;
    if (enabled is! bool) throw const FormatException('Item enabled must be boolean.');
    final typeName = map['type'];
    MtnMinecraftContentType? type;
    for (final candidate in MtnMinecraftContentType.values) {
      if (candidate.name == typeName) type = candidate;
    }
    if (type == null) throw FormatException('Unknown content type: $typeName');
    final provider = map['provider'];
    final projectId = map['projectId'];
    final title = map['title'];
    if (provider is! String || projectId is! String || title is! String) throw const FormatException('Invalid portable item identity or title.');
    if (map['direct'] is! bool) throw const FormatException('Item direct must be boolean.');
    final description = map['description'];
    final iconUrl = map['iconUrl'];
    if (description != null && description is! String) throw const FormatException('Item description must be text.');
    if (iconUrl != null && iconUrl is! String) throw const FormatException('Item iconUrl must be text.');
    return MtnMinecraftContentPackageItem(
      provider: provider,
      projectId: projectId,
      type: type,
      title: title,
      description: description as String?,
      iconUrl: iconUrl as String?,
      direct: direct,
      enabled: enabled,
      permissions: permissions,
    );
  }

  final String provider;
  final String projectId;
  final MtnMinecraftContentType type;
  final String title;
  final String? description;
  final String? iconUrl;
  final bool direct;
  final List<MtnMinecraftContentItemPermission> permissions;
  bool _enabled;

  String get key => '$provider:$projectId';
  bool get directEnabled => direct && _enabled;
  bool get canEnable => direct && permissions.contains(MtnMinecraftContentItemPermission.enable);
  bool get canDisable => direct && permissions.contains(MtnMinecraftContentItemPermission.disable);
  bool get canRemove => permissions.contains(MtnMinecraftContentItemPermission.remove);
  bool get canUpdate => permissions.contains(MtnMinecraftContentItemPermission.update);

  MtnMinecraftContentItemState _state = MtnMinecraftContentItemState.notLoaded;
  MtnMinecraftContent? _content;
  MtnMinecraftContentVersion? _version;
  MtnMinecraftContentFile? _file;
  MtnMinecraftContentPackageLockedVersion? _verifiedLock;
  MtnMinecraftContentPackageLockedVersion? _pendingLock;
  Object? _loadError;
  Future<void>? _pending;

  MtnMinecraftContentItemState get state => _state;
  MtnMinecraftContent? get content => _content;
  MtnMinecraftContentVersion? get version => _version;
  MtnMinecraftContentFile? get file => _file;
  Object? get loadError => _loadError;

  void setDirectEnabled(bool value) {
    if (!direct) throw StateError('Dependency state is derived; it cannot be changed manually.');
    if (_enabled == value) return;
    if (value && !canEnable) throw StateError('Item cannot be enabled.');
    if (!value && !canDisable) throw StateError('Item cannot be disabled.');
    _enabled = value;
  }

  /// Retrieves metadata and optionally validates the exact locked version/file.
  /// Passing refresh=true bypasses successful cached metadata, but joins an
  /// already running request for the same identity.
  Future<void> hydrate(
    MtnMinecraftContentService service, {
    MtnMinecraftContentPackageMetadataCache? cache,
    MtnMinecraftContentPackageLockedVersion? lock,
    bool refresh = false,
  }) {
    if (cache != null && !identical(cache.service, service)) throw ArgumentError.value(cache, 'cache', 'Cache belongs to another Content Service.');
    if (lock != null && lock.itemKey != key) throw ArgumentError.value(lock, 'lock', 'Lock does not belong to this item.');
    final pending = _pending;
    if (pending != null) {
      if (lock != null && (_pendingLock == null || !_pendingLock!.sameSelection(lock))) throw StateError('A different lock is already hydrating for $key.');
      return pending;
    }
    if (!refresh && _state == MtnMinecraftContentItemState.loaded && (lock == null || (_verifiedLock != null && _verifiedLock!.sameSelection(lock)))) return Future<void>.value();

    _pendingLock = lock;
    late final Future<void> request;
    request = _load(service, cache: cache, lock: lock, refresh: refresh).whenComplete(() {
      if (identical(_pending, request)) {
        _pending = null;
        _pendingLock = null;
      }
    });
    _pending = request;
    return request;
  }

  Future<void> _load(
    MtnMinecraftContentService service, {
    required MtnMinecraftContentPackageMetadataCache? cache,
    required MtnMinecraftContentPackageLockedVersion? lock,
    required bool refresh,
  }) async {
    _state = MtnMinecraftContentItemState.loading;
    _loadError = null;
    try {
      final resolved = await (cache == null ? service.getContent(provider, projectId) : cache.getContent(provider, projectId, refresh: refresh));
      if (resolved.type != type || !resolved.providers.any((metadata) => metadata.provider == provider && metadata.id == projectId)) {
        throw FormatException('Provider returned mismatched identity or type for $key.');
      }

      MtnMinecraftContentVersion? exactVersion;
      MtnMinecraftContentFile? selectedFile;
      if (lock != null) {
        exactVersion = await (cache == null ? service.getVersion(provider, lock.versionId) : cache.getVersion(provider, lock.versionId, refresh: refresh));
        if (exactVersion.content.type != type) throw FormatException('Locked version content type does not match item $key.');
        selectedFile = lock.verify(provider, projectId, exactVersion);
      }

      _content = resolved;
      _version = exactVersion;
      _file = selectedFile;
      _verifiedLock = lock;
      _state = MtnMinecraftContentItemState.loaded;
    } catch (error) {
      _content = null;
      _version = null;
      _file = null;
      _verifiedLock = null;
      _loadError = error;
      _state = MtnMinecraftContentItemState.error;
      rethrow;
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'provider': provider,
    'projectId': projectId,
    'type': type.name,
    'title': title,
    if (description != null) 'description': description,
    if (iconUrl != null) 'iconUrl': iconUrl,
    'direct': direct,
    if (direct) 'enabled': _enabled,
    'permissions': permissions.map((permission) => permission.name).toList(growable: false),
  };
}
