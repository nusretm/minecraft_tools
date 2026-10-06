import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Fabric mod metadata', () {
    late Directory gameDirectory;
    late Directory modsDirectory;
    late MtnMinecraftInfoProvider provider;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-info-fabric-metadata-',
      );
      modsDirectory = Directory(p.join(gameDirectory.path, 'mods'));
      await modsDirectory.create();
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('reads normalized Fabric metadata', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'example.jar',
        <String, String>{
          'fabric.mod.json': jsonEncode(
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

      final MtnMinecraftInfoModMetadata? metadata =
          await provider.readModMetadata(mod);

      expect(metadata, isNotNull);
      expect(metadata!.type, MtnMinecraftInfoModMetadataType.fabric);
      expect(metadata.id, 'example_mod');
      expect(metadata.name, 'Example Mod');
      expect(metadata.version, '1.2.3');
      expect(metadata.description, 'Example description');
      expect(metadata.authors, <String>['Alice', 'Bob']);
      expect(
        () => metadata.authors.add('Carol'),
        throwsUnsupportedError,
      );
    });

    test('uses Fabric defaults for optional normalized metadata', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'minimal.jar',
        <String, String>{
          'fabric.mod.json': jsonEncode(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'minimal_mod',
              'version': '2.0.0',
            },
          ),
        },
      );

      final MtnMinecraftInfoModMetadata? metadata =
          await provider.readModMetadata(mod);

      expect(metadata, isNotNull);
      expect(metadata!.name, 'minimal_mod');
      expect(metadata.description, '');
      expect(metadata.authors, isEmpty);
    });

    test('JAR without root fabric.mod.json is not Fabric metadata', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'other.jar',
        <String, String>{
          'META-INF/example.txt': 'not Fabric metadata',
          'nested/fabric.mod.json': '{}',
        },
      );

      expect(await provider.readModMetadata(mod), isNull);
    });

    test('malformed JAR is invalid data', () async {
      final File file = File(p.join(modsDirectory.path, 'broken.jar'));
      await file.writeAsBytes(<int>[1, 2, 3, 4]);

      await _expectInvalidData(
        provider.readModMetadata(MtnMinecraftInfoMod(file: file)),
      );
    });

    test('malformed fabric.mod.json is invalid data', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'broken-json.jar',
        <String, String>{
          'fabric.mod.json': '{',
        },
      );

      await _expectInvalidData(provider.readModMetadata(mod));
    });

    test('unsupported Fabric schema version is invalid data', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'schema.jar',
        <String, String>{
          'fabric.mod.json': jsonEncode(
            <String, Object?>{
              'schemaVersion': 2,
              'id': 'example_mod',
              'version': '1.0.0',
            },
          ),
        },
      );

      await _expectInvalidData(provider.readModMetadata(mod));
    });

    test('missing required Fabric identity is invalid data', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'missing-id.jar',
        <String, String>{
          'fabric.mod.json': jsonEncode(
            <String, Object?>{
              'schemaVersion': 1,
              'version': '1.0.0',
            },
          ),
        },
      );

      await _expectInvalidData(provider.readModMetadata(mod));
    });

    test('invalid author entry is invalid data', () async {
      final MtnMinecraftInfoMod mod = await _writeJar(
        modsDirectory,
        'authors.jar',
        <String, String>{
          'fabric.mod.json': jsonEncode(
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

      await _expectInvalidData(provider.readModMetadata(mod));
    });

    test('metadata reader rejects files outside this profile mods directory', () async {
      final File file = File(p.join(gameDirectory.path, 'outside.jar'));
      await file.writeAsBytes(<int>[1]);

      await expectLater(
        provider.readModMetadata(MtnMinecraftInfoMod(file: file)),
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException error) => error.error,
            'error',
            MtnMinecraftInfoProviderError.invalidPath,
          ),
        ),
      );
    });
  });
}

Future<MtnMinecraftInfoMod> _writeJar(
  Directory modsDirectory,
  String fileName,
  Map<String, String> entries,
) async {
  final Archive archive = Archive();
  for (final MapEntry<String, String> entry in entries.entries) {
    archive.add(
      ArchiveFile.bytes(
        entry.key,
        utf8.encode(entry.value),
      ),
    );
  }

  final File file = File(p.join(modsDirectory.path, fileName));
  await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
  return MtnMinecraftInfoMod(file: file);
}

Future<void> _expectInvalidData(
  Future<MtnMinecraftInfoModMetadata?> future,
) async {
  await expectLater(
    future,
    throwsA(
      isA<MtnMinecraftInfoProviderException>().having(
        (MtnMinecraftInfoProviderException error) => error.error,
        'error',
        MtnMinecraftInfoProviderError.invalidData,
      ),
    ),
  );
}
