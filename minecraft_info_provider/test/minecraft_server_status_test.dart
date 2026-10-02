import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft Java server status', () {
    test('queries status and measures ping/pong latency', () async {
      final _StatusFixture fixture = await _StatusFixture.start(
        <String, Object?>{
          'version': <String, Object?>{
            'name': '1.21.1',
            'protocol': 767,
          },
          'players': <String, Object?>{
            'max': 100,
            'online': 5,
            'sample': <Object?>[
              <String, Object?>{
                'id': '4566e69f-c907-48ee-8d71-d7ba5aa00d20',
                'name': 'Player',
              },
            ],
          },
          'description': <String, Object?>{
            'text': 'Hello ',
            'extra': <Object?>[
              <String, Object?>{'text': 'world'},
            ],
          },
          'favicon': 'data:image/png;base64,abc',
          'enforcesSecureChat': true,
        },
        expectPing: true,
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoServerStatus status =
          await const MtnMinecraftInfoServerStatusClient().query(
        host: InternetAddress.loopbackIPv4.address,
        port: fixture.port,
      );
      await fixture.done;

      expect(status.state, MtnMinecraftInfoServerState.online);
      expect(status.isOnline, isTrue);
      expect(status.versionName, '1.21.1');
      expect(status.protocol, 767);
      expect(status.onlinePlayers, 5);
      expect(status.maxPlayers, 100);
      expect(status.playerSample, hasLength(1));
      expect(status.playerSample.single.name, 'Player');
      expect(status.motd, 'Hello world');
      expect(status.favicon, 'data:image/png;base64,abc');
      expect(status.enforcesSecureChat, isTrue);
      expect(status.latency, isNotNull);
      expect(status.advertisesModded, isFalse);
      expect(status.modMetadata, isNull);
    });

    test('returns unavailable instead of throwing when endpoint is unreachable',
        () async {
      final ServerSocket reserved = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final int unavailablePort = reserved.port;
      await reserved.close();

      final MtnMinecraftInfoServerStatus status =
          await const MtnMinecraftInfoServerStatusClient().query(
        host: InternetAddress.loopbackIPv4.address,
        port: unavailablePort,
        timeout: const Duration(milliseconds: 500),
      );

      expect(status.state, MtnMinecraftInfoServerState.unavailable);
      expect(
        status.unavailableReason,
        MtnMinecraftInfoServerUnavailableReason.connection,
      );
      expect(status.isOnline, isFalse);
      expect(status.versionName, isNull);
      expect(status.protocol, isNull);
      expect(status.onlinePlayers, isNull);
      expect(status.maxPlayers, isNull);
      expect(status.motd, isNull);
      expect(status.rawJson, isNull);
      expect(status.latency, isNull);
      expect(status.modMetadata, isNull);
    });

    test('onChange ignores bookkeeping-only refresh changes', () async {
      final _StatusFixture fixture = await _StatusFixture.start(
        <String, Object?>{
          'version': <String, Object?>{
            'name': '1.21.1',
            'protocol': 767,
          },
          'players': <String, Object?>{
            'max': 20,
            'online': 3,
          },
          'description': 'Stable',
        },
      );
      addTearDown(fixture.close);

      var changes = 0;
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Stable',
        address: '${InternetAddress.loopbackIPv4.address}:${fixture.port}',
        onChange: (_) => changes++,
      );

      final MtnMinecraftInfoServerStatus first =
          await server.queryStatus(measureLatency: false);
      final DateTime firstSuccessfulAt = first.lastSuccessfulAt!;

      await Future<void>.delayed(const Duration(milliseconds: 2));

      final MtnMinecraftInfoServerStatus second =
          await server.queryStatus(measureLatency: false);

      expect(second.state, MtnMinecraftInfoServerState.online);
      expect(second.isStale, isFalse);
      expect(second.lastSuccessfulAt, isNot(firstSuccessfulAt));
      expect(changes, 1);
    });

    test('server owns status lifecycle and onChange notifications', () async {
      final _StatusFixture fixture = await _StatusFixture.start(
        <String, Object?>{
          'version': <String, Object?>{
            'name': '1.21.1',
            'protocol': 767,
          },
          'players': <String, Object?>{
            'max': 20,
            'online': 3,
          },
          'description': 'Grace test',
        },
        expectPing: true,
      );
      final int port = fixture.port;
      var changes = 0;
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Local',
        address: '${InternetAddress.loopbackIPv4.address}:$port',
        onChange: (_) => changes++,
      );

      final MtnMinecraftInfoServerStatus fresh = await server.queryStatus();
      await fixture.done;
      await fixture.close();

      expect(identical(server.status, fresh), isTrue);
      expect(fresh.state, MtnMinecraftInfoServerState.online);
      expect(fresh.isStale, isFalse);
      expect(fresh.latency, isNotNull);
      expect(fresh.lastSuccessfulAt, isNotNull);
      expect(changes, 1);

      final MtnMinecraftInfoServerStatus transient =
          await server.queryStatus(
        timeout: const Duration(milliseconds: 200),
        offlineAfter: const Duration(milliseconds: 100),
      );

      expect(transient.state, MtnMinecraftInfoServerState.online);
      expect(transient.isStale, isTrue);
      expect(transient.versionName, fresh.versionName);
      expect(transient.onlinePlayers, fresh.onlinePlayers);
      expect(transient.latency, isNull);
      expect(transient.failureSince, isNotNull);
      expect(changes, 2);

      await Future<void>.delayed(const Duration(milliseconds: 125));

      final MtnMinecraftInfoServerStatus offline =
          await server.queryStatus(
        timeout: const Duration(milliseconds: 200),
        offlineAfter: const Duration(milliseconds: 100),
      );

      expect(offline.state, MtnMinecraftInfoServerState.offline);
      expect(offline.isOffline, isTrue);
      expect(offline.isStale, isTrue);
      expect(offline.versionName, fresh.versionName);
      expect(offline.onlinePlayers, fresh.onlinePlayers);
      expect(offline.latency, isNull);
      expect(offline.lastSuccessfulAt, fresh.lastSuccessfulAt);
      expect(offline.failureSince, transient.failureSince);
      expect(changes, 3);
    });

    test('parses modern Forge advertised mods and required channels', () async {
      final _StatusFixture fixture = await _StatusFixture.start(
        <String, Object?>{
          'version': <String, Object?>{
            'name': '1.20.1 Forge',
            'protocol': 763,
          },
          'players': <String, Object?>{
            'max': 20,
            'online': 2,
          },
          'description': 'Forge server',
          'forgeData': <String, Object?>{
            'fmlNetworkVersion': 3,
            'truncated': true,
            'mods': <Object?>[
              <String, Object?>{
                'modId': 'forge',
                'modmarker': '47.3.0',
              },
              <String, Object?>{
                'modId': 'examplemod',
                'modmarker': '1.4.2',
              },
            ],
            'channels': <Object?>[
              <String, Object?>{
                'res': 'examplemod:main',
                'version': '1',
                'required': true,
              },
              <String, Object?>{
                'res': 'examplemod:optional',
                'version': '2',
                'required': false,
              },
            ],
          },
        },
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoServerStatus status =
          await const MtnMinecraftInfoServerStatusClient().query(
        host: InternetAddress.loopbackIPv4.address,
        port: fixture.port,
        measureLatency: false,
      );
      await fixture.done;

      expect(status.advertisesModded, isTrue);
      final MtnMinecraftInfoServerModMetadata metadata = status.modMetadata!;
      expect(metadata.loader, MtnMinecraftInfoServerModLoader.forge);
      expect(metadata.fmlNetworkVersion, 3);
      expect(metadata.advertisedListsComplete, isFalse);
      expect(metadata.mods, hasLength(2));
      expect(metadata.mods.last.id, 'examplemod');
      expect(metadata.mods.last.versionMarker, '1.4.2');
      expect(metadata.channels, hasLength(2));
      expect(metadata.channels.first.requiredForClient, isTrue);
      expect(metadata.channels.last.requiredForClient, isFalse);
    });

    test('parses legacy FML modinfo without guessing completeness', () async {
      final _StatusFixture fixture = await _StatusFixture.start(
        <String, Object?>{
          'version': <String, Object?>{
            'name': '1.7.10',
            'protocol': 5,
          },
          'players': <String, Object?>{
            'max': 20,
            'online': 0,
          },
          'description': 'Legacy Forge',
          'modinfo': <String, Object?>{
            'type': 'FML',
            'modList': <Object?>[
              <String, Object?>{
                'modid': 'Forge',
                'version': '10.13.4.1614',
              },
              <String, Object?>{
                'modid': 'example',
                'version': '1.0',
              },
            ],
          },
        },
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoServerStatus status =
          await const MtnMinecraftInfoServerStatusClient().query(
        host: InternetAddress.loopbackIPv4.address,
        port: fixture.port,
        measureLatency: false,
      );
      await fixture.done;

      final MtnMinecraftInfoServerModMetadata metadata = status.modMetadata!;
      expect(metadata.loader, MtnMinecraftInfoServerModLoader.forge);
      expect(metadata.mods, hasLength(2));
      expect(metadata.mods.last.id, 'example');
      expect(metadata.mods.last.versionMarker, '1.0');
      expect(metadata.channels, isEmpty);
      expect(metadata.advertisedListsComplete, isNull);
    });
  });
}

final class _StatusFixture {
  _StatusFixture._({
    required this.server,
    required this.done,
  });

  final ServerSocket server;
  final Future<void> done;

  int get port => server.port;

  static Future<_StatusFixture> start(
    Map<String, Object?> response, {
    bool expectPing = false,
  }) async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<void> done = Completer<void>();

    server.listen((Socket socket) {
      unawaited(
        _handleClient(
          socket,
          port: server.port,
          response: response,
          expectPing: expectPing,
        ).then<void>(
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

  static Future<void> _handleClient(
    Socket socket, {
    required int port,
    required Map<String, Object?> response,
    required bool expectPing,
  }) async {
    final _TestSocketReader socketReader = _TestSocketReader(socket);
    try {
      final _TestPacketReader handshake =
          await _readPacket(socketReader);
      expect(handshake.readVarInt(), 0);
      expect(handshake.readVarInt(), -1);
      expect(handshake.readString(), InternetAddress.loopbackIPv4.address);
      expect(handshake.readUint16(), port);
      expect(handshake.readVarInt(), 1);
      expect(handshake.isAtEnd, isTrue);

      final _TestPacketReader request = await _readPacket(socketReader);
      expect(request.readVarInt(), 0);
      expect(request.isAtEnd, isTrue);

      socket.add(
        _encodePacket(
          <int>[
            ..._encodeVarInt(0),
            ..._encodeString(jsonEncode(response)),
          ],
        ),
      );
      await socket.flush();

      if (expectPing) {
        final _TestPacketReader ping = await _readPacket(socketReader);
        expect(ping.readVarInt(), 1);
        final int payload = ping.readInt64();
        expect(ping.isAtEnd, isTrue);

        final ByteData pongPayload = ByteData(8)
          ..setInt64(0, payload, Endian.big);
        socket.add(
          _encodePacket(
            <int>[
              ..._encodeVarInt(1),
              ...pongPayload.buffer.asUint8List(),
            ],
          ),
        );
        await socket.flush();
      }
    } finally {
      socket.destroy();
    }
  }
}

Future<_TestPacketReader> _readPacket(_TestSocketReader reader) async {
  final int length = await reader.readVarInt();
  return _TestPacketReader(await reader.readBytes(length));
}

Uint8List _encodePacket(List<int> payload) {
  return Uint8List.fromList(
    <int>[
      ..._encodeVarInt(payload.length),
      ...payload,
    ],
  );
}

List<int> _encodeString(String value) {
  final List<int> bytes = utf8.encode(value);
  return <int>[
    ..._encodeVarInt(bytes.length),
    ...bytes,
  ];
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

final class _TestSocketReader {
  _TestSocketReader(Stream<Uint8List> stream)
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

final class _TestPacketReader {
  _TestPacketReader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int _offset = 0;

  bool get isAtEnd => _offset == bytes.length;

  int readVarInt() {
    var result = 0;
    for (var index = 0; index < 5; index++) {
      final int byte = _readByte();
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
    final String result =
        utf8.decode(bytes.sublist(_offset, _offset + length));
    _offset += length;
    return result;
  }

  int readUint16() {
    final int result = _data.getUint16(_offset, Endian.big);
    _offset += 2;
    return result;
  }

  int readInt64() {
    final int result = _data.getInt64(_offset, Endian.big);
    _offset += 8;
    return result;
  }

  int _readByte() => bytes[_offset++];
}
