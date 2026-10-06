import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Forge mod info provider', () {
    late Directory directory;
    late MtnMinecraftModInfoProviderForge provider;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-forge-provider-',
      );
      provider = const MtnMinecraftModInfoProviderForge();
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('reads normalized Forge mod info', () async {
      final Uint8List logo = Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3],
      );
      final File jar = await _writeJar(
        directory,
        'example.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"
loaderVersion = "[47,)"
license = "MIT"
issueTrackerURL = "https://github.com/example/example/issues"

[[mods]]
modId = "example_mod"
version = "1.2.3"
displayName = "Example Mod"
authors = "Alice"
description = """Example description"""
displayURL = "https://modrinth.com/mod/example"
logoFile = "example_logo.png"
displayTest = "MATCH_VERSION"

[[dependencies.example_mod]]
modId = "forge"
mandatory = true
versionRange = "[47,)"
ordering = "BEFORE"
side = "CLIENT"

[[dependencies.example_mod]]
modId = "optional_mod"
mandatory = false
versionRange = ""
ordering = "AFTER"
side = "SERVER"
''',
          ),
          'example_logo.png': logo,
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
      expect(mod.authors, <String>['Alice']);
      expect(mod.contributors, isEmpty);
      expect(mod.licenses, <String>['MIT']);
      expect(mod.urls.homepage, 'https://modrinth.com/mod/example');
      expect(mod.urls.source, isNull);
      expect(mod.urls.issues, 'https://github.com/example/example/issues');
      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
      expect(mod.hasIcon, isTrue);
      expect(await mod.getIcon(), logo);
      expect(
        mod.dependencies,
        <MtnMinecraftInfoModDependency>[
          MtnMinecraftInfoModDependency(
            id: 'forge',
            type: MtnMinecraftInfoModDependencyType.required,
            versionConstraints: <String>['[47,)'],
            ordering: MtnMinecraftInfoModDependencyOrdering.before,
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'optional_mod',
            type: MtnMinecraftInfoModDependencyType.optional,
            ordering: MtnMinecraftInfoModDependencyOrdering.after,
            clientSide: false,
            serverSide: true,
          ),
        ],
      );
    });

    test('does not infer mod side from dependency side', () async {
      final File jar = await _writeJar(
        directory,
        'dependency-side.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "dependency_side"
version = "1"

[[dependencies.dependency_side]]
modId = "minecraft"
mandatory = true
versionRange = "[1.20.1]"
ordering = "NONE"
side = "CLIENT"
''',
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
      expect(mod.dependencies.single.clientSide, isTrue);
      expect(mod.dependencies.single.serverSide, isFalse);
    });

    test('does not infer mod side from Forge displayTest', () async {
      final File jar = await _writeJar(
        directory,
        'display-tests.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "ignore_all"
version = "1"
displayTest = "IGNORE_ALL_VERSION"

[[mods]]
modId = "ignore_server"
version = "1"
displayTest = "IGNORE_SERVER_VERSION"

[[mods]]
modId = "custom_test"
version = "1"
displayTest = "NONE"
''',
          ),
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(jar))!;

      for (final MtnMinecraftInfoMod mod in mods) {
        expect(mod.clientSide, isTrue);
        expect(mod.serverSide, isTrue);
      }
    });

    test('file-level clientSideOnly marks every declared mod client-only', () async {
      final File jar = await _writeJar(
        directory,
        'client-side-only.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"
clientSideOnly = true

[[mods]]
modId = "first"
version = "1"

[[mods]]
modId = "second"
version = "1"
displayTest = "MATCH_VERSION"
''',
          ),
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(jar))!;

      for (final MtnMinecraftInfoMod mod in mods) {
        expect(mod.clientSide, isTrue);
        expect(mod.serverSide, isFalse);
      }
    });

    test('resolves Forge file version substitutions from manifest and properties', () async {
      final File jar = await _writeJar(
        directory,
        'versions.jar',
        <String, List<int>>{
          'META-INF/MANIFEST.MF': utf8.encode(
            'Manifest-Version: 1.0\r\n'
            'Implementation-Version: 9.8.7\r\n'
            '\r\n',
          ),
          'META-INF/mods.toml': utf8.encode(
            r'''
modLoader = "javafml"
properties = { declared = "2.4.6" }

[[mods]]
modId = "manifest_version"
version = "${file.jarVersion}"

[[mods]]
modId = "property_version"
version = "${file.declared}"
''',
          ),
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(jar))!;

      expect(
        mods.singleWhere(
          (MtnMinecraftInfoMod mod) => mod.id == 'manifest_version',
        ).version,
        '9.8.7',
      );
      expect(
        mods.singleWhere(
          (MtnMinecraftInfoMod mod) => mod.id == 'property_version',
        ).version,
        '2.4.6',
      );
    });

    test('missing declared logo does not invalidate Forge mod metadata', () async {
      final File jar = await _writeJar(
        directory,
        'missing-logo.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "missing_logo"
version = "1"
logoFile = "missing.png"
''',
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.hasIcon, isFalse);
      expect(await mod.getIcon(), isNull);
    });

    test('parses declared Forge JarJar mods recursively in memory', () async {
      final Uint8List grandchild = _jarBytes(
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "grandchild"
version = "1"
''',
          ),
        },
      );
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "child"
version = "1"
''',
          ),
          'META-INF/jarjar/metadata.json': _jsonBytes(
            <String, Object?>{
              'jars': <Object?>[
                <String, Object?>{
                  'path': 'META-INF/jars/grandchild.jar',
                },
              ],
            },
          ),
          'META-INF/jars/grandchild.jar': grandchild,
        },
      );
      final File root = await _writeJar(
        directory,
        'root.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "root"
version = "1"
''',
          ),
          'META-INF/jarjar/metadata.json': _jsonBytes(
            <String, Object?>{
              'jars': <Object?>[
                <String, Object?>{
                  'path': 'META-INF/jars/child.jar',
                },
              ],
            },
          ),
          'META-INF/jars/child.jar': child,
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(root))!;

      expect(
        mods.map((MtnMinecraftInfoMod mod) => mod.id),
        <String>['root', 'child', 'grandchild'],
      );

      final MtnMinecraftInfoMod rootMod = mods[0];
      final MtnMinecraftInfoMod childMod = mods[1];
      final MtnMinecraftInfoMod grandchildMod = mods[2];
      expect(childMod.parentMods, <MtnMinecraftInfoMod>[rootMod]);
      expect(
        grandchildMod.parentMods,
        <MtnMinecraftInfoMod>[childMod],
      );
    });

    test('embedded Forge logo remains readable after parsing completes', () async {
      final Uint8List icon = Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 9, 8, 7],
      );
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "child_with_logo"
version = "1"
logoFile = "child.png"
''',
          ),
          'child.png': icon,
        },
      );
      final File root = await _writeJar(
        directory,
        'root-with-icon.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "root_with_icon"
version = "1"
''',
          ),
          'META-INF/jarjar/metadata.json': _jsonBytes(
            <String, Object?>{
              'jars': <Object?>[
                <String, Object?>{
                  'path': 'META-INF/jars/child.jar',
                },
              ],
            },
          ),
          'META-INF/jars/child.jar': child,
        },
      );

      final MtnMinecraftInfoMod childMod =
          (await provider.parse(root))!.singleWhere(
        (MtnMinecraftInfoMod mod) => mod.id == 'child_with_logo',
      );

      expect(childMod.hasIcon, isTrue);
      expect(await childMod.getIcon(), icon);
    });

    test('JAR without root META-INF/mods.toml is not a Forge result', () async {
      final File jar = await _writeJar(
        directory,
        'other.jar',
        <String, List<int>>{
          'nested/META-INF/mods.toml': utf8.encode(
            'modLoader = "javafml"',
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

    test('malformed mods.toml is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'broken-toml.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '[[mods]',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('missing Forge mod identity is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'missing-id.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
version = "1"
''',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('malformed Forge dependency is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'broken-dependency.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "broken_dependency"
version = "1"

[[dependencies.broken_dependency]]
modId = "minecraft"
versionRange = "[1.20.1]"
''',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('declared Forge JarJar file must exist', () async {
      final File jar = await _writeJar(
        directory,
        'missing-embedded.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
            '''
modLoader = "javafml"

[[mods]]
modId = "root"
version = "1"
''',
          ),
          'META-INF/jarjar/metadata.json': _jsonBytes(
            <String, Object?>{
              'jars': <Object?>[
                <String, Object?>{
                  'path': 'META-INF/jars/missing.jar',
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
