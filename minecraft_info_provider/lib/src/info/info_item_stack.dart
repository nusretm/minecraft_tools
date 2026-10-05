import '../text/minecraft_text.dart';

/// Normalized persisted item-stack component overrides.
///
/// Values here represent properties explicitly serialized on the stack. They
/// do not include item-type defaults from the Minecraft item registry.
final class MtnMinecraftInfoItemStackComponents {
  MtnMinecraftInfoItemStackComponents({
    this.damage,
    this.repairCost,
    this.unbreakable,
    Map<String, int>? enchantments,
    Map<String, int>? storedEnchantments,
    this.customName,
    this.itemName,
    Iterable<MtnMinecraftText>? lore,
    Iterable<String> removedComponentIds = const <String>[],
  })  : enchantments = enchantments == null
            ? null
            : Map<String, int>.unmodifiable(enchantments),
        storedEnchantments = storedEnchantments == null
            ? null
            : Map<String, int>.unmodifiable(storedEnchantments),
        lore = lore == null
            ? null
            : List<MtnMinecraftText>.unmodifiable(lore),
        removedComponentIds =
            Set<String>.unmodifiable(removedComponentIds);

  /// Explicit durability damage consumed from the item.
  final int? damage;

  /// Explicit additional anvil repair cost.
  final int? repairCost;

  /// Explicit legacy/modern unbreakable state.
  ///
  /// Modern component presence normalizes to true. Null means this foundation
  /// did not observe an explicit value.
  final bool? unbreakable;

  /// Explicit active enchantment levels keyed by namespaced enchantment ID.
  final Map<String, int>? enchantments;

  /// Explicit stored enchantment levels, primarily used by enchanted books.
  final Map<String, int>? storedEnchantments;

  /// Explicit custom display name, such as an anvil rename.
  final MtnMinecraftText? customName;

  /// Explicit item-name component, distinct from an anvil custom name.
  final MtnMinecraftText? itemName;

  /// Explicit tooltip lore lines.
  ///
  /// Null means no lore property was persisted. An empty immutable list means
  /// lore was explicitly persisted as empty.
  final List<MtnMinecraftText>? lore;

  /// Component IDs explicitly removed by a modern item component patch.
  ///
  /// Removal is preserved separately because effective item defaults require
  /// the Minecraft item registry, which is outside this provider foundation.
  final Set<String> removedComponentIds;
}

/// Minimal semantic Minecraft item-stack snapshot.
final class MtnMinecraftInfoItemStack {
  const MtnMinecraftInfoItemStack({
    required this.id,
    required this.count,
    this.components,
  });

  /// Namespaced item identifier persisted by Minecraft.
  final String id;

  /// Semantic stack count.
  final int count;

  /// Normalized explicitly persisted item properties, when recognized.
  final MtnMinecraftInfoItemStackComponents? components;
}
