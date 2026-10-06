import 'info_server.dart';
import 'info_server_address.dart';
import 'info_server_status.dart';

enum MtnMinecraftInfoServerMatchKind {
  none,
  exact,
  normalized,
  resolvedEndpoint,
}

final class MtnMinecraftInfoServerMatch {
  const MtnMinecraftInfoServerMatch({
    required this.kind,
    required this.knownServer,
    this.matchedAddress,
  });

  final MtnMinecraftInfoServerMatchKind kind;
  final MtnMinecraftInfoKnownServer knownServer;
  final MtnMinecraftInfoServerAddress? matchedAddress;

  bool get isMatch => kind != MtnMinecraftInfoServerMatchKind.none;
}

/// Application-defined known Minecraft server/network.
///
/// [addresses] are user-facing aliases. They are compared before any resolved
/// TCP endpoint because multiple aliases may legitimately share one backend.
final class MtnMinecraftInfoKnownServer {
  MtnMinecraftInfoKnownServer({
    required this.name,
    required Iterable<String> addresses,
  }) : addresses = List<MtnMinecraftInfoServerAddress>.unmodifiable(
          addresses.map(MtnMinecraftInfoServerAddress.parse),
        ) {
    if (this.addresses.isEmpty) {
      throw ArgumentError.value(
        addresses,
        'addresses',
        'At least one known server address is required',
      );
    }
  }

  final String name;
  final List<MtnMinecraftInfoServerAddress> addresses;

  MtnMinecraftInfoServerMatch match(MtnMinecraftInfoServer server) {
    final String raw = server.address.trim();

    for (final MtnMinecraftInfoServerAddress address in addresses) {
      if (raw == address.source) {
        return MtnMinecraftInfoServerMatch(
          kind: MtnMinecraftInfoServerMatchKind.exact,
          knownServer: this,
          matchedAddress: address,
        );
      }
    }

    final MtnMinecraftInfoServerAddress normalized =
        MtnMinecraftInfoServerAddress.parse(server.address);
    for (final MtnMinecraftInfoServerAddress address in addresses) {
      if (normalized.sameIdentity(address)) {
        return MtnMinecraftInfoServerMatch(
          kind: MtnMinecraftInfoServerMatchKind.normalized,
          knownServer: this,
          matchedAddress: address,
        );
      }
    }

    final MtnMinecraftInfoServerStatus? status = server.status;
    if (status != null) {
      final MtnMinecraftInfoServerAddress resolved =
          MtnMinecraftInfoServerAddress.endpoint(
        host: status.host,
        port: status.port,
      );
      for (final MtnMinecraftInfoServerAddress address in addresses) {
        if (resolved.sameEndpoint(address)) {
          return MtnMinecraftInfoServerMatch(
            kind: MtnMinecraftInfoServerMatchKind.resolvedEndpoint,
            knownServer: this,
            matchedAddress: address,
          );
        }
      }
    }

    return MtnMinecraftInfoServerMatch(
      kind: MtnMinecraftInfoServerMatchKind.none,
      knownServer: this,
    );
  }
}
