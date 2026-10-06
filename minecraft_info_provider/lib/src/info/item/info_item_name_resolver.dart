import '../mod/info_mod_language.dart';
import '../mod/info_mod_list.dart';
import 'info_item_name.dart';

/// Resolves conventional localized item-name candidates from mod resources.
///
/// This resolver intentionally does not emulate the runtime item registry.
/// Mods can override description IDs or derive them from stack state, so
/// results are candidates backed by language resources rather than claims
/// about the authoritative runtime name.
final class MtnMinecraftInfoItemNameResolver {
  const MtnMinecraftInfoItemNameResolver({
    required this.modList,
  });

  final MtnMinecraftModList modList;

  Future<List<MtnMinecraftInfoItemName>> resolve(
    String itemId, {
    String locale = 'en_us',
  }) async {
    final MtnMinecraftInfoItemIdentity identity =
        MtnMinecraftInfoItemIdentity.parse(itemId);
    MtnMinecraftInfoModLanguage.validateLocale(locale);

    final List<MtnMinecraftInfoItemName> result =
        <MtnMinecraftInfoItemName>[];
    for (final String languageNamespace in modList.assetNamespaces) {
      for (final source in modList.getAssetSources(languageNamespace)) {
        final bytes = await source.read(
          languageNamespace,
          'lang/$locale.json',
        );
        if (bytes == null) continue;

        final MtnMinecraftInfoModLanguage language;
        try {
          language = MtnMinecraftInfoModLanguage.parse(
            source: source,
            namespace: languageNamespace,
            locale: locale,
            bytes: bytes,
          );
        } on MtnMinecraftInfoModLanguageException {
          continue;
        }

        final MtnMinecraftInfoModTranslation? itemTranslation =
            language.translation(identity.itemTranslationKey);
        if (itemTranslation != null) {
          result.add(
            MtnMinecraftInfoItemName(
              identity: identity,
              kind: MtnMinecraftInfoItemNameKind.item,
              translation: itemTranslation,
            ),
          );
        }

        final MtnMinecraftInfoModTranslation? blockTranslation =
            language.translation(identity.blockTranslationKey);
        if (blockTranslation != null) {
          result.add(
            MtnMinecraftInfoItemName(
              identity: identity,
              kind: MtnMinecraftInfoItemNameKind.block,
              translation: blockTranslation,
            ),
          );
        }
      }
    }

    return List<MtnMinecraftInfoItemName>.unmodifiable(result);
  }
}
