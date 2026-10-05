import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft legacy server ping fallback', () {
    test('falls back to the Minecraft 1.6 extended ping', () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(_LegacyFixtureMode.legacy16);
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Legacy 1.6',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      final MtnMinecraftInfoServerStatus status = await server.queryStatus(
        timeout: const Duration(seconds: 1),
      );
      await fixture.done;

      expect(status.state, MtnMinecraftInfoServerState.online);
      expect(status.format, MtnMinecraftInfoServerStatusFormat.legacy16);
      expect(status.protocol, 78);
      expect(status.versionName, '1.6.4');
      expect(status.motd?.plainText, 'Legacy 1.6 Server');
      expect(status.onlinePlayers, 4);
      expect(status.maxPlayers, 20);
      expect(status.latency, isNotNull);
      expect(status.rawJson, isNull);
      expect(status.favicon, isNull);
      expect(status.modMetadata, isNull);
      expect(fixture.connections, 2);
    });

    test('falls back to the Minecraft 1.4/1.5 ping', () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(_LegacyFixtureMode.legacy14);
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Legacy 1.5',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      final MtnMinecraftInfoServerStatus status = await server.queryStatus(
        timeout: const Duration(seconds: 1),
      );
      await fixture.done;

      expect(status.state, MtnMinecraftInfoServerState.online);
      expect(status.format, MtnMinecraftInfoServerStatusFormat.legacy14);
      expect(status.protocol, 61);
      expect(status.versionName, '1.5.2');
      expect(status.motd?.plainText, 'Legacy 1.5 Server');
      expect(status.onlinePlayers, 2);
      expect(status.maxPlayers, 10);
      expect(fixture.connections, 3);
    });

    test('falls back to the pre-1.4 ping', () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(_LegacyFixtureMode.legacyPre14);
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Very old',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      final MtnMinecraftInfoServerStatus status = await server.queryStatus(
        timeout: const Duration(seconds: 1),
      );
      await fixture.done;

      expect(status.state, MtnMinecraftInfoServerState.online);
      expect(status.format, MtnMinecraftInfoServerStatusFormat.legacyPre14);
      expect(status.protocol, isNull);
      expect(status.versionName, isNull);
      expect(status.motd?.plainText, 'Very Old Server');
      expect(status.motd?.items.single.color, MtnMinecraftTextColor.green);
      expect(status.onlinePlayers, 5);
      expect(status.maxPlayers, 12);
      expect(fixture.connections, 4);
    });

    test('does not hide malformed modern JSON with legacy fallback', () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(
        _LegacyFixtureMode.malformedModern,
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Malformed modern',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      await expectLater(
        server.queryStatus(timeout: const Duration(seconds: 1)),
        throwsA(
          isA<MtnMinecraftInfoServerStatusException>().having(
            (MtnMinecraftInfoServerStatusException error) => error.error,
            'error',
            MtnMinecraftInfoServerStatusError.invalidResponse,
          ),
        ),
      );
      await fixture.done;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fixture.connections, 1);
    });

    test('known modern server keeps stale grace instead of legacy downgrade',
        () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(
        _LegacyFixtureMode.modernThenTimeout,
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Modern grace',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      final MtnMinecraftInfoServerStatus fresh = await server.queryStatus(
        timeout: const Duration(seconds: 1),
        measureLatency: false,
      );
      expect(fresh.format, MtnMinecraftInfoServerStatusFormat.modern);
      expect(fresh.isStale, isFalse);

      final MtnMinecraftInfoServerStatus stale = await server.queryStatus(
        timeout: const Duration(milliseconds: 100),
        offlineAfter: const Duration(seconds: 1),
        measureLatency: false,
      );
      await fixture.done;

      expect(stale.state, MtnMinecraftInfoServerState.online);
      expect(stale.format, MtnMinecraftInfoServerStatusFormat.modern);
      expect(stale.isStale, isTrue);
      expect(stale.versionName, fresh.versionName);
      expect(stale.failureSince, isNotNull);
      expect(fixture.connections, 2);
    });

    test('legacy fallback can be disabled', () async {
      final _LegacyFallbackFixture fixture =
          await _LegacyFallbackFixture.start(_LegacyFixtureMode.noFallback);
      addTearDown(fixture.close);

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'No fallback',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
      );

      await expectLater(
        server.queryStatus(
          timeout: const Duration(seconds: 1),
          allowLegacyFallback: false,
        ),
        throwsA(
          isA<MtnMinecraftInfoServerStatusException>().having(
            (MtnMinecraftInfoServerStatusException error) => error.error,
            'error',
            MtnMinecraftInfoServerStatusError.invalidPacket,
          ),
        ),
      );
      await fixture.done;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fixture.connections, 1);
    });
  });
}

enum _LegacyFixtureMode {
  legacy16,
  legacy14,
  legacyPre14,
  malformedModern,
  modernThenTimeout,
  noFallback,
}

final class _LegacyFallbackFixture {
  _LegacyFallbackFixture._({
    required this.server,
    required this.done,
    required this.mode,
  });

  final ServerSocket server;
  final Future<void> done;
  final _LegacyFixtureMode mode;
  int connections = 0;

  int get port => server.port;

  static Future<_LegacyFallbackFixture> start(
    _LegacyFixtureMode mode,
  ) async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<void> done = Completer<void>();
    late final _LegacyFallbackFixture fixture;

    fixture = _LegacyFallbackFixture._(
      server: server,
      done: done.future,
      mode: mode,
    );

    server.listen((Socket socket) {
      final int connection = fixture.connections++;
      unawaited(
        fixture._handle(socket, connection).then<void>(
          (bool terminal) {
            if (terminal && !done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!done.isCompleted) done.completeError(error, stackTrace);
          },
        ),
      );
    });

    return fixture;
  }

  Future<void> close() async {
    await server.close();
  }

  Future<bool> _handle(Socket socket, int connection) async {
    final _ByteReader reader = _ByteReader(socket);
    try {
      if (connection == 0) {
        if (mode == _LegacyFixtureMode.malformedModern) {
          socket.add(_modernStatusPacket('{}'));
          await socket.flush();
          return true;
        }

        if (mode == _LegacyFixtureMode.modernThenTimeout) {
          socket.add(
            _modernStatusPacket(
              jsonEncode(
                <String, Object?>{
                  'version': <String, Object?>{
                    'name': '1.21.1',
                    'protocol': 767,
                  },
                  'players': <String, Object?>{
                    'max': 20,
                    'online': 3,
                  },
                  'description': 'Modern first response',
                },
              ),
            ),
          );
          await socket.flush();
          return false;
        }

        socket.add(<int>[0x00]);
        await socket.flush();
        return mode == _LegacyFixtureMode.noFallback;
      }

      if (connection == 1 &&
          mode == _LegacyFixtureMode.modernThenTimeout) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return true;
      }

      if (connection == 1) {
        final Uint8List prefix = await reader.readBytes(3);
        expect(prefix, orderedEquals(<int>[0xfe, 0x01, 0xfa]));

        if (mode == _LegacyFixtureMode.legacy16) {
          final Uint8List remainder = await reader.readBytes(
            _legacy16RequestLength(InternetAddress.loopbackIPv4.address) - 3,
          );
          _expectLegacy16Remainder(
            remainder,
            host: InternetAddress.loopbackIPv4.address,
            port: port,
          );
          socket.add(
            _legacyResponse(
              '§1\u000078\u00001.6.4\u0000Legacy 1.6 Server'
              '\u00004\u000020',
            ),
          );
          await socket.flush();
          return true;
        }

        return false;
      }

      if (connection == 2) {
        expect(
          await reader.readBytes(2),
          orderedEquals(<int>[0xfe, 0x01]),
        );
        if (mode == _LegacyFixtureMode.legacy14) {
          socket.add(
            _legacyResponse(
              '§1\u000061\u00001.5.2\u0000Legacy 1.5 Server'
              '\u00002\u000010',
            ),
          );
          await socket.flush();
          return true;
        }
        return false;
      }

      if (connection == 3 && mode == _LegacyFixtureMode.legacyPre14) {
        expect(await reader.readByte(), 0xfe);
        socket.add(_legacyResponse('§aVery Old Server§5§12'));
        await socket.flush();
        return true;
      }

      return false;
    } finally {
      socket.destroy();
    }
  }
}

int _legacy16RequestLength(String host) => 36 + host.codeUnits.length * 2;

void _expectLegacy16Remainder(
  Uint8List bytes, {
  required String host,
  required int port,
}) {
  final _BufferReader reader = _BufferReader(bytes);
  expect(reader.readUint16(), 11);
  expect(reader.readUtf16(11), 'MC|PingHost');
  expect(reader.readUint16(), 7 + host.codeUnits.length * 2);
  expect(reader.readByte(), 78);
  expect(reader.readUint16(), host.codeUnits.length);
  expect(reader.readUtf16(host.codeUnits.length), host);
  expect(reader.readUint32(), port);
  expect(reader.isAtEnd, isTrue);
}

Uint8List _legacyResponse(String text) {
  final Uint8List body = _encodeUtf16Be(text);
  final Uint8List bytes = Uint8List(3 + body.length);
  final ByteData data = ByteData.sublistView(bytes);
  bytes[0] = 0xff;
  data.setUint16(1, text.codeUnits.length, Endian.big);
  bytes.setRange(3, bytes.length, body);
  return bytes;
}

Uint8List _modernStatusPacket(String json) {
  final List<int> payload = <int>[
    ..._encodeVarInt(0),
    ..._encodeString(json),
  ];
  return Uint8List.fromList(
    <int>[..._encodeVarInt(payload.length), ...payload],
  );
}

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

Uint8List _encodeUtf16Be(String value) {
  final Uint8List result = Uint8List(value.codeUnits.length * 2);
  final ByteData data = ByteData.sublistView(result);
  for (var index = 0; index < value.codeUnits.length; index++) {
    data.setUint16(index * 2, value.codeUnits[index], Endian.big);
  }
  return result;
}

final class _ByteReader {
  _ByteReader(Stream<Uint8List> stream)
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

  Future<void> _ensureData() async {
    while (_offset >= _current.length) {
      if (!await _iterator.moveNext()) {
        throw StateError('Socket closed before expected request completed');
      }
      _current = _iterator.current;
      _offset = 0;
    }
  }
}

final class _BufferReader {
  _BufferReader(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;
  int offset = 0;

  bool get isAtEnd => offset == bytes.length;

  int readByte() => bytes[offset++];

  int readUint16() {
    final int value = data.getUint16(offset, Endian.big);
    offset += 2;
    return value;
  }

  int readUint32() {
    final int value = data.getUint32(offset, Endian.big);
    offset += 4;
    return value;
  }

  String readUtf16(int characters) {
    final List<int> units = List<int>.generate(
      characters,
      (int index) => data.getUint16(offset + index * 2, Endian.big),
      growable: false,
    );
    offset += characters * 2;
    return String.fromCharCodes(units);
  }
}
