import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft SRV resolver', () {
    test('queries _minecraft._tcp and orders lower priority first', () async {
      final _DnsSrvFixture fixture = await _DnsSrvFixture.start(
        <MtnMinecraftInfoSrvRecord>[
          const MtnMinecraftInfoSrvRecord(
            priority: 10,
            weight: 1,
            port: 25566,
            target: 'secondary.example.test',
          ),
          const MtnMinecraftInfoSrvRecord(
            priority: 0,
            weight: 1,
            port: 25565,
            target: 'primary.example.test',
          ),
        ],
      );
      addTearDown(fixture.close);

      final MtnMinecraftInfoDnsSrvResolver resolver =
          MtnMinecraftInfoDnsSrvResolver(
        nameservers: <String>[InternetAddress.loopbackIPv4.address],
        nameserverPort: fixture.port,
        random: Random(7),
      );

      final List<MtnMinecraftInfoSrvRecord> records =
          await resolver.lookupMinecraft(
        host: 'play.example.test',
        timeout: const Duration(seconds: 1),
      );

      expect(
        await fixture.queryName,
        '_minecraft._tcp.play.example.test',
      );
      expect(records, hasLength(2));
      expect(records.first.priority, 0);
      expect(records.first.target, 'primary.example.test');
      expect(records.first.port, 25565);
      expect(records.last.priority, 10);
      expect(records.last.target, 'secondary.example.test');
      expect(records.last.port, 25566);
    });

    test('does not query SRV for an IP address', () async {
      final MtnMinecraftInfoDnsSrvResolver resolver =
          MtnMinecraftInfoDnsSrvResolver(
        nameservers: const <String>['127.0.0.1'],
        nameserverPort: 1,
        random: Random(1),
      );

      final List<MtnMinecraftInfoSrvRecord> records =
          await resolver.lookupMinecraft(
        host: '127.0.0.1',
        timeout: const Duration(milliseconds: 50),
      );

      expect(records, isEmpty);
    });
  });
}

final class _DnsSrvFixture {
  _DnsSrvFixture._({
    required this.socket,
    required this.queryName,
    required this.subscription,
  });

  final RawDatagramSocket socket;
  final Future<String> queryName;
  final StreamSubscription<RawSocketEvent> subscription;

  int get port => socket.port;

  static Future<_DnsSrvFixture> start(
    List<MtnMinecraftInfoSrvRecord> answers,
  ) async {
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<String> queryName = Completer<String>();

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final Uint8List request = datagram!.data;
        if (request.length < 17) continue;

        final _DnsQuestion question = _readQuestion(request);
        if (!queryName.isCompleted) {
          queryName.complete(question.name);
        }

        final Uint8List response = _buildResponse(
          request,
          questionEnd: question.endOffset,
          answers: answers,
        );
        socket.send(response, datagram.address, datagram.port);
      }
    });

    return _DnsSrvFixture._(
      socket: socket,
      queryName: queryName.future,
      subscription: subscription,
    );
  }

  Future<void> close() async {
    await subscription.cancel();
    socket.close();
  }
}

final class _DnsQuestion {
  const _DnsQuestion({
    required this.name,
    required this.endOffset,
  });

  final String name;
  final int endOffset;
}

_DnsQuestion _readQuestion(Uint8List request) {
  var offset = 12;
  final List<String> labels = <String>[];
  while (true) {
    if (offset >= request.length) {
      throw StateError('Truncated DNS test question');
    }
    final int length = request[offset++];
    if (length == 0) break;
    if (offset + length > request.length) {
      throw StateError('Truncated DNS test label');
    }
    labels.add(
      String.fromCharCodes(request.sublist(offset, offset + length)),
    );
    offset += length;
  }
  if (offset + 4 > request.length) {
    throw StateError('Truncated DNS test question type/class');
  }
  offset += 4;
  return _DnsQuestion(
    name: labels.join('.'),
    endOffset: offset,
  );
}

Uint8List _buildResponse(
  Uint8List request, {
  required int questionEnd,
  required List<MtnMinecraftInfoSrvRecord> answers,
}) {
  final ByteData requestHeader = ByteData.sublistView(request);
  final BytesBuilder builder = BytesBuilder(copy: false);
  final ByteData header = ByteData(12)
    ..setUint16(0, requestHeader.getUint16(0, Endian.big), Endian.big)
    ..setUint16(2, 0x8180, Endian.big)
    ..setUint16(4, 1, Endian.big)
    ..setUint16(6, answers.length, Endian.big);
  builder
    ..add(header.buffer.asUint8List())
    ..add(request.sublist(12, questionEnd));

  for (final MtnMinecraftInfoSrvRecord answer in answers) {
    final Uint8List target = _encodeDnsName(answer.target);
    final ByteData fixed = ByteData(18)
      ..setUint16(0, 0xc00c, Endian.big)
      ..setUint16(2, 33, Endian.big)
      ..setUint16(4, 1, Endian.big)
      ..setUint32(6, 30, Endian.big)
      ..setUint16(10, 6 + target.length, Endian.big)
      ..setUint16(12, answer.priority, Endian.big)
      ..setUint16(14, answer.weight, Endian.big)
      ..setUint16(16, answer.port, Endian.big);
    builder
      ..add(fixed.buffer.asUint8List())
      ..add(target);
  }

  return builder.takeBytes();
}

Uint8List _encodeDnsName(String name) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  for (final String label in name.split('.')) {
    final List<int> bytes = label.codeUnits;
    builder
      ..addByte(bytes.length)
      ..add(bytes);
  }
  builder.addByte(0);
  return builder.takeBytes();
}
