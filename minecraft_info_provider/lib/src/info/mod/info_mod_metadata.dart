/// Metadata format discovered inside a mod JAR.
enum MtnMinecraftInfoModMetadataType {
  fabric,
}

/// Normalized metadata read from one installed mod JAR.
final class MtnMinecraftInfoModMetadata {
  MtnMinecraftInfoModMetadata({
    required this.type,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required List<String> authors,
  }) : authors = List<String>.unmodifiable(authors);

  final MtnMinecraftInfoModMetadataType type;
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> authors;
}
