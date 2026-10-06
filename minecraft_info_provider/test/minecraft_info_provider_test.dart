import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft Info Provider servers.dat', () {
    late Directory gameDirectory;
    late MtnMinecraftInfoProvider provider;

    setUp(() async {
      gameDirectory = await Directory.systemTemp.createTemp(
        'mtn-minecraft-info-',
      );
      provider = MtnMinecraftInfoProvider(gameDirectory: gameDirectory);
    });

    tearDown(() async {
      if (await gameDirectory.exists()) {
        await gameDirectory.delete(recursive: true);
      }
    });

    test('missing servers.dat reads as an empty immutable list', () async {
      final List<MtnMinecraftInfoServer> servers =
          await provider.readServers();

      expect(servers, isEmpty);
      expect(
        () => servers.add(
          MtnMinecraftInfoServer(name: 'x', address: 'x.invalid'),
        ),
        throwsUnsupportedError,
      );
    });

    test('addServer creates uncompressed servers.dat and reads it back',
        () async {
      await provider.addServer(
        MtnMinecraftInfoServer(
          name: 'Provanas Survival',
          address: 'oyna.provanas.com',
          hidden: true,
          acceptServerResourcePacks: true,
        ),
      );

      final List<int> bytes = await provider.serversFile.readAsBytes();
      final List<MtnMinecraftInfoServer> servers =
          await provider.readServers();

      expect(bytes.first, MtnMinecraftNbtType.compound.id);
      expect(bytes.sublist(0, 2), isNot(<int>[0x1f, 0x8b]));
      expect(servers, hasLength(1));
      expect(servers.single.name, 'Provanas Survival');
      expect(servers.single.address, 'oyna.provanas.com');
      expect(servers.single.hidden, isTrue);
      expect(servers.single.acceptServerResourcePacks, isTrue);
    });

    test('append preserves unknown root and existing server tags', () async {
      final MtnMinecraftNbtDocument source = MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'futureRoot': MtnMinecraftNbtValue.long(77),
            'servers': MtnMinecraftNbtValue.list(
              MtnMinecraftNbtList(
                elementType: MtnMinecraftNbtType.compound,
                values: <MtnMinecraftNbtValue>[
                  MtnMinecraftNbtValue.compound(
                    <String, MtnMinecraftNbtValue>{
                      'name': MtnMinecraftNbtValue.string('Existing'),
                      'ip': MtnMinecraftNbtValue.string('existing.invalid'),
                      'futureServerTag': MtnMinecraftNbtValue.intValue(99),
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      );
      await provider.serversFile.writeAsBytes(
        const MtnMinecraftNbtCodec().encode(source),
        flush: true,
      );

      await provider.addServer(
        MtnMinecraftInfoServer(
          name: 'New',
          address: 'new.invalid:25566',
          icon: 'base64-icon',
          hidden: true,
          acceptServerResourcePacks: false,
        ),
      );

      final MtnMinecraftNbtDocument updated =
          const MtnMinecraftNbtCodec().decode(
        await provider.serversFile.readAsBytes(),
      );
      final Map<String, MtnMinecraftNbtValue> root =
          updated.root.asCompound;
      final List<MtnMinecraftNbtValue> values =
          root['servers']!.asList.values;

      expect(root['futureRoot']?.asLong, 77);
      expect(values, hasLength(2));
      expect(
        values.first.asCompound['futureServerTag']?.asInt,
        99,
      );
      expect(values.last.asCompound['name']?.asString, 'New');
      expect(values.last.asCompound['ip']?.asString, 'new.invalid:25566');
      expect(values.last.asCompound['icon']?.asString, 'base64-icon');
      expect(values.last.asCompound['hidden']?.asByte, 1);
      expect(values.last.asCompound['acceptTextures']?.asByte, 0);
    });

    test('addServer can insert at the first position', () async {
      await provider.addServer(
        MtnMinecraftInfoServer(
          name: 'Existing',
          address: 'existing.invalid',
        ),
      );
      await provider.addServer(
        MtnMinecraftInfoServer(
          name: 'First',
          address: 'first.invalid',
          acceptServerResourcePacks: true,
        ),
        first: true,
      );

      final List<MtnMinecraftInfoServer> servers =
          await provider.readServers();

      expect(servers, hasLength(2));
      expect(servers.first.name, 'First');
      expect(servers.first.address, 'first.invalid');
      expect(servers.first.acceptServerResourcePacks, isTrue);
      expect(servers.last.name, 'Existing');
      expect(servers.last.address, 'existing.invalid');
    });

    test('concurrent adds are serialized and none are lost', () async {
      await Future.wait(
        List<Future<void>>.generate(
          12,
          (int index) => provider.addServer(
            MtnMinecraftInfoServer(
              name: 'Server $index',
              address: 'server-$index.invalid',
            ),
          ),
        ),
      );

      final List<MtnMinecraftInfoServer> servers =
          await provider.readServers();

      expect(servers, hasLength(12));
      expect(
        servers.map((MtnMinecraftInfoServer server) => server.address).toSet(),
        hasLength(12),
      );
    });

    test('non-compound NBT root fails with invalidData', () async {
      await provider.serversFile.writeAsBytes(
        const MtnMinecraftNbtCodec().encode(
          MtnMinecraftNbtDocument(
            name: '',
            root: MtnMinecraftNbtValue.string('not-a-compound'),
          ),
        ),
        flush: true,
      );

      expect(
        provider.readServers,
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidData,
          ),
        ),
      );
    });

    test('malformed servers list fails with invalidData', () async {
      final MtnMinecraftNbtDocument source = MtnMinecraftNbtDocument(
        name: '',
        root: MtnMinecraftNbtValue.compound(
          <String, MtnMinecraftNbtValue>{
            'servers': MtnMinecraftNbtValue.string('not-a-list'),
          },
        ),
      );
      await provider.serversFile.writeAsBytes(
        const MtnMinecraftNbtCodec().encode(source),
        flush: true,
      );

      expect(
        provider.readServers,
        throwsA(
          isA<MtnMinecraftInfoProviderException>().having(
            (MtnMinecraftInfoProviderException exception) => exception.error,
            'error',
            MtnMinecraftInfoProviderError.invalidData,
          ),
        ),
      );
    });
  });
}
