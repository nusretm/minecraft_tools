# Minecraft Info Provider

Pure Dart Minecraft local-information package and Java Edition NBT toolkit.

The package is independent from MtnLauncher and Flutter. Applications can use
it to inspect or update supported Minecraft local data without importing
launcher runtime, package-management or UI code.

## Current scope

- Generic Java Edition NBT binary codec
- Big-endian numeric payloads
- Java modified UTF-8 strings
- Every standard NBT payload tag
- Java Edition `servers.dat` read
- Java Edition `servers.dat` append
- Preservation of unknown existing NBT tags
- Server name, address, icon, hidden-address state and resource-pack policy
- Serialized same-file operations and atomic replacement
- Java Edition `_minecraft._tcp` SRV discovery for bare hostnames
- Server address normalization and known-server matching
- Legacy pre-1.7 Java server-list ping fallback
- Java Edition `saves/*/level.dat` world discovery
- Gzip-wrapped `level.dat` decoding through the existing raw NBT codec
- Immutable core world metadata and per-world invalid/corrupt status

## Usage

```dart
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

final info = MtnMinecraftInfoProvider(
  gameDirectory: Directory(r'C:\Users\me\AppData\Roaming\.minecraft'),
);

final servers = await info.readServers();
final worlds = await info.readWorlds();

await info.addServer(
  MtnMinecraftInfoServer(
    name: 'Example',
    address: 'play.example.net',
  ),
);
```

## Public naming

Information models use the locked `MtnMinecraftInfo<Subject>` convention:

- `MtnMinecraftInfoServer`
- `MtnMinecraftInfoWorld`
- future `MtnMinecraftInfoPlayer`

The NBT layer is format-oriented and intentionally separate from semantic
Minecraft info models.

## Java world discovery

`MtnMinecraftInfoProvider.readWorlds()` discovers direct child directories
under `<gameDirectory>/saves` that contain a regular `level.dat` file.

`level.dat` is treated as an outer gzip container. The decompressed bytes are
decoded by the existing `MtnMinecraftNbtCodec`; compression is not added to the
raw NBT API.

The first world foundation exposes:

- filesystem `directory` and `directoryName`
- Minecraft `LevelName` as nullable `name`
- nullable `DataVersion`
- nullable `Version` metadata (`Id`, `Name`, `Snapshot`, `Series`)
- nullable `LastPlayed` as UTC `DateTime`
- `levelFile` and `iconFile` path accessors
- `available` / `invalid` world state
- world-local errors for read, gzip, NBT and schema failures

Filesystem identity and Minecraft display identity remain separate:
`directoryName` is never replaced by `LevelName`.

A missing `saves` directory produces an immutable empty list. Discovery is
deterministically ordered by directory name. Symlink entries are not followed.
One corrupt world does not fail discovery of sibling worlds.

This checkpoint intentionally does not normalize version-specific fields such
as difficulty, game mode, spawn, world border, player data or world generation.
`level.dat_old` is not used as an implicit recovery source.

## Java server status

The primary API is owned by `MtnMinecraftInfoServer`:

```dart
final server = MtnMinecraftInfoServer(
  name: 'Example',
  address: 'mc.example.net',
  onChange: (server) {
    print(server.status?.state);
  },
);

final status = await server.queryStatus();

print(status.state);
print(status.versionName);
print(status.protocol);
print(status.onlinePlayers);
print(status.maxPlayers);
print(status.motd);
print(status.latency);
```

`MtnMinecraftInfoServer.status` is read-only runtime state and is never
persisted into `servers.dat`. `queryStatus()` invokes the raw Server List
Ping client internally, compares the result with the current status, updates
the effective state, and invokes `onChange` only when the effective public
status changes.

The raw `MtnMinecraftInfoServerStatusClient` remains a stateless transport
primitive. It performs the standard TCP handshake, requests the JSON status
response, optionally measures ping/pong latency, and reports transport
unavailability reasons. It does not own server history.

Network reachability is domain state, not an exception.

- A target that has never produced a successful status response is
  `unavailable` when it cannot be reached.
- DNS resolution failure is always `unavailable`.
- After one successful response, transient connect/status failures keep the
  same server instance effectively `online` during a one-minute grace window.
- The grace window starts with the first consecutive non-DNS failure, not from
  the last successful query.
- If consecutive non-DNS failures continue past the grace window, the server
  instance becomes `offline`.
- Any successful response resets the failure window immediately.
- Grace/offline states retain the last successful snapshot with
  `isStale=true`; latency is cleared to null.
- `lastSuccessfulAt` and `failureSince` expose the relevant timestamps.

The default grace is one minute and can be overridden per
`server.queryStatus(offlineAfter: ...)`. History belongs to the
`MtnMinecraftInfoServer` instance; different objects do not share runtime
state.

Malformed Minecraft protocol packets or malformed status JSON remain
exceptions because an endpoint was reached but returned invalid data.

A ping/pong failure after a valid status response does not change
`state=online`; only `latency` becomes null.

Recognized Forge metadata is exposed without turning advisory information into
guaranteed client requirements:

- legacy `modinfo.modList`
- modern `forgeData.mods`
- modern `forgeData.channels`
- `fmlNetworkVersion`
- `truncated`

A listed mod is therefore an **advertised mod**, not automatically a required
client mod. Modern Forge channel entries carry an explicit
`requiredForClient` flag and are modeled as such. List completeness is
true/false only when the response provides enough information; otherwise it is
null.

The exact status JSON is retained in `rawJson` so loader/proxy-specific fields
that are not modeled yet are not lost.

Server List Ping is not a login handshake. A successful query does not prove
that authentication, loader negotiation or final join compatibility will
succeed.

## Legacy pre-1.7 server ping fallback

`MtnMinecraftInfoServer.queryStatus()` tries the modern Java Server List Ping
first. By default, legacy fallback is enabled:

```dart
final status = await server.queryStatus(
  allowLegacyFallback: true,
);
```

Fallback is attempted only when the modern endpoint was reachable enough to
suggest a protocol mismatch:

- modern status timeout
- invalid modern packet framing

Malformed modern JSON or malformed modern status schema remains
`MtnMinecraftInfoServerStatusError.invalidResponse` and does not fall back.

Once a server instance has already produced a successful modern response,
transient modern timeouts do not downgrade that instance to a legacy snapshot.
The existing stale/grace lifecycle is preserved. Legacy discovery is intended
for previously unknown or already-legacy servers.

The fallback order is:

1. Minecraft 1.6 extended ping: `FE 01 FA` with `MC|PingHost`
2. Minecraft 1.4/1.5 ping: `FE 01`
3. pre-1.4 ping: `FE`

The status exposes which wire format succeeded:

```dart
switch (status.format) {
  case MtnMinecraftInfoServerStatusFormat.modern:
  case MtnMinecraftInfoServerStatusFormat.legacy16:
  case MtnMinecraftInfoServerStatusFormat.legacy14:
  case MtnMinecraftInfoServerStatusFormat.legacyPre14:
  case null:
}
```

Legacy 1.6/1.4-style responses can provide protocol version, displayed server
version, MOTD, online players and max players. Very old responses provide only
MOTD and player counts, so `protocol` and `versionName` remain null.

Legacy responses do not provide modern JSON-only metadata such as favicon,
secure-chat state, player samples or Forge status metadata. `rawJson` is null.
Legacy latency, when requested, is measured over the legacy ping
request/response because those formats have no separate modern ping/pong
packet.

Set `allowLegacyFallback: false` when a caller wants strict modern-only
behavior. The command-line query tool exposes the same behavior with
`--no-legacy`.

## Java server SRV discovery

When a server address is a bare hostname, `queryStatus()` first checks:

```text
_minecraft._tcp.<hostname>
```

If SRV records exist, their target host and port become the TCP status target.
The resulting `MtnMinecraftInfoServerStatus.host` and `.port` therefore
represent the actual resolved endpoint, while `MtnMinecraftInfoServer.address`
continues to preserve the address supplied by the user.

For Server List Ping specifically, the TCP connection uses the resolved SRV
target while the handshake address remains the original user-facing hostname
(and its address-form port). This matches current vanilla status-ping behavior
and keeps proxy/virtual-host routing compatible.

SRV candidate ordering follows RFC 2782:

- lower numeric priority is attempted first
- records with equal priority are selected using their weight
- if one candidate cannot be reached, the next ordered candidate is attempted

A single SRV target of `.` explicitly marks the service unavailable and does
not fall back to port 25565.

SRV lookup only occurs when no port was explicitly supplied. For example:

```text
play.example.net
  -> SRV lookup enabled

play.example.net:25565
  -> explicit target, SRV skipped
```

When no usable SRV record exists, the package falls back to the original
hostname on Java's default port 25565.

The default Pure Dart resolver sends UDP SRV queries to Cloudflare
(`1.1.1.1`) and then Google (`8.8.8.8`) within one shared lookup timeout
budget. Applications that need a private,
split-DNS or system-specific resolver can inject their own
`MtnMinecraftInfoSrvResolver` into `server.queryStatus()`.

A real server can be checked with SRV enabled by omitting `--port`:

```powershell
dart run tool/query_minecraft_server.dart `
  --host play.example.net
```

To bypass SRV explicitly:

```powershell
dart run tool/query_minecraft_server.dart `
  --host play.example.net `
  --port 25565
```

The tool prints both the original address and the actual resolved target.

## Server address normalization and known-server matching

`MtnMinecraftInfoServerAddress` parses and canonicalizes Java server
addresses without changing the persisted value stored in
`MtnMinecraftInfoServer.address`.

Examples:

```text
Example.COM.           -> example.com
example.com:25565      -> example.com
example.com:25566      -> example.com:25566
2001:0db8::1           -> [2001:db8::1]
[2001:db8::1]:25565    -> [2001:db8::1]
```

Normalization covers:

- surrounding whitespace
- DNS case folding
- trailing DNS root dots
- default Java port equivalence
- IPv4/IPv6 textual normalization
- bracketed IPv6 address formatting

The original address is preserved. Canonicalization exists only for identity
and endpoint comparisons.

Applications can define known networks/servers with
`MtnMinecraftInfoKnownServer`:

```dart
final known = MtnMinecraftInfoKnownServer(
  name: 'Example Network',
  addresses: [
    'play.example.net',
    'example.net:25566',
  ],
);

final match = known.match(server);

switch (match.kind) {
  case MtnMinecraftInfoServerMatchKind.exact:
  case MtnMinecraftInfoServerMatchKind.normalized:
    // Strong user-facing address evidence.
    break;
  case MtnMinecraftInfoServerMatchKind.resolvedEndpoint:
    // Weaker evidence: the current resolved TCP backend matched.
    break;
  case MtnMinecraftInfoServerMatchKind.none:
    break;
}
```

Match precedence is:

1. exact trimmed user-facing address
2. normalized address identity
3. current resolved endpoint from `server.status`
4. no match

Resolved endpoint matching is intentionally weaker. Multiple domains may share
the same proxy or backend, so the package does not automatically infer a unique
known server from protocol, MOTD, version, player counts, favicon, or a shared
resolved endpoint.

## NBT boundary

`MtnMinecraftNbtCodec` reads/writes raw Java Edition NBT payloads. Compression
is an outer file concern. `servers.dat` is uncompressed; future readers such
as `level.dat` may wrap the codec in gzip without changing the NBT model.

The raw codec accepts any non-`TAG_End` root. File-specific providers impose
their own schema requirements. The `servers.dat` provider requires a compound
root with a compound-list `servers` field.

## Validation

```powershell
dart pub get
dart analyze
dart test
```

A real Java Edition `servers.dat` can be validated without modifying it:

```powershell
dart run tool/validate_minecraft_info_provider.dart `
  --servers-file "C:\path\to\.minecraft\servers.dat"
```

The validator copies the source to a temporary directory, reads it through the
public provider, appends a validation server to the copy, re-reads it and
verifies preservation of every pre-existing server compound.

## Validation status

Validated on Windows with Dart:

- `dart analyze` -> no issues
- `dart test` -> 10/10 PASS
- real Java Edition `servers.dat` -> PASS
  - 32780 bytes
  - 2 existing servers parsed
  - append produced 3 servers
  - all pre-existing server compounds preserved

## Deferred

- address deduplication/write policy
- world discovery / `level.dat`
- playerdata
- statistics
- installed-content information
- client-mod activity discovery


## Server status validation status

Java Edition modern Server Status/Ping foundation is COMPLETE / VALIDATED / LOCKED.

Validated on Windows with Dart:

- `dart analyze` -> no issues
- `dart test` -> 13/13 PASS
- real `mc.hypixel.net:25565` query -> PASS
- real response parsed version/protocol/player counts/MOTD/favicon
- ping/pong latency measured successfully
- missing/failed latency measurement remains non-fatal and returns `null`

The real validation observed Hypixel advertising protocol 47 with a multi-version
display string and no recognized mod metadata. This confirms that the provider
must report server-advertised values as-is rather than infer a single playable
client version from the display string.
