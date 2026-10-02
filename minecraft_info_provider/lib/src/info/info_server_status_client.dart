import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'info_server_status.dart';

enum MtnMinecraftInfoServerStatusError {
  invalidPacket(8203),
  invalidResponse(8204);

  const MtnMinecraftInfoServerStatusError(this.code);

  final int code;
}

final class MtnMinecraftInfoServerStatusException implements Exception {
  const MtnMinecraftInfoServerStatusException(this.error);

  final MtnMinecraftInfoServerStatusError error;

  @override
  String toString() =>
      'MtnMinecraftInfoServerStatusException(${error.name})';
}

/// Queries the modern Java Edition Server List Ping endpoint over TCP.
///
/// This is a status query only. It does not authenticate or perform a login
/// handshake, and advertised mod metadata is not treated as a definitive list
/// of client requirements.
final class MtnMinecraftInfoServerStatusClient {
  const MtnMinecraftInfoServerStatusClient();

  static const int _maximumPacketLength = 1024 * 1024;

  Future<MtnMinecraftInfoServerStatus> query({
    required String host,
    int port = 25565,
    Duration timeout = const Duration(seconds: 5),
    int protocolVersion = -1,
    bool measureLatency = true,
    String? handshakeHost,
    int? handshakePort,
  }) async {
    final String normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Host must not be empty');
    }
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Timeout must be greater than zero',
      );
    }
    if (InternetAddress.tryParse(normalizedHost) == null) {
      try {
        final List<InternetAddress> resolved =
            await InternetAddress.lookup(normalizedHost).timeout(timeout);
        if (resolved.isEmpty) {
          return MtnMinecraftInfoServerStatus.unavailable(
            host: normalizedHost,
            port: port,
            reason: MtnMinecraftInfoServerUnavailableReason.dns,
          );
        }
      } on TimeoutException {
        return MtnMinecraftInfoServerStatus.unavailable(
          host: normalizedHost,
          port: port,
          reason: MtnMinecraftInfoServerUnavailableReason.dns,
        );
      } on SocketException {
        return MtnMinecraftInfoServerStatus.unavailable(
          host: normalizedHost,
          port: port,
          reason: MtnMinecraftInfoServerUnavailableReason.dns,
        );
      }
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        normalizedHost,
        port,
        timeout: timeout,
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      final _SocketByteReader reader = _SocketByteReader(socket);

      final String rawJson = await _requestStatus(
        socket,
        reader,
        host: handshakeHost?.trim().isNotEmpty == true
            ? handshakeHost!.trim()
            : normalizedHost,
        port: handshakePort ?? port,
        protocolVersion: protocolVersion,
      ).timeout(timeout);

      Duration? latency;
      if (measureLatency) {
        try {
          latency = await _measureLatency(socket, reader).timeout(timeout);
        } on TimeoutException {
          latency = null;
        } on SocketException {
          latency = null;
        } on _StatusProtocolException {
          latency = null;
        }
      }

      return _parseStatus(
        rawJson,
        host: normalizedHost,
        port: port,
        latency: latency,
      );
    } on MtnMinecraftInfoServerStatusException {
      rethrow;
    } on TimeoutException {
      return MtnMinecraftInfoServerStatus.unavailable(
        host: normalizedHost,
        port: port,
        reason: MtnMinecraftInfoServerUnavailableReason.timeout,
      );
    } on SocketException {
      return MtnMinecraftInfoServerStatus.unavailable(
        host: normalizedHost,
        port: port,
        reason: MtnMinecraftInfoServerUnavailableReason.connection,
      );
    } on _StatusProtocolException {
      throw const MtnMinecraftInfoServerStatusException(
        MtnMinecraftInfoServerStatusError.invalidPacket,
      );
    } on _StatusResponseException {
      throw const MtnMinecraftInfoServerStatusException(
        MtnMinecraftInfoServerStatusError.invalidResponse,
      );
    } on FormatException {
      throw const MtnMinecraftInfoServerStatusException(
        MtnMinecraftInfoServerStatusError.invalidResponse,
      );
    } finally {
      socket?.destroy();
    }
  }

  Future<String> _requestStatus(
    Socket socket,
    _SocketByteReader reader, {
    required String host,
    required int port,
    required int protocolVersion,
  }) async {
    final BytesBuilder handshake = BytesBuilder(copy: false)
      ..add(_encodeVarInt(0))
      ..add(_encodeVarInt(protocolVersion))
      ..add(_encodeString(host));

    final ByteData portBytes = ByteData(2)..setUint16(0, port, Endian.big);
    handshake
      ..add(portBytes.buffer.asUint8List())
      ..add(_encodeVarInt(1));

    socket
      ..add(_encodePacket(handshake.takeBytes()))
      ..add(_encodePacket(_encodeVarInt(0)));
    await socket.flush();

    final _PacketReader response = await _readPacket(reader);
    if (response.readVarInt() != 0) {
      throw const _StatusProtocolException();
    }
    final String json = response.readString();
    if (!response.isAtEnd) {
      throw const _StatusProtocolException();
    }
    return json;
  }

  Future<Duration> _measureLatency(
    Socket socket,
    _SocketByteReader reader,
  ) async {
    final int payload = DateTime.now().microsecondsSinceEpoch;
    final ByteData value = ByteData(8)
      ..setInt64(0, payload, Endian.big);
    final BytesBuilder ping = BytesBuilder(copy: false)
      ..add(_encodeVarInt(1))
      ..add(value.buffer.asUint8List());

    final Stopwatch stopwatch = Stopwatch()..start();
    socket.add(_encodePacket(ping.takeBytes()));
    await socket.flush();

    final _PacketReader pong = await _readPacket(reader);
    if (pong.readVarInt() != 1 || pong.readInt64() != payload || !pong.isAtEnd) {
      throw const _StatusProtocolException();
    }
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  Future<_PacketReader> _readPacket(_SocketByteReader reader) async {
    final int length = await reader.readVarInt();
    if (length <= 0 || length > _maximumPacketLength) {
      throw const _StatusProtocolException();
    }
    return _PacketReader(await reader.readBytes(length));
  }
}


MtnMinecraftInfoServerStatus _parseStatus(
  String rawJson, {
  required String host,
  required int port,
  required Duration? latency,
}) {
  final Object? decoded = jsonDecode(rawJson) as Object?;
  final Map<String, Object?> root = _expectObject(decoded);
  final Map<String, Object?> version = _expectObject(root['version']);
  final Map<String, Object?> players = _expectObject(root['players']);

  final String versionName = _expectString(version['name']);
  final int protocol = _expectInt(version['protocol']);
  final int onlinePlayers = _expectInt(players['online']);
  final int maxPlayers = _expectInt(players['max']);

  final List<MtnMinecraftInfoServerStatusPlayer> sample =
      <MtnMinecraftInfoServerStatusPlayer>[];
  final Object? sampleValue = players['sample'];
  if (sampleValue != null) {
    final List<Object?> values = _expectList(sampleValue);
    for (final Object? value in values) {
      final Map<String, Object?> player = _expectObject(value);
      sample.add(
        MtnMinecraftInfoServerStatusPlayer(
          id: _expectString(player['id']),
          name: _expectString(player['name']),
        ),
      );
    }
  }

  final Object? faviconValue = root['favicon'];
  final String? favicon = faviconValue == null
      ? null
      : _expectString(faviconValue);
  final Object? secureChatValue = root['enforcesSecureChat'];
  final bool? enforcesSecureChat = secureChatValue == null
      ? null
      : _expectBool(secureChatValue);

  final MtnMinecraftInfoServerModMetadata? modMetadata =
      _parseModMetadata(root);
  final Object? isModdedValue = root['isModded'];
  final bool explicitlyModded =
      isModdedValue == null ? false : _expectBool(isModdedValue);

  return MtnMinecraftInfoServerStatus(
    state: MtnMinecraftInfoServerState.online,
    host: host,
    port: port,
    format: MtnMinecraftInfoServerStatusFormat.modern,
    versionName: versionName,
    protocol: protocol,
    onlinePlayers: onlinePlayers,
    maxPlayers: maxPlayers,
    playerSample: sample,
    motd: _chatPlainText(root['description']),
    rawJson: rawJson,
    favicon: favicon,
    latency: latency,
    enforcesSecureChat: enforcesSecureChat,
    advertisesModded: explicitlyModded || modMetadata != null,
    modMetadata: modMetadata,
  );
}

MtnMinecraftInfoServerModMetadata? _parseModMetadata(
  Map<String, Object?> root,
) {
  final Object? forgeDataValue = root['forgeData'];
  if (forgeDataValue != null) {
    final Map<String, Object?> forgeData = _expectObject(forgeDataValue);
    final List<MtnMinecraftInfoServerAdvertisedMod> mods =
        <MtnMinecraftInfoServerAdvertisedMod>[];
    final List<MtnMinecraftInfoServerAdvertisedChannel> channels =
        <MtnMinecraftInfoServerAdvertisedChannel>[];

    final Object? modsValue = forgeData['mods'];
    if (modsValue != null) {
      for (final Object? value in _expectList(modsValue)) {
        final Map<String, Object?> mod = _expectObject(value);
        mods.add(
          MtnMinecraftInfoServerAdvertisedMod(
            id: _expectString(mod['modId']),
            versionMarker: _optionalString(mod['modmarker']),
          ),
        );
      }
    }

    final Object? channelsValue = forgeData['channels'];
    if (channelsValue != null) {
      for (final Object? value in _expectList(channelsValue)) {
        final Map<String, Object?> channel = _expectObject(value);
        channels.add(
          MtnMinecraftInfoServerAdvertisedChannel(
            name: _expectString(channel['res']),
            version: _expectString(channel['version']),
            requiredForClient: _expectBool(channel['required']),
          ),
        );
      }
    }

    final Object? networkVersion = forgeData['fmlNetworkVersion'];
    final Object? truncated = forgeData['truncated'];
    return MtnMinecraftInfoServerModMetadata(
      loader: MtnMinecraftInfoServerModLoader.forge,
      mods: mods,
      channels: channels,
      fmlNetworkVersion:
          networkVersion == null ? null : _expectInt(networkVersion),
      advertisedListsComplete:
          truncated == null ? null : !_expectBool(truncated),
    );
  }

  final Object? legacyValue = root['modinfo'];
  if (legacyValue == null) return null;

  final Map<String, Object?> legacy = _expectObject(legacyValue);
  final String type = _expectString(legacy['type']);
  final List<MtnMinecraftInfoServerAdvertisedMod> mods =
      <MtnMinecraftInfoServerAdvertisedMod>[];
  final Object? modListValue = legacy['modList'];
  if (modListValue != null) {
    for (final Object? value in _expectList(modListValue)) {
      final Map<String, Object?> mod = _expectObject(value);
      mods.add(
        MtnMinecraftInfoServerAdvertisedMod(
          id: _expectString(mod['modid']),
          versionMarker: _optionalString(mod['version']),
        ),
      );
    }
  }
  return MtnMinecraftInfoServerModMetadata(
    loader: type == 'FML'
        ? MtnMinecraftInfoServerModLoader.forge
        : MtnMinecraftInfoServerModLoader.unknown,
    mods: mods,
    channels: const <MtnMinecraftInfoServerAdvertisedChannel>[],
  );
}

String _chatPlainText(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is List<Object?>) {
    return value.map(_chatPlainText).join();
  }
  if (value is Map<String, Object?>) {
    final StringBuffer result = StringBuffer();
    final Object? text = value['text'];
    if (text is String) result.write(text);
    final Object? extra = value['extra'];
    if (extra is List<Object?>) {
      for (final Object? child in extra) {
        result.write(_chatPlainText(child));
      }
    }
    return result.toString();
  }
  throw const _StatusResponseException();
}

Map<String, Object?> _expectObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw const _StatusResponseException();
}

List<Object?> _expectList(Object? value) {
  if (value is List<Object?>) return value;
  throw const _StatusResponseException();
}

String _expectString(Object? value) {
  if (value is String) return value;
  throw const _StatusResponseException();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  return _expectString(value);
}

int _expectInt(Object? value) {
  if (value is int) return value;
  throw const _StatusResponseException();
}

bool _expectBool(Object? value) {
  if (value is bool) return value;
  throw const _StatusResponseException();
}

Uint8List _encodePacket(List<int> payload) {
  final BytesBuilder packet = BytesBuilder(copy: false)
    ..add(_encodeVarInt(payload.length))
    ..add(payload);
  return packet.takeBytes();
}

Uint8List _encodeString(String value) {
  final List<int> bytes = utf8.encode(value);
  final BytesBuilder encoded = BytesBuilder(copy: false)
    ..add(_encodeVarInt(bytes.length))
    ..add(bytes);
  return encoded.takeBytes();
}

Uint8List _encodeVarInt(int value) {
  var remaining = value & 0xffffffff;
  final BytesBuilder result = BytesBuilder(copy: false);
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    result.addByte(byte);
  } while (remaining != 0);
  return result.takeBytes();
}

final class _SocketByteReader {
  _SocketByteReader(Stream<Uint8List> stream)
      : _iterator = StreamIterator<Uint8List>(stream);

  final StreamIterator<Uint8List> _iterator;
  Uint8List _current = Uint8List(0);
  int _offset = 0;

  Future<int> readByte() async {
    await _ensureData();
    return _current[_offset++];
  }

  Future<Uint8List> readBytes(int count) async {
    if (count < 0) throw const _StatusProtocolException();
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
    throw const _StatusProtocolException();
  }

  Future<void> _ensureData() async {
    while (_offset >= _current.length) {
      if (!await _iterator.moveNext()) {
        throw const _StatusProtocolException();
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
    throw const _StatusProtocolException();
  }

  String readString() {
    final int length = readVarInt();
    if (length < 0 || _offset + length > bytes.length) {
      throw const _StatusProtocolException();
    }
    final String result = utf8.decode(
      bytes.sublist(_offset, _offset + length),
    );
    _offset += length;
    return result;
  }

  int readInt64() {
    if (_offset + 8 > bytes.length) {
      throw const _StatusProtocolException();
    }
    final int result = _data.getInt64(_offset, Endian.big);
    _offset += 8;
    return result;
  }

  int _readByte() {
    if (_offset >= bytes.length) {
      throw const _StatusProtocolException();
    }
    return bytes[_offset++];
  }
}

final class _StatusProtocolException implements Exception {
  const _StatusProtocolException();
}

final class _StatusResponseException implements Exception {
  const _StatusResponseException();
}
