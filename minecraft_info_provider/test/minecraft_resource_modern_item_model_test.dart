import 'dart:convert';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';
import 'package:test/test.dart';

void main() {
  MtnMinecraftResourceEnvironment environment(String version) =>
      MtnMinecraftResourceEnvironment(
        version: MtnMinecraftVersion.parse(
          version, type: MtnMinecraftGameVersionType.release,
        ),
        loaderType: MtnMinecraftLoaderType.fabric,
      );

  MtnMinecraftResourceItemRequest request(
    String id, {String? effective}
  ) => MtnMinecraftResourceItemRequest(
    item: MtnMinecraftInfoItemIdentity.parse(id),
    effectiveItemModel: effective == null ? null : MtnMinecraftResourceLocation.parse(effective),
  );

  MtnMinecraftInfoModAssetSource source(
    String namespace,
    Map<String, List<int>> assets, {
    List<String>? reads,
    Object? failure,
  }) => MtnMinecraftInfoModAssetSource(
    rootFile: null,
    namespaces: <String>[namespace],
    loader: (String path) async {
      reads?.add(path);
      if (failure != null) throw failure;
      final List<int>? bytes = assets[path];
      return bytes == null ? null : Uint8List.fromList(bytes);
    },
  );

  List<int> jsonBytes(Object object) => utf8.encode(jsonEncode(object));
  Map<String, Object?> model(String name) => <String, Object?>{
    'type': 'minecraft:model', 'model': name,
  };
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jAocAAAAASUVORK5CYII=',
  );

  group('CP4 modern client item-model graph', () {
    test('normal model resolves source-backed JSON, parent and raw PNG without flattening graph', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/torch.json': jsonBytes(<String, Object?>{
          'model': model('verity:item/torch'),
          'hand_animation_on_swap': false,
          'oversized_in_gui': true,
        }),
        'assets/verity/models/item/torch.json': jsonBytes(<String, Object?>{
          'textures': <String, Object?>{'layer0': 'verity:item/torch'},
        }),
        'assets/verity/textures/item/torch.png': png,
      });
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[mod],
      );
      final result = (await loader.loadItem(
        environment: environment('1.21.4'),
        request: request('verity:torch'),
      ))!;

      expect(result.itemModelGraph, isNotNull);
      expect(result.itemModelGraph!.root, isA<MtnMinecraftResourceItemModelNodeModel>());
      expect(result.itemModelGraph!.definition.json['hand_animation_on_swap'], false);
      expect(result.itemModelGraph!.definition.json['oversized_in_gui'], true);
      expect(result.model, isNull); // Modern items have multiple possible models.
      expect(result.itemModelGraph!.bindings, hasLength(1));
      final binding = result.itemModelGraph!.bindings.single;
      expect(binding.model!.location.toString(), 'verity:item/torch');
      expect(binding.model!.resource.source, same(mod));
      expect(binding.textures.single.image!.resource.source, same(mod));
      expect(result.pngList.single, png);
      expect(result.isComplete, isTrue);
    });

    test('all seven node types preserve branch structure and static model order', () async {
      final entries = <String, List<int>>{
        'assets/verity/items/complex.json': jsonBytes(<String, Object?>{
          'model': <String, Object?>{
            'type': 'minecraft:composite',
            'transformation': <String, Object?>{'scale': <int>[1, 1, 1]},
            'models': <Object?>[
              model('verity:item/a'),
              <String, Object?>{
                'type': 'minecraft:condition',
                'property': 'minecraft:using_item',
                'on_true': model('verity:item/b'),
                'on_false': model('verity:item/c'),
              },
              <String, Object?>{
                'type': 'minecraft:select',
                'property': 'minecraft:display_context',
                'cases': <Object?>[
                  <String, Object?>{
                    'when': <String>['gui', 'ground'],
                    'model': model('verity:item/d'),
                  },
                ],
                'fallback': model('verity:item/e'),
              },
              <String, Object?>{
                'type': 'minecraft:range_dispatch',
                'property': 'minecraft:damage',
                'scale': 0.5,
                'entries': <Object?>[
                  <String, Object?>{'threshold': 0.0, 'model': model('verity:item/f')},
                  <String, Object?>{'threshold': 0.8, 'model': model('verity:item/g')},
                ],
                'fallback': model('verity:item/h'),
              },
              <String, Object?>{'type': 'minecraft:empty'},
            ],
          },
        }),
      };
      for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        entries['assets/verity/models/item/$id.json'] = jsonBytes(<String, Object?>{
          'textures': <String, String>{'layer0': 'verity:item/$id'},
        });
        entries['assets/verity/textures/item/$id.png'] = png;
      }
      final mod = source('verity', entries);
      final item = (await MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[mod],
      ).loadItem(
        environment: environment('1.21.4'),
        request: request('verity:complex'),
      ))!;

      final graph = item.itemModelGraph!;
      final root = graph.root as MtnMinecraftResourceItemModelNodeComposite;
      expect(root.children, hasLength(5));
      expect(root.raw['transformation'], isNotNull);
      final condition = root.children[1] as MtnMinecraftResourceItemModelNodeCondition;
      expect(condition.property, 'minecraft:using_item');
      expect(condition.children, hasLength(2));
      final select = root.children[2] as MtnMinecraftResourceItemModelNodeSelect;
      expect(select.cases.single.when, <String>['gui', 'ground']);
      expect(select.fallback, isNotNull);
      final range = root.children[3] as MtnMinecraftResourceItemModelNodeRangeDispatch;
      expect(range.entries.map((entry) => entry.threshold), <double>[0.0, 0.8]);
      expect(range.raw['scale'], 0.5);
      expect(range.fallback, isNotNull);
      expect(root.children.last, isA<MtnMinecraftResourceItemModelNodeEmpty>());
      expect(
        graph.bindings.map((binding) => binding.model!.location.path),
        <String>[
          'item/a', 'item/b', 'item/c', 'item/d',
          'item/e', 'item/f', 'item/g', 'item/h',
        ],
      );
      expect(item.isComplete, isTrue);
      expect(item.pngList, hasLength(8));
    });

    test('empty is valid; unknown node and special renderer are distinct partial states', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/empty.json': jsonBytes(<String, Object?>{
          'model': <String, String>{'type': 'minecraft:empty'},
        }),
        'assets/verity/items/future.json': jsonBytes(<String, Object?>{
          'model': <String, Object?>{
            'type': 'verity:future', 'custom_payload': <int>[1, 2, 3],
          },
        }),
        'assets/verity/items/special.json': jsonBytes(<String, Object?>{
          'model': <String, Object?>{
            'type': 'minecraft:special',
            'base': 'verity:block/chest',
            'model': <String, Object?>{
              'type': 'minecraft:chest', 'texture': 'verity:chest',
            },
          },
        }),
        'assets/verity/models/block/chest.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{'particle': 'verity:block/chest'},
        }),
        'assets/verity/textures/block/chest.png': png,
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final empty = (await loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:empty'),
      ))!;
      expect(empty.isComplete, isTrue);
      expect(empty.itemModelGraph!.root, isA<MtnMinecraftResourceItemModelNodeEmpty>());
      expect(empty.pngList, isEmpty);

      final future = (await loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:future'),
      ))!;
      expect(future.itemModelGraph!.root, isA<MtnMinecraftResourceItemModelNodeUnknown>());
      expect(future.itemModelGraph!.root.raw['custom_payload'], <int>[1, 2, 3]);
      expect(future.issues.single.kind, MtnMinecraftResourceIssueKind.unknownItemModelNode);

      final special = (await loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:special'),
      ))!;
      expect(special.itemModelGraph!.root, isA<MtnMinecraftResourceItemModelNodeSpecial>());
      expect(special.itemModelGraph!.bindings.single.model!.location.path, 'block/chest');
      expect(special.issues.single.kind, MtnMinecraftResourceIssueKind.unsupportedSpecialRenderer);
      expect(special.textures.single.image, isNotNull);
      expect(special.isComplete, isFalse);
    });

    test('explicit effective item-model ID is authoritative, registry fallback marked', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/alt.json': jsonBytes(<String, Object?>{
          'model': <String, String>{'type': 'minecraft:empty'},
        }),
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final item = (await loader.loadItem(
        environment: environment('1.21.4'),
        request: request('verity:different', effective: 'verity:alt'),
      ))!;
      expect(item.entry.modelIdentity.toString(), 'verity:alt');
      expect(item.entry.usedConventionalFallback, isFalse);
      expect(await loader.loadItem(
        environment: environment('1.21.4'),
        request: request('verity:missing'),
      ), isNull);
    });

    test('26.1 structured textures retain sprite and translucency; 1.21.4 rejects them', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/torch.json': jsonBytes(<String, Object?>{
          'model': <String, Object?>{
            'type': 'minecraft:model',
            'model': 'verity:item/torch',
            'transformation': <String, Object?>{'translation': <int>[0, 1, 0]},
          },
        }),
        'assets/verity/models/item/torch.json': jsonBytes(<String, Object?>{
          'textures': <String, Object?>{
            'layer0': <String, Object?>{
              'sprite': 'verity:item/torch', 'force_translucent': true,
            },
          },
        }),
        'assets/verity/textures/item/torch.png': png,
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final modern = (await loader.loadItem(
        environment: environment('26.1'), request: request('verity:torch'),
      ))!;
      expect(modern.itemModelGraph!.root.raw['transformation'], isNotNull);
      expect(modern.textures.single.location.toString(), 'verity:item/torch');
      expect(modern.textures.single.forceTranslucent, isTrue);
      expect(modern.itemModelGraph!.bindings.single.model!.textureDeclarations['layer0'], isA<Map<String, Object?>>());
      expect(modern.isComplete, isTrue);
      await expectLater(
        loader.loadItem(environment: environment('1.21.4'), request: request('verity:torch')),
        throwsFormatException,
      );
    });

    test('missing normal model retains graph and diagnostic; malformed available JSON propagates', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/missing.json': jsonBytes(<String, Object?>{
          'model': model('verity:item/nonexistent'),
        }),
        'assets/verity/items/broken.json': utf8.encode('{broken'),
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final missing = (await loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:missing'),
      ))!;
      expect(missing.itemModelGraph!.bindings.single.model, isNull);
      expect(missing.issues.single.kind, MtnMinecraftResourceIssueKind.missingParent);
      await expectLater(loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:broken'),
      ), throwsFormatException);
    });

    test('parser rejects malformed known nodes and bounded recursion', () {
      const parser = MtnMinecraftResourceItemModelParser();
      void rejects(Object document) => expect(
        () => parser.parse(Uint8List.fromList(jsonBytes(document))),
        throwsFormatException,
      );
      rejects(<String, Object?>{'model': <String, String>{'type': 'minecraft:model'}});
      rejects(<String, Object?>{'model': <String, Object?>{
        'type': 'minecraft:condition', 'property': 'minecraft:using_item',
        'on_true': <String, String>{'type': 'minecraft:empty'},
      }});
      rejects(<String, Object?>{'model': <String, Object?>{
        'type': 'minecraft:range_dispatch', 'property': 'minecraft:damage',
        'entries': <Object?>[<String, Object?>{'threshold': 'no', 'model': model('verity:item/a')}],
      }});
      Object nested = <String, String>{'type': 'minecraft:empty'};
      for (int i = 0; i < 70; i++) {
        nested = <String, Object?>{
          'type': 'minecraft:composite', 'models': <Object>[nested],
        };
      }
      rejects(<String, Object>{'model': nested});
    });
  });
}
