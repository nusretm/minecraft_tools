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

    await _addMatches(
      result,
      identity,
      MtnMinecraftInfoItemNameKind.item,
      identity.itemTranslationKey,
      locale,
    );
    await _addMatches(
      result,
      identity,
      MtnMinecraftInfoItemNameKind.block,
      identity.blockTranslationKey,
      locale,
    );

    return List<MtnMinecraftInfoItemName>.unmodifiable(result);
  }

  Future<void> _addMatches(
    List<MtnMinecraftInfoItemName> result,
    MtnMinecraftInfoItemIdentity identity,
    MtnMinecraftInfoItemNameKind kind,
    String translationKey,
    String locale,
  ) async {
    for (final String languageNamespace in modList.assetNamespaces) {
      final List<MtnMinecraftInfoModTranslation> translations =
          await modList.getTranslations(
        languageNamespace,
        translationKey,
        locale: locale,
      );

      for (final MtnMinecraftInfoModTranslation translation in translations) {
        result.add(
          MtnMinecraftInfoItemName(
            identity: identity,
            kind: kind,
            translation: translation,
          ),
        );
      }
    }
  }
}
