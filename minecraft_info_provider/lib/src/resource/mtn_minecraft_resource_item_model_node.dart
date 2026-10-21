import 'mtn_minecraft_resource_location.dart';
import 'mtn_minecraft_resource_model.dart';
import 'mtn_minecraft_resource_texture.dart';

/// Parsed item model tree; runtime item state is deliberately not evaluated.
abstract class MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeAbs(this.type, Map<String, Object?> raw)
      : raw = Map<String, Object?>.unmodifiable(raw);

  /// Original wire type; unknown future types remain distinguishable.
  final String type;
  final Map<String, Object?> raw;
  List<MtnMinecraftResourceItemModelNodeAbs> get children =>
      const <MtnMinecraftResourceItemModelNodeAbs>[];
}

final class MtnMinecraftResourceItemModelNodeModel extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeModel(Map<String, Object?> raw, this.modelLocation)
      : super('minecraft:model', raw);

  final MtnMinecraftResourceLocation modelLocation;
}

final class MtnMinecraftResourceItemModelNodeComposite extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeComposite(Map<String, Object?> raw, Iterable<MtnMinecraftResourceItemModelNodeAbs> models)
      : models = List<MtnMinecraftResourceItemModelNodeAbs>.unmodifiable(models),
        super('minecraft:composite', raw);

  final List<MtnMinecraftResourceItemModelNodeAbs> models;
  @override
  List<MtnMinecraftResourceItemModelNodeAbs> get children => models;
}

final class MtnMinecraftResourceItemModelNodeCondition extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeCondition(
    Map<String, Object?> raw, this.property, this.onTrue, this.onFalse,
  ) : super('minecraft:condition', raw);

  final String property;
  final MtnMinecraftResourceItemModelNodeAbs onTrue;
  final MtnMinecraftResourceItemModelNodeAbs onFalse;
  @override
  List<MtnMinecraftResourceItemModelNodeAbs> get children =>
      <MtnMinecraftResourceItemModelNodeAbs>[onTrue, onFalse];
}

final class MtnMinecraftResourceItemModelSelectCase {
  const MtnMinecraftResourceItemModelSelectCase({
    required this.when,
    required this.model,
  });

  /// Original matcher, either a single string or a list of strings.
  final Object when;
  final MtnMinecraftResourceItemModelNodeAbs model;
}

final class MtnMinecraftResourceItemModelNodeSelect extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeSelect(
    Map<String, Object?> raw,
    this.property,
    Iterable<MtnMinecraftResourceItemModelSelectCase> cases,
    this.fallback,
  ) : cases = List<MtnMinecraftResourceItemModelSelectCase>.unmodifiable(cases),
      super('minecraft:select', raw);

  final String property;
  final List<MtnMinecraftResourceItemModelSelectCase> cases;
  final MtnMinecraftResourceItemModelNodeAbs? fallback;
  @override
  List<MtnMinecraftResourceItemModelNodeAbs> get children =>
      <MtnMinecraftResourceItemModelNodeAbs>[
        for (final MtnMinecraftResourceItemModelSelectCase value in cases) value.model,
        if (fallback != null) fallback!,
      ];
}

final class MtnMinecraftResourceItemModelRangeEntry {
  const MtnMinecraftResourceItemModelRangeEntry({
    required this.threshold,
    required this.model,
  });

  final double threshold;
  final MtnMinecraftResourceItemModelNodeAbs model;
}

final class MtnMinecraftResourceItemModelNodeRangeDispatch extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeRangeDispatch(
    Map<String, Object?> raw,
    this.property,
    Iterable<MtnMinecraftResourceItemModelRangeEntry> entries,
    this.fallback,
  ) : entries = List<MtnMinecraftResourceItemModelRangeEntry>.unmodifiable(entries),
      super('minecraft:range_dispatch', raw);

  final String property;
  final List<MtnMinecraftResourceItemModelRangeEntry> entries;
  final MtnMinecraftResourceItemModelNodeAbs? fallback;
  @override
  List<MtnMinecraftResourceItemModelNodeAbs> get children =>
      <MtnMinecraftResourceItemModelNodeAbs>[
        for (final MtnMinecraftResourceItemModelRangeEntry entry in entries) entry.model,
        if (fallback != null) fallback!,
      ];
}

final class MtnMinecraftResourceItemModelNodeSpecial extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeSpecial(
    Map<String, Object?> raw, this.baseLocation, Map<String, Object?> renderer,
  ) : renderer = Map<String, Object?>.unmodifiable(renderer),
      super('minecraft:special', raw);

  final MtnMinecraftResourceLocation baseLocation;
  final Map<String, Object?> renderer;
}

final class MtnMinecraftResourceItemModelNodeEmpty extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeEmpty(Map<String, Object?> raw)
      : super('minecraft:empty', raw);
}

final class MtnMinecraftResourceItemModelNodeUnknown extends MtnMinecraftResourceItemModelNodeAbs {
  MtnMinecraftResourceItemModelNodeUnknown(super.type, super.raw);
}

/// The parsed item definition, including top-level animation and future fields.
final class MtnMinecraftResourceItemModelDefinition {
  MtnMinecraftResourceItemModelDefinition({
    required Map<String, Object?> json,
    required this.root,
  }) : json = Map<String, Object?>.unmodifiable(json);

  final Map<String, Object?> json;
  final MtnMinecraftResourceItemModelNodeAbs root;
}

/// Model and PNG resources belonging to one exact branch node.
final class MtnMinecraftResourceItemModelBinding {
  MtnMinecraftResourceItemModelBinding({
    required this.node,
    required this.model,
    required Iterable<MtnMinecraftResourceTexture> textures,
  }) : textures = List<MtnMinecraftResourceTexture>.unmodifiable(textures);

  final MtnMinecraftResourceItemModelNodeAbs node;
  final MtnMinecraftResourceModel? model;
  final List<MtnMinecraftResourceTexture> textures;
}

/// Complete static graph. Bindings include ALL branches, never a selected one.
final class MtnMinecraftResourceItemModelGraph {
  MtnMinecraftResourceItemModelGraph({
    required this.definition,
    required Iterable<MtnMinecraftResourceItemModelBinding> bindings,
  }) : bindings = List<MtnMinecraftResourceItemModelBinding>.unmodifiable(bindings);

  final MtnMinecraftResourceItemModelDefinition definition;
  final List<MtnMinecraftResourceItemModelBinding> bindings;

  MtnMinecraftResourceItemModelNodeAbs get root => definition.root;
}
