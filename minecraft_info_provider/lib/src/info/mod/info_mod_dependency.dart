enum MtnMinecraftInfoModDependencyType {
  required,
  recommended,
  suggested,
  conflict,
  incompatible,
}

/// One provider-independent relationship from a mod to another mod/runtime ID.
final class MtnMinecraftInfoModDependency {
  MtnMinecraftInfoModDependency({
    required this.id,
    required this.type,
    Iterable<String> versionConstraints = const <String>[],
    this.clientSide = true,
    this.serverSide = true,
  }) : versionConstraints =
            List<String>.unmodifiable(versionConstraints);

  final String id;
  final MtnMinecraftInfoModDependencyType type;

  /// Alternative accepted constraints. Multiple entries are OR alternatives.
  final List<String> versionConstraints;

  /// Whether this relationship applies on the physical client side.
  final bool clientSide;

  /// Whether this relationship applies on the dedicated server side.
  final bool serverSide;

  @override
  bool operator ==(Object other) {
    if (other is! MtnMinecraftInfoModDependency ||
        id != other.id ||
        type != other.type ||
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
        clientSide,
        serverSide,
        Object.hashAll(versionConstraints),
      );
}
