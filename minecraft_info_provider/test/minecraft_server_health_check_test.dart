import 'dart:async';
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft server health check', () {
    test('auto-check interval is clamped to 15 seconds', () {
      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Server',
        address: 'example.invalid',
      );

      expect(server.autoCheck, isFalse);
      expect(server.autoCheckSec, 15);

      server.autoCheckSec = 0;
      expect(server.autoCheckSec, 15);

      server.autoCheckSec = 14;
      expect(server.autoCheckSec, 15);

      server.autoCheckSec = 30;
      expect(server.autoCheckSec, 30);

      server.dispose();
    });

    test('checker queries immediately on add and coordinates lifecycle',
        () async {
      final ServerSocket reserved = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final int unavailablePort = reserved.port;
      await reserved.close();

      var originalChanges = 0;
      var adds = 0;
      var changes = 0;
      var removes = 0;
      final Completer<void> firstChange = Completer<void>();

      final MtnMinecraftInfoServer server = MtnMinecraftInfoServer(
        name: 'Server',
        address: '127.0.0.1:$unavailablePort',
        onChange: (MtnMinecraftInfoServer server) {
          originalChanges++;
        },
      );
      final MtnMinecraftInfoServerHealthCheck checker =
          MtnMinecraftInfoServerHealthCheck(
        intervalSec: 0,
        onAdd: (
          MtnMinecraftInfoServerHealthCheck checker,
          MtnMinecraftInfoServer server,
        ) {
          adds++;
        },
        onChange: (
          MtnMinecraftInfoServerHealthCheck checker,
          MtnMinecraftInfoServer server,
        ) {
          changes++;
          if (!firstChange.isCompleted) firstChange.complete();
        },
        onRemove: (
          MtnMinecraftInfoServerHealthCheck checker,
          MtnMinecraftInfoServer server,
        ) {
          removes++;
        },
      );

      expect(checker.intervalSec, 15);
      expect(checker.add(server), isTrue);
      expect(checker.add(server), isFalse);
      expect(checker.servers, <MtnMinecraftInfoServer>[server]);
      expect(adds, 1);
      expect(server.autoCheckSec, 15);
      expect(server.autoCheck, isFalse);
      expect(
        () => checker.servers.add(
          MtnMinecraftInfoServer(
            name: 'Other',
            address: 'other.invalid',
          ),
        ),
        throwsUnsupportedError,
      );

      checker.start();
      expect(checker.active, isTrue);

      await firstChange.future.timeout(const Duration(seconds: 5));

      expect(originalChanges, 1);
      expect(changes, 1);
      expect(server.status, isNotNull);
      expect(server.autoCheck, isTrue);

      checker.intervalSec = 30;
      expect(checker.intervalSec, 30);
      expect(server.autoCheckSec, 30);
      expect(server.autoCheck, isTrue);

      checker.stop();
      expect(checker.active, isFalse);
      expect(server.autoCheck, isFalse);

      expect(checker.remove(server), isTrue);
      expect(checker.remove(server), isFalse);
      expect(checker.servers, isEmpty);
      expect(removes, 1);
      expect(server.autoCheck, isFalse);
      expect(server.onChange, isNull);
      expect(() => server.autoCheck = true, throwsStateError);

      checker.dispose();
    });

    test('dispose removes and disposes every managed server', () {
      var removes = 0;
      final MtnMinecraftInfoServer first = MtnMinecraftInfoServer(
        name: 'First',
        address: 'first.invalid',
      );
      final MtnMinecraftInfoServer second = MtnMinecraftInfoServer(
        name: 'Second',
        address: 'second.invalid',
      );
      final MtnMinecraftInfoServerHealthCheck checker =
          MtnMinecraftInfoServerHealthCheck(
        onRemove: (
          MtnMinecraftInfoServerHealthCheck checker,
          MtnMinecraftInfoServer server,
        ) {
          removes++;
        },
      );

      checker.add(first);
      checker.add(second);
      checker.start();
      checker.dispose();

      expect(removes, 2);
      expect(checker.servers, isEmpty);
      expect(first.autoCheck, isFalse);
      expect(second.autoCheck, isFalse);
      expect(() => first.autoCheck = true, throwsStateError);
      expect(() => second.autoCheck = true, throwsStateError);
      expect(checker.dispose, returnsNormally);
    });
  });
}
