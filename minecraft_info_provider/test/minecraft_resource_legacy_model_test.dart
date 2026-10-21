import 'dart:convert';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';
import 'package:test/test.dart';

void main() {
  MtnMinecraftResourceEnvironment environment(String raw) =>
      MtnMinecraftResourceEnvironment(
        version: MtnMinecraftVersion.parse(
          raw, type: MtnMinecraftGameVersionType.release,
        ),
        loaderType: MtnMinecraftLoaderType.fabric,
      );

  MtnMinecraftResourceItemRequest request(String id) =>
      MtnMinecraftResourceItemRequest(item: MtnMinecraftInfoItemIdentity.parse(id));

  MtnMinecraftInfoModAssetSource source(
    String namespace,
    Map<String, List<int>> assets, {
    List<String>? reads,
    bool fail = false,
  }) =>
      MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>[namespace],
        loader: (String path) async {
          reads?.add(path);
          if (fail) throw const FormatException('source failure');
          final List<int>? bytes = assets[path];
          return bytes == null ? null : Uint8List.fromList(bytes);
        },
      );

  List<int> jsonBytes(Object object) => utf8.encode(jsonEncode(object));

  // Valid PNG resource bytes, kept opaque: CP3 never decodes or re-encodes.
  final List<int> png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jAocAAAAASUVORK5CYII=',
  );

  group('CP3 legacy static model and texture resources', () {
    test('loads an item JSON and an original PNG, retaining image provenance', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/flashlight.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{'layer0': 'verity:item/flashlight'},
        }),
        'assets/verity/textures/item/flashlight.png': png,
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);

      final result = (await loader.loadItem(
        environment: environment('1.21.1'),
        request: request('verity:flashlight'),
      ))!;

      expect(result.isComplete, isTrue);
      expect(result.model!.location.toString(), 'verity:item/flashlight');
      expect(result.model!.resource.source, same(mod));
      expect(result.textures, hasLength(1));
      expect(result.textures.single.symbol, 'layer0');
      expect(result.textures.single.location.toString(), 'verity:item/flashlight');
      expect(result.textures.single.image!.resource.source, same(mod));
      expect(result.pngList, hasLength(1));
      expect(result.pngList.single, png);

      final Uint8List copy = result.pngList.single;
      copy[0] = 0;
      expect(result.pngList.single[0], 137); // original PNG signature retained
    });

    test('cross-source and cross-namespace parent, inherited properties and layers', () async {
      final reads = <String>[];
      final vanilla = source('minecraft', <String, List<int>>{
        'assets/minecraft/models/item/handheld.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{
            'layer0': 'minecraft:item/default',
            'particle': '#layer0',
          },
          'display': <String, Object?>{'ground': <String, Object?>{'scale': <int>[1, 1, 1]}},
          'elements': <Object?>[<String, Object?>{'name': 'parent-geometry'}],
        }),
        'assets/minecraft/textures/item/default.png': png,
      }, reads: reads);
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/flashlight.json': jsonBytes(<String, Object?>{
          'parent': 'minecraft:item/handheld',
          'textures': <String, String>{
            'layer0': 'verity:item/flashlight',
            'layer1': '#layer0',
          },
          'display': <String, Object?>{'gui': <String, Object?>{'scale': <int>[2, 2, 2]}},
        }),
        'assets/verity/textures/item/flashlight.png': png,
      }, reads: reads);
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[vanilla, mod],
      );

      final result = (await loader.loadItem(
        environment: environment('1.21.1'),
        request: request('verity:flashlight'),
      ))!;
      final model = result.model!;

      expect(result.isComplete, isTrue);
      expect(model.parentLocation.toString(), 'minecraft:item/handheld');
      expect(model.parent!.resource.source, same(vanilla));
      expect(model.resource.source, same(mod));
      expect(model.textureReferences['layer0'], 'verity:item/flashlight');
      expect(model.textureReferences['layer1'], '#layer0');
      expect(model.textureReferences['particle'], '#layer0');
      final display = model.effectiveProperties['display'] as Map<String, dynamic>;
      expect(display.keys, containsAll(<String>['ground', 'gui']));
      expect(model.effectiveProperties['elements'], isNotNull);
      expect(result.textures.map((item) => item.symbol), <String>['layer0', 'layer1', 'particle']);
      expect(result.textures.every((texture) => texture.location.toString() == 'verity:item/flashlight'), isTrue);
      expect(result.pngList, hasLength(2)); // visual layers; no duplicate particle candidate
      expect(reads, contains('assets/minecraft/models/item/handheld.json'));
      expect(reads, contains('assets/verity/textures/item/flashlight.png'));
      expect(reads, isNot(contains('assets/minecraft/textures/item/default.png')));
    });

    test('missing vanilla parent retains the child model and its PNG', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/flashlight.json': jsonBytes(<String, Object?>{
          'parent': 'minecraft:item/handheld',
          'textures': <String, String>{'layer0': 'verity:item/flashlight'},
        }),
        'assets/verity/textures/item/flashlight.png': png,
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final result = (await loader.loadItem(
        environment: environment('1.21.1'),
        request: request('verity:flashlight'),
      ))!;
      expect(result.model, isNotNull);
      expect(result.model!.parent, isNull);
      expect(result.model!.parentLocation.toString(), 'minecraft:item/handheld');
      expect(result.pngList, hasLength(1));
      expect(result.isComplete, isFalse);
      expect(
        result.issues.where((issue) => issue.kind == MtnMinecraftResourceIssueKind.missingParent)
            .map((issue) => issue.reference),
        <String>['minecraft:item/handheld'],
      );
    });

    test('parent cycles and variable cycles preserve partial results', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/a.json': jsonBytes(<String, Object?>{
          'parent': 'verity:item/b',
          'textures': <String, String>{'layer0': '#other', 'other': '#layer0'},
        }),
        'assets/verity/models/item/b.json': jsonBytes(<String, Object?>{
          'parent': 'verity:item/a',
        }),
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      final result = (await loader.loadItem(
        environment: environment('1.21.1'),
        request: request('verity:a'),
      ))!;
      expect(result.model, isNotNull);
      expect(result.model!.parent, isNotNull);
      expect(result.model!.parent!.parent, isNull);
      expect(result.issues.map((issue) => issue.kind), contains(MtnMinecraftResourceIssueKind.parentCycle));
      expect(result.issues.map((issue) => issue.kind), contains(MtnMinecraftResourceIssueKind.textureVariableCycle));
      expect(result.pngList, isEmpty);
    });

    test('missing and malformed texture references remain unresolved', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/a.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{
            'layer0': '#missing',
            'layer1': 'UPPERCASE:invalid',
            'layer2': 'verity:item/absent',
          },
        }),
      });
      final result = (await MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[mod],
      ).loadItem(environment: environment('1.21.1'), request: request('verity:a')))!;
      expect(result.textures, hasLength(3));
      expect(result.issues.map((issue) => issue.kind), containsAll(<MtnMinecraftResourceIssueKind>[
        MtnMinecraftResourceIssueKind.missingTextureVariable,
        MtnMinecraftResourceIssueKind.invalidTextureReference,
        MtnMinecraftResourceIssueKind.missingTexture,
      ]));
      expect(result.isComplete, isFalse);
    });

    test('runtime model overrides are preserved, never silently evaluated', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/models/item/a.json': jsonBytes(<String, Object?>{
          'overrides': <Object?>[
            <String, Object?>{'predicate': <String, int>{'pull': 1}, 'model': 'verity:item/pulled'},
          ],
        }),
      });
      final result = (await MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[mod],
      ).loadItem(environment: environment('1.21.1'), request: request('verity:a')))!;
      expect(result.model!.json['overrides'], isNotNull);
      expect(result.issues.single.kind, MtnMinecraftResourceIssueKind.runtimeOverridesNotEvaluated);
    });

    test('malformed effective JSON or failing higher-precedence source propagates', () async {
      final good = source('verity', <String, List<int>>{
        'assets/verity/models/item/a.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{'layer0': 'verity:item/valid'},
        }),
      });
      final invalid = source('verity', <String, List<int>>{
        'assets/verity/models/item/a.json': utf8.encode('{broken json'),
      });
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[good, invalid],
      );
      await expectLater(loader.loadItem(
        environment: environment('1.21.1'), request: request('verity:a'),
      ), throwsFormatException);
      loader.unregisterSource(invalid);
      loader.registerSource(source('verity', <String, List<int>>{}, fail: true));
      await expectLater(loader.loadItem(
        environment: environment('1.21.1'), request: request('verity:a'),
      ), throwsFormatException);
    });

    test('modern item graph preserves unresolved model; missing entry remains null', () async {
      final mod = source('verity', <String, List<int>>{
        'assets/verity/items/a.json': jsonBytes(<String, Object?>{
          'model': <String, Object?>{'type': 'minecraft:model', 'model': 'verity:item/a'},
        }),
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[mod]);
      expect(await loader.loadItem(
        environment: environment('1.21.1'), request: request('verity:missing'),
      ), isNull);
      final modern = (await loader.loadItem(
        environment: environment('1.21.4'), request: request('verity:a'),
      ))!;
      expect(modern.entry.kind, MtnMinecraftResourceItemEntryKind.itemDefinition);
      expect(modern.model, isNull);
      expect(modern.itemModelGraph!.root, isA<MtnMinecraftResourceItemModelNodeModel>());
      expect(modern.itemModelGraph!.bindings.single.model, isNull);
      expect(modern.issues.single.kind, MtnMinecraftResourceIssueKind.missingParent);
      expect(modern.isComplete, isFalse);
    });
  });
}
