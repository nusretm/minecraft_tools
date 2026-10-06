import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('mod language translation foundation', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-mod-language-',
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('reads one exact locale and preserves translation metadata', () async {
      final File jar = await _writeFabricJar(
        directory,
        'example.jar',
        id: 'example_mod',
        version: '1',
        entries: <String, List<int>>{
          'assets/example/lang/en_us.json': utf8.encode(
            jsonEncode(
              <String, String>{
                'item.example.widget': 'Widget',
              },
            ),
          ),
          'assets/example/lang/tr_tr.json': utf8.encode(
            jsonEncode(
              <String, String>{
                'item.example.widget': 'Parça',
                'tooltip.example.widget': 'Açıklama',
              },
            ),
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final List<MtnMinecraftInfoModLanguage> languages =
          await list.readLanguages(
        'example',
        locale: 'tr_tr',
      );

      expect(languages, hasLength(1));
      final MtnMinecraftInfoModLanguage language = languages.single;
      expect(language.namespace, 'example');
      expect(language.locale, 'tr_tr');
      expect(language['item.example.widget'], 'Parça');
      expect(language['tooltip.example.widget'], 'Açıklama');
      expect(language.contains('missing'), isFalse);
      expect(
        language.source.rootFile?.path,
        p.normalize(p.absolute(jar.path)),
      );

      final MtnMinecraftInfoModTranslation? translation =
          language.translation('item.example.widget');
      expect(translation, isNotNull);
      expect(translation!.namespace, 'example');
      expect(translation.locale, 'tr_tr');
      expect(translation.key, 'item.example.widget');
      expect(translation.value, 'Parça');
      expect(identical(translation.source, language.source), isTrue);

      expect(
        () => language.translations['new.key'] = 'New value',
        throwsUnsupportedError,
      );
    });

    test('does not apply implicit en_us fallback', () async {
      final File jar = await _writeFabricJar(
        directory,
        'fallback.jar',
        id: 'fallback_mod',
        version: '1',
        entries: <String, List<int>>{
          'assets/fallback/lang/en_us.json': utf8.encode(
            '{"item.fallback.test":"English"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      expect(
        await list.readLanguages(
          'fallback',
          locale: 'tr_tr',
        ),
        isEmpty,
      );
      expect(
        await list.getTranslations(
          'fallback',
          'item.fallback.test',
          locale: 'tr_tr',
        ),
        isEmpty,
      );
    });

    test('preserves every translation candidate across asset sources', () async {
      final File first = await _writeFabricJar(
        directory,
        'first.jar',
        id: 'first_mod',
        version: '1',
        entries: <String, List<int>>{
          'assets/shared/lang/en_us.json': utf8.encode(
            '{"item.shared.widget":"First"}',
          ),
        },
      );
      final File second = await _writeFabricJar(
        directory,
        'second.jar',
        id: 'second_mod',
        version: '1',
        entries: <String, List<int>>{
          'assets/shared/lang/en_us.json': utf8.encode(
            '{"item.shared.widget":"Second"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(first);
      await list.add(second);

      final List<MtnMinecraftInfoModTranslation> translations =
          await list.getTranslations(
        'shared',
        'item.shared.widget',
      );

      expect(translations, hasLength(2));
      expect(
        translations.map(
          (MtnMinecraftInfoModTranslation item) => item.value,
        ).toSet(),
        <String>{'First', 'Second'},
      );
      expect(
        translations.map(
          (MtnMinecraftInfoModTranslation item) =>
              p.basename(item.source.rootFile!.path),
        ).toSet(),
        <String>{'first.jar', 'second.jar'},
      );
    });

    test('missing translation key is not synthesized', () async {
      final File jar = await _writeFabricJar(
        directory,
        'missing-key.jar',
        id: 'missing_key',
        version: '1',
        entries: <String, List<int>>{
          'assets/missing_key/lang/en_us.json': utf8.encode(
            '{"item.missing_key.present":"Present"}',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      expect(
        await list.getTranslations(
          'missing_key',
          'item.missing_key.absent',
        ),
        isEmpty,
      );
    });

    test('rejects malformed language JSON as invalid data', () async {
      final File jar = await _writeFabricJar(
        directory,
        'broken-json.jar',
        id: 'broken_json',
        version: '1',
        entries: <String, List<int>>{
          'assets/broken_json/lang/en_us.json': utf8.encode(
            '{"item.broken_json.test":',
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      await _expectInvalidLanguageData(
        list.readLanguages('broken_json'),
      );
    });

    test('matches Minecraft primitive language value semantics', () async {
      final File jar = await _writeFabricJar(
        directory,
        'primitive-values.jar',
        id: 'primitive_values',
        version: '1',
        entries: <String, List<int>>{
          'assets/primitive_values/lang/en_us.json': utf8.encode(
            jsonEncode(
              <String, Object?>{
                'translation.string': 'Value %d / %2\$.2f',
                'translation.integer': 42,
                'translation.double': 1.5,
                'translation.boolean': true,
              },
            ),
          ),
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(jar);

      final MtnMinecraftInfoModLanguage language =
          (await list.readLanguages('primitive_values')).single;

      expect(language['translation.string'], 'Value %s / %2\$s');
      expect(language['translation.integer'], '42');
      expect(language['translation.double'], '1.5');
      expect(language['translation.boolean'], 'true');
    });

    test('rejects composite language values as invalid data', () async {
      final List<(String, Object?)> cases = <(String, Object?)>[
        ('null', null),
        ('array', <Object?>['value']),
        ('object', <String, Object?>{'text': 'value'}),
      ];

      for (final (String name, Object? invalidValue) in cases) {
        final File jar = await _writeFabricJar(
          directory,
          'composite-$name.jar',
          id: 'composite_value',
          version: '1',
          entries: <String, List<int>>{
            'assets/composite_value/lang/en_us.json': utf8.encode(
              jsonEncode(
                <String, Object?>{
                  'translation.invalid': invalidValue,
                },
              ),
            ),
          },
        );
        final MtnMinecraftModList list = _fabricList();
        await list.add(jar);

        await _expectInvalidLanguageData(
          list.readLanguages('composite_value'),
        );

        await jar.delete();
      }
    });

    test('rejects invalid locale names before reading assets', () async {
      final MtnMinecraftModList list = _fabricList();

      await expectLater(
        list.readLanguages(
          'example',
          locale: 'EN_US',
        ),
        throwsArgumentError,
      );
      await expectLater(
        list.readLanguages(
          'example',
          locale: '../en_us',
        ),
        throwsArgumentError,
      );
      await expectLater(
        list.readLanguages(
          'example',
          locale: 'en/us',
        ),
        throwsArgumentError,
      );
    });

    test('reads embedded Fabric language resources lazily', () async {
      final Uint8List child = _fabricJarBytes(
        id: 'child',
        version: '1',
        entries: <String, List<int>>{
          'assets/child_lang/lang/en_us.json': utf8.encode(
            '{"item.child_lang.widget":"Embedded Widget"}',
          ),
        },
      );
      final File root = await _writeFabricJar(
        directory,
        'root.jar',
        id: 'root',
        version: '1',
        metadataExtras: <String, Object?>{
          'jars': <Object?>[
            <String, Object?>{
              'file': 'META-INF/jars/child.jar',
            },
          ],
        },
        entries: <String, List<int>>{
          'META-INF/jars/child.jar': child,
        },
      );
      final MtnMinecraftModList list = _fabricList();
      await list.add(root);

      final List<MtnMinecraftInfoModTranslation> translations =
          await list.getTranslations(
        'child_lang',
        'item.child_lang.widget',
      );

      expect(translations, hasLength(1));
      expect(translations.single.value, 'Embedded Widget');
      expect(
        translations.single.source.embeddedArchivePaths,
        <String>['META-INF/jars/child.jar'],
      );
      expect(
        translations.single.source.rootFile?.path,
        p.normalize(p.absolute(root.path)),
      );
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
  required String version,
  Map<String, Object?> metadataExtras = const <String, Object?>{},
  Map<String, List<int>> entries = const <String, List<int>>{},
}) async {
  final File file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    _fabricJarBytes(
      id: id,
      version: version,
      metadataExtras: metadataExtras,
      entries: entries,
    ),
  );
  return file;
}

Uint8List _fabricJarBytes({
  required String id,
  required String version,
  Map<String, Object?> metadataExtras = const <String, Object?>{},
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
              'version': version,
              ...metadataExtras,
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

Future<void> _expectInvalidLanguageData(
  Future<List<MtnMinecraftInfoModLanguage>> future,
) async {
  await expectLater(
    future,
    throwsA(
      isA<MtnMinecraftInfoModLanguageException>().having(
        (MtnMinecraftInfoModLanguageException error) => error.error,
        'error',
        MtnMinecraftInfoModLanguageError.invalidData,
      ),
    ),
  );
}
