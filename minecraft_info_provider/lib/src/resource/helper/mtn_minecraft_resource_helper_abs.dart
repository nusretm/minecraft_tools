import 'package:minecraft_models/minecraft_models.dart';

import '../mtn_minecraft_resource_data.dart';
import '../mtn_minecraft_resource_environment.dart';
import '../mtn_minecraft_resource_item_entry.dart';
import '../mtn_minecraft_resource_item_request.dart';
import '../mtn_minecraft_resource_loader.dart';
import '../mtn_minecraft_resource_location.dart';

/// Shared entry selection and source reads for item-resource helpers.
///
/// Subclasses own version-specific entry identity and directory policy.
/// Model JSON, textures and runtime branch selection are excluded from CP2.
abstract class MtnMinecraftResourceHelperAbs {
  MtnMinecraftResourceHelperAbs({
    required this.name,
    required this.title,
    this.versionMin,
    this.versionMax,
    Set<MtnMinecraftLoaderType>? loaderTypes,
  }) : loaderTypes = loaderTypes == null
            ? null
            : Set<MtnMinecraftLoaderType>.unmodifiable(loaderTypes) {
    if (name.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('Resource helper name and title must not be empty.');
    }
    if (this.loaderTypes != null && this.loaderTypes!.isEmpty) {
      throw ArgumentError.value(loaderTypes, 'loaderTypes', 'must not be empty');
    }
    if (versionMin != null && !_isOrderedRelease(versionMin!)) {
      throw ArgumentError.value(versionMin, 'versionMin', 'must be an ordered release');
    }
    if (versionMax != null && !_isOrderedRelease(versionMax!)) {
      throw ArgumentError.value(versionMax, 'versionMax', 'must be an ordered release');
    }
    if (versionMin != null && versionMax != null && versionMin! > versionMax!) {
      throw ArgumentError('Resource helper versionMin must be <= versionMax.');
    }
  }

  final String name;
  final String title;
  final MtnMinecraftVersion? versionMin;
  final MtnMinecraftVersion? versionMax;
  final Set<MtnMinecraftLoaderType>? loaderTypes;

  /// Directory inside `assets/<namespace>/` where this format's entry lives.
  String get entryDirectory;

  /// Whether entry identity comes from effective minecraft:item_model.
  bool get usesEffectiveItemModel => false;

  MtnMinecraftResourceItemEntryKind get entryKind =>
      MtnMinecraftResourceItemEntryKind.normalModel;

  /// Conservative selection. Snapshots are not ordered as numeric releases.
  bool supports(MtnMinecraftResourceEnvironment environment) {
    if (loaderTypes != null && !loaderTypes!.contains(environment.loaderType)) {
      return false;
    }
    if (!_isOrderedRelease(environment.version)) return false;
    if (versionMin != null && environment.version < versionMin!) return false;
    if (versionMax != null && environment.version > versionMax!) return false;
    return true;
  }

  /// Load the raw entry; do not parse JSON or interpret runtime item state.
  ///
  /// A missing source result allows another helper to try. Source failures
  /// propagate and never result in a silent lower-priority fallback.
  Future<MtnMinecraftResourceItemEntry?> loadItemEntry(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceItemRequest request,
  ) async {
    final MtnMinecraftResourceLocation itemIdentity =
        MtnMinecraftResourceLocation.parse(request.item.id);
    final bool usesExplicit = usesEffectiveItemModel && request.effectiveItemModel != null;
    final MtnMinecraftResourceLocation modelIdentity =
        usesExplicit ? request.effectiveItemModel! : itemIdentity;

    final MtnMinecraftResourceItemModelIdentityOrigin origin = !usesEffectiveItemModel
        ? MtnMinecraftResourceItemModelIdentityOrigin.legacyRegistry
        : usesExplicit
            ? MtnMinecraftResourceItemModelIdentityOrigin.effectiveItemModel
            : MtnMinecraftResourceItemModelIdentityOrigin.conventionalRegistryFallback;

    final MtnMinecraftResourceLocation entry = MtnMinecraftResourceLocation(
      namespace: modelIdentity.namespace,
      path: '$entryDirectory/${modelIdentity.path}.json',
    );
    final MtnMinecraftResourceData? resource = await loader.read(entry.namespace, entry.path);
    if (resource == null) return null;

    return MtnMinecraftResourceItemEntry(
      itemIdentity: itemIdentity,
      modelIdentity: modelIdentity,
      entryLocation: entry,
      kind: entryKind,
      modelIdentityOrigin: origin,
      resource: resource,
    );
  }

  static bool _isOrderedRelease(MtnMinecraftVersion version) =>
      version.type == MtnMinecraftGameVersionType.release &&
      version.major != null &&
      version.qualifier == null;
}
