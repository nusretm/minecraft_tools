import 'dart:collection';

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

  final MtnMinecraftInfoModAssetSource source;
  final String namespace;
  final String locale;
  final Map<String, String> translations;

  bool contains(String key) => translations.containsKey(key);

  String? operator [](String key) => translations[key];
}
