import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft server address normalization', () {
    test('normalizes DNS case trailing dot and default port', () {
      final MtnMinecraftInfoServerAddress left =
          MtnMinecraftInfoServerAddress.parse(' Example.COM. ');
      final MtnMinecraftInfoServerAddress right =
          MtnMinecraftInfoServerAddress.parse('example.com:25565');

      expect(left.canonicalHost, 'example.com');
      expect(left.canonicalAddress, 'example.com');
      expect(left.hasExplicitPort, isFalse);
      expect(right.hasExplicitPort, isTrue);
      expect(left.sameIdentity(right), isTrue);
      expect(left.sameEndpoint(right), isTrue);
    });

    test('keeps non-default port in canonical identity', () {
      final MtnMinecraftInfoServerAddress address =
          MtnMinecraftInfoServerAddress.parse('EXAMPLE.com:25566');

      expect(address.canonicalHost, 'example.com');
      expect(address.port, 25566);
      expect(address.canonicalAddress, 'example.com:25566');
    });

    test('normalizes bracketed and unbracketed IPv6 identity', () {
      final MtnMinecraftInfoServerAddress left =
          MtnMinecraftInfoServerAddress.parse('2001:0db8::1');
      final MtnMinecraftInfoServerAddress right =
          MtnMinecraftInfoServerAddress.parse(
        '[2001:db8:0:0:0:0:0:1]:25565',
      );

      expect(left.sameIdentity(right), isTrue);
      expect(left.sameEndpoint(right), isTrue);
      expect(left.canonicalAddress, '[2001:db8::1]');
      expect(right.canonicalAddress, '[2001:db8::1]');
    });

    test('uses stable IPv6 zero compression', () {
      expect(
        MtnMinecraftInfoServerAddress.parse(
          '0:0:0:0:0:0:0:0',
        ).canonicalAddress,
        '[::]',
      );
      expect(
        MtnMinecraftInfoServerAddress.parse(
          '0:0:0:1:0:0:0:0',
        ).canonicalAddress,
        '[0:0:0:1::]',
      );
      expect(
        MtnMinecraftInfoServerAddress.parse(
          '2001:0:0:1:0:0:0:1',
        ).canonicalAddress,
        '[2001:0:0:1::1]',
      );
    });
  });

  group('Known Minecraft server matching', () {
    test('prefers exact alias match', () {
      final MtnMinecraftInfoKnownServer known = MtnMinecraftInfoKnownServer(
        name: 'Example',
        addresses: const <String>[
          'play.example.net',
          'example.net:25566',
        ],
      );
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Saved',
        address: 'play.example.net',
      );

      final MtnMinecraftInfoServerMatch match = known.match(server);

      expect(match.kind, MtnMinecraftInfoServerMatchKind.exact);
      expect(match.isMatch, isTrue);
      expect(match.matchedAddress?.source, 'play.example.net');
    });

    test('matches normalized alias without changing persisted address', () {
      final MtnMinecraftInfoKnownServer known = MtnMinecraftInfoKnownServer(
        name: 'Example',
        addresses: const <String>['play.example.net'],
      );
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Saved',
        address: 'PLAY.EXAMPLE.NET.:25565',
      );

      final MtnMinecraftInfoServerMatch match = known.match(server);

      expect(match.kind, MtnMinecraftInfoServerMatchKind.normalized);
      expect(server.address, 'PLAY.EXAMPLE.NET.:25565');
      expect(server.parsedAddress.canonicalAddress, 'play.example.net');
    });

    test('does not infer identity from protocol or display data', () {
      final MtnMinecraftInfoKnownServer known = MtnMinecraftInfoKnownServer(
        name: 'Example',
        addresses: const <String>['play.example.net'],
      );
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Same looking server',
        address: 'other.example.net',
      );

      final MtnMinecraftInfoServerMatch match = known.match(server);

      expect(match.kind, MtnMinecraftInfoServerMatchKind.none);
      expect(match.isMatch, isFalse);
    });

    test('uses resolved endpoint only as fallback evidence', () async {
      final _StatusFixture fixture = await _StatusFixture.start();
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Alias',
        address: 'play.alias.test',
      );
      final _FakeSrvResolver resolver = _FakeSrvResolver(
        <MtnMinecraftInfoSrvRecord>[
          MtnMinecraftInfoSrvRecord(
            priority: 0,
            weight: 0,
            port: fixture.port,
            target: InternetAddress.loopbackIPv4.address,
          ),
        ],
      );

      await server.queryStatus(
        measureLatency: false,
        srvResolver: resolver,
      );
      await fixture.done;

      final MtnMinecraftInfoKnownServer known = MtnMinecraftInfoKnownServer(
        name: 'Backend',
        addresses: <String>[
          '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
        ],
      );

      final MtnMinecraftInfoServerMatch match = known.match(server);

      expect(match.kind, MtnMinecraftInfoServerMatchKind.resolvedEndpoint);
      expect(match.isMatch, isTrue);
      expect(server.address, 'play.alias.test');
      expect(server.status?.host, InternetAddress.loopbackIPv4.address);
      expect(server.status?.port, fixture.port);
    });
  });
}

final class _FakeSrvResolver implements MtnMinecraftInfoSrvResolver {
  _FakeSrvResolver(this.records);

  final List<MtnMinecraftInfoSrvRecord> records;

  @override
  Future<List<MtnMinecraftInfoSrvRecord>> lookupMinecraft({
    required String host,
    Duration timeout = const Duration(seconds: 3),
  }) async =>
      records;
}

final class _StatusFixture {
  _StatusFixture._({
    required this.server,
    required this.done,
  });

  final ServerSocket server;
  final Future<void> done;

  int get port => server.port;

  static Future<_StatusFixture> start() async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<void> done = Completer<void>();

    server.listen((Socket socket) {
      unawaited(
        _handle(socket, server.port).then<void>(
          (_) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!done.isCompleted) done.completeError(error, stackTrace);
          },
        ),
      );
    });

    return _StatusFixture._(
      server: server,
      done: done.future,
    );
  }

  Future<void> close() async {
    await server.close();
  }

  static Future<void> _handle(Socket socket, int port) async {
    final _SocketReader reader = _SocketReader(socket);
    try {
      final _PacketReader handshake = await _readPacket(reader);
      expect(handshake.readVarInt(), 0);
      expect(handshake.readVarInt(), -1);
      expect(handshake.readString(), 'play.alias.test');
      expect(handshake.readUint16(), 25565);
      expect(handshake.readVarInt(), 1);

      final _PacketReader request = await _readPacket(reader);
      expect(request.readVarInt(), 0);

      final Map<String, Object?> response = <String, Object?>{
        'version': <String, Object?>{
          'name': '1.21.1',
          'protocol': 767,
        },
        'players': <String, Object?>{
          'max': 20,
          'online': 1,
        },
        'description': 'Known-server match fixture',
      };

      socket.add(
        _encodePacket(
          <int>[
            ..._encodeVarInt(0),
            ..._encodeString(jsonEncode(response)),
          ],
        ),
      );
      await socket.flush();
    } finally {
      socket.destroy();
    }
  }
}

Future<_PacketReader> _readPacket(_SocketReader reader) async {
  final int length = await reader.readVarInt();
  return _PacketReader(await reader.readBytes(length));
}

Uint8List _encodePacket(List<int> payload) => Uint8List.fromList(
      <int>[..._encodeVarInt(payload.length), ...payload],
    );

List<int> _encodeString(String value) {
  final List<int> bytes = utf8.encode(value);
  return <int>[..._encodeVarInt(bytes.length), ...bytes];
}

List<int> _encodeVarInt(int value) {
  var remaining = value & 0xffffffff;
  final List<int> result = <int>[];
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    result.add(byte);
  } while (remaining != 0);
  return result;
}

final class _SocketReader {
  _SocketReader(Stream<Uint8List> stream)
      : _iterator = StreamIterator<Uint8List>(stream);

  final StreamIterator<Uint8List> _iterator;
  Uint8List _current = Uint8List(0);
  int _offset = 0;

  Future<int> readByte() async {
    await _ensureData();
    return _current[_offset++];
  }

  Future<Uint8List> readBytes(int count) async {
    final BytesBuilder result = BytesBuilder(copy: false);
    var remaining = count;
    while (remaining > 0) {
      await _ensureData();
      final int available = _current.length - _offset;
      final int take = available < remaining ? available : remaining;
      result.add(_current.sublist(_offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
    return result.takeBytes();
  }

  Future<int> readVarInt() async {
    var result = 0;
    for (var index = 0; index < 5; index++) {
      final int byte = await readByte();
      result |= (byte & 0x7f) << (7 * index);
      if ((byte & 0x80) == 0) {
        if ((result & 0x80000000) != 0) {
          return result - 0x100000000;
        }
        return result;
      }
    }
    throw StateError('Invalid VarInt');
  }

  Future<void> _ensureData() async {
    while (_offset >= _current.length) {
      if (!await _iterator.moveNext()) {
        throw StateError('Socket closed before packet completed');
      }
      _current = _iterator.current;
      _offset = 0;
    }
  }
}

final class _PacketReader {
  _PacketReader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int _offset = 0;

  int readVarInt() {
    var result = 0;
    for (var index = 0; index < 5; index++) {
      final int byte = bytes[_offset++];
      result |= (byte & 0x7f) << (7 * index);
      if ((byte & 0x80) == 0) {
        if ((result & 0x80000000) != 0) {
          return result - 0x100000000;
        }
        return result;
      }
    }
    throw StateError('Invalid VarInt');
  }

  String readString() {
    final int length = readVarInt();
    final String value =
        utf8.decode(bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  int readUint16() {
    final int value = _data.getUint16(_offset, Endian.big);
    _offset += 2;
    return value;
  }
}
