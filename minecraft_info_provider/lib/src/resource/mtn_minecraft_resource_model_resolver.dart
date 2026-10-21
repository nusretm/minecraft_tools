import 'dart:convert';

import 'mtn_minecraft_resource_data.dart';
import 'mtn_minecraft_resource_loader.dart';
import 'mtn_minecraft_resource_location.dart';
import 'mtn_minecraft_resource_model.dart';

/// Resolves normal model JSON and inherited static properties through the
/// effective source stack, without emulating runtime predicates.
final class MtnMinecraftResourceModelResolver {
  const MtnMinecraftResourceModelResolver();

  /// Resolve a normal model, optionally reusing a selected item entry.
  ///
  /// Missing/cyclic parents become issues. Malformed JSON and source failures
  /// propagate and cannot silently fall back to a lower-precedence source.
  Future<MtnMinecraftResourceModelResolution> resolve(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceLocation location, {
    MtnMinecraftResourceData? rootResource,
  }) async {
    final List<MtnMinecraftResourceIssue> issues = <MtnMinecraftResourceIssue>[];
    final MtnMinecraftResourceModel? model = await _resolveModel(
      loader,
      location,
      <MtnMinecraftResourceLocation>{},
      issues,
      knownResource: rootResource,
    );
    return MtnMinecraftResourceModelResolution(model: model, issues: issues);
  }

  Future<MtnMinecraftResourceModel?> _resolveModel(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceLocation location,
    Set<MtnMinecraftResourceLocation> active,
    List<MtnMinecraftResourceIssue> issues, {
    MtnMinecraftResourceData? knownResource,
  }) async {
    if (!active.add(location)) {
      issues.add(MtnMinecraftResourceIssue(
        kind: MtnMinecraftResourceIssueKind.parentCycle,
        reference: location.toString(),
      ));
      return null;
    }

    try {
      final MtnMinecraftResourceData? resource = knownResource ??
          await loader.read(location.namespace, 'models/${location.path}.json');
      if (resource == null) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.missingParent,
          reference: location.toString(),
        ));
        return null;
      }

      final Object? decoded = jsonDecode(utf8.decode(resource.bytes));
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Model "$location" must be a JSON object.');
      }
      final Map<String, Object?> json = Map<String, Object?>.from(decoded);
      final Object? parentValue = json['parent'];
      if (parentValue != null && parentValue is! String) {
        throw FormatException('Model "$location" has a non-string parent.');
      }

      MtnMinecraftResourceLocation? parentLocation;
      MtnMinecraftResourceModel? parent;
      if (parentValue is String) {
        try {
          parentLocation = MtnMinecraftResourceLocation.parse(parentValue);
        } on ArgumentError {
          issues.add(MtnMinecraftResourceIssue(
            kind: MtnMinecraftResourceIssueKind.invalidParent,
            reference: parentValue,
          ));
        }
        if (parentLocation != null) {
          parent = await _resolveModel(loader, parentLocation, active, issues);
        }
      }

      final Map<String, String> textureReferences =
          <String, String>{...?parent?.textureReferences};
      final Object? localTextures = json['textures'];
      if (localTextures != null) {
        if (localTextures is! Map<String, dynamic>) {
          throw FormatException('Model "$location" has invalid textures.');
        }
        for (final MapEntry<String, dynamic> entry in localTextures.entries) {
          if (entry.value is! String || entry.key.isEmpty) {
            throw FormatException('Model "$location" contains an invalid texture binding.');
          }
          textureReferences[entry.key] = entry.value as String;
        }
      }

      final Map<String, Object?> properties =
          <String, Object?>{...?parent?.effectiveProperties};
      for (final MapEntry<String, Object?> entry in json.entries) {
        if (entry.key == 'parent' || entry.key == 'textures') continue;
        if (entry.key == 'display' &&
            entry.value is Map<String, dynamic> &&
            properties['display'] is Map<String, dynamic>) {
          properties['display'] = <String, dynamic>{
            ...(properties['display'] as Map<String, dynamic>),
            ...(entry.value as Map<String, dynamic>),
          };
        } else {
          properties[entry.key] = entry.value;
        }
      }

      if (json['overrides'] is List && (json['overrides'] as List).isNotEmpty) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.runtimeOverridesNotEvaluated,
          reference: location.toString(),
        ));
      }

      return MtnMinecraftResourceModel(
        location: location,
        resource: resource,
        json: json,
        parentLocation: parentLocation,
        parent: parent,
        textureReferences: textureReferences,
        effectiveProperties: properties,
      );
    } finally {
      active.remove(location);
    }
  }
}
