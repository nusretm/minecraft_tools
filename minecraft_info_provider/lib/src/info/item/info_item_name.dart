import '../mod/info_mod_asset_source.dart';
import '../mod/info_mod_language.dart';

/// Conventional translation-key prefix used when deriving an item display name.
enum MtnMinecraftInfoItemNameKind {
  item,
  block,
}

/// Parsed namespaced item registry identity.
///
/// This model represents only the persisted registry identity. It does not
/// claim to know a runtime-overridden description ID.
final class MtnMinecraftInfoItemIdentity {
  factory MtnMinecraftInfoItemIdentity.parse(String id) {
    if (id.isEmpty || id.trim() != id) {
      throw ArgumentError.value(
        id,
        'id',
        'must be a namespaced Minecraft item identifier',
      );
    }

    final int separator = id.indexOf(':');
    if (separator <= 0 ||
        separator != id.lastIndexOf(':') ||
        separator == id.length - 1) {
      throw ArgumentError.value(
        id,
        'id',
        'must use the namespace:path form',
      );
    }

    final String namespace = id.substring(0, separator);
    final String path = id.substring(separator + 1);
    if (!_namespacePattern.hasMatch(namespace) ||
        !_pathPattern.hasMatch(path)) {
      throw ArgumentError.value(
        id,
        'id',
        'contains invalid Minecraft identifier characters',
      );
    }

    return MtnMinecraftInfoItemIdentity._(
      id: id,
      namespace: namespace,
      path: path,
    );
  }

  const MtnMinecraftInfoItemIdentity._({
    required this.id,
    required this.namespace,
    required this.path,
  });

  final String id;
  final String namespace;
  final String path;

  String get translationPath => path.replaceAll('/', '.');

  String get itemTranslationKey =>
      'item.$namespace.$translationPath';

  String get blockTranslationKey =>
      'block.$namespace.$translationPath';

  List<String> get conventionalTranslationKeys =>
      List<String>.unmodifiable(
        <String>[
          itemTranslationKey,
          blockTranslationKey,
        ],
      );

  @override
  String toString() => id;
}

/// One localized name candidate derived from a conventional item/block key.
///
/// A candidate is not authoritative runtime registry metadata. Mods may
/// override an item's description ID or derive it from stack state.
final class MtnMinecraftInfoItemName {
  const MtnMinecraftInfoItemName({
    required this.identity,
    required this.kind,
    required this.translation,
  });

  final MtnMinecraftInfoItemIdentity identity;
  final MtnMinecraftInfoItemNameKind kind;
  final MtnMinecraftInfoModTranslation translation;

  String get itemId => identity.id;
  String get translationKey => translation.key;
  String get value => translation.value;
  String get locale => translation.locale;
  MtnMinecraftInfoModAssetSource get source => translation.source;
  String get languageNamespace => translation.namespace;
}

final RegExp _namespacePattern = RegExp(r'^[a-z0-9_.-]+$');
final RegExp _pathPattern = RegExp(r'^[a-z0-9/._-]+$');
