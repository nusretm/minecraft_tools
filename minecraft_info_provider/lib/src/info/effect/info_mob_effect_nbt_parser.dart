import '../../nbt/minecraft_nbt.dart';
import 'info_mob_effect.dart';

/// Internal parser for the shared persisted Minecraft mob-effect instance.
final class MtnMinecraftInfoMobEffectNbtParser {
  const MtnMinecraftInfoMobEffectNbtParser();

  List<MtnMinecraftInfoMobEffect> parseList(
    MtnMinecraftNbtValue value, {
    required bool modern,
  }) {
    if (value.type != MtnMinecraftNbtType.list) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }

    final MtnMinecraftNbtList list = value.asList;
    if (list.values.isEmpty) {
      if (list.elementType != MtnMinecraftNbtType.end &&
          list.elementType != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoMobEffectNbtParserException();
      }
      return const <MtnMinecraftInfoMobEffect>[];
    }
    if (list.elementType != MtnMinecraftNbtType.compound) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }

    return List<MtnMinecraftInfoMobEffect>.unmodifiable(
      list.values.map(
        (MtnMinecraftNbtValue entry) =>
            _parseCompound(entry.asCompound, modern: modern),
      ),
    );
  }

  MtnMinecraftInfoMobEffect _parseCompound(
    Map<String, MtnMinecraftNbtValue> data, {
    required bool modern,
  }) {
    final MtnMinecraftInfoMobEffectId id =
        modern ? _modernId(data) : _legacyId(data);
    final String amplifierName = modern ? 'amplifier' : 'Amplifier';
    final String durationName = modern ? 'duration' : 'Duration';
    final String ambientName = modern ? 'ambient' : 'Ambient';
    final String showParticlesName =
        modern ? 'show_particles' : 'ShowParticles';
    final String showIconName = modern ? 'show_icon' : 'ShowIcon';
    final String hiddenEffectName =
        modern ? 'hidden_effect' : 'HiddenEffect';

    final MtnMinecraftNbtValue? hidden = data[hiddenEffectName];
    MtnMinecraftInfoMobEffect? hiddenEffect;
    if (hidden != null) {
      if (hidden.type != MtnMinecraftNbtType.compound) {
        throw const MtnMinecraftInfoMobEffectNbtParserException();
      }
      hiddenEffect = _parseCompound(hidden.asCompound, modern: modern);
    }

    return MtnMinecraftInfoMobEffect(
      id: id,
      amplifier: _optionalAmplifier(data, amplifierName) ?? 0,
      duration: _optionalInt(data, durationName) ?? 0,
      ambient: _optionalBoolean(data, ambientName) ?? false,
      showParticles: _optionalBoolean(data, showParticlesName) ?? true,
      showIcon: _optionalBoolean(data, showIconName) ?? true,
      hiddenEffect: hiddenEffect,
    );
  }

  MtnMinecraftInfoMobEffectId _modernId(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['id'];
    if (value?.type != MtnMinecraftNbtType.string ||
        value!.asString.isEmpty) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }
    return MtnMinecraftInfoMobEffectId.resourceLocation(value.asString);
  }

  MtnMinecraftInfoMobEffectId _legacyId(
    Map<String, MtnMinecraftNbtValue> data,
  ) {
    final MtnMinecraftNbtValue? value = data['Id'];
    if (value == null) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }

    final int id = switch (value.type) {
      MtnMinecraftNbtType.byte => value.asByte & 0xff,
      MtnMinecraftNbtType.intValue => value.asInt,
      _ => throw const MtnMinecraftInfoMobEffectNbtParserException(),
    };
    if (id < 0) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }
    return MtnMinecraftInfoMobEffectId.legacyNumeric(id);
  }

  int? _optionalAmplifier(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;

    if (value.type == MtnMinecraftNbtType.byte) {
      return value.asByte & 0xff;
    }
    if (value.type == MtnMinecraftNbtType.intValue) {
      final int amplifier = value.asInt;
      if (amplifier < 0 || amplifier > 127) {
        throw const MtnMinecraftInfoMobEffectNbtParserException();
      }
      return amplifier;
    }

    throw const MtnMinecraftInfoMobEffectNbtParserException();
  }

  int? _optionalInt(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.intValue) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }
    return value.asInt;
  }

  bool? _optionalBoolean(
    Map<String, MtnMinecraftNbtValue> data,
    String name,
  ) {
    final MtnMinecraftNbtValue? value = data[name];
    if (value == null) return null;
    if (value.type != MtnMinecraftNbtType.byte ||
        (value.asByte != 0 && value.asByte != 1)) {
      throw const MtnMinecraftInfoMobEffectNbtParserException();
    }
    return value.asByte == 1;
  }
}

final class MtnMinecraftInfoMobEffectNbtParserException implements Exception {
  const MtnMinecraftInfoMobEffectNbtParserException();
}
