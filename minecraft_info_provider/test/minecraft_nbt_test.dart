import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft Java NBT codec', () {
    test('round-trips every Java Edition NBT payload type', () {
      final MtnMinecraftNbtDocument source = MtnMinecraftNbtDocument(
        name: 'root',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'byte': MtnMinecraftNbtValue.byte(-12),
            'short': MtnMinecraftNbtValue.short(-1234),
            'int': MtnMinecraftNbtValue.intValue(-123456),
            'long': MtnMinecraftNbtValue.long(1234567890123),
            'float': MtnMinecraftNbtValue.float(1.5),
            'double': MtnMinecraftNbtValue.doubleValue(-2.25),
            'bytes': MtnMinecraftNbtValue.byteArray(
              <int>[0, 1, 127, 128, 255],
            ),
            'string': MtnMinecraftNbtValue.string(
              'hello\u0000\u{1F680}',
            ),
            'list': MtnMinecraftNbtValue.list(
              MtnMinecraftNbtList(
                elementType: MtnMinecraftNbtType.string,
                values: <MtnMinecraftNbtValue>[
                  MtnMinecraftNbtValue.string('one'),
                  MtnMinecraftNbtValue.string('two'),
                ],
              ),
            ),
            'compound': MtnMinecraftNbtValue.compound(
              <String, MtnMinecraftNbtValue>{
                'nested': MtnMinecraftNbtValue.intValue(42),
              },
            ),
            'ints': MtnMinecraftNbtValue.intArray(
              <int>[-1, 0, 1, 0x7fffffff],
            ),
            'longs': MtnMinecraftNbtValue.longArray(
              <int>[-1, 0, 1, 0x7fffffffffffffff],
            ),
          },
        ),
      );

      const MtnMinecraftNbtCodec codec = MtnMinecraftNbtCodec();
      final List<int> encoded = codec.encode(source);
      final MtnMinecraftNbtDocument decoded = codec.decode(encoded);
      final Map<String, MtnMinecraftNbtValue> root = decoded.root.asCompound;

      expect(encoded.first, MtnMinecraftNbtType.compound.id);
      expect(decoded.name, 'root');
      expect(root['byte']?.asByte, -12);
      expect(root['short']?.asShort, -1234);
      expect(root['int']?.asInt, -123456);
      expect(root['long']?.asLong, 1234567890123);
      expect(root['float']?.asFloat, 1.5);
      expect(root['double']?.asDouble, -2.25);
      expect(root['bytes']?.asByteArray, <int>[0, 1, 127, 128, 255]);
      expect(root['string']?.asString, 'hello\u0000\u{1F680}');
      expect(
        root['list']?.asList.values
            .map((MtnMinecraftNbtValue value) => value.asString),
        <String>['one', 'two'],
      );
      expect(root['compound']?.asCompound['nested']?.asInt, 42);
      expect(root['ints']?.asIntArray, <int>[-1, 0, 1, 0x7fffffff]);
      expect(
        root['longs']?.asLongArray,
        <int>[-1, 0, 1, 0x7fffffffffffffff],
      );
      expect(codec.encode(decoded), encoded);
    });

    test('preserves the element type of an empty list', () {
      final MtnMinecraftNbtDocument source = MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'empty': MtnMinecraftNbtValue.list(
              MtnMinecraftNbtList(
                elementType: MtnMinecraftNbtType.compound,
                values: const <MtnMinecraftNbtValue>[],
              ),
            ),
          },
        ),
      );

      final MtnMinecraftNbtDocument decoded =
          const MtnMinecraftNbtCodec().decode(
        const MtnMinecraftNbtCodec().encode(source),
      );

      expect(
        decoded.root.asCompound['empty']?.asList.elementType,
        MtnMinecraftNbtType.compound,
      );
    });

    test('supports non-compound roots and rejects TAG_End roots', () {
      const MtnMinecraftNbtCodec codec = MtnMinecraftNbtCodec();
      final MtnMinecraftNbtDocument document = MtnMinecraftNbtDocument(
        name: 'name',
        root: MtnMinecraftNbtValue.string('value'),
      );

      final MtnMinecraftNbtDocument decoded =
          codec.decode(codec.encode(document));

      expect(decoded.name, 'name');
      expect(decoded.root.asString, 'value');
      expect(
        () => codec.decode(<int>[MtnMinecraftNbtType.end.id]),
        throwsA(_nbtError(MtnMinecraftNbtError.invalidRoot)),
      );
    });

    test('rejects truncation, trailing bytes, and invalid modified UTF-8', () {
      const MtnMinecraftNbtCodec codec = MtnMinecraftNbtCodec();

      final List<int> valid = codec.encode(
        MtnMinecraftNbtDocument(
          name: '',
          root: MtnMinecraftNbtValue.compound(
            <String, MtnMinecraftNbtValue>{
              'name': MtnMinecraftNbtValue.string('value'),
            },
          ),
        ),
      );
      expect(
        () => codec.decode(valid.sublist(0, valid.length - 1)),
        throwsA(_nbtError(MtnMinecraftNbtError.unexpectedEndOfData)),
      );
      expect(
        () => codec.decode(<int>[...valid, 0]),
        throwsA(_nbtError(MtnMinecraftNbtError.trailingData)),
      );
      expect(
        () => codec.decode(<int>[
          MtnMinecraftNbtType.string.id,
          0,
          0,
          0,
          1,
          0,
        ]),
        throwsA(_nbtError(MtnMinecraftNbtError.invalidString)),
      );
      expect(
        () => codec.decode(<int>[
          MtnMinecraftNbtType.string.id,
          0,
          0,
          0,
          2,
          0xc0,
          0x81,
        ]),
        throwsA(_nbtError(MtnMinecraftNbtError.invalidString)),
      );
    });
  });
}

Matcher _nbtError(MtnMinecraftNbtError error) =>
    isA<MtnMinecraftNbtException>().having(
      (MtnMinecraftNbtException exception) => exception.error,
      'error',
      error,
    );
