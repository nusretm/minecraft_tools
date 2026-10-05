/// Minimal semantic Minecraft item-stack snapshot.
///
/// Item metadata such as legacy `tag` and modern `components` is
/// intentionally outside the inventory/equipment foundation.
final class MtnMinecraftInfoItemStack {
  const MtnMinecraftInfoItemStack({
    required this.id,
    required this.count,
  });

  /// Namespaced item identifier persisted by Minecraft.
  final String id;

  /// Semantic stack count.
  final int count;
}
