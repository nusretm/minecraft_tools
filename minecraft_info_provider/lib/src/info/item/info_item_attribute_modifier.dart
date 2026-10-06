import '../../text/minecraft_text.dart';

/// Semantic operation used by a Minecraft attribute modifier.
enum MtnMinecraftInfoAttributeModifierOperation {
  addValue,
  addMultipliedBase,
  addMultipliedTotal,
}

/// Equipment slot or slot group in which an item attribute modifier applies.
enum MtnMinecraftInfoItemAttributeModifierSlot {
  any,
  hand,
  armor,
  mainHand,
  offHand,
  head,
  chest,
  legs,
  feet,
  body,
  saddle,
}

/// Persisted display behavior for one item attribute modifier.
enum MtnMinecraftInfoItemAttributeModifierDisplayType {
  defaultDisplay,
  hidden,
  override,
}

/// Optional persisted tooltip display override for one item attribute modifier.
final class MtnMinecraftInfoItemAttributeModifierDisplay {
  const MtnMinecraftInfoItemAttributeModifierDisplay({
    required this.type,
    this.value,
  }) : assert(
          type == MtnMinecraftInfoItemAttributeModifierDisplayType.override
              ? value != null
              : value == null,
        );

  final MtnMinecraftInfoItemAttributeModifierDisplayType type;

  /// Replacement text for [MtnMinecraftInfoItemAttributeModifierDisplayType.override].
  final MtnMinecraftText? value;
}

/// One explicitly persisted item attribute modifier.
final class MtnMinecraftInfoItemAttributeModifier {
  const MtnMinecraftInfoItemAttributeModifier({
    required this.attributeId,
    required this.amount,
    required this.operation,
    required this.slot,
    this.id,
    this.legacyUuid,
    this.legacyName,
    this.display,
  }) : assert(
          (id != null && legacyUuid == null && legacyName == null) ||
              (id == null && legacyUuid != null && legacyName != null),
        );

  /// Persisted attribute registry ID/name.
  ///
  /// The provider preserves the external value rather than requiring a closed
  /// vanilla attribute registry.
  final String attributeId;

  /// 1.21+ namespaced modifier ID, when persisted in the modern identity form.
  final String? id;

  /// Pre-1.21 UUID identity, normalized to canonical lowercase text.
  ///
  /// The provider deliberately does not convert this UUID into a modern
  /// namespaced modifier ID.
  final String? legacyUuid;

  /// Pre-1.21 human-readable modifier name.
  final String? legacyName;

  final double amount;

  final MtnMinecraftInfoAttributeModifierOperation operation;

  final MtnMinecraftInfoItemAttributeModifierSlot slot;

  /// 1.21.6+ explicit display metadata, when persisted.
  final MtnMinecraftInfoItemAttributeModifierDisplay? display;
}
