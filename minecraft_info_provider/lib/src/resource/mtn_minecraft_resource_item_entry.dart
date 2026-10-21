import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_location.dart';

/// Entry file type, not an already parsed model or texture graph.
enum MtnMinecraftResourceItemEntryKind {
  normalModel,
  itemDefinition,
}

/// How the entry's model identity was obtained.
enum MtnMinecraftResourceItemModelIdentityOrigin {
  /// The legacy item model convention uses the registry item ID.
  legacyRegistry,

  /// Caller explicitly supplied the effective minecraft:item_model identity.
  effectiveItemModel,

  /// A modern/transition client entry used a non-authoritative registry guess.
  conventionalRegistryFallback,
}

/// An unparsed item entry retaining original physical source provenance.
final class MtnMinecraftResourceItemEntry {
  const MtnMinecraftResourceItemEntry({
    required this.itemIdentity,
    required this.modelIdentity,
    required this.entryLocation,
    required this.kind,
    required this.modelIdentityOrigin,
    required this.resource,
  });

  final MtnMinecraftResourceLocation itemIdentity;
  final MtnMinecraftResourceLocation modelIdentity;
  final MtnMinecraftResourceLocation entryLocation;
  final MtnMinecraftResourceItemEntryKind kind;
  final MtnMinecraftResourceItemModelIdentityOrigin modelIdentityOrigin;
  final MtnMinecraftResourceData resource;

  bool get usedConventionalFallback =>
      modelIdentityOrigin == MtnMinecraftResourceItemModelIdentityOrigin.conventionalRegistryFallback;
}
