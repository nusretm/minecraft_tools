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
                    'homepage': 'https://example.com/bob',
                  },
                },
              ],
              'contributors': <Object?>[
                'Carol',
                <String, Object?>{
                  'name': 'Dave',
                },
              ],
              'contact': <String, String>{
                'homepage': 'https://modrinth.com/mod/example',
                'sources': 'https://github.com/example/example',
                'issues': 'https://github.com/example/example/issues',
                'email': 'ignored@example.com',
              },
              'license': <String>[
                'MIT',
                'Apache-2.0',
              ],
              'environment': 'client',
              'provides': <String>[
                'example_alias',
              ],
              'depends': <String, Object?>{
                'fabricloader': '>=0.19.0',
                'minecraft': <String>[
                  '26.1',
                  '26.1.1',
                ],
              },
              'recommends': <String, String>{
                'modmenu': '*',
              },
              'suggests': <String, String>{
                'rei': '>=20',
              },
              'conflicts': <String, String>{
                'conflicting_mod': '*',
              },
              'breaks': <String, String>{
                'broken_mod': '<2.0.0',
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
      expect(mod.contributors, <String>['Carol', 'Dave']);
      expect(mod.licenses, <String>['MIT', 'Apache-2.0']);
      expect(mod.urls.homepage, 'https://modrinth.com/mod/example');
      expect(mod.urls.source, 'https://github.com/example/example');
      expect(mod.urls.issues, 'https://github.com/example/example/issues');
      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isFalse);
      expect(mod.providedIds, <String>['example_alias']);
      expect(
        mod.dependencies,
        <MtnMinecraftInfoModDependency>[
          MtnMinecraftInfoModDependency(
            id: 'fabricloader',
            type: MtnMinecraftInfoModDependencyType.required,
            versionConstraints: <String>['>=0.19.0'],
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'minecraft',
            type: MtnMinecraftInfoModDependencyType.required,
            versionConstraints: <String>['26.1', '26.1.1'],
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'modmenu',
            type: MtnMinecraftInfoModDependencyType.recommended,
            versionConstraints: <String>['*'],
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'rei',
            type: MtnMinecraftInfoModDependencyType.suggested,
            versionConstraints: <String>['>=20'],
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'conflicting_mod',
            type: MtnMinecraftInfoModDependencyType.conflict,
            versionConstraints: <String>['*'],
            clientSide: true,
            serverSide: false,
          ),
          MtnMinecraftInfoModDependency(
            id: 'broken_mod',
            type: MtnMinecraftInfoModDependencyType.incompatible,
            versionConstraints: <String>['<2.0.0'],
            clientSide: true,
            serverSide: false,
          ),
        ],
      );
      expect(mod.parentMods, isEmpty);
      expect(mod.modTypes, isEmpty);
      expect(() => mod.authors.add('Carol'), throwsUnsupportedError);
      expect(() => mod.contributors.add('Eve'), throwsUnsupportedError);
      expect(() => mod.licenses.add('GPL-3.0'), throwsUnsupportedError);
      expect(() => mod.dependencies.clear(), throwsUnsupportedError);
      expect(() => mod.providedIds.clear(), throwsUnsupportedError);
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
      expect(mod.contributors, isEmpty);
      expect(mod.licenses, isEmpty);
      expect(mod.urls.isEmpty, isTrue);
      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
      expect(mod.dependencies, isEmpty);
      expect(mod.providedIds, isEmpty);
    });

    test('normalizes empty Fabric license metadata as unspecified', () async {
      final File emptyStringJar = await _writeJar(
        directory,
        'empty-license-string.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'empty_license_string',
              'version': '1',
              'license': '',
            },
          ),
        },
      );
      final File emptyEntriesJar = await _writeJar(
        directory,
        'empty-license-entries.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'empty_license_entries',
              'version': '1',
              'license': <String>[
                '',
                'MIT',
                '',
                'MIT',
              ],
            },
          ),
        },
      );

      expect(
        (await provider.parse(emptyStringJar))!.single.licenses,
        isEmpty,
      );
      expect(
        (await provider.parse(emptyEntriesJar))!.single.licenses,
        <String>['MIT'],
      );
    });

    test('normalizes empty Fabric people metadata as unspecified', () async {
      final File jar = await _writeJar(
        directory,
        'empty-people.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'empty_people',
              'version': '1',
              'authors': <Object?>[
                '',
                <String, Object?>{'name': ''},
                'Alice',
              ],
              'contributors': <Object?>[
                '',
                <String, Object?>{'name': ''},
                'Bob',
              ],
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.authors, <String>['Alice']);
      expect(mod.contributors, <String>['Bob']);
    });

    test('does not derive source URL from issue tracker metadata', () async {
      final File jar = await _writeJar(
        directory,
        'issues-only.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'issues_only',
              'version': '1',
              'contact': <String, String>{
                'issues': 'https://github.com/example/project/issues',
              },
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.urls.issues, 'https://github.com/example/project/issues');
      expect(mod.urls.source, isNull);
    });

    test('normalizes Fabric server-only environment', () async {
      final File jar = await _writeJar(
        directory,
        'server-only.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'server_only',
              'version': '1',
              'environment': 'server',
              'depends': <String, String>{
                'minecraft': '*',
              },
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.clientSide, isFalse);
      expect(mod.serverSide, isTrue);
      expect(mod.dependencies.single.clientSide, isFalse);
      expect(mod.dependencies.single.serverSide, isTrue);
    });

    test('accepts Fabric environment arrays and normalizes both sides', () async {
      final File jar = await _writeJar(
        directory,
        'both-sides.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'both_sides',
              'version': '1',
              'environment': <String>[
                'client',
                'server',
              ],
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
    });

    test('reads a single Fabric icon lazily', () async {
      final Uint8List icon = Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3],
      );
      final File jar = await _writeJar(
        directory,
        'icon.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'icon_mod',
              'version': '1',
              'icon': 'assets/icon_mod/icon.png',
            },
          ),
          'assets/icon_mod/icon.png': icon,
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.hasIcon, isTrue);
      expect(await mod.getIcon(), icon);
      expect(await mod.getIcon(size: 32), icon);
    });

    test('selects Fabric sized icons using loader preferred-size semantics', () async {
      final Uint8List icon16 = Uint8List.fromList(<int>[16]);
      final Uint8List icon64 = Uint8List.fromList(<int>[64]);
      final Uint8List icon256 = Uint8List.fromList(<int>[2, 5, 6]);
      final File jar = await _writeJar(
        directory,
        'sized-icons.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'sized_icon_mod',
              'version': '1',
              'icon': <String, String>{
                '16': 'assets/icon16.png',
                '64': 'assets/icon64.png',
                '256': 'assets/icon256.png',
              },
            },
          ),
          'assets/icon16.png': icon16,
          'assets/icon64.png': icon64,
          'assets/icon256.png': icon256,
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(await mod.getIcon(size: 16), icon16);
      expect(await mod.getIcon(size: 32), icon64);
      expect(await mod.getIcon(size: 128), icon256);
      expect(await mod.getIcon(size: 512), icon256);
    });

    test('missing declared icon is unavailable without invalidating the mod', () async {
      final File jar = await _writeJar(
        directory,
        'missing-icon.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'missing_icon_mod',
              'version': '1',
              'icon': 'assets/missing.png',
            },
          ),
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      expect(mod.hasIcon, isFalse);
      expect(await mod.getIcon(), isNull);
    });

    test('embedded mod icon remains readable after root parsing completes', () async {
      final Uint8List childIcon = Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 9, 8, 7],
      );
      final Uint8List child = _jarBytes(
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'child_with_icon',
              'version': '1',
              'icon': 'assets/child/icon.png',
            },
          ),
          'assets/child/icon.png': childIcon,
        },
      );
      final File rootJar = await _writeJar(
        directory,
        'root-with-icon-child.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'root_with_icon_child',
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
      final MtnMinecraftInfoMod childMod = mods.singleWhere(
        (MtnMinecraftInfoMod mod) => mod.id == 'child_with_icon',
      );

      expect(childMod.isEmbedded, isTrue);
      expect(childMod.hasIcon, isTrue);
      expect(await childMod.getIcon(), childIcon);
    });

    test('getIcon rejects non-positive preferred sizes', () async {
      final File jar = await _writeJar(
        directory,
        'icon-size.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'icon_size_mod',
              'version': '1',
              'icon': 'icon.png',
            },
          ),
          'icon.png': <int>[1],
        },
      );

      final MtnMinecraftInfoMod mod = (await provider.parse(jar))!.single;

      await expectLater(
        mod.getIcon(size: 0),
        throwsArgumentError,
      );
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

    test('malformed rich Fabric metadata is invalid data', () async {
      final File jar = await _writeJar(
        directory,
        'invalid-rich-metadata.jar',
        <String, List<int>>{
          'fabric.mod.json': _jsonBytes(
            <String, Object?>{
              'schemaVersion': 1,
              'id': 'invalid_rich_metadata',
              'version': '1',
              'depends': <String, Object?>{
                'minecraft': <Object?>['26.1', 26],
              },
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
