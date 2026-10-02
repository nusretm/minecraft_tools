import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

final class MtnMinecraftInfoSrvRecord {
  const MtnMinecraftInfoSrvRecord({
    required this.priority,
    required this.weight,
    required this.port,
    required this.target,
  });

  final int priority;
  final int weight;
  final int port;
  final String target;
}

abstract interface class MtnMinecraftInfoSrvResolver {
  Future<List<MtnMinecraftInfoSrvRecord>> lookupMinecraft({
    required String host,
    Duration timeout = const Duration(seconds: 3),
  });
}

/// Pure Dart DNS SRV resolver for Minecraft Java Edition.
///
/// Queries `_minecraft._tcp.<host>` using UDP DNS. The default resolver list
/// uses Cloudflare and Google public DNS. Applications may provide a different
/// resolver implementation to `MtnMinecraftInfoServer.queryStatus()`.
final class MtnMinecraftInfoDnsSrvResolver
    implements MtnMinecraftInfoSrvResolver {
  MtnMinecraftInfoDnsSrvResolver({
    List<String> nameservers = const <String>['1.1.1.1', '8.8.8.8'],
    this.nameserverPort = 53,
    Random? random,
  })  : nameservers = List<String>.unmodifiable(nameservers),
        _random = random ?? Random.secure();

  final List<String> nameservers;
  final int nameserverPort;
  final Random _random;

  @override
  Future<List<MtnMinecraftInfoSrvRecord>> lookupMinecraft({
    required String host,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final String normalized = host.trim().replaceFirst(RegExp(r'\.$'), '');
    if (normalized.isEmpty || InternetAddress.tryParse(normalized) != null) {
      return const <MtnMinecraftInfoSrvRecord>[];
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Timeout must be greater than zero',
      );
    }

    final String queryName = '_minecraft._tcp.$normalized';
    final Stopwatch budget = Stopwatch()..start();

    for (final String nameserver in nameservers) {
      final Duration remaining = timeout - budget.elapsed;
      if (remaining <= Duration.zero) break;

      try {
        final List<MtnMinecraftInfoSrvRecord> records = await _query(
          queryName: queryName,
          nameserver: nameserver,
          timeout: remaining,
        );
        return _order(records);
      } on TimeoutException {
        continue;
      } on SocketException {
        continue;
      } on FormatException {
        continue;
      }
    }

    return const <MtnMinecraftInfoSrvRecord>[];
  }

  Future<List<MtnMinecraftInfoSrvRecord>> _query({
    required String queryName,
    required String nameserver,
    required Duration timeout,
  }) async {
    final InternetAddress dnsAddress = InternetAddress(nameserver);
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      dnsAddress.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4,
      0,
    );

    StreamSubscription<RawSocketEvent>? subscription;
    try {
      final int id = _random.nextInt(0x10000);
      final Uint8List request = _buildQuery(id, queryName);
      socket.send(request, dnsAddress, nameserverPort);

      final Completer<Uint8List> completer = Completer<Uint8List>();
      subscription = socket.listen(
        (RawSocketEvent event) {
          if (event != RawSocketEvent.read) return;

          Datagram? datagram;
          while ((datagram = socket.receive()) != null) {
            final Uint8List data = datagram!.data;
            if (data.length < 12) continue;

            final ByteData header = ByteData.sublistView(data);
            if (header.getUint16(0, Endian.big) != id) continue;

            if (!completer.isCompleted) {
              completer.complete(data);
            }
            return;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      final Uint8List response = await completer.future.timeout(timeout);
      return _parseResponse(response);
    } finally {
      await subscription?.cancel();
      socket.close();
    }
  }

  List<MtnMinecraftInfoSrvRecord> _order(
    List<MtnMinecraftInfoSrvRecord> records,
  ) {
    if (records.length < 2) {
      return List<MtnMinecraftInfoSrvRecord>.unmodifiable(records);
    }

    final List<MtnMinecraftInfoSrvRecord> remaining =
        List<MtnMinecraftInfoSrvRecord>.of(records)
          ..sort(
            (MtnMinecraftInfoSrvRecord left,
                    MtnMinecraftInfoSrvRecord right) =>
                left.priority.compareTo(right.priority),
          );
    final List<MtnMinecraftInfoSrvRecord> ordered =
        <MtnMinecraftInfoSrvRecord>[];

    while (remaining.isNotEmpty) {
      final int priority = remaining.first.priority;
      final List<MtnMinecraftInfoSrvRecord> group =
          remaining
              .where(
                (MtnMinecraftInfoSrvRecord record) =>
                    record.priority == priority,
              )
              .toList();

      remaining.removeWhere(
        (MtnMinecraftInfoSrvRecord record) => record.priority == priority,
      );

      while (group.isNotEmpty) {
        group.sort(
          (MtnMinecraftInfoSrvRecord left,
                  MtnMinecraftInfoSrvRecord right) =>
              left.weight == 0
                  ? (right.weight == 0 ? 0 : -1)
                  : (right.weight == 0 ? 1 : 0),
        );

        final int totalWeight = group.fold<int>(
          0,
          (int sum, MtnMinecraftInfoSrvRecord record) =>
              sum + record.weight,
        );
        final int pick = _random.nextInt(totalWeight + 1);

        var running = 0;
        var selectedIndex = group.length - 1;
        for (var index = 0; index < group.length; index++) {
          running += group[index].weight;
          if (running >= pick) {
            selectedIndex = index;
            break;
          }
        }

        ordered.add(group.removeAt(selectedIndex));
      }
    }

    return List<MtnMinecraftInfoSrvRecord>.unmodifiable(ordered);
  }
}

Uint8List _buildQuery(int id, String name) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  final ByteData header = ByteData(12)
    ..setUint16(0, id, Endian.big)
    ..setUint16(2, 0x0100, Endian.big)
    ..setUint16(4, 1, Endian.big);

  builder.add(header.buffer.asUint8List());

  for (final String label in name.split('.')) {
    final List<int> bytes = label.codeUnits;
    if (bytes.isEmpty || bytes.length > 63) {
      throw FormatException('Invalid DNS label in $name');
    }
    builder
      ..addByte(bytes.length)
      ..add(bytes);
  }

  builder
    ..addByte(0)
    ..add(<int>[0x00, 0x21, 0x00, 0x01]);

  return builder.takeBytes();
}

List<MtnMinecraftInfoSrvRecord> _parseResponse(Uint8List packet) {
  if (packet.length < 12) {
    throw const FormatException('DNS packet too short');
  }

  final ByteData data = ByteData.sublistView(packet);
  final int flags = data.getUint16(2, Endian.big);
  final int rcode = flags & 0x000f;

  if (rcode == 3) {
    return const <MtnMinecraftInfoSrvRecord>[];
  }
  if (rcode != 0) {
    throw FormatException('DNS response code $rcode');
  }
  if ((flags & 0x0200) != 0) {
    throw const FormatException('Truncated DNS response');
  }

  final int questionCount = data.getUint16(4, Endian.big);
  final int answerCount = data.getUint16(6, Endian.big);
  var offset = 12;

  for (var i = 0; i < questionCount; i++) {
    final _DnsNameResult name = _readDnsName(packet, offset);
    offset = name.nextOffset;
    if (offset + 4 > packet.length) {
      throw const FormatException('Truncated DNS question');
    }
    offset += 4;
  }

  final List<MtnMinecraftInfoSrvRecord> records =
      <MtnMinecraftInfoSrvRecord>[];

  for (var i = 0; i < answerCount; i++) {
    final _DnsNameResult owner = _readDnsName(packet, offset);
    offset = owner.nextOffset;

    if (offset + 10 > packet.length) {
      throw const FormatException('Truncated DNS answer');
    }

    final int type = data.getUint16(offset, Endian.big);
    final int recordClass = data.getUint16(offset + 2, Endian.big);
    final int length = data.getUint16(offset + 8, Endian.big);

    offset += 10;
    final int recordEnd = offset + length;
    if (recordEnd > packet.length) {
      throw const FormatException('Truncated DNS record data');
    }

    if (type == 33 && recordClass == 1) {
      if (length < 7) {
        throw const FormatException('Invalid SRV record');
      }

      final int priority = data.getUint16(offset, Endian.big);
      final int weight = data.getUint16(offset + 2, Endian.big);
      final int port = data.getUint16(offset + 4, Endian.big);
      final _DnsNameResult target = _readDnsName(packet, offset + 6);

      if (target.nextOffset > recordEnd) {
        throw const FormatException('Invalid SRV target');
      }

      final String normalizedTarget = target.name.isEmpty
          ? '.'
          : target.name.replaceFirst(RegExp(r'\.$'), '');

      records.add(
        MtnMinecraftInfoSrvRecord(
          priority: priority,
          weight: weight,
          port: port,
          target: normalizedTarget,
        ),
      );
    }

    offset = recordEnd;
  }

  return records;
}

final class _DnsNameResult {
  const _DnsNameResult({
    required this.name,
    required this.nextOffset,
  });

  final String name;
  final int nextOffset;
}

_DnsNameResult _readDnsName(Uint8List packet, int start) {
  final List<String> labels = <String>[];
  var offset = start;
  int? nextOffset;
  final Set<int> visited = <int>{};

  while (true) {
    if (offset >= packet.length) {
      throw const FormatException('Truncated DNS name');
    }
    if (!visited.add(offset)) {
      throw const FormatException('DNS compression loop');
    }

    final int length = packet[offset];

    if ((length & 0xc0) == 0xc0) {
      if (offset + 1 >= packet.length) {
        throw const FormatException('Truncated DNS pointer');
      }

      final int pointer = ((length & 0x3f) << 8) | packet[offset + 1];
      nextOffset ??= offset + 2;
      offset = pointer;
      continue;
    }

    if ((length & 0xc0) != 0) {
      throw const FormatException('Unsupported DNS label encoding');
    }

    offset++;
    if (length == 0) {
      nextOffset ??= offset;
      break;
    }

    if (offset + length > packet.length) {
      throw const FormatException('Truncated DNS label');
    }

    labels.add(
      String.fromCharCodes(packet.sublist(offset, offset + length)),
    );
    offset += length;
  }

  return _DnsNameResult(
    name: labels.join('.'),
    nextOffset: nextOffset,
  );
}
