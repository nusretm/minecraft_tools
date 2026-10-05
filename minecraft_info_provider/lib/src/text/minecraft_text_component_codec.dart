part of 'minecraft_text.dart';

final class _MtnMinecraftTextComponentCodec {
  const _MtnMinecraftTextComponentCodec();

  List<MtnMinecraftTextItem> parseJsonSource(
    String source, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    final Object? decoded = jsonDecode(source) as Object?;
    return parseJsonValue(decoded, baseStyle: baseStyle);
  }

  List<MtnMinecraftTextItem> parseJsonValue(
    Object? value, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    final List<MtnMinecraftTextItem> result = <MtnMinecraftTextItem>[];
    _appendValue(value, baseStyle, result);
    return List<MtnMinecraftTextItem>.unmodifiable(result);
  }

  List<MtnMinecraftTextItem> parseNbtValue(
    MtnMinecraftNbtValue value, {
    MtnMinecraftTextStyle baseStyle = MtnMinecraftTextStyle.defaults,
  }) {
    if (value.type == MtnMinecraftNbtType.string) {
      final String source = value.asString;
      Object? decoded;
      try {
        decoded = jsonDecode(source) as Object?;
      } on FormatException {
        final List<MtnMinecraftTextItem> result = <MtnMinecraftTextItem>[];
        _appendLiteral(source, baseStyle, result);
        return List<MtnMinecraftTextItem>.unmodifiable(result);
      }
      return parseJsonValue(decoded, baseStyle: baseStyle);
    }
    return parseJsonValue(_nbtToObject(value), baseStyle: baseStyle);
  }

  String encodeJson(Iterable<MtnMinecraftTextItem> items) =>
      jsonEncode(_itemsToComponentValue(items));

  MtnMinecraftNbtValue encodeNbt(Iterable<MtnMinecraftTextItem> items) =>
      _objectToNbt(_itemsToComponentValue(items));

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
    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> object = <String, Object?>{};
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException('Invalid Minecraft text component key');
        }
        object[entry.key as String] = entry.value;
      }
      _appendObject(object, parentStyle, result);
      return;
    }
    throw const FormatException('Invalid Minecraft text component value');
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
        throw const FormatException('Invalid Minecraft text component text');
      }
      _appendLiteral(textValue.toString(), style, result);
    } else if (object['translate'] != null) {
      _appendTranslation(object, style, result);
    } else {
      final String? fallback = _contentFallback(object);
      if (fallback != null) _appendLiteral(fallback, style, result);
    }

    final Object? extra = object['extra'];
    if (extra != null) {
      if (extra is! List<Object?>) {
        throw const FormatException('Invalid Minecraft text component extra');
      }
      for (final Object? child in extra) {
        _appendValue(child, style, result);
      }
    }
  }

  void _appendTranslation(
    Map<String, Object?> object,
    MtnMinecraftTextStyle style,
    List<MtnMinecraftTextItem> result,
  ) {
    final Object? translateValue = object['translate'];
    if (translateValue is! String || translateValue.isEmpty) {
      throw const FormatException('Invalid Minecraft text component translation');
    }

    final Object? fallbackValue = object['fallback'];
    if (fallbackValue != null && fallbackValue is! String) {
      throw const FormatException(
        'Invalid Minecraft text component translation fallback',
      );
    }
    final String? fallback = fallbackValue as String?;

    final List<MtnMinecraftText> withValues = <MtnMinecraftText>[];
    final Object? withValue = object['with'];
    if (withValue != null) {
      if (withValue is! List<Object?>) {
        throw const FormatException(
          'Invalid Minecraft text component translation arguments',
        );
      }
      for (final Object? value in withValue) {
        final List<MtnMinecraftTextItem> items =
            parseJsonValue(value, baseStyle: style);
        withValues.add(
          MtnMinecraftText._fromParsedItems(
            items: items,
            baseStyle: style,
          ),
        );
      }
    }

    _appendItem(
      MtnMinecraftTextItem(
        text: fallback ?? translateValue,
        style: style,
        translate: translateValue,
        translateFallback: fallback,
        translateWith: List<MtnMinecraftText>.unmodifiable(withValues),
      ),
      result,
    );
  }

  MtnMinecraftTextStyle _readStyle(
    Map<String, Object?> object,
    MtnMinecraftTextStyle parent,
  ) {
    var result = parent;
    final Object? colorValue = object['color'];
    if (colorValue != null) {
      if (colorValue is! String) {
        throw const FormatException('Invalid Minecraft text component color');
      }
      if (colorValue == 'reset') {
        result = result.copyWith(color: MtnMinecraftTextColor.white);
      } else {
        final MtnMinecraftTextColor? color =
            MtnMinecraftTextColor.tryFromMinecraftValue(colorValue);
        if (color == null) {
          throw const FormatException('Unknown Minecraft text component color');
        }
        result = result.copyWith(color: color);
      }
    }

    return result.copyWith(
      bold: _styleBoolean(object, 'bold', result.bold),
      italic: _styleBoolean(object, 'italic', result.italic),
      underlined: _styleBoolean(object, 'underlined', result.underlined),
      strikethrough: _styleBoolean(object, 'strikethrough', result.strikethrough),
      obfuscated: _styleBoolean(object, 'obfuscated', result.obfuscated),
    );
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
    throw FormatException('Invalid Minecraft text component style: $name');
  }

  String? _contentFallback(Map<String, Object?> object) {
    for (final String key in <String>['keybind', 'selector', 'nbt']) {
      final Object? value = object[key];
      if (value == null) continue;
      if (value is! String) {
        throw FormatException('Invalid Minecraft text component $key');
      }
      return value;
    }

    final Object? score = object['score'];
    if (score != null) {
      if (score is! Map<Object?, Object?>) {
        throw const FormatException('Invalid Minecraft text component score');
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
    final MtnMinecraftText parsed = MtnMinecraftText(text: value, baseStyle: style);
    for (final MtnMinecraftTextItem item in parsed.items) {
      _appendItem(item, result);
    }
  }

  void _appendItem(
    MtnMinecraftTextItem item,
    List<MtnMinecraftTextItem> result,
  ) {
    if (item.text.isEmpty) return;
    if (result.isNotEmpty &&
        result.last.style == item.style &&
        !result.last.isTranslated &&
        !item.isTranslated) {
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

  Object _itemsToComponentValue(Iterable<MtnMinecraftTextItem> items) {
    final List<Map<String, Object?>> components = <Map<String, Object?>>[
      for (final MtnMinecraftTextItem item in items)
        if (item.text.isNotEmpty) _itemToComponentObject(item),
    ];
    if (components.isEmpty) return <String, Object?>{'text': ''};
    if (components.length == 1) return components.single;
    return <String, Object?>{
      'text': '',
      'extra': <Object?>[...components],
    };
  }

  Map<String, Object?> _itemToComponentObject(MtnMinecraftTextItem item) {
    final String? translate = item.translate;
    final Map<String, Object?> result;
    if (translate == null) {
      result = <String, Object?>{'text': item.text};
    } else {
      result = <String, Object?>{'translate': translate};
      final String? fallback = item.translateFallback;
      if (fallback != null) {
        result['fallback'] = fallback;
      }
      if (item.translateWith.isNotEmpty) {
        result['with'] = <Object?>[
          for (final MtnMinecraftText value in item.translateWith)
            _itemsToComponentValue(value.items),
        ];
      }
    }

    if (item.color != MtnMinecraftTextColor.white) {
      result['color'] = item.color.isNamed ? item.color.name! : item.color.hex;
    }
    if (item.bold) result['bold'] = true;
    if (item.italic) result['italic'] = true;
    if (item.underlined) result['underlined'] = true;
    if (item.strikethrough) result['strikethrough'] = true;
    if (item.obfuscated) result['obfuscated'] = true;
    return result;
  }

  Object? _nbtToObject(MtnMinecraftNbtValue value) => switch (value.type) {
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
            for (final MapEntry<String, MtnMinecraftNbtValue> entry in value.asCompound.entries)
              entry.key: _nbtToObject(entry.value),
          },
        MtnMinecraftNbtType.intArray => value.asIntArray,
        MtnMinecraftNbtType.longArray => value.asLongArray,
      };

  MtnMinecraftNbtValue _objectToNbt(Object? value) {
    if (value == null) {
      throw const FormatException('Null cannot be serialized as Minecraft text NBT');
    }
    if (value is String) return MtnMinecraftNbtValue.string(value);
    if (value is bool) return MtnMinecraftNbtValue.byte(value ? 1 : 0);
    if (value is int) return MtnMinecraftNbtValue.intValue(value);
    if (value is double) return MtnMinecraftNbtValue.doubleValue(value);
    if (value is Map<String, Object?>) {
      return MtnMinecraftNbtValue.compound(
        <String, MtnMinecraftNbtValue>{
          for (final MapEntry<String, Object?> entry in value.entries)
            entry.key: _objectToNbt(entry.value),
        },
      );
    }
    if (value is List<Object?>) {
      if (value.isEmpty) {
        return MtnMinecraftNbtValue.list(
          MtnMinecraftNbtList(
            elementType: MtnMinecraftNbtType.end,
            values: const <MtnMinecraftNbtValue>[],
          ),
        );
      }
      final List<MtnMinecraftNbtValue> values = value.map(_objectToNbt).toList(growable: false);
      final MtnMinecraftNbtType elementType = values.first.type;
      for (final MtnMinecraftNbtValue item in values) {
        if (item.type != elementType) {
          throw const FormatException('Minecraft text NBT list contains heterogeneous values');
        }
      }
      return MtnMinecraftNbtValue.list(
        MtnMinecraftNbtList(elementType: elementType, values: values),
      );
    }
    throw const FormatException('Unsupported Minecraft text NBT serialization value');
  }
}
