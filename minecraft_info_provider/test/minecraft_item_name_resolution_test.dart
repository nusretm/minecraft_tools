import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('item name resolution foundation', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-item-name-',
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('parses item identity and derives conventional translation keys', () {
      final MtnMinecraftInfoItemIdentity identity =
          MtnMinecraftInfoItemIdentity.parse(
        'example:tools/iron_hammer',
      );

      expect(identity.id, 'example:tools/iron_hammer');
      expect(identity.namespace, 'example');
      expect(identity.path, 'tools/iron_hammer');
      expect(identity.translationPath, 'tools.iron_hammer');
      expect(
        identity.itemTranslationKey,
        'item.example.tools.iron_hammer',
      );
      expect(
        identity.blockTranslationKey,
        'block.example.tools.iron_hammer',
      );
      expect(
        identity.conventionalTranslationKeys,
        <String>[
          'item.example.tools.iron_hammer',
          'block.example.tools.iron_hammer',
        ],
      );
    });

    test('rejects malformed or non-namespaced item identities', () {
      for (final String id in <String>[
        '',
        'stone',
        ' example:stone',
        'example:stone ',
        ':stone',
        'example:',
        'example:one:two',
        'Example:stone',
        'example:Stone',
        'example:bad path',
      ]) {
        expect(
          () => MtnMinecraftInfoItemIdentity.parse(id),
          throwsArgumentError,
          reason: id,
        );
      }
    });

    test('resolves conventional item translation key', () async {
      final File jar = await _writeFabricJar(
        directory,
        'item.jar',
        id: 'example_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            '{"item.example.widget":"Widget"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final List<MtnMinecraftInfoItemName> names =
          await MtnMinecraftInfoItemNameResolver(
        modList: list,
      ).resolve('example:widget');

      expect(names, hasLength(1));
      final MtnMinecraftInfoItemName name = names.single;
      expect(name.itemId, 'example:widget');
      expect(name.kind, MtnMinecraftInfoItemNameKind.item);
      expect(name.translationKey, 'item.example.widget');
      expect(name.value, 'Widget');
      expect(name.locale, 'en_us');
      expect(name.languageNamespace, 'example');
      expect(
        name.source.rootFile?.path,
        p.normalize(p.absolute(jar.path)),
      );
    });

    test('resolves conventional block translation key for block items',
        () async {
      final File jar = await _writeFabricJar(
        directory,
        'block-item.jar',
        id: 'example_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            '{"block.example.machine":"Machine"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final List<MtnMinecraftInfoItemName> names =
          await MtnMinecraftInfoItemNameResolver(
        modList: list,
      ).resolve('example:machine');

      expect(names, hasLength(1));
      expect(names.single.kind, MtnMinecraftInfoItemNameKind.block);
      expect(names.single.translationKey, 'block.example.machine');
      expect(names.single.value, 'Machine');
    });

    test('preserves item and block candidates without choosing a winner',
        () async {
      final File jar = await _writeFabricJar(
        directory,
        'both.jar',
        id: 'example_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            jsonEncode(
              <String, String>{
                'item.example.shared': 'Item Name',
                'block.example.shared': 'Block Name',
              },
            ),
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final List<MtnMinecraftInfoItemName> names =
          await MtnMinecraftInfoItemNameResolver(
        modList: list,
      ).resolve('example:shared');

      expect(names, hasLength(2));
      expect(
        names.map((MtnMinecraftInfoItemName item) => item.kind).toSet(),
        <MtnMinecraftInfoItemNameKind>{
          MtnMinecraftInfoItemNameKind.item,
          MtnMinecraftInfoItemNameKind.block,
        },
      );
      expect(
        names.map((MtnMinecraftInfoItemName item) => item.value).toSet(),
        <String>{'Item Name', 'Block Name'},
      );
    });

    test('searches language resources across asset namespaces', () async {
      final File jar = await _writeFabricJar(
        directory,
        'cross-namespace.jar',
        id: 'example_mod',
        entries: <String, List<int>>{
          'assets/translations/lang/en_us.json': utf8.encode(
            '{"item.example.cross_namespace":"Cross Namespace"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final List<MtnMinecraftInfoItemName> names =
          await MtnMinecraftInfoItemNameResolver(
        modList: list,
      ).resolve('example:cross_namespace');

      expect(names, hasLength(1));
      expect(names.single.value, 'Cross Namespace');
      expect(names.single.languageNamespace, 'translations');
    });

    test('preserves duplicate conventional names from multiple sources',
        () async {
      final File first = await _writeFabricJar(
        directory,
        'first.jar',
        id: 'first_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            '{"item.example.widget":"First Widget"}',
          ),
        },
      );
      final File second = await _writeFabricJar(
        directory,
        'second.jar',
        id: 'second_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            '{"item.example.widget":"Second Widget"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(first);
      await list.add(second);

      final List<MtnMinecraftInfoItemName> names =
          await MtnMinecraftInfoItemNameResolver(
        modList: list,
      ).resolve('example:widget');

      expect(names, hasLength(2));
      expect(
        names.map((MtnMinecraftInfoItemName item) => item.value).toSet(),
        <String>{'First Widget', 'Second Widget'},
      );
    });

    test('uses exact locale and does not guess custom description ids',
        () async {
      final File jar = await _writeFabricJar(
        directory,
        'exact.jar',
        id: 'example_mod',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            jsonEncode(
              <String, String>{
                'item.example.widget': 'English Widget',
                'example.custom.widget_name': 'Custom Runtime Name',
              },
            ),
          ),
          'assets/example/lang/tr_tr.json': utf8.encode(
            '{"example.custom.widget_name":"Özel Çalışma Zamanı Adı"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);
      final MtnMinecraftInfoItemNameResolver resolver =
          MtnMinecraftInfoItemNameResolver(modList: list);

      expect(
        await resolver.resolve(
          'example:widget',
          locale: 'tr_tr',
        ),
        isEmpty,
      );

      final List<MtnMinecraftInfoItemName> english =
          await resolver.resolve('example:widget');
      expect(english, hasLength(1));
      expect(english.single.value, 'English Widget');
    });
  });
}

MtnMinecraftModList _fabricList() => MtnMinecraftModList(
      providers: const <MtnMinecraftModInfoProvider>[
        MtnMinecraftModInfoProviderFabric(),
      ],
    );

Future<File> _writeFabricJar(
  Directory directory,
  String fileName, {
  required String id,
  Map<String, List<int>> entries = const <String, List<int>>{},
}) async {
  final File file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    _fabricJarBytes(
      id: id,
      entries: entries,
    ),
  );
  return file;
}

Uint8List _fabricJarBytes({
  required String id,
  Map<String, List<int>> entries = const <String, List<int>>{},
}) {
  final Archive archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'fabric.mod.json',
        utf8.encode(
          jsonEncode(
            <String, Object?>{
              'schemaVersion': 1,
              'id': id,
              'version': '1',
            },
          ),
        ),
      ),
    );

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
