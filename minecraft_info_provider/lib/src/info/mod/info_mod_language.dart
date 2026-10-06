import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'info_mod_asset_source.dart';

enum MtnMinecraftInfoModLanguageError {
  invalidData,
}

final class MtnMinecraftInfoModLanguageException implements Exception {
  const MtnMinecraftInfoModLanguageException(this.error);

  final MtnMinecraftInfoModLanguageError error;

  @override
  String toString() =>
      'MtnMinecraftInfoModLanguageException(${error.name})';
}

/// One exact-locale translation table read from one mod asset source.
final class MtnMinecraftInfoModLanguage {
  MtnMinecraftInfoModLanguage._({
    required this.source,
    required this.namespace,
    required this.locale,
    required Map<String, String> translations,
  }) : translations = UnmodifiableMapView<String, String>(
          Map<String, String>.of(translations),
        );

  static void validateLocale(String locale) {
    if (!_localePattern.hasMatch(locale)) {
      throw ArgumentError.value(
        locale,
        'locale',
        'must be a lowercase Minecraft language locale',
      );
    }
  }

  factory MtnMinecraftInfoModLanguage.parse({
    required MtnMinecraftInfoModAssetSource source,
    required String namespace,
    required String locale,
    required Uint8List bytes,
  }) {
    validateLocale(locale);
    if (!source.containsNamespace(namespace)) {
      throw ArgumentError.value(
        namespace,
        'namespace',
        'is not exposed by the asset source',
      );
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(bytes),
      );
    } on FormatException {
      throw const MtnMinecraftInfoModLanguageException(
        MtnMinecraftInfoModLanguageError.invalidData,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const MtnMinecraftInfoModLanguageException(
        MtnMinecraftInfoModLanguageError.invalidData,
      );
    }

    final Map<String, String> translations = <String, String>{};
    for (final MapEntry<String, dynamic> entry in decoded.entries) {
      final Object? value = entry.value;
      if (value is! String) {
        throw const MtnMinecraftInfoModLanguageException(
          MtnMinecraftInfoModLanguageError.invalidData,
        );
      }
      translations[entry.key] = value;
    }

    return MtnMinecraftInfoModLanguage._(
      source: source,
      namespace: namespace,
      locale: locale,
      translations: translations,
    );
  }

  final MtnMinecraftInfoModAssetSource source;
  final String namespace;
  final String locale;
  final Map<String, String> translations;

  bool contains(String key) => translations.containsKey(key);

  String? operator [](String key) => translations[key];

  MtnMinecraftInfoModTranslation? translation(String key) {
    final String? value = translations[key];
    if (value == null) return null;

    return MtnMinecraftInfoModTranslation(
      source: source,
      namespace: namespace,
      locale: locale,
      key: key,
      value: value,
    );
  }
}

/// One translation-key candidate preserved with its exact asset source.
final class MtnMinecraftInfoModTranslation {
  const MtnMinecraftInfoModTranslation({
    required this.source,
    required this.namespace,
    required this.locale,
    required this.key,
    required this.value,
  });

  final MtnMinecraftInfoModAssetSource source;
  final String namespace;
  final String locale;
  final String key;
  final String value;
}

final RegExp _localePattern = RegExp(r'^[a-z0-9_-]+$');
