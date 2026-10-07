part of 'minecraft_content_models.dart';

abstract class MtnMinecraftContentModel {
  const MtnMinecraftContentModel();

  Map<String, dynamic> toMap();

  Uint8List encode() => Uint8List.fromList(utf8.encode(toJson()));

  String toJson() => jsonEncode(toMap());

  static Map<String, dynamic> decode(Uint8List value) => jsonDecode(utf8.decode(value));

  static String jsonEncode(Map<String, dynamic> map) {
    return json.encode(
      map,
      toEncodable: (Object? value) {
        if (value is DateTime) return value.toIso8601String();
        if (value is Enum) return value.name;
        if (value is MtnMinecraftContentModel) return value.toMap();
        throw UnsupportedError('Cannot convert to JSON: $value');
      },
    );
  }

  static Map<String, dynamic> jsonDecode(String value) {
    final Object? decoded = json.decode(value);
    if (decoded is! Map<Object?, Object?>) throw const FormatException('Expected a JSON object.');
    return decoded.map((key, item) => MapEntry(key.toString(), item));
  }

  static int intFromMap(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? nullableIntFromMap(Object? value) {
    if (value == null || value == '') return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? nullableDoubleFromMap(Object? value) {
    if (value == null || value == '') return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String stringFromMap(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? nullableStringFromMap(Object? value) {
    if (value == null) return null;
    final result = value.toString();
    return result.isEmpty ? null : result;
  }

  static bool boolFromMap(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || value == '1') return true;
      if (normalized == 'false' || value == '0') return false;
    }
    return fallback;
  }

  static bool? nullableBoolFromMap(Object? value) {
    if (value == null || value == '') return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || value == '1') return true;
      if (normalized == 'false' || value == '0') return false;
    }
    return null;
  }

  static DateTime dateTimeFromMap(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      final result = dateTimeFromString(value);
      if (result != null) return result;
    }
    throw FormatException('Invalid DateTime value: $value');
  }

  static DateTime? nullableDateTimeFromMap(Object? value) {
    if (value == null || value == '') return null;
    return dateTimeFromMap(value);
  }

  static DateTime? dateTimeFromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final input = value.trim();
    final parsed = DateTime.tryParse(input);
    if (parsed != null && parsed.year > 1900) return parsed;

    final dayFirst = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(input);
    if (dayFirst != null) {
      final result = DateTime(
        int.parse(dayFirst.group(3)!),
        int.parse(dayFirst.group(2)!),
        int.parse(dayFirst.group(1)!),
        int.tryParse(dayFirst.group(4) ?? '') ?? 0,
        int.tryParse(dayFirst.group(5) ?? '') ?? 0,
        int.tryParse(dayFirst.group(6) ?? '') ?? 0,
      );
      if (result.year > 1900) return result;
    }

    final yearFirst = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(input);
    if (yearFirst != null) {
      final result = DateTime(
        int.parse(yearFirst.group(1)!),
        int.parse(yearFirst.group(2)!),
        int.parse(yearFirst.group(3)!),
        int.tryParse(yearFirst.group(4) ?? '') ?? 0,
        int.tryParse(yearFirst.group(5) ?? '') ?? 0,
        int.tryParse(yearFirst.group(6) ?? '') ?? 0,
      );
      if (result.year > 1900) return result;
    }

    return null;
  }

  static Map<String, dynamic> mapFromMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map<Object?, Object?>) return value.map((key, item) => MapEntry(key.toString(), item));
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> mapListFromMap(Object? value) {
    if (value is! Iterable<Object?>) return <Map<String, dynamic>>[];
    return value.map(mapFromMap).toList(growable: true);
  }

  static List<String> stringListFromMap(Object? value) {
    if (value is! Iterable<Object?>) return <String>[];
    return value.map((item) => item.toString()).toList(growable: true);
  }

  static T enumFromMap<T extends Enum>(List<T> values, Object? value) {
    final name = value?.toString();
    for (final item in values) {
      if (item.name == name) return item;
    }
    throw FormatException('Invalid ${T.toString()} value: $value');
  }

  static List<T> enumListFromMap<T extends Enum>(List<T> values, Object? value) {
    if (value is! Iterable<Object?>) return <T>[];
    return value.map((item) => enumFromMap(values, item)).toList(growable: true);
  }

  @override
  String toString() {
    final values = toMap().entries.map((entry) => '${entry.key}=${entry.value}').join(', ');
    return '$runtimeType($values)';
  }
}
