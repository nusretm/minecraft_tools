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

## Usage

```dart
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

final info = MtnMinecraftInfoProvider(
  gameDirectory: Directory(r'C:\Users\me\AppData\Roaming\.minecraft'),
);

final servers = await info.readServers();

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
- future `MtnMinecraftInfoWorld`
- future `MtnMinecraftInfoPlayer`

The NBT layer is format-oriented and intentionally separate from semantic
Minecraft info models.

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

SRV discovery and legacy pre-1.7 ping fallback are outside this checkpoint;
`host` and `port` are the concrete TCP target.

A real server can be checked with:

```powershell
dart run tool/query_minecraft_server.dart `
  --host mc.hypixel.net `
  --port 25565
```

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

- known-server matching
- address normalization/deduplication policy
- world discovery / `level.dat`
- playerdata
- statistics
- installed-content information
- client-mod activity discovery


## Server status validation status

Java Edition Server Status/Ping foundation is COMPLETE / VALIDATED / LOCKED.

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
