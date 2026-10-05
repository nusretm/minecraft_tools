/// Minecraft Java text color.
///
/// The sixteen classic colors are exposed as named static constants while
/// arbitrary RGB colors remain representable without a Flutter dependency.
final class MtnMinecraftTextColor {

  factory MtnMinecraftTextColor.fromCode(String code) {
    final MtnMinecraftTextColor? value = tryFromCode(code);
    if (value == null) {
      throw FormatException('Unknown Minecraft text color code: $code');
    }
    return value;
  }

  MtnMinecraftTextColor.rgb(this.colorR, this.colorG, this.colorB)
      : code = null,
        name = null {
    _checkChannel(colorR, 'red');
    _checkChannel(colorG, 'green');
    _checkChannel(colorB, 'blue');
  }
  const MtnMinecraftTextColor._named({
    required this.code,
    required this.name,
    required this.colorR,
    required this.colorG,
    required this.colorB,
  });

  static const MtnMinecraftTextColor black = MtnMinecraftTextColor._named(
    code: '0',
    name: 'black',
    colorR: 0,
    colorG: 0,
    colorB: 0,
  );
  static const MtnMinecraftTextColor darkBlue = MtnMinecraftTextColor._named(
    code: '1',
    name: 'dark_blue',
    colorR: 0,
    colorG: 0,
    colorB: 170,
  );
  static const MtnMinecraftTextColor darkGreen = MtnMinecraftTextColor._named(
    code: '2',
    name: 'dark_green',
    colorR: 0,
    colorG: 170,
    colorB: 0,
  );
  static const MtnMinecraftTextColor darkAqua = MtnMinecraftTextColor._named(
    code: '3',
    name: 'dark_aqua',
    colorR: 0,
    colorG: 170,
    colorB: 170,
  );
  static const MtnMinecraftTextColor darkRed = MtnMinecraftTextColor._named(
    code: '4',
    name: 'dark_red',
    colorR: 170,
    colorG: 0,
    colorB: 0,
  );
  static const MtnMinecraftTextColor darkPurple = MtnMinecraftTextColor._named(
    code: '5',
    name: 'dark_purple',
    colorR: 170,
    colorG: 0,
    colorB: 170,
  );
  static const MtnMinecraftTextColor gold = MtnMinecraftTextColor._named(
    code: '6',
    name: 'gold',
    colorR: 255,
    colorG: 170,
    colorB: 0,
  );
  static const MtnMinecraftTextColor gray = MtnMinecraftTextColor._named(
    code: '7',
    name: 'gray',
    colorR: 170,
    colorG: 170,
    colorB: 170,
  );
  static const MtnMinecraftTextColor darkGray = MtnMinecraftTextColor._named(
    code: '8',
    name: 'dark_gray',
    colorR: 85,
    colorG: 85,
    colorB: 85,
  );
  static const MtnMinecraftTextColor blue = MtnMinecraftTextColor._named(
    code: '9',
    name: 'blue',
    colorR: 85,
    colorG: 85,
    colorB: 255,
  );
  static const MtnMinecraftTextColor green = MtnMinecraftTextColor._named(
    code: 'a',
    name: 'green',
    colorR: 85,
    colorG: 255,
    colorB: 85,
  );
  static const MtnMinecraftTextColor aqua = MtnMinecraftTextColor._named(
    code: 'b',
    name: 'aqua',
    colorR: 85,
    colorG: 255,
    colorB: 255,
  );
  static const MtnMinecraftTextColor red = MtnMinecraftTextColor._named(
    code: 'c',
    name: 'red',
    colorR: 255,
    colorG: 85,
    colorB: 85,
  );
  static const MtnMinecraftTextColor lightPurple = MtnMinecraftTextColor._named(
    code: 'd',
    name: 'light_purple',
    colorR: 255,
    colorG: 85,
    colorB: 255,
  );
  static const MtnMinecraftTextColor yellow = MtnMinecraftTextColor._named(
    code: 'e',
    name: 'yellow',
    colorR: 255,
    colorG: 255,
    colorB: 85,
  );
  static const MtnMinecraftTextColor white = MtnMinecraftTextColor._named(
    code: 'f',
    name: 'white',
    colorR: 255,
    colorG: 255,
    colorB: 255,
  );

  static const List<MtnMinecraftTextColor> namedValues =
      <MtnMinecraftTextColor>[
    black,
    darkBlue,
    darkGreen,
    darkAqua,
    darkRed,
    darkPurple,
    gold,
    gray,
    darkGray,
    blue,
    green,
    aqua,
    red,
    lightPurple,
    yellow,
    white,
  ];

  /// Classic formatting code, or null for an arbitrary RGB color.
  final String? code;

  /// Minecraft named-color token, or null for an arbitrary RGB color.
  final String? name;

  final int colorR;
  final int colorG;
  final int colorB;

  int get rgb => (colorR << 16) | (colorG << 8) | colorB;

  String get hex =>
      '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  bool get isNamed => code != null;

  static MtnMinecraftTextColor? tryFromCode(String code) {
    final String clean =
        code.trim().replaceAll('§', '').replaceAll('&', '');
    if (clean.length == 1) {
      final String normalized = clean.toLowerCase();
      for (final MtnMinecraftTextColor color in namedValues) {
        if (color.code == normalized) return color;
      }
      return null;
    }

    if (clean.length == 7 && clean[0].toLowerCase() == 'x') {
      return _tryFromHexDigits(clean.substring(1));
    }
    return null;
  }

  static MtnMinecraftTextColor? tryFromMinecraftValue(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.startsWith('#') && normalized.length == 7) {
      return _tryFromHexDigits(normalized.substring(1));
    }
    for (final MtnMinecraftTextColor color in namedValues) {
      if (color.name == normalized) return color;
    }
    return null;
  }

  static MtnMinecraftTextColor? _tryFromHexDigits(String value) {
    if (value.length != 6) return null;
    final int? rgb = int.tryParse(value, radix: 16);
    if (rgb == null) return null;
    return MtnMinecraftTextColor.rgb(
      (rgb >> 16) & 0xff,
      (rgb >> 8) & 0xff,
      rgb & 0xff,
    );
  }

  @override
  String toString() => _format('&');

  String toServerString() => _format('§');

  String _format(String marker) {
    final String? code = this.code;
    if (code != null) return '$marker$code';

    final String digits = hex.substring(1);
    final StringBuffer result = StringBuffer()
      ..write(marker)
      ..write('x');
    for (final int unit in digits.codeUnits) {
      result
        ..write(marker)
        ..writeCharCode(unit);
    }
    return result.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is MtnMinecraftTextColor &&
      other.code == code &&
      other.colorR == colorR &&
      other.colorG == colorG &&
      other.colorB == colorB;

  @override
  int get hashCode => Object.hash(code, colorR, colorG, colorB);

  static void _checkChannel(int value, String name) {
    if (value < 0 || value > 255) {
      throw RangeError.range(value, 0, 255, name);
    }
  }
}

/// Classic Minecraft text-format operations.
enum MtnMinecraftTextFormat {
  obfuscated('k'),
  bold('l'),
  strikethrough('m'),
  underlined('n'),
  italic('o'),
  reset('r');

  const MtnMinecraftTextFormat(this.code);

  final String code;

  static MtnMinecraftTextFormat? tryFromCode(String code) {
    final String clean =
        code.trim().replaceAll('§', '').replaceAll('&', '').toLowerCase();
    if (clean.length != 1) return null;
    for (final MtnMinecraftTextFormat format in values) {
      if (format.code == clean) return format;
    }
    return null;
  }

  @override
  String toString() => '&$code';

  String toServerString() => '§$code';
}

/// Fully resolved style used by render-ready Minecraft text items.
final class MtnMinecraftTextStyle {
  const MtnMinecraftTextStyle({
    this.color = MtnMinecraftTextColor.white,
    this.bold = false,
    this.italic = false,
    this.underlined = false,
    this.strikethrough = false,
    this.obfuscated = false,
  });

  static const MtnMinecraftTextStyle defaults = MtnMinecraftTextStyle();

  final MtnMinecraftTextColor color;
  final bool bold;
  final bool italic;
  final bool underlined;
  final bool strikethrough;
  final bool obfuscated;

  MtnMinecraftTextStyle copyWith({
    MtnMinecraftTextColor? color,
    bool? bold,
    bool? italic,
    bool? underlined,
    bool? strikethrough,
    bool? obfuscated,
  }) =>
      MtnMinecraftTextStyle(
        color: color ?? this.color,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underlined: underlined ?? this.underlined,
        strikethrough: strikethrough ?? this.strikethrough,
        obfuscated: obfuscated ?? this.obfuscated,
      );

  @override
  bool operator ==(Object other) =>
      other is MtnMinecraftTextStyle &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic &&
      other.underlined == underlined &&
      other.strikethrough == strikethrough &&
      other.obfuscated == obfuscated;

  @override
  int get hashCode => Object.hash(
        color,
        bold,
        italic,
        underlined,
        strikethrough,
        obfuscated,
      );
}

/// One render-ready span of Minecraft text.
final class MtnMinecraftTextItem {
  const MtnMinecraftTextItem({
    required this.text,
    required this.style,
  });

  final String text;
  final MtnMinecraftTextStyle style;

  MtnMinecraftTextColor get color => style.color;
  bool get bold => style.bold;
  bool get italic => style.italic;
  bool get underlined => style.underlined;
  bool get strikethrough => style.strikethrough;
  bool get obfuscated => style.obfuscated;
}

/// Global semantic Minecraft text value.
///
/// [text] is the source of truth. Classic section-sign formatting is resolved
/// lazily into [items], and changing [text] automatically changes subsequent
/// [plainText] and [items] results.
final class MtnMinecraftText {
  MtnMinecraftText({
    required this.text,
    this.baseStyle = MtnMinecraftTextStyle.defaults,
  });

  factory MtnMinecraftText.fromItems(
    Iterable<MtnMinecraftTextItem> items,
  ) =>
      MtnMinecraftText(text: _encodeItems(items));

  String text;

  /// Effective starting style for source text before any formatting code.
  final MtnMinecraftTextStyle baseStyle;

  String get plainText {
    final StringBuffer result = StringBuffer();
    for (final MtnMinecraftTextItem item in items) {
      result.write(item.text);
    }
    return result.toString();
  }

  List<MtnMinecraftTextItem> get items =>
      _MtnMinecraftLegacyTextParser(text, baseStyle).parse();

  @override
  String toString() => text;
}

final class _MtnMinecraftLegacyTextParser {
  _MtnMinecraftLegacyTextParser(this.source, this.baseStyle);

  final String source;
  final MtnMinecraftTextStyle baseStyle;

  List<MtnMinecraftTextItem> parse() {
    final List<MtnMinecraftTextItem> result = <MtnMinecraftTextItem>[];
    final StringBuffer buffer = StringBuffer();
    var style = baseStyle;

    void flush() {
      if (buffer.isEmpty) return;
      final String value = buffer.toString();
      buffer.clear();

      if (result.isNotEmpty && result.last.style == style) {
        final MtnMinecraftTextItem previous = result.removeLast();
        result.add(
          MtnMinecraftTextItem(
            text: previous.text + value,
            style: style,
          ),
        );
        return;
      }
      result.add(MtnMinecraftTextItem(text: value, style: style));
    }

    var index = 0;
    while (index < source.length) {
      if (source.codeUnitAt(index) != 0x00a7 || index + 1 >= source.length) {
        buffer.writeCharCode(source.codeUnitAt(index));
        index++;
        continue;
      }

      final String next =
          String.fromCharCode(source.codeUnitAt(index + 1)).toLowerCase();
      if (next == 'x') {
        final _RgbSequence? rgb = _readRgb(index);
        if (rgb != null) {
          flush();
          style = MtnMinecraftTextStyle(color: rgb.color);
          index = rgb.nextIndex;
          continue;
        }

        final int literalEnd = _readMalformedRgbPrefixEnd(index);
        buffer.write(source.substring(index, literalEnd));
        index = literalEnd;
        continue;
      }

      final MtnMinecraftTextColor? color =
          MtnMinecraftTextColor.tryFromCode(next);
      if (color != null) {
        flush();
        style = MtnMinecraftTextStyle(color: color);
        index += 2;
        continue;
      }

      final MtnMinecraftTextFormat? format =
          MtnMinecraftTextFormat.tryFromCode(next);
      if (format != null) {
        flush();
        style = switch (format) {
          MtnMinecraftTextFormat.obfuscated =>
            style.copyWith(obfuscated: true),
          MtnMinecraftTextFormat.bold => style.copyWith(bold: true),
          MtnMinecraftTextFormat.strikethrough =>
            style.copyWith(strikethrough: true),
          MtnMinecraftTextFormat.underlined =>
            style.copyWith(underlined: true),
          MtnMinecraftTextFormat.italic => style.copyWith(italic: true),
          MtnMinecraftTextFormat.reset => baseStyle,
        };
        index += 2;
        continue;
      }

      buffer.write('§');
      index++;
    }

    flush();
    return List<MtnMinecraftTextItem>.unmodifiable(result);
  }

  int _readMalformedRgbPrefixEnd(int index) {
    var cursor = index + 2;
    var parts = 0;

    while (parts < 6 &&
        cursor + 1 < source.length &&
        source.codeUnitAt(cursor) == 0x00a7) {
      final String digit =
          String.fromCharCode(source.codeUnitAt(cursor + 1));
      if (int.tryParse(digit, radix: 16) == null) break;
      cursor += 2;
      parts++;
    }

    return cursor;
  }

  _RgbSequence? _readRgb(int index) {
    if (index + 13 >= source.length) return null;

    final StringBuffer digits = StringBuffer();
    var cursor = index + 2;
    for (var part = 0; part < 6; part++) {
      if (cursor + 1 >= source.length ||
          source.codeUnitAt(cursor) != 0x00a7) {
        return null;
      }
      final String digit = String.fromCharCode(source.codeUnitAt(cursor + 1));
      if (int.tryParse(digit, radix: 16) == null) return null;
      digits.write(digit);
      cursor += 2;
    }

    final MtnMinecraftTextColor? color =
        MtnMinecraftTextColor._tryFromHexDigits(digits.toString());
    if (color == null) return null;
    return _RgbSequence(color: color, nextIndex: cursor);
  }
}

final class _RgbSequence {
  const _RgbSequence({
    required this.color,
    required this.nextIndex,
  });

  final MtnMinecraftTextColor color;
  final int nextIndex;
}

String _encodeItems(Iterable<MtnMinecraftTextItem> items) {
  final StringBuffer result = StringBuffer();
  for (final MtnMinecraftTextItem item in items) {
    if (item.text.isEmpty) continue;
    result.write(MtnMinecraftTextFormat.reset.toServerString());
    result.write(item.color.toServerString());
    if (item.obfuscated) {
      result.write(MtnMinecraftTextFormat.obfuscated.toServerString());
    }
    if (item.bold) {
      result.write(MtnMinecraftTextFormat.bold.toServerString());
    }
    if (item.strikethrough) {
      result.write(MtnMinecraftTextFormat.strikethrough.toServerString());
    }
    if (item.underlined) {
      result.write(MtnMinecraftTextFormat.underlined.toServerString());
    }
    if (item.italic) {
      result.write(MtnMinecraftTextFormat.italic.toServerString());
    }
    result.write(item.text);
  }
  return result.toString();
}