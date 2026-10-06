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
  MtnMinecraftInfoModLanguage({
    required this.source,
    required this.namespace,
    required this.locale,
    required Map<String, String> translations,
  }) : translations = UnmodifiableMapView<String, String>(
          Map<String, String>.of(translations),
        );

  factory MtnMinecraftInfoModLanguage.parse({
    required MtnMinecraftInfoModAssetSource source,
    required String namespace,
    required String locale,
    required Uint8List bytes,
  }) {
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

    return MtnMinecraftInfoModLanguage(
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
}
