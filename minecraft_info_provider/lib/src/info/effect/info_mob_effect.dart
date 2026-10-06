/// Persisted Minecraft mob-effect identity normalized across storage versions.
final class MtnMinecraftInfoMobEffectId {
  MtnMinecraftInfoMobEffectId._({
    this.resourceLocation,
    this.legacyNumeric,
  });

  factory MtnMinecraftInfoMobEffectId.resourceLocation(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Mob effect resource location cannot be empty',
      );
    }
    return MtnMinecraftInfoMobEffectId._(resourceLocation: value);
  }

  factory MtnMinecraftInfoMobEffectId.legacyNumeric(int value) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Legacy mob effect ID cannot be negative',
      );
    }
    return MtnMinecraftInfoMobEffectId._(legacyNumeric: value);
  }

  /// 1.20.2+ resource-location identity, when stored in the modern format.
  final String? resourceLocation;

  /// Pre-1.20.2 numeric registry identity, when stored in the legacy format.
  ///
  /// The provider deliberately does not guess a resource location for legacy
  /// numeric IDs because modded registry mappings are not available here.
  final int? legacyNumeric;

  bool get isResourceLocation => resourceLocation != null;

  bool get isLegacyNumeric => legacyNumeric != null;

  @override
  String toString() => resourceLocation ?? legacyNumeric.toString();
}

/// Immutable semantic Minecraft mob-effect instance.
///
/// This model is intentionally shared rather than player-specific so the same
/// persisted effect structure can later be reused by item potion components.
final class MtnMinecraftInfoMobEffect {
  const MtnMinecraftInfoMobEffect({
    required this.id,
    required this.amplifier,
    required this.duration,
    required this.ambient,
    required this.showParticles,
    required this.showIcon,
    this.hiddenEffect,
  });

  final MtnMinecraftInfoMobEffectId id;

  /// Persisted amplifier value. Zero represents effect level I.
  final int amplifier;

  /// Persisted duration in game ticks.
  final int duration;

  final bool ambient;
  final bool showParticles;
  final bool showIcon;

  /// Lower-priority effect of the same type restored after this effect expires.
  final MtnMinecraftInfoMobEffect? hiddenEffect;
}
