import 'dart:convert';

import '../nbt/minecraft_nbt.dart';
import 'minecraft_text.dart';

/// Internal parser that normalizes JSON and inline-NBT Minecraft text
/// components into render-ready [MtnMinecraftText].
final class MtnMinecraftTextComponentParser {
  const MtnMinecraftTextComponentParser();

  MtnMinecraftText parseJsonSource(
    String source, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    try {
      return parseJsonValue(
        jsonDecode(source),
        baseStyle: baseStyle,
      );
    } on FormatException {
      return MtnMinecraftText(text: source, baseStyle: baseStyle);
    }
  }

  MtnMinecraftText parseJsonValue(
    Object? value, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    final List<MtnMinecraftTextItem> items = <MtnMinecraftTextItem>[];
    _appendValue(value, baseStyle, items);
    return MtnMinecraftText.fromItems(items);
  }

  MtnMinecraftText parseNbtValue(
    MtnMinecraftNbtValue value, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    if (value.type == MtnMinecraftNbtType.string) {
      return parseJsonSource(value.asString, baseStyle: baseStyle);
    }
    return parseJsonValue(
      _nbtToObject(value),
      baseStyle: baseStyle,
    );
  }

  void _appendValue(
    Object? value,
    MtnMinecraftTextStyle parentStyle,
    List<MtnMinecraftTextItem> result,
  ) {
    if (value == null) return;

    if (value is String) {
      _appendLiteral(value, parentStyle, result);
      return;
    }
    if (value is num || value is bool) {
      _appendLiteral(value.toString(), parentStyle, result);
      return;
    }
    if (value is List<Object?>) {
      for (final Object? child in value) {
        _appendValue(child, parentStyle, result);
      }
      return;
    }
    if (value is Map) {
      final Map<String, Object?> object = <String, Object?>{};
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        if (entry.key is! String) {
          throw const MtnMinecraftTextComponentParserException();
        }
        object[entry.key! as String] = entry.value;
      }
      _appendObject(object, parentStyle, result);
      return;
    }

    throw const MtnMinecraftTextComponentParserException();
  }

  void _appendObject(
    Map<String, Object?> object,
    MtnMinecraftTextStyle parentStyle,
    List<MtnMinecraftTextItem> result,
  ) {
    final MtnMinecraftTextStyle style = _readStyle(object, parentStyle);

    final Object? textValue = object['text'];
    if (textValue != null) {
      if (textValue is! String && textValue is! num && textValue is! bool) {
        throw const MtnMinecraftTextComponentParserException();
      }
      _appendLiteral(textValue.toString(), style, result);
    } else {
      final String? fallback = _contentFallback(object);
      if (fallback != null) {
        _appendLiteral(fallback, style, result);
      }
    }

    final Object? extra = object['extra'];
    if (extra != null) {
      if (extra is! List<Object?>) {
        throw const MtnMinecraftTextComponentParserException();
      }
      for (final Object? child in extra) {
        _appendValue(child, style, result);
      }
    }
  }

  MtnMinecraftTextStyle _readStyle(
    Map<String, Object?> object,
    MtnMinecraftTextStyle parent,
  ) {
    var result = parent;

    final Object? colorValue = object['color'];
    if (colorValue != null) {
      if (colorValue is! String) {
        throw const MtnMinecraftTextComponentParserException();
      }
      if (colorValue == 'reset') {
        result = result.copyWith(color: MtnMinecraftTextColor.white);
      } else {
        final MtnMinecraftTextColor? color =
            MtnMinecraftTextColor.tryFromMinecraftValue(colorValue);
        if (color == null) {
          throw const MtnMinecraftTextComponentParserException();
        }
        result = result.copyWith(color: color);
      }
    }

    result = result.copyWith(
      bold: _styleBoolean(object, 'bold', result.bold),
      italic: _styleBoolean(object, 'italic', result.italic),
      underlined: _styleBoolean(
        object,
        'underlined',
        result.underlined,
      ),
      strikethrough: _styleBoolean(
        object,
        'strikethrough',
        result.strikethrough,
      ),
      obfuscated: _styleBoolean(
        object,
        'obfuscated',
        result.obfuscated,
      ),
    );
    return result;
  }

  bool _styleBoolean(
    Map<String, Object?> object,
    String name,
    bool inherited,
  ) {
    final Object? value = object[name];
    if (value == null) return inherited;
    if (value is bool) return value;
    if (value is int && (value == 0 || value == 1)) return value == 1;
    throw const MtnMinecraftTextComponentParserException();
  }

  String? _contentFallback(Map<String, Object?> object) {
    final Object? translate = object['translate'];
    if (translate != null) {
      if (translate is! String || translate.isEmpty) {
        throw const MtnMinecraftTextComponentParserException();
      }
      final Object? fallback = object['fallback'];
      if (fallback == null) return translate;
      if (fallback is! String) {
        throw const MtnMinecraftTextComponentParserException();
      }
      return fallback;
    }

    for (final String key in <String>['keybind', 'selector', 'nbt']) {
      final Object? value = object[key];
      if (value == null) continue;
      if (value is! String) {
        throw const MtnMinecraftTextComponentParserException();
      }
      return value;
    }

    final Object? score = object['score'];
    if (score != null) {
      if (score is! Map) {
        throw const MtnMinecraftTextComponentParserException();
      }
      final Object? value = score['value'];
      if (value is String) return value;
      final Object? name = score['name'];
      if (name is String) return name;
    }

    return null;
  }

  void _appendLiteral(
    String value,
    MtnMinecraftTextStyle style,
    List<MtnMinecraftTextItem> result,
  ) {
    if (value.isEmpty) return;
    final MtnMinecraftText parsed =
        MtnMinecraftText(text: value, baseStyle: style);
    for (final MtnMinecraftTextItem item in parsed.items) {
      _appendItem(item, result);
    }
  }

  void _appendItem(
    MtnMinecraftTextItem item,
    List<MtnMinecraftTextItem> result,
  ) {
    if (item.text.isEmpty) return;
    if (result.isNotEmpty && result.last.style == item.style) {
      final MtnMinecraftTextItem previous = result.removeLast();
      result.add(
        MtnMinecraftTextItem(
          text: previous.text + item.text,
          style: item.style,
        ),
      );
      return;
    }
    result.add(item);
  }

  Object? _nbtToObject(MtnMinecraftNbtValue value) {
    return switch (value.type) {
      MtnMinecraftNbtType.end => null,
      MtnMinecraftNbtType.byte => value.asByte,
      MtnMinecraftNbtType.short => value.asShort,
      MtnMinecraftNbtType.intValue => value.asInt,
      MtnMinecraftNbtType.long => value.asLong,
      MtnMinecraftNbtType.float => value.asFloat,
      MtnMinecraftNbtType.doubleValue => value.asDouble,
      MtnMinecraftNbtType.byteArray => value.asByteArray.toList(growable: false),
      MtnMinecraftNbtType.string => value.asString,
      MtnMinecraftNbtType.list => <Object?>[
          for (final MtnMinecraftNbtValue child in value.asList.values)
            _nbtToObject(child),
        ],
      MtnMinecraftNbtType.compound => <String, Object?>{
          for (final MapEntry<String, MtnMinecraftNbtValue> entry
              in value.asCompound.entries)
            entry.key: _nbtToObject(entry.value),
        },
      MtnMinecraftNbtType.intArray => value.asIntArray,
      MtnMinecraftNbtType.longArray => value.asLongArray,
    };
  }
}

final class MtnMinecraftTextComponentParserException implements Exception {
  const MtnMinecraftTextComponentParserException();
}
