import 'dart:typed_data';

import 'helper/mtn_minecraft_resource_helper_abs.dart';
import 'mtn_minecraft_resource_item.dart';
import 'mtn_minecraft_resource_item_entry.dart';
import 'mtn_minecraft_resource_item_model_node.dart';
import 'mtn_minecraft_resource_item_model_parser.dart';
import 'mtn_minecraft_resource_loader.dart';
import 'mtn_minecraft_resource_model.dart';
import 'mtn_minecraft_resource_texture.dart';

/// Resolves ALL statically referenced normal models; never chooses an item
/// predicate branch or flattens its tree into a runtime rendering decision.
final class MtnMinecraftResourceItemModelResolver {
  const MtnMinecraftResourceItemModelResolver();

  Future<MtnMinecraftResourceItem> resolve(
    MtnMinecraftResourceLoader loader,
    MtnMinecraftResourceHelperAbs helper,
    MtnMinecraftResourceItemEntry entry, {
    bool allowTextureObjects = false,
  }) async {
    final MtnMinecraftResourceItemModelDefinition definition =
        const MtnMinecraftResourceItemModelParser().parse(entry.resource.bytes);
    final List<MtnMinecraftResourceIssue> issues = <MtnMinecraftResourceIssue>[];
    final List<MtnMinecraftResourceItemModelBinding> bindings =
        <MtnMinecraftResourceItemModelBinding>[];
    final List<MtnMinecraftResourceTexture> allTextures = <MtnMinecraftResourceTexture>[];

    Future<void> walk(MtnMinecraftResourceItemModelNodeAbs node) async {
      if (node is MtnMinecraftResourceItemModelNodeModel ||
          node is MtnMinecraftResourceItemModelNodeSpecial) {
        final location = node is MtnMinecraftResourceItemModelNodeModel
            ? node.modelLocation
            : (node as MtnMinecraftResourceItemModelNodeSpecial).baseLocation;
        final MtnMinecraftResourceModelResolution resolved = await helper.loadModel(
          loader, location, allowTextureObjects: allowTextureObjects,
        );
        issues.addAll(resolved.issues);
        final List<MtnMinecraftResourceTexture> textures =
            await helper.loadModelTextures(loader, resolved.model, issues);
        bindings.add(MtnMinecraftResourceItemModelBinding(
          node: node, model: resolved.model, textures: textures,
        ));
        allTextures.addAll(textures);
        if (node is MtnMinecraftResourceItemModelNodeSpecial) {
          // A base model alone cannot reproduce a special Minecraft renderer.
          issues.add(MtnMinecraftResourceIssue(
            kind: MtnMinecraftResourceIssueKind.unsupportedSpecialRenderer,
            reference: node.renderer['type'].toString(),
          ));
        }
      } else if (node is MtnMinecraftResourceItemModelNodeUnknown) {
        issues.add(MtnMinecraftResourceIssue(
          kind: MtnMinecraftResourceIssueKind.unknownItemModelNode,
          reference: node.type,
        ));
      }
      for (final MtnMinecraftResourceItemModelNodeAbs child in node.children) {
        await walk(child);
      }
    }

    await walk(definition.root);
    return MtnMinecraftResourceItem(
      entry: entry,
      model: null,
      textures: allTextures,
      issues: issues,
      itemModelGraph: MtnMinecraftResourceItemModelGraph(
        definition: definition,
        bindings: bindings,
      ),
    );
  }
}
