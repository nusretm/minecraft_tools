import 'mtn_minecraft_resource_source_abs.dart';

/// A generic Minecraft client resource identity (namespace:path).
///
/// Unlike an item registry ID, this represents models, item definitions and
/// textures. Unqualified IDs use the Minecraft namespace.
final class MtnMinecraftResourceLocation {
  MtnMinecraftResourceLocation({
    required this.namespace,
    required this.path,
  }) {
    MtnMinecraftResourceSourceAbs.validateResource(namespace, path);
    if (path.split('/').any((String segment) => segment.isEmpty || segment == '.')) {
      throw ArgumentError.value(path, 'path', 'must have non-empty resource segments');
    }
  }

  factory MtnMinecraftResourceLocation.parse(
    String id, {
    String defaultNamespace = 'minecraft',
  }) {
    if (id.isEmpty || id.trim() != id) {
      throw ArgumentError.value(id, 'id', 'must be a non-empty resource identifier');
    }

    final int separator = id.indexOf(':');
    if (separator != id.lastIndexOf(':')) {
      throw ArgumentError.value(id, 'id', 'must contain no more than one namespace separator');
    }

    return MtnMinecraftResourceLocation(
      namespace: separator < 0 ? defaultNamespace : id.substring(0, separator),
      path: separator < 0 ? id : id.substring(separator + 1),
    );
  }

  final String namespace;
  final String path;

  @override
  String toString() => '$namespace:$path';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MtnMinecraftResourceLocation &&
          other.namespace == namespace &&
          other.path == path;

  @override
  int get hashCode => Object.hash(namespace, path);
}
