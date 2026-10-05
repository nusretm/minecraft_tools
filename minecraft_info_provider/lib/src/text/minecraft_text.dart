/// Minecraft Java text color.
///
/// The sixteen classic colors are exposed as named static constants while
/// arbitrary RGB colors remain representable without a Flutter dependency.
final class MtnMinecraftTextColor {
  const MtnMinecraftTextColor._named({
    required this.code,
    required this.name,
    required this.red,
    required this.green,
    required this.blue,
  });

  MtnMinecraftTextColor.rgb(this.red, this.green, this.blue)
      : code = null,
        name = null {
    _checkChannel(red, 'red');
    _checkChannel(green, 'green');
    _checkChannel(blue, 'blue');
  }

  static const MtnMinecraftTextColor black = MtnMinecraftTextColor._named(
    code: '0',
    name: 'black',
    red: 0,
    green: 0,
    blue: 0,
  );
  static const MtnMinecraftTextColor darkBlue = MtnMinecraftTextColor._named(
    code: '1',
    name: 'dark_blue',
    red: 0,
    green: 0,
    blue: 170,
  );
  static const MtnMinecraftTextColor darkGreen = MtnMinecraftTextColor._named(
    code: '2',
    name: 'dark_green',
    red: 0,
    green: 170,
    blue: 0,
  );
  static const MtnMinecraftTextColor darkAqua = MtnMinecraftTextColor._named(
    code: '3',
    name: 'dark_aqua',
    red: 0,
    green: 170,
    blue: 170,
  );
  static const MtnMinecraftTextColor darkRed = MtnMinecraftTextColor._named(
    code: '4',
    name: 'dark_red',
    red: 170,
    green: 0,
    blue: 0,
  );
  static const MtnMinecraftTextColor darkPurple = MtnMinecraftTextColor._named(
    code: '5',
    name: 'dark_purple',
    red: 170,
    green: 0,
    blue: 170,
  );
  static const MtnMinecraftTextColor gold = MtnMinecraftTextColor._named(
    code: '6',
    name: 'gold',
    red: 255,
    green: 170,
    blue: 0,
  );
  static const MtnMinecraftTextColor gray = MtnMinecraftTextColor._named(
    code: '7',
    name: 'gray',
    red: 170,
    green: 170,
    blue: 170,
  );
  static const MtnMinecraftTextColor darkGray = MtnMinecraftTextColor._named(
    code: '8',
    name: 'dark_gray',
    red: 85,
    green: 85,
    blue: 85,
  );
  static const MtnMinecraftTextColor blue = MtnMinecraftTextColor._named(
    code: '9',
    name: 'blue',
    red: 85,
    green: 85,
    blue: 255,
  );
  static const MtnMinecraftTextColor green = MtnMinecraftTextColor._named(
    code: 'a',
    name: 'green',
    red: 85,
    green: 255,
    blue: 85,
  );
  static const MtnMinecraftTextColor aqua = MtnMinecraftTextColor._named(
    code: 'b',
    name: 'aqua',
    red: 85,
    green: 255,
    blue: 255,
  );
  static const MtnMinecraftTextColor red = MtnMinecraftTextColor._named(
    code: 'c',
    name: 'red',
    red: 255,
    green: 85,
    blue: 85,
  );
  static const MtnMinecraftTextColor lightPurple = MtnMinecraftTextColor._named(
    code: 'd',
    name: 'light_purple',
    red: 255,
    green: 85,
    blue: 255,
  );
  static const MtnMinecraftTextColor yellow = MtnMinecraftTextColor._named(
    code: 'e',
    name: 'yellow',
    red: 255,
    green: 255,
    blue: 85,
  );
  static const MtnMinecraftTextColor white = MtnMinecraftTextColor._named(
    code: 'f',
    name: 'white',
    red: 255,
    green: 255,
    blue: 255,
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

  final int red;
  final int green;
  final int blue;

  int get rgb => (red << 16) | (green << 8) | blue;

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

  factory MtnMinecraftTextColor.fromCode(String code) {
    final MtnMinecraftTextColor? value = tryFromCode(code);
    if (value == null) {
      throw FormatException('Unknown Minecraft text color code: $code');
    }
    return value;
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
      other.red == red &&
      other.green == green &&
      other.blue == blue;

  @override
  int get hashCode => Object.hash(code, red, green, blue);

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
  MtnMinecraftText({required String text}) : _text = text;

  factory MtnMinecraftText.fromItems(
    Iterable<MtnMinecraftTextItem> items,
  ) =>
      MtnMinecraftText(text: _encodeItems(items));

  String _text;

  String get text => _text;

  set text(String value) {
    _text = value;
  }

  String get plainText {
    final StringBuffer result = StringBuffer();
    for (final MtnMinecraftTextItem item in items) {
      result.write(item.text);
    }
    return result.toString();
  }

  List<MtnMinecraftTextItem> get items =>
      _MtnMinecraftLegacyTextParser(_text).parse();

  @override
  String toString() => text;
}

final class _MtnMinecraftLegacyTextParser {
  _MtnMinecraftLegacyTextParser(this.source);

  final String source;

  List<MtnMinecraftTextItem> parse() {
    final List<MtnMinecraftTextItem> result = <MtnMinecraftTextItem>[];
    final StringBuffer buffer = StringBuffer();
    var style = MtnMinecraftTextStyle.defaults;

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
          MtnMinecraftTextFormat.reset => MtnMinecraftTextStyle.defaults,
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
