import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Fabric mod info provider', () {
    late Directory directory;
    late MtnMinecraftModInfoProviderFabric provider;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-fabric-provider-',
      );
      provider = const MtnMinecraftModInfoProviderFabric();
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('reads normalized Fabric mod info', () async {
      final File jar = await _writeJar(
        directory,
        'example.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'example_mod',
              'version': '1.2.3',
              'name': 'Example Mod',
              'description': 'Example description',
              'authors': <Object?>[
                'Alice',
                <String, Object?>{
                  'name': 'Bob',
                  'contact': <String, String>{
                    'homepage': 'https://example.com',
                  },
                },
              ],
              'depends': <String, String>{
                'fabricloader': '>=0.19.0',
              },
            },
          ),
        },
      );

      final List<MtnMinecraftInfoMod>? mods = await provider.parse(jar);

      expect(mods, isNotNull);
      expect(mods, hasLength(1));
      final MtnMinecraftInfoMod mod = mods!.single;
      expect(mod.id, 'example_mod');
      expect(mod.name, 'Example Mod');
      expect(mod.version, '1.2.3');
      expect(mod.description, 'Example description');
      expect(mod.authors, <String>['Alice', 'Bob']);
      expect(mod.parentMods, isEmpty);
      expect(mod.modTypes, isEmpty);
      expect(() => mod.authors.add('Carol'), throwsUnsupportedError);
    });

    test('uses Fabric defaults for optional normalized fields', () async {
      final File jar = await _writeJar(
        directory,
        'minimal.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'minimal_mod',
              'version': '2.0.0',
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.name, 'minimal_mod');
      expect(mod.description, '');
      expect(mod.authors, isEmpty);
    });

    test('JAR without root fabric.mod.json is not a Fabric result', () async {
      final File jar = await _writeJar(
        directory,
        'other.jar',
        <String, List<int>>{
          'META-INF/example.txt': utf8.encode('not Fabric metadata'),
          'nested/fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'nested',
              'version': '1',
            },
          ),
        },
      );

      expect(await provider.parse(jar), isNull);
    });

    test('malformed JAR is invalid data', () async {
      final File file = File(p.join(directory.path, 'broken.jar'));
      await file.writeAsBytes(<int>[1, 2, 3, 4]);

      await _expectInvalidData(provider.parse(file));
    });

    test('malformed fabric.mod.json is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'broken-json.jar',
        <String, List<int>>{
          'fabric.mod.json': utf8.encode('{'),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('unsupported Fabric schema version is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'schema.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 2,
              'id': 'example_mod',
              'version': '1.0.0',
            },
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('missing required Fabric identity is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'missing-id.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'version': '1.0.0',
            },
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('invalid author entry is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'authors.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'example_mod',
              'version': '1.0.0',
              'authors': <Object?>[
                <String, Object?>{'contact': <String, String>{}},
              ],
            },
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('parses declared embedded JARs recursively in memory', () async {
      final Uint8List grandchild = _jarBytes(
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'grandchild',
              'version': '1',
            },
          ),
        },
      );
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'child',
              'version': '1',
              'jars': <Object?>[
                <String, String>{
                  'file': 'META-INF/jars/grandchild.jar',
                },
              ],
            },
          ),
          'META-INF/jars/grandchild.jar': grandchild,
        },
      );
      final File rootJar = await _writeJar(
        directory,
        'root.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'root',
              'version': '1',
              'jars': <Object?>[
                <String, String>{
                  'file': 'META-INF/jars/child.jar',
                },
              ],
            },
          ),
          'META-INF/jars/child.jar': child,
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(rootJar))!;

      expect(mods.map((MtnMinecraftInfoMod mod) => mod.id),
          <String>['root', 'child', 'grandchild']);
      final MtnMinecraftInfoMod root = mods[0];
      final MtnMinecraftInfoMod parsedChild = mods[1];
      final MtnMinecraftInfoMod parsedGrandchild = mods[2];
      expect(parsedChild.parentMods, <MtnMinecraftInfoMod>[root]);
      expect(
        parsedGrandchild.parentMods,
        <MtnMinecraftInfoMod>[parsedChild],
      );
    });

    test('declared embedded JAR must exist in the parent archive', () async {
      final File jar = await _writeJar(
        directory,
        'missing-embedded.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'root',
              'version': '1',
              'jars': <Object?>[
                <String, String>{
                  'file': 'META-INF/jars/missing.jar',
                },
              ],
            },
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
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

Uint8List _jsonBytes(Map<String, Object?> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Future<void> _expectInvalidData(
  Future<List<MtnMinecraftInfoMod>?> future,
) async {
  await expectLater(
    future,
    throwsA(
      isA<MtnMinecraftModInfoProviderException>().having(
        (MtnMinecraftModInfoProviderException error) => error.error,
        'error',
        MtnMinecraftModInfoProviderError.invalidData,
      ),
    ),
  );
}
