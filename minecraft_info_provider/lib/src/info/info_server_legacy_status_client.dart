import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'info_server_status.dart';

enum _LegacyPingVariant {
  legacy16,
  legacy14,
  legacyPre14,
}

/// Stateless pre-1.7 Java Edition server-list ping client.
///
/// The caller is expected to try the modern Server List Ping first. This client
/// only provides the fallback wire formats used by older Java servers.
final class MtnMinecraftInfoServerLegacyStatusClient {
  const MtnMinecraftInfoServerLegacyStatusClient();

  static const int _maximumResponseCharacters = 32767;

  Future<MtnMinecraftInfoServerStatus?> query({
    required String host,
    required int port,
    required String handshakeHost,
    required int handshakePort,
    Duration timeout = const Duration(seconds: 5),
    bool measureLatency = true,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Timeout must be greater than zero',
      );
    }

    final List<_LegacyPingVariant> variants = <_LegacyPingVariant>[
      _LegacyPingVariant.legacy16,
      _LegacyPingVariant.legacy14,
      _LegacyPingVariant.legacyPre14,
    ];
    final Stopwatch budget = Stopwatch()..start();

    for (var index = 0; index < variants.length; index++) {
      final Duration remaining = timeout - budget.elapsed;
      if (remaining <= Duration.zero) break;

      final int attemptsLeft = variants.length - index;
      final Duration attemptTimeout = Duration(
        microseconds: remaining.inMicroseconds ~/ attemptsLeft,
      );

      final MtnMinecraftInfoServerStatus? status = await _tryVariant(
        variants[index],
        host: host,
        port: port,
        handshakeHost: handshakeHost,
        handshakePort: handshakePort,
        timeout: attemptTimeout,
        measureLatency: measureLatency,
      );
      if (status != null) return status;
    }

    return null;
  }

  Future<MtnMinecraftInfoServerStatus?> _tryVariant(
    _LegacyPingVariant variant, {
    required String host,
    required int port,
    required String handshakeHost,
    required int handshakePort,
    required Duration timeout,
    required bool measureLatency,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      final _LegacySocketReader reader = _LegacySocketReader(socket);

      final Uint8List request = switch (variant) {
        _LegacyPingVariant.legacy16 => _encodeLegacy16Request(
            handshakeHost,
            handshakePort,
          ),
        _LegacyPingVariant.legacy14 => Uint8List.fromList(<int>[0xfe, 0x01]),
        _LegacyPingVariant.legacyPre14 => Uint8List.fromList(<int>[0xfe]),
      };

      final Stopwatch stopwatch = Stopwatch()..start();
      socket.add(request);
      await socket.flush();

      final String? response =
          await _readLegacyResponse(reader).timeout(timeout);
      stopwatch.stop();
      if (response == null) return null;

      return _parseLegacyResponse(
        response,
        variant: variant,
        host: host,
        port: port,
        latency: measureLatency ? stopwatch.elapsed : null,
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on _LegacyProtocolException {
      return null;
    } finally {
      socket?.destroy();
    }
  }

  Future<String?> _readLegacyResponse(_LegacySocketReader reader) async {
    final int packetId = await reader.readByte();
    if (packetId != 0xff) return null;

    final int characterLength = await reader.readUint16();
    if (characterLength < 1 ||
        characterLength > _maximumResponseCharacters) {
      throw const _LegacyProtocolException();
    }

    final Uint8List bytes =
        await reader.readBytes(characterLength * 2);
    return _decodeUtf16Be(bytes);
  }
}

Uint8List _encodeLegacy16Request(String host, int port) {
  final Uint8List channel = _encodeUtf16Be('MC|PingHost');
  final Uint8List hostBytes = _encodeUtf16Be(host);

  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(<int>[0xfe, 0x01, 0xfa]);

  final ByteData channelLength = ByteData(2)
    ..setUint16(0, 'MC|PingHost'.codeUnits.length, Endian.big);
  builder
    ..add(channelLength.buffer.asUint8List())
    ..add(channel);

  final ByteData payloadLength = ByteData(2)
    ..setUint16(0, 7 + hostBytes.length, Endian.big);
  builder
    ..add(payloadLength.buffer.asUint8List())
    ..addByte(78);

  final ByteData hostLength = ByteData(2)
    ..setUint16(0, host.codeUnits.length, Endian.big);
  builder
    ..add(hostLength.buffer.asUint8List())
    ..add(hostBytes);

  final ByteData portBytes = ByteData(4)
    ..setUint32(0, port, Endian.big);
  builder.add(portBytes.buffer.asUint8List());

  return builder.takeBytes();
}

MtnMinecraftInfoServerStatus? _parseLegacyResponse(
  String response, {
  required _LegacyPingVariant variant,
  required String host,
  required int port,
  required Duration? latency,
}) {
  if (response.startsWith('§1\u0000')) {
    final List<String> fields = response.split('\u0000');
    if (fields.length < 6 || fields.first != '§1') return null;

    final int? protocol = int.tryParse(fields[1]);
    final int? online = int.tryParse(fields[4]);
    final int? max = int.tryParse(fields[5]);
    if (protocol == null || online == null || max == null) return null;

    return MtnMinecraftInfoServerStatus(
      state: MtnMinecraftInfoServerState.online,
      host: host,
      port: port,
      format: _formatForVariant(variant),
      versionName: fields[2],
      protocol: protocol,
      onlinePlayers: online,
      maxPlayers: max,
      motd: fields[3],
      latency: latency,
    );
  }

  final int lastSeparator = response.lastIndexOf('§');
  if (lastSeparator <= 0 || lastSeparator == response.length - 1) {
    return null;
  }
  final int secondLastSeparator =
      response.lastIndexOf('§', lastSeparator - 1);
  if (secondLastSeparator < 0) return null;

  final int? online = int.tryParse(
    response.substring(secondLastSeparator + 1, lastSeparator),
  );
  final int? max = int.tryParse(response.substring(lastSeparator + 1));
  if (online == null || max == null) return null;

  return MtnMinecraftInfoServerStatus(
    state: MtnMinecraftInfoServerState.online,
    host: host,
    port: port,
    format: MtnMinecraftInfoServerStatusFormat.legacyPre14,
    onlinePlayers: online,
    maxPlayers: max,
    motd: response.substring(0, secondLastSeparator),
    latency: latency,
  );
}

MtnMinecraftInfoServerStatusFormat _formatForVariant(
  _LegacyPingVariant variant,
) =>
    switch (variant) {
      _LegacyPingVariant.legacy16 =>
        MtnMinecraftInfoServerStatusFormat.legacy16,
      _LegacyPingVariant.legacy14 =>
        MtnMinecraftInfoServerStatusFormat.legacy14,
      _LegacyPingVariant.legacyPre14 =>
        MtnMinecraftInfoServerStatusFormat.legacyPre14,
    };

Uint8List _encodeUtf16Be(String value) {
  final List<int> units = value.codeUnits;
  final Uint8List bytes = Uint8List(units.length * 2);
  final ByteData data = ByteData.sublistView(bytes);
  for (var index = 0; index < units.length; index++) {
    data.setUint16(index * 2, units[index], Endian.big);
  }
  return bytes;
}

String _decodeUtf16Be(Uint8List bytes) {
  if (bytes.length.isOdd) throw const _LegacyProtocolException();

  final ByteData data = ByteData.sublistView(bytes);
  final List<int> units = List<int>.generate(
    bytes.length ~/ 2,
    (int index) => data.getUint16(index * 2, Endian.big),
    growable: false,
  );
  return String.fromCharCodes(units);
}

final class _LegacySocketReader {
  _LegacySocketReader(Stream<Uint8List> stream)
      : _iterator = StreamIterator<Uint8List>(stream);

  final StreamIterator<Uint8List> _iterator;
  Uint8List _current = Uint8List(0);
  int _offset = 0;

  Future<int> readByte() async {
    await _ensureData();
    return _current[_offset++];
  }

  Future<int> readUint16() async {
    final Uint8List bytes = await readBytes(2);
    return ByteData.sublistView(bytes).getUint16(0, Endian.big);
  }

  Future<Uint8List> readBytes(int count) async {
    if (count < 0) throw const _LegacyProtocolException();

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
        throw const _LegacyProtocolException();
      }
      _current = _iterator.current;
      _offset = 0;
    }
  }
}

final class _LegacyProtocolException implements Exception {
  const _LegacyProtocolException();
}
