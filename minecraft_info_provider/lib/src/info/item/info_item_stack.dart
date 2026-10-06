import '../../nbt/minecraft_nbt.dart';
import '../../text/minecraft_text.dart';
import '../effect/info_potion_contents.dart';
import 'info_item_attribute_modifier.dart';
import 'info_item_custom_model_data.dart';

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
    this.potionContents,
    this.potionDurationScale,
    Iterable<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers,
    this.customModelData,
    Map<int, MtnMinecraftInfoItemStack>? containerContents,
    Iterable<MtnMinecraftInfoItemStack>? bundleContents,
    Iterable<MtnMinecraftInfoItemStack>? chargedProjectiles,
    this.useRemainder,
    Map<String, MtnMinecraftNbtValue>? customData,
    Map<String, MtnMinecraftNbtValue>? legacyTag,
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
        attributeModifiers = attributeModifiers == null
            ? null
            : List<MtnMinecraftInfoItemAttributeModifier>.unmodifiable(
                attributeModifiers,
              ),
        containerContents = containerContents == null
            ? null
            : Map<int, MtnMinecraftInfoItemStack>.unmodifiable(containerContents),
        bundleContents = bundleContents == null
            ? null
            : List<MtnMinecraftInfoItemStack>.unmodifiable(bundleContents),
        chargedProjectiles = chargedProjectiles == null
            ? null
            : List<MtnMinecraftInfoItemStack>.unmodifiable(chargedProjectiles),
        customData = customData == null
            ? null
            : Map<String, MtnMinecraftNbtValue>.unmodifiable(customData),
        legacyTag = legacyTag == null
            ? null
            : Map<String, MtnMinecraftNbtValue>.unmodifiable(legacyTag),
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

  /// Explicit persisted potion contents.
  ///
  /// Null means this stack did not persist potion-content metadata. An
  /// explicitly persisted empty potion-contents value remains a non-null
  /// [MtnMinecraftInfoPotionContents] with an empty custom-effect list.
  final MtnMinecraftInfoPotionContents? potionContents;

  /// Explicit duration scale applied to potion contents, when persisted.
  ///
  /// Null means the component was absent and the provider does not synthesize
  /// Minecraft's registry/default value.
  final double? potionDurationScale;

  /// Explicitly persisted item attribute modifiers.
  ///
  /// Null means no attribute-modifier override was persisted. An empty
  /// immutable list means the property was explicitly persisted as empty.
  final List<MtnMinecraftInfoItemAttributeModifier>? attributeModifiers;

  /// Explicit persisted custom-model data.
  ///
  /// Null means the stack did not persist a custom-model-data override.
  final MtnMinecraftInfoItemCustomModelData? customModelData;

  /// Explicit persisted slotted container contents.
  ///
  /// Null means no container contents were persisted. An empty immutable map
  /// means the contents were explicitly persisted as empty. Keys are persisted
  /// slot numbers; effective container capacity requires registry knowledge.
  final Map<int, MtnMinecraftInfoItemStack>? containerContents;

  /// Explicit persisted Bundle contents.
  ///
  /// Null means the property was absent. An empty immutable list means it was
  /// explicitly persisted as empty.
  final List<MtnMinecraftInfoItemStack>? bundleContents;

  /// Explicit persisted Crossbow charged projectiles.
  final List<MtnMinecraftInfoItemStack>? chargedProjectiles;

  /// Explicit item produced/returned after using this stack, when persisted.
  final MtnMinecraftInfoItemStack? useRemainder;

  /// Explicit 1.20.5+ `minecraft:custom_data` NBT compound.
  ///
  /// Null means the component was absent. An empty immutable map means an
  /// explicit empty custom-data compound was persisted.
  final Map<String, MtnMinecraftNbtValue>? customData;

  /// Raw pre-1.20.5 item `tag` compound, preserved without data-fixer guesses.
  ///
  /// This is intentionally not interpreted as modern custom data. It retains
  /// both known Minecraft fields and unknown/modded fields exactly as they
  /// were persisted while semantic fields are parsed separately as usual.
  final Map<String, MtnMinecraftNbtValue>? legacyTag;

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
