import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('resource source core CP1', () {
    test('existing mod asset source keeps validation, copying and provenance', () async {
      final Uint8List backing = Uint8List.fromList(<int>[1, 2, 3]);
      final List<String> requests = <String>[];
      final MtnMinecraftInfoModAssetSource source =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['zeta', 'example', 'example'],
        loader: (String path) async {
          requests.add(path);
          return backing;
        },
      );

      expect(source, isA<MtnMinecraftResourceSourceAbs>());
      expect(source.namespaces, <String>['example', 'zeta']);
      expect(() => source.namespaces.add('new'), throwsUnsupportedError);
      expect(source.containsNamespace('example'), isTrue);
      expect(source.containsNamespace('missing'), isFalse);

      final Uint8List first = (await source.read('example', 'models/item/test.json'))!;
      expect(first, <int>[1, 2, 3]);
      expect(identical(first, backing), isFalse);
      first[0] = 99;
      expect(backing[0], 1);
      expect(requests, <String>['assets/example/models/item/test.json']);

      expect(await source.read('missing', 'models/item/test.json'), isNull);
      expect(requests, hasLength(1));
      await expectLater(source.read('Example', 'models/item/test.json'), throwsArgumentError);
      await expectLater(source.read('example', '../unsafe.txt'), throwsArgumentError);
      await expectLater(source.read('example', '/unsafe.txt'), throwsArgumentError);
      expect(
        () => MtnMinecraftInfoModAssetSource(
          rootFile: null,
          namespaces: <String>['Invalid'],
          loader: (String path) async => null,
        ),
        throwsArgumentError,
      );
    });

    test('effective read uses last registered source, preserving provenance', () async {
      final List<String> reads = <String>[];
      final MtnMinecraftInfoModAssetSource low =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async {
          reads.add('low:$path');
          return Uint8List.fromList(<int>[1]);
        },
      );
      final MtnMinecraftInfoModAssetSource high =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async {
          reads.add('high:$path');
          return Uint8List.fromList(<int>[2]);
        },
      );
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[low, high],
      );

      final MtnMinecraftResourceData result =
          (await loader.read('example', 'textures/item/test.png'))!;
      expect(result.source, same(high));
      expect(result.namespace, 'example');
      expect(result.path, 'textures/item/test.png');
      expect(result.assetPath, 'assets/example/textures/item/test.png');
      expect(result.bytes, <int>[2]);
      expect(reads, <String>['high:assets/example/textures/item/test.png']);
      expect(loader.sources, <MtnMinecraftResourceSourceAbs>[low, high]);
    });

    test('readAll preserves all candidates in high-to-low order', () async {
      final Uint8List lowBytes = Uint8List.fromList(<int>[1]);
      final Uint8List highBytes = Uint8List.fromList(<int>[2]);
      final MtnMinecraftInfoModAssetSource low =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async => lowBytes,
      );
      final MtnMinecraftInfoModAssetSource high =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async => highBytes,
      );
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[low, high],
      );

      final List<MtnMinecraftResourceData> all =
          await loader.readAll('example', 'textures/item/test.png');
      expect(all, hasLength(2));
      expect(all[0].source, same(high));
      expect(all[0].bytes, <int>[2]);
      expect(all[1].source, same(low));
      expect(all[1].bytes, <int>[1]);
      expect(() => all.clear(), throwsUnsupportedError);

      highBytes[0] = 77;
      expect(all[0].bytes, <int>[2]);
      final MtnMinecraftResourceData effective =
          (await loader.read('example', 'textures/item/test.png'))!;
      expect(effective.source, same(all.first.source));
    });

    test('unregister and clear retain explicit stack order and missing semantics', () async {
      final MtnMinecraftInfoModAssetSource low =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async => Uint8List.fromList(<int>[1]),
      );
      final MtnMinecraftInfoModAssetSource high =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['other'],
        loader: (String path) async => Uint8List.fromList(<int>[2]),
      );
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader();
      loader.registerSource(low);
      loader.registerSource(high);
      expect(() => loader.registerSource(low), throwsStateError);
      final List<MtnMinecraftResourceSourceAbs> snapshot = loader.sources;
      expect(() => snapshot.remove(low), throwsUnsupportedError);
      expect(await loader.read('absent', 'test.json'), isNull);
      expect(await loader.readAll('absent', 'test.json'), isEmpty);
      expect((await loader.read('example', 'test.json'))?.source, same(low));

      expect(loader.unregisterSource(high), isTrue);
      expect(loader.unregisterSource(high), isFalse);
      expect(loader.sources, <MtnMinecraftResourceSourceAbs>[low]);
      expect(snapshot, <MtnMinecraftResourceSourceAbs>[low, high]);
      loader.clearSources();
      expect(loader.sources, isEmpty);
      expect(await loader.read('example', 'test.json'), isNull);
      await expectLater(loader.read('INVALID', 'test.json'), throwsArgumentError);
      await expectLater(loader.readAll('example', '../test.json'), throwsArgumentError);
    });

    test('missing top resource falls back; malformed top resource does not', () async {
      int lowReads = 0;
      bool broken = false;
      final MtnMinecraftInfoModAssetSource low =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async {
          lowReads++;
          return Uint8List.fromList(<int>[3]);
        },
      );
      final MtnMinecraftInfoModAssetSource high =
          MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>['example'],
        loader: (String path) async {
          if (broken) throw const FormatException('broken effective resource');
          return null;
        },
      );
      final MtnMinecraftResourceLoader loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[low, high],
      );

      expect((await loader.read('example', 'test.json'))?.source, same(low));
      expect(lowReads, 1);
      broken = true;
      await expectLater(loader.read('example', 'test.json'), throwsFormatException);
      await expectLater(loader.readAll('example', 'test.json'), throwsFormatException);
      expect(lowReads, 1);
    });
  });
}
