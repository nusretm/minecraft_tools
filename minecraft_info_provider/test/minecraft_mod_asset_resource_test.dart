import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('mod asset resource foundation', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-mod-assets-',
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('asset source validates identifiers and returns copied bytes', () async {
      final Uint8List original = Uint8List.fromList(<int>[1, 2, 3]);
      final List<String> requested = <String>[];
      final MtnMinecraftInfoModAssetSource source =
          MtnMinecraftInfoModAssetSource(
        rootFile: File(p.join(directory.path, 'example.jar')),
        namespaces: <String>['example'],
        loader: (String path) async {
          requested.add(path);
          return original;
        },
      );

      final Uint8List? read = await source.read(
        'example',
        'lang/en_us.json',
      );

      expect(requested, <String>['assets/example/lang/en_us.json']);
      expect(read, original);
      expect(identical(read, original), isFalse);

      expect(
        () => source.read('Example', 'lang/en_us.json'),
        throwsArgumentError,
      );
      expect(
        () => source.read('example', '../secret.txt'),
        throwsArgumentError,
      );
      expect(
        () => source.read('example', '/textures/item/a.png'),
        throwsArgumentError,
      );
    });

    test('Fabric exposes archive namespaces without assuming mod ownership', () async {
      final Uint8List language = Uint8List.fromList(
        utf8.encode('{"item.other_namespace.example":"Example"}'),
      );
      final File jar = await _writeJar(
        directory,
        'fabric-assets.jar',
        <String, List<int>>{
          'fabric.mod.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'schemaVersion': 1,
                'id': 'example_mod',
                'version': '1',
              },
            ),
          ),
          'assets/other_namespace/lang/en_us.json': language,
          'assets/minecraft/textures/item/example.png': <int>[4, 5, 6],
          'assets/INVALID/textures/item/ignored.png': <int>[7],
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await const MtnMinecraftModInfoProviderFabric().parse(jar))!;

      expect(mods, hasLength(1));
      final MtnMinecraftInfoMod mod = mods.single;
      expect(mod.id, 'example_mod');
      expect(
        mod.assetNamespaces,
        <String>['minecraft', 'other_namespace'],
      );
      expect(mod.assetSources, hasLength(1));
      expect(
        await mod.assetSources.single.read(
          'other_namespace',
          'lang/en_us.json',
        ),
        language,
      );
    });

    test('Forge exposes lazy archive assets', () async {
      final Uint8List texture = Uint8List.fromList(<int>[8, 9, 10]);
      final File jar = await _writeJar(
        directory,
        'forge-assets.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"
license = "MIT"

[[mods]]
modId = "forge_mod"
version = "1"
''',
          ),
          'assets/forge_assets/textures/item/example.png': texture,
        },
      );

      final MtnMinecraftInfoMod mod =
          (await const MtnMinecraftModInfoProviderForge().parse(jar))!.single;

      expect(mod.assetNamespaces, <String>['forge_assets']);
      expect(
        await mod.assetSources.single.read(
          'forge_assets',
          'textures/item/example.png',
        ),
        texture,
      );
    });

    test('NeoForge exposes lazy archive assets', () async {
      final Uint8List clientItem = Uint8List.fromList(
        utf8.encode('{"model":{"type":"minecraft:model"}}'),
      );
      final File jar = await _writeJar(
        directory,
        'neoforge-assets.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "neoforge_mod"
version = "1"
''',
          ),
          'assets/neoforge_assets/items/example.json': clientItem,
        },
      );

      final MtnMinecraftInfoMod mod =
          (await const MtnMinecraftModInfoProviderNeoForge().parse(jar))!.single;

      expect(mod.assetNamespaces, <String>['neoforge_assets']);
      expect(
        await mod.assetSources.single.read(
          'neoforge_assets',
          'items/example.json',
        ),
        clientItem,
      );
    });

    test('embedded Fabric asset source follows archive chain lazily', () async {
      final Uint8List embeddedTexture =
          Uint8List.fromList(<int>[11, 12, 13]);
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'fabric.mod.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'schemaVersion': 1,
                'id': 'child',
                'version': '1',
              },
            ),
          ),
          'assets/child_assets/textures/item/child.png': embeddedTexture,
        },
      );
      final File root = await _writeJar(
        directory,
        'root.jar',
        <String, List<int>>{
          'fabric.mod.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'schemaVersion': 1,
                'id': 'root',
                'version': '1',
                'jars': <Object?>[
                  <String, Object?>{
                    'file': 'META-INF/jars/child.jar',
                  },
                ],
              },
            ),
          ),
          'META-INF/jars/child.jar': child,
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await const MtnMinecraftModInfoProviderFabric().parse(root))!;
      final MtnMinecraftInfoMod childMod = mods.singleWhere(
        (MtnMinecraftInfoMod mod) => mod.id == 'child',
      );

      expect(childMod.assetNamespaces, <String>['child_assets']);
      expect(childMod.assetSources, hasLength(1));
      final MtnMinecraftInfoModAssetSource source =
          childMod.assetSources.single;
      expect(source.rootFile?.path, p.normalize(p.absolute(root.path)));
      expect(
        source.embeddedArchivePaths,
        <String>['META-INF/jars/child.jar'],
      );
      expect(
        await source.read(
          'child_assets',
          'textures/item/child.png',
        ),
        embeddedTexture,
      );
    });

    test('mod list deduplicates one archive exposed by multiple providers', () async {
      final File jar = await _writeJar(
        directory,
        'multi-provider.jar',
        <String, List<int>>{
          'fabric.mod.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'schemaVersion': 1,
                'id': 'example',
                'version': '1',
              },
            ),
          ),
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"
license = "MIT"

[[mods]]
modId = "example"
version = "1"
''',
          ),
          'assets/example/lang/en_us.json': utf8.encode(
            '{"item.example.test":"Test"}',
          ),
        },
      );
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: const <MtnMinecraftModInfoProvider>[
          MtnMinecraftModInfoProviderFabric(),
          MtnMinecraftModInfoProviderForge(),
        ],
      );

      await list.add(jar);

      expect(list.mods, hasLength(1));
      expect(list.mods.single.modTypes, <String>['fabric', 'forge']);
      expect(list.mods.single.assetSources, hasLength(1));
      expect(list.assetSources, hasLength(1));
      expect(list.assetNamespaces, <String>['example']);
      expect(list.getAssetSources('example'), hasLength(1));
      expect(list.getAssetSources('missing'), isEmpty);
    });

    test('archive with no assets does not create an empty asset source', () async {
      final File jar = await _writeJar(
        directory,
        'no-assets.jar',
        <String, List<int>>{
          'fabric.mod.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'schemaVersion': 1,
                'id': 'no_assets',
                'version': '1',
              },
            ),
          ),
        },
      );

      final MtnMinecraftInfoMod mod =
          (await const MtnMinecraftModInfoProviderFabric().parse(jar))!.single;

      expect(mod.assetSources, isEmpty);
      expect(mod.assetNamespaces, isEmpty);
    });
  });
}

Future<File> _writeJar(
  Directory directory,
  String fileName,
  Map<String, List<int>> entries,
) async {
  final File file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(_jarBytes(entries));
  return file;
}

Uint8List _jarBytes(Map<String, List<int>> entries) {
  final Archive archive = Archive();
  for (final MapEntry<String, List<int>> entry in entries.entries) {
    archive.add(
      ArchiveFile.bytes(
        entry.key,
        entry.value,
      ),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}
