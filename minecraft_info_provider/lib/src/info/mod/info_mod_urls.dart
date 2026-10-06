/// Provider-independent URLs associated with one Minecraft mod.
final class MtnMinecraftInfoModUrls {
  const MtnMinecraftInfoModUrls({
    this.homepage,
    this.source,
    this.issues,
  });

  final String? homepage;
  final String? source;
  final String? issues;

  bool get isEmpty =>
      homepage == null &&
      source == null &&
      issues == null;

  MtnMinecraftInfoModUrls mergeMissing(
    MtnMinecraftInfoModUrls other,
  ) => MtnMinecraftInfoModUrls(
        homepage: homepage ?? other.homepage,
        source: source ?? other.source,
        issues: issues ?? other.issues,
      );

  @override
  bool operator ==(Object other) =>
      other is MtnMinecraftInfoModUrls &&
      homepage == other.homepage &&
      source == other.source &&
      issues == other.issues;

  @override
  int get hashCode => Object.hash(homepage, source, issues);
}
