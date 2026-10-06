import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('NeoForge mod info provider', () {
    late Directory directory;
    late MtnMinecraftModInfoProviderNeoForge provider;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-neoforge-provider-',
      );
      provider = const MtnMinecraftModInfoProviderNeoForge();
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('reads normalized NeoForge mod info', () async {
      final Uint8List icon = Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3],
      );
      final File jar = await _writeJar(
        directory,
        'example.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
modLoader = "javafml"
loaderVersion = "[1,)"
license = "MIT"
issueTrackerURL = "https://github.com/example/example/issues"

[[mods]]
modId = "example_mod"
version = "1.2.3"
displayName = "Example Mod"
authors = "Alice"
description = """Example description"""
displayURL = "https://modrinth.com/mod/example"
iconFile = "example_icon.png"

[[dependencies.example_mod]]
modId = "neoforge"
type = "required"
versionRange = "[26.3,)"
ordering = "NONE"
side = "CLIENT"

[[dependencies.example_mod]]
modId = "optional_mod"
type = "optional"
versionRange = ""
ordering = "AFTER"
side = "SERVER"

[[dependencies.example_mod]]
modId = "bad_mod"
type = "incompatible"
versionRange = "[2,)"
ordering = "BEFORE"
side = "BOTH"

[[dependencies.example_mod]]
modId = "warning_mod"
type = "discouraged"
versionRange = "[3,)"
ordering = "NONE"
side = "BOTH"
''',
          ),
          'example_icon.png': icon,
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
      expect(mod.licenses, <String>['MIT']);
      expect(mod.urls.homepage, 'https://modrinth.com/mod/example');
      expect(mod.urls.source, isNull);
      expect(mod.urls.issues, 'https://github.com/example/example/issues');
      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
      expect(mod.hasIcon, isTrue);
      expect(await mod.getIcon(), icon);
      expect(
        mod.dependencies.map(
          (MtnMinecraftInfoModDependency dependency) => dependency.type,
        ),
        <MtnMinecraftInfoModDependencyType>[
          MtnMinecraftInfoModDependencyType.required,
          MtnMinecraftInfoModDependencyType.optional,
          MtnMinecraftInfoModDependencyType.incompatible,
          MtnMinecraftInfoModDependencyType.discouraged,
        ],
      );
      expect(mod.dependencies[0].clientSide, isTrue);
      expect(mod.dependencies[0].serverSide, isFalse);
      expect(
        mod.dependencies[1].ordering,
        MtnMinecraftInfoModDependencyOrdering.after,
      );
      expect(
        mod.dependencies[2].ordering,
        MtnMinecraftInfoModDependencyOrdering.before,
      );
    });

    test('uses NeoForge dependency defaults', () async {
      final File jar = await _writeJar(
        directory,
        'defaults.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "defaults"
version = "1"

[[dependencies.defaults]]
modId = "minecraft"
''',
          ),
        },
      );

      final MtnMinecraftInfoModDependency dependency =
          (await provider.parse(jar))!.single.dependencies.single;

      expect(dependency.type, MtnMinecraftInfoModDependencyType.required);
      expect(dependency.versionConstraints, isEmpty);
      expect(
        dependency.ordering,
        MtnMinecraftInfoModDependencyOrdering.none,
      );
      expect(dependency.clientSide, isTrue);
      expect(dependency.serverSide, isTrue);
    });

    test('does not infer mod side from dependency side', () async {
      final File jar = await _writeJar(
        directory,
        'dependency-side.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "dependency_side"
version = "1"

[[dependencies.dependency_side]]
modId = "minecraft"
type = "required"
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

    test('prefers mod iconFile over file-level iconFile', () async {
      final Uint8List fileIcon = Uint8List.fromList(<int>[1]);
      final Uint8List modIcon = Uint8List.fromList(<int>[2]);
      final File jar = await _writeJar(
        directory,
        'icon-precedence.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"
iconFile = "file.png"

[[mods]]
modId = "icon_precedence"
version = "1"
iconFile = "mod.png"
''',
          ),
          'file.png': fileIcon,
          'mod.png': modIcon,
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(await mod.getIcon(), modIcon);
    });

    test('uses file-level iconFile fallback', () async {
      final Uint8List icon = Uint8List.fromList(<int>[3]);
      final File jar = await _writeJar(
        directory,
        'file-icon.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"
iconFile = "file.png"

[[mods]]
modId = "file_icon"
version = "1"
''',
          ),
          'file.png': icon,
        },
      );

      expect(await (await provider.parse(jar))!.single.getIcon(), icon);
    });

    test('does not reinterpret NeoForge logoFile as iconFile', () async {
      final File jar = await _writeJar(
        directory,
        'logo-file.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "logo_file"
version = "1"
logoFile = "logo.png"
''',
          ),
          'logo.png': <int>[4],
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.hasIcon, isFalse);
      expect(await mod.getIcon(), isNull);
    });

    test('resolves NeoForge file version substitutions', () async {
      final File jar = await _writeJar(
        directory,
        'versions.jar',
        <String, List<int>>{
          'META-INF/MANIFEST.MF': utf8.encode(
            'Manifest-Version: 1.0\r\n'
            'Implementation-Version: 9.8.7\r\n'
            '\r\n',
          ),
          'META-INF/neoforge.mods.toml': utf8.encode(
            r'''
license = "MIT"
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

      expect(mods[0].version, '9.8.7');
      expect(mods[1].version, '2.4.6');
    });

    test('missing declared icon does not invalidate metadata', () async {
      final File jar = await _writeJar(
        directory,
        'missing-icon.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "missing_icon"
version = "1"
iconFile = "missing.png"
''',
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.hasIcon, isFalse);
      expect(await mod.getIcon(), isNull);
    });

    test('parses declared NeoForge JarJar mods recursively', () async {
      final Uint8List grandchild = _jarBytes(
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "grandchild"
version = "1"
''',
          ),
        },
      );
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

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
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

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
      expect(mods[1].parentMods, <MtnMinecraftInfoMod>[mods[0]]);
      expect(mods[2].parentMods, <MtnMinecraftInfoMod>[mods[1]]);
    });

    test('embedded NeoForge icon remains readable after parsing', () async {
      final Uint8List icon = Uint8List.fromList(<int>[5, 6, 7]);
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "child_icon"
version = "1"
iconFile = "child.png"
''',
          ),
          'child.png': icon,
        },
      );
      final File root = await _writeJar(
        directory,
        'root-icon.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "root_icon"
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
        (MtnMinecraftInfoMod mod) => mod.id == 'child_icon',
      );

      expect(await childMod.getIcon(), icon);
    });

    test('JarJar libraries without NeoForge metadata are ignored', () async {
      final Uint8List library = _jarBytes(
        <String, List<int>>{
          'META-INF/library.txt': utf8.encode('library only'),
        },
      );
      final File root = await _writeJar(
        directory,
        'root-library.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "root"
version = "1"
''',
          ),
          'META-INF/jarjar/metadata.json': _jsonBytes(
            <String, Object?>{
              'jars': <Object?>[
                <String, Object?>{
                  'path': 'META-INF/jars/library.jar',
                },
              ],
            },
          ),
          'META-INF/jars/library.jar': library,
        },
      );

      final List<MtnMinecraftInfoMod> mods =
          (await provider.parse(root))!;

      expect(mods, hasLength(1));
      expect(mods.single.id, 'root');
    });

    test('JAR without root neoforge.mods.toml is not a NeoForge result', () async {
      final File jar = await _writeJar(
        directory,
        'other.jar',
        <String, List<int>>{
          'META-INF/mods.toml': utf8.encode(
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

    test('malformed neoforge.mods.toml is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'broken-toml.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '[[mods]',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('missing mandatory NeoForge license is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'missing-license.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
[[mods]]
modId = "missing_license"
version = "1"
''',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('missing NeoForge mod identity is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'missing-id.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
version = "1"
''',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('unknown NeoForge dependency type is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'unknown-type.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

[[mods]]
modId = "unknown_type"
version = "1"

[[dependencies.unknown_type]]
modId = "minecraft"
type = "mystery"
''',
          ),
        },
      );

      await _expectInvalidData(provider.parse(jar));
    });

    test('declared NeoForge JarJar file must exist', () async {
      final File jar = await _writeJar(
        directory,
        'missing-embedded.jar',
        <String, List<int>>{
          'META-INF/neoforge.mods.toml': utf8.encode(
            '''
license = "MIT"

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
