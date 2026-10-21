import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mtn-vanilla-resource-cp5-');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  List<int> jsonBytes(Object value) => utf8.encode(jsonEncode(value));
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jAocAAAAASUVORK5CYII=',
  );

  Future<File> writeJar(String name, Map<String, List<int>> entries) async {
    final Archive archive = Archive();
    for (final MapEntry<String, List<int>> entry in entries.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    final File file = File(p.join(directory.path, name));
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
    return file;
  }

  MtnMinecraftResourceEnvironment environment(String version) =>
      MtnMinecraftResourceEnvironment(
        version: MtnMinecraftVersion.parse(
          version, type: MtnMinecraftGameVersionType.release,
        ),
        loaderType: MtnMinecraftLoaderType.fabric,
      );

  group('CP5 Vanilla client JAR resource source', () {
    test('discovers sorted namespaces and reads only indexed asset files', () async {
      final File jar = await writeJar('client.jar', <String, List<int>>{
        'assets/minecraft/models/item/generated.json': jsonBytes(<String, Object?>{'parent': 'minecraft:builtin/generated'}),
        'assets/another_namespace/textures/item/test.png': png,
        'assets/minecraft/textures/item/default.png': png,
        'assets/INVALID/models/a.json': <int>[1],
        'assets/minecraft/../invalid.png': <int>[2],
        'assets/minecraft//invalid.png': <int>[3],
        'META-INF/MANIFEST.MF': utf8.encode('manifest'),
      });
      final MtnMinecraftResourceSourceVanilla source =
          await MtnMinecraftResourceSourceVanilla.open(clientJar: jar);
      expect(source, isA<MtnMinecraftResourceSourceAbs>());
      expect(source.clientJar.path, p.normalize(p.absolute(jar.path)));
      expect(source.namespaces, <String>['another_namespace', 'minecraft']);
      expect(() => source.namespaces.add('test'), throwsUnsupportedError);
      expect(source.containsNamespace('minecraft'), isTrue);
      expect(source.containsNamespace('INVALID'), isFalse);

      final Uint8List first = (await source.read('minecraft', 'textures/item/default.png'))!;
      expect(first, png);
      first[0] = 0;
      final Uint8List second = (await source.read('minecraft', 'textures/item/default.png'))!;
      expect(second, png);
      expect(await source.read('minecraft', 'textures/item/absent.png'), isNull);
      expect(await source.read('nonexistent', 'textures/item/default.png'), isNull);
      expect(await source.read('minecraft', 'META-INF/MANIFEST.MF'), isNull);
      await expectLater(source.read('minecraft', '../secret.txt'), throwsArgumentError);
      await expectLater(source.read('minecraft', '/textures/test.png'), throwsArgumentError);
    });

    test('invalid/missing JAR throws; indexed resources do not silently become missing', () async {
      final File absent = File(p.join(directory.path, 'absent.jar'));
      await expectLater(MtnMinecraftResourceSourceVanilla.open(clientJar: absent), throwsA(isA<FileSystemException>()));

      final File invalid = File(p.join(directory.path, 'invalid.jar'));
      await invalid.writeAsBytes(<int>[1, 2, 3, 4, 5]);
      await expectLater(MtnMinecraftResourceSourceVanilla.open(clientJar: invalid), throwsFormatException);

      final File valid = await writeJar('mutable-client.jar', <String, List<int>>{
        'assets/minecraft/models/item/a.json': jsonBytes(<String, String>{'parent': 'minecraft:item/generated'}),
      });
      final MtnMinecraftResourceSourceVanilla source =
          await MtnMinecraftResourceSourceVanilla.open(clientJar: valid);
      await valid.writeAsBytes(<int>[1, 2, 3, 4, 5]);
      await expectLater(source.read('minecraft', 'models/item/a.json'), throwsA(isA<Exception>()));
      expect(await source.read('minecraft', 'models/item/absent.json'), isNull);
    });

    test('mod archive uses shared ZIP reader and overrides Vanilla source with provenance', () async {
      final File vanillaJar = await writeJar('client.jar', <String, List<int>>{
        'assets/minecraft/models/item/generated.json': jsonBytes(<String, String>{'parent': 'minecraft:builtin/generated'}),
      });
      final File modJar = await writeJar('overrides.jar', <String, List<int>>{
        'fabric.mod.json': jsonBytes(<String, Object?>{
          'schemaVersion': 1, 'id': 'overrides', 'version': '1.0',
        }),
        'assets/minecraft/models/item/generated.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{'layer0': 'minecraft:item/override'},
        }),
        'assets/minecraft/textures/item/override.png': png,
      });
      final MtnMinecraftResourceSourceVanilla vanilla =
          await MtnMinecraftResourceSourceVanilla.open(clientJar: vanillaJar);
      final MtnMinecraftInfoModAssetSource mod =
          (await const MtnMinecraftModInfoProviderFabric().parse(modJar))!.single.assetSources.single;
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[vanilla, mod],
      );
      final MtnMinecraftResourceData effective =
          (await loader.read('minecraft', 'models/item/generated.json'))!;
      expect(effective.source, same(mod));
      expect(effective.assetPath, 'assets/minecraft/models/item/generated.json');
      final List<MtnMinecraftResourceData> candidates =
          await loader.readAll('minecraft', 'models/item/generated.json');
      expect(candidates, hasLength(2));
      expect(candidates[0].source, same(mod));
      expect(candidates[1].source, same(vanilla));
      expect(await mod.read('minecraft', 'textures/item/override.png'), png);
      expect((await loader.read('minecraft', 'textures/item/override.png'))!.source, same(mod));
    });

    test('modern item resolves Mod -> Vanilla -> Mod parent and original texture PNG', () async {
      final File vanillaJar = await writeJar('client.jar', <String, List<int>>{
        'assets/minecraft/models/item/handheld.json': jsonBytes(<String, Object?>{
          'parent': 'verity:item/base',
          'display': <String, Object?>{'ground': <String, Object?>{'scale': <int>[1, 1, 1]}},
        }),
      });
      final File modJar = await writeJar('verity.jar', <String, List<int>>{
        'fabric.mod.json': jsonBytes(<String, Object?>{
          'schemaVersion': 1, 'id': 'verity', 'version': '1.0',
        }),
        'assets/verity/items/flashlight.json': jsonBytes(<String, Object?>{
          'model': <String, String>{'type': 'minecraft:model', 'model': 'verity:item/flashlight'},
        }),
        'assets/verity/models/item/flashlight.json': jsonBytes(<String, Object?>{
          'parent': 'minecraft:item/handheld',
          'textures': <String, String>{'layer0': 'verity:item/flashlight'},
        }),
        'assets/verity/models/item/base.json': jsonBytes(<String, Object?>{
          'textures': <String, String>{'particle': '#layer0'},
        }),
        'assets/verity/textures/item/flashlight.png': png,
      });
      final MtnMinecraftResourceSourceVanilla vanilla =
          await MtnMinecraftResourceSourceVanilla.open(clientJar: vanillaJar);
      final MtnMinecraftInfoModAssetSource mod =
          (await const MtnMinecraftModInfoProviderFabric().parse(modJar))!.single.assetSources.single;
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[vanilla, mod],
      );
      final MtnMinecraftResourceItem item = (await loader.loadItem(
        environment: environment('26.1.2'),
        request: MtnMinecraftResourceItemRequest(
          item: MtnMinecraftInfoItemIdentity.parse('verity:flashlight'),
        ),
      ))!;
      final binding = item.itemModelGraph!.bindings.single;
      expect(item.isComplete, isTrue);
      expect(binding.model!.resource.source, same(mod));
      expect(binding.model!.parent!.resource.source, same(vanilla));
      expect(binding.model!.parent!.parent!.resource.source, same(mod));
      expect(binding.model!.parent!.parent!.location.toString(), 'verity:item/base');
      expect(binding.textures.singleWhere((MtnMinecraftResourceTexture texture) => texture.symbol == 'layer0').image!.resource.source, same(mod));
      expect(item.pngList, hasLength(1));
      expect(item.pngList.single, png);
    });
  });
}
