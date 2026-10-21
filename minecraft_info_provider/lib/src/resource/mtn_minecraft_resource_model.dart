import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_location.dart';

/// A normal Minecraft model JSON and its resolved static parent chain.
///
/// Original JSON survives for geometry, display transforms and extensions.
final class MtnMinecraftResourceModel {
  MtnMinecraftResourceModel({
    required this.location,
    required this.resource,
    required Map<String, Object?> json,
    required this.parentLocation,
    required this.parent,
    required Map<String, String> textureReferences,
    Map<String, Object?> textureDeclarations = const <String, Object?>{},
    required Map<String, Object?> effectiveProperties,
  })  : json = Map<String, Object?>.unmodifiable(json),
        textureReferences = Map<String, String>.unmodifiable(textureReferences),
        textureDeclarations = Map<String, Object?>.unmodifiable(textureDeclarations),
        effectiveProperties = Map<String, Object?>.unmodifiable(effectiveProperties);

  final MtnMinecraftResourceLocation location;
  final MtnMinecraftResourceData resource;
  final MtnMinecraftResourceLocation? parentLocation;
  final MtnMinecraftResourceModel? parent;
  final Map<String, Object?> json;
  final Map<String, String> textureReferences;
  /// Optional original 26.1 texture object declarations and their render hints.
  final Map<String, Object?> textureDeclarations;
  final Map<String, Object?> effectiveProperties;
}

/// Static resource references left unresolved, retaining partial model results.
enum MtnMinecraftResourceIssueKind {
  missingParent,
  invalidParent,
  parentCycle,
  missingTextureVariable,
  textureVariableCycle,
  invalidTextureReference,
  missingTexture,
  unsupportedItemDefinition,
  unknownItemModelNode,
  unsupportedSpecialRenderer,
  runtimeOverridesNotEvaluated,
}

final class MtnMinecraftResourceIssue {
  const MtnMinecraftResourceIssue({
    required this.kind,
    required this.reference,
  });

  final MtnMinecraftResourceIssueKind kind;
  final String reference;

  @override
  String toString() => '${kind.name}: $reference';
}

final class MtnMinecraftResourceModelResolution {
  MtnMinecraftResourceModelResolution({
    required this.model,
    required Iterable<MtnMinecraftResourceIssue> issues,
  }) : issues = List<MtnMinecraftResourceIssue>.unmodifiable(issues);

  final MtnMinecraftResourceModel? model;
  final List<MtnMinecraftResourceIssue> issues;
}
