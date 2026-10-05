import 'info_mob_effect.dart';

/// Persisted potion contents normalized across legacy item tags and modern
/// data-component storage.
///
/// This model is intentionally not item-specific because Minecraft also reuses
/// the same potion-contents structure in other persisted domains.
final class MtnMinecraftInfoPotionContents {
  MtnMinecraftInfoPotionContents({
    this.potion,
    this.customColor,
    Iterable<MtnMinecraftInfoMobEffect> customEffects =
        const <MtnMinecraftInfoMobEffect>[],
    this.customName,
  }) : customEffects =
            List<MtnMinecraftInfoMobEffect>.unmodifiable(customEffects);

  /// Persisted potion registry ID, when explicitly present.
  final String? potion;

  /// Persisted custom RGB integer, when explicitly present.
  final int? customColor;

  /// Additional explicitly persisted custom effects.
  ///
  /// The list is always immutable. Absence of the persisted custom-effects
  /// field normalizes to an empty list inside an existing potion-contents
  /// value.
  final List<MtnMinecraftInfoMobEffect> customEffects;

  /// Optional potion-name suffix used by modern potion contents.
  ///
  /// This is not a Minecraft text component; Minecraft uses it when choosing
  /// the containing stack's translation key.
  final String? customName;
}
