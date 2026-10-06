import '../../nbt/minecraft_nbt.dart';
import 'info_mob_effect.dart';
import 'info_mob_effect_nbt_parser.dart';
import 'info_potion_contents.dart';

/// Internal cross-version parser for persisted potion contents.
final class MtnMinecraftInfoPotionContentsNbtParser {
  const MtnMinecraftInfoPotionContentsNbtParser();

  MtnMinecraftInfoPotionContents? parseLegacy(
    Map<String, MtnMinecraftNbtValue> tag,
  ) {
    const List<String> names = <String>[
      'Potion',
      'CustomPotionColor',
      'custom_potion_effects',
      'CustomPotionEffects',
    ];
    if (!names.any(tag.containsKey)) return null;

    final List<MtnMinecraftInfoMobEffect> customEffects;
    final MtnMinecraftNbtValue? modernEffects =
        tag['custom_potion_effects'];
    final MtnMinecraftNbtValue? legacyEffects =
        tag['CustomPotionEffects'];
    if (modernEffects != null) {
      customEffects = _parseEffects(modernEffects, modern: true);
    } else if (legacyEffects != null) {
      customEffects = _parseEffects(legacyEffects, modern: false);
    } else {
      customEffects = const <MtnMinecraftInfoMobEffect>[];
    }

    return MtnMinecraftInfoPotionContents(
      potion: _optionalNonEmptyString(tag, 'Potion'),
      customColor: _optionalInt(tag, 'CustomPotionColor'),
      customEffects: customEffects,
    );
  }

  MtnMinecraftInfoPotionContents parseModern(
    MtnMinecraftNbtValue value,
  ) {
    if (value.type == MtnMinecraftNbtType.string) {
      final String potion = value.asString;
      if (potion.isEmpty) {
        throw const MtnMinecraftInfoPotionContentsNbtParserException();
      }
      return MtnMinecraftInfoPotionContents(potion: potion);
    }
    if (value.type != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoPotionContentsNbtParserException();
    }

    final Map<String, MtnMinecraftNbtValue> data = value.asCompound;
    final MtnMinecraftNbtValue? customEffectsValue =
        data['custom_effects'];
    final List<MtnMinecraftInfoMobEffect> customEffects =
        customEffectsValue == null
            ? const <MtnMinecraftInfoMobEffect>[]
            : _parseEffects(customEffectsValue, modern: true);

    return MtnMinecraftInfoPotionContents(
      potion: _optionalNonEmptyString(data, 'potion'),
      customColor: _optionalInt(data, 'custom_color'),
      customEffects: customEffects,
      customName: _optionalString(data, 'custom_name'),
    );
  }

  List<MtnMinecraftInfoMobEffect> _parseEffects(
    MtnMinecraftNbtValue value, {
    required bool modern,
  }) {
    try {
      return const MtnMinecraftInfoMobEffectNbtParser().parseList(
        value,
        modern: modern,
      );
    } on MtnMinecraftInfoMobEffectNbtParserException {
      throw const MtnMinecraftInfoPotionContentsNbtParserException();
    }
  }

  String? _optionalNonEmptyString(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final String? value = _optionalString(data, name);
    if (value != null && value.isEmpty) {
      throw const MtnMinecraftInfoPotionContentsNbtParserException();
    }
    return value;
  }

  String? _optionalString(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.string) {
      throw const MtnMinecraftInfoPotionContentsNbtParserException();
    }
    return value.asString;
  }

  int? _optionalInt(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.intValue) {
      throw const MtnMinecraftInfoPotionContentsNbtParserException();
    }
    return value.asInt;
  }
}

final class MtnMinecraftInfoPotionContentsNbtParserException
    implements Exception {
  const MtnMinecraftInfoPotionContentsNbtParserException();
}
