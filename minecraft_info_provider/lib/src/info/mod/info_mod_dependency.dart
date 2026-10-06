enum MtnMinecraftInfoModDependencyType {
  required,
  optional,
  recommended,
  suggested,
  conflict,
  incompatible,
}

enum MtnMinecraftInfoModDependencyOrdering {
  none,
  before,
  after,
}

/// One provider-independent relationship from a mod to another mod/runtime ID.
final class MtnMinecraftInfoModDependency {
  MtnMinecraftInfoModDependency({
    required this.id,
    required this.type,
    Iterable<String> versionConstraints = const <String>[],
    this.ordering = MtnMinecraftInfoModDependencyOrdering.none,
    this.clientSide = true,
    this.serverSide = true,
  }) : versionConstraints =
            List<String>.unmodifiable(versionConstraints);

  final String id;
  final MtnMinecraftInfoModDependencyType type;

  /// Alternative accepted constraints. Multiple entries are OR alternatives.
  final List<String> versionConstraints;

  final MtnMinecraftInfoModDependencyOrdering ordering;

  /// Whether this relationship applies on the physical client side.
  final bool clientSide;

  /// Whether this relationship applies on the dedicated server side.
  final bool serverSide;

  @override
  bool operator ==(Object other) {
    if (other is! MtnMinecraftInfoModDependency ||
        id != other.id ||
        type != other.type ||
        ordering != other.ordering ||
        clientSide != other.clientSide ||
        serverSide != other.serverSide ||
        versionConstraints.length != other.versionConstraints.length) {
      return false;
    }

    for (int index = 0; index < versionConstraints.length; index++) {
      if (versionConstraints[index] != other.versionConstraints[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        ordering,
        clientSide,
        serverSide,
        Object.hashAll(versionConstraints),
      );
}
