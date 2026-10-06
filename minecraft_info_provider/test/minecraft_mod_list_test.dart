import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftModList', () {
    test('offers one root JAR to every registered provider and merges mod types', () async {
      final List<String> calls = <String>[];
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _CallbackModInfoProvider(
            name: 'fabric',
            onParse: (File file) {
              calls.add('fabric');
              return <MtnMinecraftInfoMod>[
                MtnMinecraftInfoMod(
                  id: 'example',
                  name: 'Example',
                  version: '1.0.0',
                ),
              ];
            },
          ),
          _CallbackModInfoProvider(
            name: 'forge',
            onParse: (File file) {
              calls.add('forge');
              return <MtnMinecraftInfoMod>[
                MtnMinecraftInfoMod(
                  id: 'example',
                  name: 'Example',
                  version: '1.0.0',
                ),
              ];
            },
          ),
        ],
      );

      final File file = File(p.join(Directory.systemTemp.path, 'example.jar'));
      await list.add(file);

      expect(calls, <String>['fabric', 'forge']);
      expect(list.mods, hasLength(1));
      expect(list.mods.single.modTypes, <String>['fabric', 'forge']);
      expect(list.mods.single.isInstalled, isTrue);
      expect(list.mods.single.installedFiles, hasLength(1));
    });

    test('merges generic metadata from every provider without loader-specific core fields', () async {
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _CallbackModInfoProvider(
            name: 'fabric',
            onParse: (File file) => <MtnMinecraftInfoMod>[
              MtnMinecraftInfoMod(
                id: 'example',
                name: 'Example',
                version: '1.0.0',
                authors: <String>['Alice'],
                contributors: <String>['Carol'],
                licenses: <String>['MIT'],
                urls: const MtnMinecraftInfoModUrls(
                  homepage: 'https://modrinth.com/mod/example',
                  issues: 'https://github.com/example/example/issues',
                ),
                clientSide: true,
                serverSide: false,
                dependencies: <MtnMinecraftInfoModDependency>[
                  MtnMinecraftInfoModDependency(
                    id: 'minecraft',
                    type: MtnMinecraftInfoModDependencyType.requiredDependency,
                    versionConstraints: <String>['~26.3'],
                    clientSide: true,
                    serverSide: false,
                  ),
                ],
                providedIds: <String>['example_alias'],
              ),
            ],
          ),
          _CallbackModInfoProvider(
            name: 'forge',
            onParse: (File file) => <MtnMinecraftInfoMod>[
              MtnMinecraftInfoMod(
                id: 'example',
                name: 'Example',
                version: '1.0.0',
                authors: <String>['Bob'],
                contributors: <String>['Dave'],
                licenses: <String>['Apache-2.0'],
                urls: const MtnMinecraftInfoModUrls(
                  source: 'https://github.com/example/example',
                ),
                clientSide: false,
                serverSide: true,
                dependencies: <MtnMinecraftInfoModDependency>[
                  MtnMinecraftInfoModDependency(
                    id: 'forge',
                    type: MtnMinecraftInfoModDependencyType.requiredDependency,
                    versionConstraints: <String>['[47,)'],
                    clientSide: false,
                    serverSide: true,
                  ),
                ],
                providedIds: <String>['example_legacy'],
              ),
            ],
          ),
        ],
      );

      await list.add(File(p.join(Directory.systemTemp.path, 'example.jar')));

      final MtnMinecraftInfoMod mod = list.mods.single;
      expect(mod.authors, <String>['Alice', 'Bob']);
      expect(mod.contributors, <String>['Carol', 'Dave']);
      expect(mod.licenses, <String>['MIT', 'Apache-2.0']);
      expect(mod.urls.homepage, 'https://modrinth.com/mod/example');
      expect(mod.urls.source, 'https://github.com/example/example');
      expect(mod.urls.issues, 'https://github.com/example/example/issues');
      expect(mod.clientSide, isTrue);
      expect(mod.serverSide, isTrue);
      expect(mod.dependencies, hasLength(2));
      expect(mod.providedIds, <String>['example_alias', 'example_legacy']);
      expect(mod.modTypes, <String>['fabric', 'forge']);
    });

    test('merges the same embedded mod and preserves every parent', () async {
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _DependencyGraphModInfoProvider(),
        ],
      );

      final File first = File(p.join(Directory.systemTemp.path, 'first.jar'));
      final File second = File(p.join(Directory.systemTemp.path, 'second.jar'));

      await list.add(first);
      await list.add(second);

      final MtnMinecraftInfoMod dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependency.isInstalled, isFalse);
      expect(dependency.isEmbedded, isTrue);
      expect(
        dependency.parentMods.map((MtnMinecraftInfoMod mod) => mod.id).toSet(),
        <String>{'first', 'second'},
      );

      final MtnMinecraftInfoMod firstMod =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'first');
      expect(
        list.getDependencyList(firstMod).map((MtnMinecraftInfoMod mod) => mod.id),
        <String>['shared'],
      );
    });

    test('remove keeps a shared dependency until its last parent disappears', () async {
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _DependencyGraphModInfoProvider(),
        ],
      );
      final File first = File(p.join(Directory.systemTemp.path, 'first.jar'));
      final File second = File(p.join(Directory.systemTemp.path, 'second.jar'));

      await list.add(first);
      await list.add(second);

      final MtnMinecraftInfoMod firstMod =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'first');
      expect(list.remove(firstMod), isTrue);

      final MtnMinecraftInfoMod dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(
        dependency.parentMods.map((MtnMinecraftInfoMod mod) => mod.id),
        <String>['second'],
      );

      final MtnMinecraftInfoMod secondMod =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'second');
      expect(list.remove(secondMod), isTrue);
      expect(list.mods, isEmpty);
    });

    test('remove keeps an embedded dependency that is also directly installed', () async {
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _DependencyGraphModInfoProvider(),
        ],
      );
      final File parent = File(p.join(Directory.systemTemp.path, 'first.jar'));
      final File dependencyFile =
          File(p.join(Directory.systemTemp.path, 'shared.jar'));

      await list.add(parent);
      await list.add(dependencyFile);

      final MtnMinecraftInfoMod dependencyBefore =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependencyBefore.isInstalled, isTrue);
      expect(dependencyBefore.isEmbedded, isTrue);

      final MtnMinecraftInfoMod parentMod =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'first');
      expect(list.remove(parentMod), isTrue);

      final MtnMinecraftInfoMod dependencyAfter =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependencyAfter.isInstalled, isTrue);
      expect(dependencyAfter.isEmbedded, isFalse);
      expect(dependencyAfter.installedFiles.single.path, dependencyFile.path);
    });

    test('remove rejects an embedded-only mod', () async {
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _DependencyGraphModInfoProvider(),
        ],
      );
      final File parent = File(p.join(Directory.systemTemp.path, 'first.jar'));

      await list.add(parent);

      final MtnMinecraftInfoMod dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependency.isEmbedded, isTrue);
      expect(dependency.isInstalled, isFalse);

      expect(list.remove(dependency), isFalse);
      expect(list.mods, hasLength(2));
      expect(
        list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared').parentMods,
        hasLength(1),
      );
    });

    test('onItem emits add update and remove for normalized list changes', () async {
      final List<String> events = <String>[];
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _DependencyGraphModInfoProvider(),
        ],
        onItem: (
          MtnMinecraftModList list,
          MtnMinecraftInfoMod mod,
          MtnListEvent event,
        ) {
          events.add('${event.name}:${mod.id}@${mod.version}');
        },
      );

      final File first = File(p.join(Directory.systemTemp.path, 'first.jar'));
      final File second = File(p.join(Directory.systemTemp.path, 'second.jar'));

      await list.add(first);
      expect(
        events,
        <String>[
          'add:first@1',
          'add:shared@1',
        ],
      );

      events.clear();
      await list.add(second);
      expect(events, contains('add:second@1'));
      expect(events, contains('update:shared@1'));

      events.clear();
      final MtnMinecraftInfoMod firstMod =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'first');
      expect(list.remove(firstMod), isTrue);
      expect(events, contains('remove:first@1'));
      expect(events, contains('update:shared@1'));

      events.clear();
      list.clear();
      expect(events, contains('remove:second@1'));
      expect(events, contains('remove:shared@1'));
    });

    test('normalized list preserves provider-backed lazy icon access', () async {
      final Uint8List icon = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[
          _CallbackModInfoProvider(
            name: 'fabric',
            onParse: (File file) => <MtnMinecraftInfoMod>[
              MtnMinecraftInfoMod(
                id: 'icon_mod',
                name: 'Icon Mod',
                version: '1',
                iconLoaders: <MtnMinecraftInfoModIconLoader>[
                  (int size) async => icon,
                ],
              ),
            ],
          ),
        ],
      );

      await list.add(File(p.join(Directory.systemTemp.path, 'icon-mod.jar')));

      final MtnMinecraftInfoMod mod = list.mods.single;
      expect(mod.hasIcon, isTrue);
      expect(await mod.getIcon(), icon);
    });

    test('unregister removes that provider contribution from existing roots', () async {
      final _CallbackModInfoProvider fabric = _CallbackModInfoProvider(
        name: 'fabric',
        onParse: (File file) => <MtnMinecraftInfoMod>[
          MtnMinecraftInfoMod(
            id: 'example',
            name: 'Example',
            version: '1',
          ),
        ],
      );
      final _CallbackModInfoProvider forge = _CallbackModInfoProvider(
        name: 'forge',
        onParse: (File file) => <MtnMinecraftInfoMod>[
          MtnMinecraftInfoMod(
            id: 'example',
            name: 'Example',
            version: '1',
          ),
        ],
      );
      final MtnMinecraftModList list = MtnMinecraftModList(
        providers: <MtnMinecraftModInfoProvider>[fabric, forge],
      );

      await list.add(File(p.join(Directory.systemTemp.path, 'example.jar')));
      expect(list.mods.single.modTypes, <String>['fabric', 'forge']);

      expect(list.unregister(forge), isTrue);
      expect(list.mods.single.modTypes, <String>['fabric']);
    });

    test('rejects duplicate provider names', () {
      final MtnMinecraftModList list = MtnMinecraftModList();
      list.register(
        _CallbackModInfoProvider(
          name: 'fabric',
          onParse: (File file) => null,
        ),
      );

      expect(
        () => list.register(
          _CallbackModInfoProvider(
            name: 'fabric',
            onParse: (File file) => null,
          ),
        ),
        throwsStateError,
      );
    });
  });
}

typedef _ParseCallback = List<MtnMinecraftInfoMod>? Function(File file);

final class _CallbackModInfoProvider
    extends MtnMinecraftModInfoProvider {
  const _CallbackModInfoProvider({
    required this.name,
    required this.onParse,
  });

  @override
  final String name;
  final _ParseCallback onParse;

  @override
  Future<List<MtnMinecraftInfoMod>?> parse(File jarFile) async =>
      onParse(jarFile);

  @override
  Future<List<MtnMinecraftInfoMod>?> parseJarContent(
    Uint8List content, {
    MtnMinecraftInfoMod? parentMod,
  }) async =>
      null;
}

final class _DependencyGraphModInfoProvider
    extends MtnMinecraftModInfoProvider {
  @override
  String get name => 'fabric';

  @override
  Future<List<MtnMinecraftInfoMod>?> parse(File jarFile) async {
    final String id = p.basenameWithoutExtension(jarFile.path);
    if (id == 'shared') {
      return <MtnMinecraftInfoMod>[
        MtnMinecraftInfoMod(
          id: 'shared',
          name: 'Shared',
          version: '1',
        ),
      ];
    }

    final MtnMinecraftInfoMod parent = MtnMinecraftInfoMod(
      id: id,
      name: id,
      version: '1',
    );
    final MtnMinecraftInfoMod dependency = MtnMinecraftInfoMod(
      id: 'shared',
      name: 'Shared',
      version: '1',
      parentMods: <MtnMinecraftInfoMod>[parent],
    );
    return <MtnMinecraftInfoMod>[parent, dependency];
  }

  @override
  Future<List<MtnMinecraftInfoMod>?> parseJarContent(
    Uint8List content, {
    MtnMinecraftInfoMod? parentMod,
  }) async =>
      null;
}
