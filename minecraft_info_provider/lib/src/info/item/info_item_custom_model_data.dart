/// Explicitly persisted Minecraft item custom-model data.
///
/// Pre-1.21.4 numeric storage is preserved in [legacyValue]. Current storage
/// keeps the four independent lists introduced by the expanded component.
final class MtnMinecraftInfoItemCustomModelData {
  MtnMinecraftInfoItemCustomModelData({
    this.legacyValue,
    Iterable<double> floats = const <double>[],
    Iterable<bool> flags = const <bool>[],
    Iterable<String> strings = const <String>[],
    Iterable<int> colors = const <int>[],
  })  : assert(
          legacyValue == null ||
              (floats.isEmpty &&
                  flags.isEmpty &&
                  strings.isEmpty &&
                  colors.isEmpty),
        ),
        floats = List<double>.unmodifiable(floats),
        flags = List<bool>.unmodifiable(flags),
        strings = List<String>.unmodifiable(strings),
        colors = List<int>.unmodifiable(colors);

  /// Numeric CustomModelData representation used before the 1.21.4 expansion.
  ///
  /// This covers both the legacy CustomModelData item tag and the
  /// 1.20.5-1.21.3 minecraft:custom_model_data integer component.
  final int? legacyValue;

  /// Current numeric model-property values.
  final List<double> floats;

  /// Current boolean model-property values.
  final List<bool> flags;

  /// Current discrete string model-property values.
  final List<String> strings;

  /// Current packed RGB color values.
  ///
  /// Values are preserved as persisted integers rather than constrained to a
  /// text-color or rendering-specific abstraction.
  final List<int> colors;
}
