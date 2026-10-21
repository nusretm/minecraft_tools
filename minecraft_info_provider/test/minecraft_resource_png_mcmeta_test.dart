import 'dart:convert';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:minecraft_models/minecraft_models.dart';
import 'package:test/test.dart';

void main() {
  Uint8List pngHeader(int width, int height) {
    // Only PNG signature and IHDR are required: the resource parser never
    // decodes pixels, examines IDAT or checks the image CRC.
    final Uint8List png = Uint8List.fromList(<int>[
      137, 80, 78, 71, 13, 10, 26, 10,
      0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 0, 0, 0, 0, 0,
      8, 6, 0, 0, 0, 0, 0, 0, 0,
    ]);
    final ByteData header = ByteData.sublistView(png);
    header.setUint32(16, width, Endian.big);
    header.setUint32(20, height, Endian.big);
    return png;
  }

  Uint8List meta(Object? json) => Uint8List.fromList(utf8.encode(jsonEncode(json)));
  final MtnMinecraftResourceImageAnimationParser parser =
      const MtnMinecraftResourceImageAnimationParser();

  MtnMinecraftInfoModAssetSource source(Map<String, Uint8List> assets, {
    String namespace = 'example',
    List<String>? readPaths,
  }) => MtnMinecraftInfoModAssetSource(
        rootFile: null,
        namespaces: <String>[namespace],
        loader: (String path) async {
          readPaths?.add(path);
          return assets[path];
        },
      );

  MtnMinecraftResourceEnvironment environment(String version) =>
      MtnMinecraftResourceEnvironment(
        version: MtnMinecraftVersion.parse(
          version, type: MtnMinecraftGameVersionType.release,
        ),
        loaderType: MtnMinecraftLoaderType.fabric,
      );

  MtnMinecraftResourceItemRequest request(String name) =>
      MtnMinecraftResourceItemRequest(
        item: MtnMinecraftInfoItemIdentity.parse('example:$name'),
      );

  void expectRegion(
    MtnMinecraftResourceImageRegion? actual, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    expect(actual, isNotNull);
    expect(actual!.x, x);
    expect(actual.y, y);
    expect(actual.width, width);
    expect(actual.height, height);
  }

  group('CP6 first logical PNG frame parser', () {
    test('no animation section leaves region null without parsing PNG header', () {
      expect(parser.parse(png: Uint8List.fromList(<int>[1]), metadata: meta(<String, Object?>{
        'texture': <String, bool>{'blur': true},
      })), isNull);
    });

    test('default square frames, explicit integer order, and raw PNG size', () {
      final Uint8List png = pngHeader(16, 128);
      final MtnMinecraftResourceImageRegion? region = parser.parse(
        png: png, metadata: meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[3, 0, 2]},
        }),
      );
      expectRegion(region, x: 0, y: 48, width: 16, height: 16);
      expect(png.length, 33);
    });

    test('frame objects, timings and interpolation are validated but not applied', () {
      final region = parser.parse(
        png: pngHeader(16, 64),
        metadata: meta(<String, Object?>{
          'animation': <String, Object?>{
            'frametime': 4,
            'interpolate': true,
            'frames': <Object?>[
              <String, int>{'index': 2, 'time': 7},
              <String, int>{'index': 0, 'time': 2},
            ],
          },
        }),
      );
      expectRegion(region, x: 0, y: 32, width: 16, height: 16);
    });

    test('empty animation uses first physical frame and is not a static null region', () {
      expectRegion(
        parser.parse(png: pngHeader(32, 96), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{},
        })),
        x: 0, y: 0, width: 32, height: 32,
      );
    });

    test('multi-column grid uses left-to-right row-major first frame index', () {
      expectRegion(
        parser.parse(png: pngHeader(64, 32), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{
            'width': 16, 'height': 16, 'frames': <int>[5, 1],
          },
        })),
        x: 16, y: 16, width: 16, height: 16,
      );
    });

    test('one explicit dimension defaults the other to whole PNG dimension', () {
      expectRegion(
        parser.parse(png: pngHeader(32, 16), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{'width': 16, 'frames': <int>[1]},
        })),
        x: 16, y: 0, width: 16, height: 16,
      );
      expectRegion(
        parser.parse(png: pngHeader(16, 32), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{'height': 16, 'frames': <int>[1]},
        })),
        x: 0, y: 16, width: 16, height: 16,
      );
    });

    test('invalid animation JSON, geometry, entries and headers fail explicitly', () {
      final Uint8List png = pngHeader(32, 64);
      final List<Object?> invalid = <Object?>[
        <String, Object?>{'animation': null},
        <String, Object?>{'animation': 'invalid'},
        <String, Object?>{'animation': <String, Object?>{'width': 0}},
        <String, Object?>{'animation': <String, Object?>{'width': 12}},
        <String, Object?>{'animation': <String, Object?>{'height': 3}},
        <String, Object?>{'animation': <String, Object?>{'frametime': 0}},
        <String, Object?>{'animation': <String, Object?>{'frametime': 1.5}},
        <String, Object?>{'animation': <String, Object?>{'interpolate': 1}},
        <String, Object?>{'animation': <String, Object?>{'frames': <int>[]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <int>[-1]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <int>[2]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <Object?>[null]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <Object?>[<String, int>{'time': 2}]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <Object?>[<String, int>{'index': 0, 'time': 0}]}},
        <String, Object?>{'animation': <String, Object?>{'frames': <Object?>[0, 2]}},
      ];
      for (final Object? value in invalid) {
        expect(
          () => parser.parse(png: png, metadata: meta(value)),
          throwsFormatException,
          reason: value.toString(),
        );
      }
      expect(() => parser.parse(png: png, metadata: meta(<int>[1])), throwsFormatException);
      expect(() => parser.parse(png: png, metadata: Uint8List.fromList(utf8.encode('{'))), throwsFormatException);
      expect(() => parser.parse(
        png: Uint8List.fromList(<int>[1, 2, 3]), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{},
        }),
      ), throwsFormatException);
      expect(() => parser.parse(
        png: pngHeader(0, 64), metadata: meta(<String, Object?>{
          'animation': <String, Object?>{},
        }),
      ), throwsFormatException);
      expect(() => MtnMinecraftResourceImageRegion(x: -1, y: 0, width: 16, height: 16), throwsArgumentError);
    });
  });

  group('CP6 texture source integration', () {
    test('no mcmeta preserves original raw PNG and null region', () async {
      final Uint8List opaque = Uint8List.fromList(<int>[1, 2, 3]);
      final List<String> reads = <String>[];
      final src = source(<String, Uint8List>{
        'assets/example/textures/item/plain.png': opaque,
      }, readPaths: reads);
      final image = await MtnMinecraftResourceHelperLegacy().loadTexture(
        MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[src]),
        MtnMinecraftResourceLocation.parse('example:item/plain'),
      );
      expect(image, isNotNull);
      expect(image!.region, isNull);
      expect(image.png, opaque);
      image.png[0] = 22;
      expect(image.png[0], 1);
      expect(reads, <String>[
        'assets/example/textures/item/plain.png',
        'assets/example/textures/item/plain.png.mcmeta',
      ]);
    });

    test('winning PNG source owns metadata; no fallback to lower source', () async {
      final Uint8List png = pngHeader(16, 64);
      final List<String> lowReads = <String>[];
      final List<String> highReads = <String>[];
      final low = source(<String, Uint8List>{
        'assets/example/textures/item/example.png': png,
        'assets/example/textures/item/example.png.mcmeta': meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[2]},
        }),
      }, readPaths: lowReads);
      final high = source(<String, Uint8List>{
        'assets/example/textures/item/example.png': png,
      }, readPaths: highReads);
      final loader = MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[low, high],
      );
      final image = (await MtnMinecraftResourceHelperLegacy().loadTexture(
        loader, MtnMinecraftResourceLocation.parse('example:item/example'),
      ))!;
      expect(image.resource.source, same(high));
      expect(image.region, isNull);
      expect(highReads, <String>[
        'assets/example/textures/item/example.png',
        'assets/example/textures/item/example.png.mcmeta',
      ]);
      expect(lowReads, isEmpty);
    });

    test('selected lower PNG never borrows metadata from higher source', () async {
      final png = pngHeader(16, 64);
      final high = source(<String, Uint8List>{
        'assets/example/textures/item/example.png.mcmeta': meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[3]},
        }),
      });
      final low = source(<String, Uint8List>{
        'assets/example/textures/item/example.png': png,
      });
      final image = (await MtnMinecraftResourceHelperLegacy().loadTexture(
        MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[low, high]),
        MtnMinecraftResourceLocation.parse('example:item/example'),
      ))!;
      expect(image.resource.source, same(low));
      expect(image.region, isNull);
    });

    test('malformed winning PNG metadata propagates, not lower source fallback', () async {
      final png = pngHeader(16, 64);
      final low = source(<String, Uint8List>{
        'assets/example/textures/item/a.png': png,
      });
      final high = source(<String, Uint8List>{
        'assets/example/textures/item/a.png': png,
        'assets/example/textures/item/a.png.mcmeta': meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[7]},
        }),
      });
      await expectLater(
        MtnMinecraftResourceHelperLegacy().loadTexture(
          MtnMinecraftResourceLoader(sources: <MtnMinecraftResourceSourceAbs>[low, high]),
          MtnMinecraftResourceLocation.parse('example:item/a'),
        ),
        throwsFormatException,
      );
    });

    test('modern 26.2 model graph carries region while pngList stays original', () async {
      final Uint8List png = pngHeader(16, 128);
      final src = source(<String, Uint8List>{
        'assets/example/items/demo.json': meta(<String, Object?>{
          'model': <String, String>{'type': 'minecraft:model', 'model': 'example:item/demo'},
        }),
        'assets/example/models/item/demo.json': meta(<String, Object?>{
          'textures': <String, String>{'layer0': 'example:item/demo'},
        }),
        'assets/example/textures/item/demo.png': png,
        'assets/example/textures/item/demo.png.mcmeta': meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[3, 0]},
        }),
      });
      final item = (await MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[src],
      ).loadItem(environment: environment('26.2'), request: request('demo')))!;
      expect(item.isComplete, isTrue);
      final texture = item.itemModelGraph!.bindings.single.textures.single;
      expect(texture.image!.resource.source, same(src));
      expectRegion(texture.image!.region, x: 0, y: 48, width: 16, height: 16);
      expect(item.pngList, hasLength(1));
      expect(item.pngList.single, png);
    });

    test('legacy item loads animated texture region through same helper hook', () async {
      final Uint8List png = pngHeader(16, 64);
      final src = source(<String, Uint8List>{
        'assets/example/models/item/demo.json': meta(<String, Object?>{
          'textures': <String, String>{'layer0': 'example:item/demo'},
        }),
        'assets/example/textures/item/demo.png': png,
        'assets/example/textures/item/demo.png.mcmeta': meta(<String, Object?>{
          'animation': <String, Object?>{'frames': <int>[2]},
        }),
      });
      final item = (await MtnMinecraftResourceLoader(
        sources: <MtnMinecraftResourceSourceAbs>[src],
      ).loadItem(environment: environment('1.21.1'), request: request('demo')))!;
      expect(item.isComplete, isTrue);
      expectRegion(item.textures.single.image!.region, x: 0, y: 32, width: 16, height: 16);
      expect(item.pngList.single, png);
    });
  });
}
