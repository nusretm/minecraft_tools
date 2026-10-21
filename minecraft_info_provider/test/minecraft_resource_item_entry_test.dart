import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';
import 'package:test/test.dart';

class TestResourceHelper extends MtnMinecraftResourceHelperAbs {
  TestResourceHelper({
    required String name,
    String directory = 'custom',
    MtnMinecraftVersion? min,
    MtnMinecraftVersion? max,
    Set<MtnMinecraftLoaderType>? types,
  })  : directory = directory,
        super(
          name: name,
          title: name,
          versionMin: min,
          versionMax: max,
          loaderTypes: types,
        );

  final String directory;

  @override
  String get entryDirectory => directory;
}

void main() {
  MtnMinecraftResourceEnvironment environment(
    String gameVersion, {
    MtnMinecraftGameVersionType type = MtnMinecraftGameVersionType.release,
    MtnMinecraftLoaderType loader = MtnMinecraftLoaderType.vanilla,
  }) =>
      MtnMinecraftResourceEnvironment(
        version: MtnMinecraftVersion.parse(gameVersion, type: type),
        loaderType: loader,
      );

  MtnMinecraftResourceItemRequest request(
    String id, {
    String? itemModel,
  }) =>
      MtnMinecraftResourceItemRequest(
        item: MtnMinecraftInfoItemIdentity.parse(id),
        effectiveItemModel: itemModel == null ? null : MtnMinecraftResourceLocation.parse(itemModel),
      );

  MtnMinecraftInfoModAssetSource source(
    String namespace,
    Map<String, List<int>> assets, {
    List<String>? reads,
    FormatException? error,
  }) =>
      MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>[namespace],
        loader: (String path) async {
          reads?.add(path);
          if (error != null) throw error;
          final List<int>? bytes = assets[path];
          return bytes == null ? null : Uint8List.fromList(bytes);
        },
      );

  group('CP2 resource location', () {
    test('parses default namespace, preserves identity and equality', () {
      final explicit = MtnMinecraftResourceLocation.parse('minecraft:item/diamond_sword');
      final implicit = MtnMinecraftResourceLocation.parse('item/diamond_sword');
      final other = MtnMinecraftResourceLocation.parse(
        'flashlight',
        defaultNamespace: 'verity',
      );
      expect(explicit, implicit);
      expect(explicit.hashCode, implicit.hashCode);
      expect(explicit.toString(), 'minecraft:item/diamond_sword');
      expect(other.toString(), 'verity:flashlight');
      expect(<MtnMinecraftResourceLocation>{implicit, explicit}, hasLength(1));
      expect(other, isNot(explicit));
    });

    test('rejects malformed namespaces, invalid segments and traversal', () {
      for (final String value in <String>[
        '', ' ', ':item', 'minecraft:', 'A:item', 'minecraft:foo:bar',
        'minecraft:../secret', '../bad', '/absolute', 'a//b', 'a/./b', 'a/',
      ]) {
        expect(() => MtnMinecraftResourceLocation.parse(value), throwsArgumentError, reason: value);
      }
      expect(() => MtnMinecraftResourceLocation.parse('item', defaultNamespace: 'BAD'), throwsArgumentError);
      expect(() => request('example:../bad'), throwsArgumentError);
    });
  });

  group('CP2 helper registration and selection', () {
    test('registers built-ins through one registry with immutable snapshots', () {
      final loader = MtnMinecraftResourceLoader();
      expect(loader.helpers.map((h) => h.name), <String>['legacy', 'item-model-component', 'modern']);
      final snapshot = loader.helpers;
      expect(() => snapshot.clear(), throwsUnsupportedError);
      expect(() => loader.registerHelper(MtnMinecraftResourceHelperLegacy()), throwsStateError);

      final custom = TestResourceHelper(name: 'custom');
      loader.registerHelper(custom);
      expect(loader.helpers.last, same(custom));
      expect(snapshot, hasLength(3));
      expect(loader.unregisterHelper(custom), isTrue);
      expect(loader.unregisterHelper(custom), isFalse);
      loader.clearHelpers();
      expect(loader.helpers, isEmpty);
    });

    test('selects period boundaries across all canonical loader families', () {
      final helpers = MtnMinecraftResourceLoader().helpers;
      for (final loaderType in MtnMinecraftLoaderType.values) {
        expect(helpers.where((h) => h.supports(environment('1.21.1', loader: loaderType))).single.name, 'legacy');
        expect(helpers.where((h) => h.supports(environment('1.21.2', loader: loaderType))).single.name, 'item-model-component');
        expect(helpers.where((h) => h.supports(environment('1.21.3', loader: loaderType))).single.name, 'item-model-component');
        expect(helpers.where((h) => h.supports(environment('1.21.4', loader: loaderType))).single.name, 'modern');
        expect(helpers.where((h) => h.supports(environment('26.1.2', loader: loaderType))).single.name, 'modern');
      }
      expect(helpers.where((h) => h.supports(environment('26.3-snapshot-10', type: MtnMinecraftGameVersionType.snapshot))), isEmpty);
      expect(helpers.where((h) => h.supports(environment('24w14a', type: MtnMinecraftGameVersionType.snapshot))), isEmpty);
    });

    test('validates metadata and optional loader applicability', () {
      MtnMinecraftVersion v(String raw) => MtnMinecraftVersion.parse(raw, type: MtnMinecraftGameVersionType.release);
      expect(() => TestResourceHelper(name: ''), throwsArgumentError);
      expect(() => TestResourceHelper(name: 'empty', types: <MtnMinecraftLoaderType>{}), throwsArgumentError);
      expect(() => TestResourceHelper(name: 'range', min: v('1.21.4'), max: v('1.21.1')), throwsArgumentError);
      expect(
        () => TestResourceHelper(
          name: 'snapshot',
          min: MtnMinecraftVersion.parse('26.3-snapshot-10', type: MtnMinecraftGameVersionType.snapshot),
        ),
        throwsArgumentError,
      );
      final fabric = TestResourceHelper(
        name: 'fabric-only',
        types: <MtnMinecraftLoaderType>{MtnMinecraftLoaderType.fabric},
      );
      expect(fabric.supports(environment('1.21.4', loader: MtnMinecraftLoaderType.fabric)), isTrue);
      expect(fabric.supports(environment('1.21.4', loader: MtnMinecraftLoaderType.forge)), isFalse);
      expect(() => fabric.loaderTypes!.clear(), throwsUnsupportedError);
    });

    test('can disable built-ins when only custom helpers are wanted', () {
      final loader = MtnMinecraftResourceLoader(
        registerBuiltInHelpers: false,
        helpers: <MtnMinecraftResourceHelperAbs>[TestResourceHelper(name: 'only-custom')],
      );
      expect(loader.helpers, hasLength(1));
      expect(loader.helpers.single.name, 'only-custom');
    });
  });

  group('CP2 item entries', () {
    test('legacy uses registry identity even if override was given', () async {
      final src = source('verity', <String, List<int>>{
        'assets/verity/models/item/flashlight.json': <int>[1],
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]);
      final entry = (await loader.loadItemEntry(
        environment: environment('1.21.1'),
        request: request('verity:flashlight', itemModel: 'verity:override'),
      ))!;
      expect(entry.kind, MtnMinecraftResourceItemEntryKind.normalModel);
      expect(entry.modelIdentity.toString(), 'verity:flashlight');
      expect(entry.entryLocation.toString(), 'verity:models/item/flashlight.json');
      expect(entry.modelIdentityOrigin, MtnMinecraftResourceItemModelIdentityOrigin.legacyRegistry);
      expect(entry.resource.source, same(src));
      expect(entry.resource.bytes, <int>[1]);
    });

    test('component helper uses effective model ID under models/item', () async {
      final reads = <String>[];
      final src = source('verity', <String, List<int>>{
        'assets/verity/models/item/override.json': <int>[2],
      }, reads: reads);
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]);
      final entry = (await loader.loadItemEntry(
        environment: environment('1.21.3', loader: MtnMinecraftLoaderType.fabric),
        request: request('verity:flashlight', itemModel: 'verity:override'),
      ))!;
      expect(entry.itemIdentity.toString(), 'verity:flashlight');
      expect(entry.modelIdentity.toString(), 'verity:override');
      expect(entry.entryLocation.toString(), 'verity:models/item/override.json');
      expect(entry.kind, MtnMinecraftResourceItemEntryKind.normalModel);
      expect(entry.modelIdentityOrigin, MtnMinecraftResourceItemModelIdentityOrigin.effectiveItemModel);
      expect(reads, <String>['assets/verity/models/item/override.json']);
    });

    test('modern effective item-model identity may use another namespace', () async {
      final src = source('minecraft', <String, List<int>>{
        'assets/minecraft/items/diamond_sword.json': <int>[3],
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]);
      final entry = (await loader.loadItemEntry(
        environment: environment('26.1.2'),
        request: request('verity:flashlight', itemModel: 'minecraft:diamond_sword'),
      ))!;
      expect(entry.itemIdentity.toString(), 'verity:flashlight');
      expect(entry.modelIdentity.toString(), 'minecraft:diamond_sword');
      expect(entry.entryLocation.toString(), 'minecraft:items/diamond_sword.json');
      expect(entry.resource.assetPath, 'assets/minecraft/items/diamond_sword.json');
      expect(entry.kind, MtnMinecraftResourceItemEntryKind.itemDefinition);
      expect(entry.usedConventionalFallback, isFalse);
    });

    test('unknown modern effective identity is marked as conventional fallback', () async {
      final src = source('verity', <String, List<int>>{
        'assets/verity/items/flashlight.json': <int>[4],
      });
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]);
      final entry = (await loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:flashlight'),
      ))!;
      expect(entry.usedConventionalFallback, isTrue);
      expect(entry.modelIdentityOrigin, MtnMinecraftResourceItemModelIdentityOrigin.conventionalRegistryFallback);
      expect(entry.entryLocation.toString(), 'verity:items/flashlight.json');
    });

    test('missing entry and unsupported snapshot return null', () async {
      final src = source('verity', <String, List<int>>{});
      final loader = MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]);
      expect(await loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:missing'),
      ), isNull);
      expect(await loader.loadItemEntry(
        environment: environment('26.3-snapshot-10', type: MtnMinecraftGameVersionType.snapshot),
        request: request('verity:flashlight'),
      ), isNull);
    });

    test('preserves effective source precedence and source errors from CP1', () async {
      final low = source('verity', <String, List<int>>{
        'assets/verity/items/flashlight.json': <int>[1],
      });
      final high = source('verity', <String, List<int>>{
        'assets/verity/items/flashlight.json': <int>[9],
      });
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[low, high],
      );
      final found = (await loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:flashlight'),
      ))!;
      expect(found.resource.source, same(high));
      expect(found.resource.bytes, <int>[9]);

      loader.unregisterSource(high);
      final fallback = (await loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:flashlight'),
      ))!;
      expect(fallback.resource.source, same(low));

      final broken = source('verity', <String, List<int>>{}, error: const FormatException('broken source'));
      loader.registerSource(broken);
      await expectLater(loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:flashlight'),
      ), throwsFormatException);
    });

    test('custom helper has priority; null permits standard helper fallback', () async {
      final reads = <String>[];
      final src = source('verity', <String, List<int>>{
        'assets/verity/items/flashlight.json': <int>[5],
      }, reads: reads);
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[src],
        helpers: <MtnMinecraftResourceHelperAbs>[
          TestResourceHelper(name: 'custom-priority', directory: 'not-found'),
        ],
      );
      final entry = (await loader.loadItemEntry(
        environment: environment('1.21.4'),
        request: request('verity:flashlight'),
      ))!;
      expect(entry.kind, MtnMinecraftResourceItemEntryKind.itemDefinition);
      expect(reads, <String>[
        'assets/verity/not-found/flashlight.json',
        'assets/verity/items/flashlight.json',
      ]);
    });
  });
}
