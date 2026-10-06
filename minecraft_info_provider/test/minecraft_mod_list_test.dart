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

      expect(list.remove(first), isTrue);
      MtnMinecraftInfoMod dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(
        dependency.parentMods.map((MtnMinecraftInfoMod mod) => mod.id),
        <String>['second'],
      );

      expect(list.remove(second), isTrue);
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

      MtnMinecraftInfoMod dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependency.isInstalled, isTrue);
      expect(dependency.isEmbedded, isTrue);

      list.remove(parent);

      dependency =
          list.mods.singleWhere((MtnMinecraftInfoMod mod) => mod.id == 'shared');
      expect(dependency.isInstalled, isTrue);
      expect(dependency.isEmbedded, isFalse);
      expect(dependency.installedFiles.single.path, dependencyFile.path);
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
