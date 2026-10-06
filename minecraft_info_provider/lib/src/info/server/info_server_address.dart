import 'dart:io';

/// Parsed and normalized Minecraft Java server address.
///
/// [source] preserves the caller-provided value. [canonicalAddress] is intended
/// for identity comparisons and never replaces persisted `servers.dat` data.
final class MtnMinecraftInfoServerAddress {
  MtnMinecraftInfoServerAddress._({
    required this.source,
    required this.host,
    required this.port,
    required this.hasExplicitPort,
    required this.canonicalHost,
    required this.canonicalAddress,
  });

  factory MtnMinecraftInfoServerAddress.parse(String address) {
    final String source = address.trim();
    if (source.isEmpty) {
      throw ArgumentError.value(
        address,
        'address',
        'Server address must not be empty',
      );
    }

    late final String host;
    late final int port;
    late final bool hasExplicitPort;

    if (source.startsWith('[')) {
      final int closing = source.indexOf(']');
      if (closing <= 1) {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid bracketed IPv6 server address',
        );
      }

      host = source.substring(1, closing);
      if (closing == source.length - 1) {
        port = 25565;
        hasExplicitPort = false;
      } else {
        if (source[closing + 1] != ':') {
          throw ArgumentError.value(
            address,
            'address',
            'Invalid bracketed IPv6 server address',
          );
        }
        port = _parsePort(source.substring(closing + 2), address);
        hasExplicitPort = true;
      }
    } else {
      final int firstColon = source.indexOf(':');
      final int lastColon = source.lastIndexOf(':');

      if (firstColon >= 0 && firstColon == lastColon) {
        host = source.substring(0, firstColon);
        if (host.isEmpty) {
          throw ArgumentError.value(
            address,
            'address',
            'Server host must not be empty',
          );
        }
        port = _parsePort(source.substring(firstColon + 1), address);
        hasExplicitPort = true;
      } else {
        host = source;
        port = 25565;
        hasExplicitPort = false;
      }
    }

    if (host.trim().isEmpty) {
      throw ArgumentError.value(
        address,
        'address',
        'Server host must not be empty',
      );
    }

    final String canonicalHost = _canonicalizeHost(host);
    return MtnMinecraftInfoServerAddress._(
      source: source,
      host: host,
      port: port,
      hasExplicitPort: hasExplicitPort,
      canonicalHost: canonicalHost,
      canonicalAddress: _formatCanonicalAddress(canonicalHost, port),
    );
  }

  factory MtnMinecraftInfoServerAddress.endpoint({
    required String host,
    required int port,
  }) {
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }

    final String sourceHost = host.trim();
    if (sourceHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Host must not be empty');
    }

    final String canonicalHost = _canonicalizeHost(sourceHost);
    return MtnMinecraftInfoServerAddress._(
      source: _formatAddress(sourceHost, port, alwaysIncludePort: true),
      host: sourceHost,
      port: port,
      hasExplicitPort: true,
      canonicalHost: canonicalHost,
      canonicalAddress: _formatCanonicalAddress(canonicalHost, port),
    );
  }

  /// Original trimmed address.
  final String source;

  /// Host as supplied by the caller, excluding IPv6 brackets.
  final String host;

  /// Effective port. Bare addresses use Java Edition's default 25565.
  final int port;

  /// Whether the input explicitly included a port.
  final bool hasExplicitPort;

  /// Lower-cased DNS hostname, or normalized textual IP address.
  final String canonicalHost;

  /// Canonical identity string. The default port 25565 is omitted.
  final String canonicalAddress;

  bool sameIdentity(MtnMinecraftInfoServerAddress other) =>
      canonicalAddress == other.canonicalAddress;

  bool sameEndpoint(MtnMinecraftInfoServerAddress other) =>
      canonicalHost == other.canonicalHost && port == other.port;

  @override
  String toString() => canonicalAddress;
}

int _parsePort(String raw, String address) {
  final int? port = int.tryParse(raw);
  if (port == null || port < 1 || port > 65535) {
    throw ArgumentError.value(
      address,
      'address',
      'Server port must be in the range 1..65535',
    );
  }
  return port;
}

String _canonicalizeHost(String host) {
  final String trimmed = host.trim();
  final InternetAddress? ip = InternetAddress.tryParse(trimmed);
  if (ip != null) {
    return ip.type == InternetAddressType.IPv6
        ? _canonicalizeIpv6(ip.rawAddress)
        : ip.rawAddress.join('.');
  }

  var normalized = trimmed.toLowerCase();
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty) {
    throw ArgumentError.value(host, 'host', 'Host must not be empty');
  }
  return normalized;
}

String _formatCanonicalAddress(String host, int port) {
  if (port == 25565) return _formatHost(host);
  return '${_formatHost(host)}:$port';
}

String _formatAddress(
  String host,
  int port, {
  required bool alwaysIncludePort,
}) {
  if (!alwaysIncludePort && port == 25565) return _formatHost(host);
  return '${_formatHost(host)}:$port';
}

String _formatHost(String host) => host.contains(':') ? '[$host]' : host;


String _canonicalizeIpv6(List<int> bytes) {
  if (bytes.length != 16) {
    throw ArgumentError.value(bytes, 'bytes', 'IPv6 address must be 16 bytes');
  }

  final List<int> words = List<int>.generate(
    8,
    (int index) => (bytes[index * 2] << 8) | bytes[index * 2 + 1],
    growable: false,
  );

  var bestStart = -1;
  var bestLength = 0;
  var index = 0;
  while (index < words.length) {
    if (words[index] != 0) {
      index++;
      continue;
    }

    final int start = index;
    while (index < words.length && words[index] == 0) {
      index++;
    }
    final int length = index - start;
    if (length >= 2 && length > bestLength) {
      bestStart = start;
      bestLength = length;
    }
  }

  final List<String> parts = words
      .map((int word) => word.toRadixString(16))
      .toList(growable: false);

  if (bestStart < 0) {
    return parts.join(':');
  }

  final String left = parts.sublist(0, bestStart).join(':');
  final String right =
      parts.sublist(bestStart + bestLength).join(':');

  if (left.isEmpty && right.isEmpty) return '::';
  if (left.isEmpty) return '::$right';
  if (right.isEmpty) return '$left::';
  return '$left::$right';
}
