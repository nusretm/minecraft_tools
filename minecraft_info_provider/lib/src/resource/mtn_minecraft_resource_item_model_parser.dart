import 'dart:convert';
import 'dart:typed_data';

import 'mtn_minecraft_resource_item_model_node.dart';
import 'mtn_minecraft_resource_location.dart';

/// Parses item-model wire types without choosing runtime-dependent branches.
final class MtnMinecraftResourceItemModelParser {
  const MtnMinecraftResourceItemModelParser({
    this.maxDepth = 64,
    this.maxNodes = 2048,
  }) : assert(maxDepth > 0),
       assert(maxNodes > 0);

  final int maxDepth;
  final int maxNodes;

  MtnMinecraftResourceItemModelDefinition parse(Uint8List bytes) {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Item definition must be a JSON object.');
    }
    final Map<String, Object?> document = Map<String, Object?>.from(decoded);
    final _ItemModelParseCounter count = _ItemModelParseCounter();
    return MtnMinecraftResourceItemModelDefinition(
      json: document,
      root: _parseNode(document['model'], count, 0, 'model'),
    );
  }

  MtnMinecraftResourceItemModelNodeAbs _parseNode(
    Object? input, _ItemModelParseCounter count, int depth, String context,
  ) {
    if (depth >= maxDepth || ++count.value > maxNodes) {
      throw FormatException('Item model graph exceeds structural limit at $context');
    }
    if (input is! Map<String, dynamic>) {
      throw FormatException('Expected item-model object at $context');
    }
    final Map<String, Object?> raw = Map<String, Object?>.from(input);
    final Object? rawType = raw['type'];
    if (rawType is! String || rawType.isEmpty) {
      throw FormatException('Missing item-model type at $context');
    }
    final String type = rawType.contains(':') ? rawType : 'minecraft:$rawType';

    MtnMinecraftResourceItemModelNodeAbs parseChild(Object? value, String name) =>
        _parseNode(value, count, depth + 1, '$context.$name');

    String requireString(Object? value, String field) {
      if (value is! String || value.isEmpty) {
        throw FormatException('Expected non-empty $field in $context');
      }
      return value;
    }

    switch (type) {
      case 'minecraft:model':
        final String modelId = requireString(raw['model'], 'model');
        return MtnMinecraftResourceItemModelNodeModel(
          raw, MtnMinecraftResourceLocation.parse(modelId),
        );

      case 'minecraft:composite':
        final Object? values = raw['models'];
        if (values is! List || values.isEmpty) {
          throw FormatException('Composite models must be non-empty at $context');
        }
        return MtnMinecraftResourceItemModelNodeComposite(raw, <MtnMinecraftResourceItemModelNodeAbs>[
          for (int i = 0; i < values.length; i++) parseChild(values[i], 'models[$i]'),
        ]);

      case 'minecraft:condition':
        return MtnMinecraftResourceItemModelNodeCondition(
          raw, requireString(raw['property'], 'property'),
          parseChild(raw['on_true'], 'on_true'),
          parseChild(raw['on_false'], 'on_false'),
        );

      case 'minecraft:select':
        final Object? rawCases = raw['cases'];
        if (rawCases is! List) throw FormatException('Select cases must be a list at $context');
        final List<MtnMinecraftResourceItemModelSelectCase> cases = <MtnMinecraftResourceItemModelSelectCase>[];
        for (int i = 0; i < rawCases.length; i++) {
          final Object? rawCase = rawCases[i];
          if (rawCase is! Map<String, dynamic>) throw FormatException('Invalid select case at $context');
          final Object? when = rawCase['when'];
          if (when is! String && (when is! List || when.isEmpty || !when.every((Object? v) => v is String))) {
            throw FormatException('Invalid select matcher at $context');
          }
          cases.add(MtnMinecraftResourceItemModelSelectCase(
            when: when!,
            model: parseChild(rawCase['model'], 'cases[$i].model'),
          ));
        }
        return MtnMinecraftResourceItemModelNodeSelect(
          raw, requireString(raw['property'], 'property'), cases,
          raw['fallback'] == null ? null : parseChild(raw['fallback'], 'fallback'),
        );

      case 'minecraft:range_dispatch':
        final Object? rawEntries = raw['entries'];
        if (rawEntries is! List) throw FormatException('Range entries must be a list at $context');
        final List<MtnMinecraftResourceItemModelRangeEntry> entries = <MtnMinecraftResourceItemModelRangeEntry>[];
        for (int i = 0; i < rawEntries.length; i++) {
          final Object? entry = rawEntries[i];
          if (entry is! Map<String, dynamic> || entry['threshold'] is! num) {
            throw FormatException('Invalid range entry at $context');
          }
          final double threshold = (entry['threshold'] as num).toDouble();
          if (!threshold.isFinite) throw FormatException('Non-finite range threshold at $context');
          entries.add(MtnMinecraftResourceItemModelRangeEntry(
            threshold: threshold,
            model: parseChild(entry['model'], 'entries[$i].model'),
          ));
        }
        final Object? scale = raw['scale'];
        if (scale != null && (scale is! num || !(scale.toDouble().isFinite))) {
          throw FormatException('Invalid range scale at $context');
        }
        return MtnMinecraftResourceItemModelNodeRangeDispatch(
          raw, requireString(raw['property'], 'property'), entries,
          raw['fallback'] == null ? null : parseChild(raw['fallback'], 'fallback'),
        );

      case 'minecraft:special':
        final Object? renderer = raw['model'];
        if (renderer is! Map<String, dynamic>) {
          throw FormatException('Invalid special renderer at $context');
        }
        requireString(renderer['type'], 'special renderer type');
        return MtnMinecraftResourceItemModelNodeSpecial(
          raw,
          MtnMinecraftResourceLocation.parse(requireString(raw['base'], 'base')),
          Map<String, Object?>.from(renderer),
        );

      case 'minecraft:empty':
        return MtnMinecraftResourceItemModelNodeEmpty(raw);

      default:
        // A future node is not a known empty node or a silently chosen branch.
        return MtnMinecraftResourceItemModelNodeUnknown(rawType, raw);
    }
  }
}

final class _ItemModelParseCounter {
  int value = 0;
}
