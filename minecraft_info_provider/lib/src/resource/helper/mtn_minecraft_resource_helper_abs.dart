import 'package:minecraft_models/minecraft_models.dart';

import '../mtn_minecraft_resource_data.dart';
import '../mtn_minecraft_resource_environment.dart';
import '../mtn_minecraft_resource_image.dart';
import '../mtn_minecraft_resource_item.dart';
import '../mtn_minecraft_resource_item_entry.dart';
import '../mtn_minecraft_resource_item_request.dart';
import '../mtn_minecraft_resource_loader.dart';
import '../mtn_minecraft_resource_location.dart';
import '../mtn_minecraft_resource_model.dart';
import '../mtn_minecraft_resource_model_resolver.dart';
import '../mtn_minecraft_resource_texture.dart';

/// Shared entry selection and source reads for item-resource helpers.
///
/// Subclasses own version-specific entry identity and directory policy.
/// CP2 owns entry selection; CP3 adds shared static model/texture resolution.
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

  /// Standard normal-model JSON resolution, including parent inheritance.
  Future<MtnMinecraftResourceModelResolution> loadModel(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceLocation location, {
    MtnMinecraftResourceData? rootResource,
    bool allowTextureObjects = false,
  }) =>
      const MtnMinecraftResourceModelResolver().resolve(
        loader, location, rootResource: rootResource,
        allowTextureObjects: allowTextureObjects,
      );

  /// Loads raw PNG bytes by sprite ID from the effective CP1 source stack.
  Future<MtnMinecraftResourceImage?> loadTexture(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceLocation location,
  ) async {
    final MtnMinecraftResourceData? data =
        await loader.read(location.namespace, 'textures/${location.path}.png');
    if (data == null) return null;
    return MtnMinecraftResourceImage(location: location, resource: data);
  }

  /// Resolves the static normal-model and texture graph for one item.
  ///
  /// In CP3 modern items/*.json graph evaluation is intentionally unsupported;
  /// the raw entry remains accessible and the result carries an issue.
  /// Missing entries return null, while incomplete graphs remain non-null.
  Future<MtnMinecraftResourceItem?> loadItem(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceItemRequest request, {
    MtnMinecraftResourceEnvironment? environment,
  }) async {
    final MtnMinecraftResourceItemEntry? entry = await loadItemEntry(loader, request);
    if (entry == null) return null;

    if (entry.kind == MtnMinecraftResourceItemEntryKind.itemDefinition) {
      return MtnMinecraftResourceItem(
        entry: entry,
        model: null,
        textures: const <MtnMinecraftResourceTexture>[],
        issues: <MtnMinecraftResourceIssue>[
          MtnMinecraftResourceIssue(
            kind: MtnMinecraftResourceIssueKind.unsupportedItemDefinition,
            reference: entry.entryLocation.toString(),
          ),
        ],
      );
    }

    final String path = entry.entryLocation.path;
    if (!path.startsWith('models/') || !path.endsWith('.json')) {
      throw FormatException('Normal model entry has an unexpected path: $path');
    }
    final MtnMinecraftResourceLocation root = MtnMinecraftResourceLocation(
      namespace: entry.entryLocation.namespace,
      path: path.substring('models/'.length, path.length - '.json'.length),
    );
    final MtnMinecraftResourceModelResolution resolved =
        await loadModel(loader, root, rootResource: entry.resource);
    final List<MtnMinecraftResourceIssue> issues = <MtnMinecraftResourceIssue>[
      ...resolved.issues,
    ];
    final List<MtnMinecraftResourceTexture> textures =
        await loadModelTextures(loader, resolved.model, issues);

    return MtnMinecraftResourceItem(
      entry: entry,
      model: resolved.model,
      textures: textures,
      issues: issues,
    );
  }

  /// Shared source/texture resolution for legacy and modern model leaves.
  Future<List<MtnMinecraftResourceTexture>> loadModelTextures(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceModel? model,
    List<MtnMinecraftResourceIssue> issues,
  ) async {
    final List<MtnMinecraftResourceTexture> textures = <MtnMinecraftResourceTexture>[];
    final Map<String, String> references =
        model?.textureReferences ?? const <String, String>{};
    final List<String> symbols = references.keys.toList()..sort(_compareTextureSymbols);

    for (final String symbol in symbols) {
      final MtnMinecraftResourceLocation? location =
          _resolveTextureLocation(symbol, references, issues);
      final MtnMinecraftResourceImage? image =
          location == null ? null : await loadTexture(loader, location);
      if (location != null && image == null) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.missingTexture,
          reference: location.toString(),
        ));
      }
      final Object? declaration = model?.textureDeclarations[symbol];
      textures.add(MtnMinecraftResourceTexture(
        symbol: symbol,
        reference: references[symbol]!,
        location: location,
        image: image,
        forceTranslucent: declaration is Map && declaration['force_translucent'] == true,
      ));
    }
    return textures;
  }

  MtnMinecraftResourceLocation? _resolveTextureLocation(
    String symbol,
    Map<String, String> references,
    List<MtnMinecraftResourceIssue> issues,
  ) {
    final Set<String> visited = <String>{};
    String current = '#$symbol';
    while (current.startsWith('#')) {
      final String name = current.substring(1);
      if (!visited.add(name)) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.textureVariableCycle,
          reference: name,
        ));
        return null;
      }
      final String? next = references[name];
      if (next == null) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.missingTextureVariable,
          reference: name,
        ));
        return null;
      }
      current = next;
    }
    try {
      return MtnMinecraftResourceLocation.parse(current);
    } on ArgumentError {
      issues.add(MtnMinecraftResourceIssue(
        kind: MtnMinecraftResourceIssueKind.invalidTextureReference,
        reference: current,
      ));
      return null;
    }
  }

  static final RegExp _layerName = RegExp(r'^layer([0-9]+)$');

  static int _compareTextureSymbols(String a, String b) {
    final RegExpMatch? ma = _layerName.firstMatch(a);
    final RegExpMatch? mb = _layerName.firstMatch(b);
    if (ma != null && mb != null) {
      return int.parse(ma.group(1)!).compareTo(int.parse(mb.group(1)!));
    }
    if (ma != null) return -1;
    if (mb != null) return 1;
    if (a == 'particle') return 1;
    if (b == 'particle') return -1;
    return a.compareTo(b);
  }

  static bool _isOrderedRelease(MtnMinecraftVersion version) =>
      version.type == MtnMinecraftGameVersionType.release &&
      version.major != null &&
      version.qualifier == null;
}
