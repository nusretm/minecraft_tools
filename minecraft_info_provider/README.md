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
- World-owned immutable player snapshots with isolated player-aggregate status
- Raw Java Edition world `icon.png` read and atomic write
- Java Edition player-data discovery for legacy `playerdata/` and 26.1+ `players/data/`
- Immutable core player metadata with modern-over-legacy UUID precedence
- On-demand Java Edition player statistics for legacy `stats/` and 26.1+ `players/stats/`
- Generic immutable statistics maps that preserve unknown vanilla, future and modded keys
- On-demand Java Edition player advancement progress for legacy `advancements/` and 26.1+ `players/advancements/`
- Immutable advancement progress with authoritative `done` state and UTC criterion timestamps
- Player gameplay-core metadata including rotation, game modes, health,
  absorption, food, XP, abilities, selected hotbar slot, respawn and last-death
- Cross-version respawn normalization from legacy `Spawn*`, 1.21.5
  `respawn.angle`, and 1.21.9+ `respawn.yaw` / `respawn.pitch`
- Immutable 36-slot player inventory and 27-slot ender chest snapshots
- Minimal semantic `MtnMinecraftInfoItemStack` with namespaced item ID and count
- Legacy armor/off-hand slot normalization and modern player equipment support
- Legacy `Count` and modern `count` item-stack count normalization
- Cross-version item core-property normalization for damage, repair cost,
  unbreakable state, active enchantments and stored enchantments
- Preservation of modern explicitly removed component IDs without requiring
  an item registry

## Usage

```dart
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

final info = MtnMinecraftInfoProvider(
  gameDirectory: Directory(r'C:\Users\me\AppData\Roaming\.minecraft'),
);

final servers = await info.readServers();
final worlds = await info.readWorlds();
final players = worlds.isEmpty
    ? const <MtnMinecraftInfoPlayer>[]
    : worlds.first.players;
final iconBytes = worlds.isEmpty ? null : worlds.first.icon;

if (worlds.isNotEmpty && worlds.first.players.isNotEmpty) {
  final stats = await info.readPlayerStats(
    worlds.first,
    worlds.first.players.first,
  );
  print(stats?.values['minecraft:custom']?['minecraft:jump']);

  final advancements = await info.readPlayerAdvancements(
    worlds.first,
    worlds.first.players.first,
  );
  print(
    advancements
        ?.advancements['minecraft:story/root']
        ?.done,
  );
}

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
- `MtnMinecraftInfoPlayer`

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
- immutable `players` snapshots discovered with the world
- independent `playersState` / `playersError` aggregate status
- raw nullable `icon` bytes from `icon.png`
- `available` / `invalid` world state
- world-local errors for read, gzip, NBT and schema failures

Filesystem identity and Minecraft display identity remain separate:
`directoryName` is never replaced by `LevelName`.

A missing `saves` directory produces an immutable empty list. Discovery is
deterministically ordered by directory name. Symlink entries are not followed.
One corrupt world does not fail discovery of sibling worlds.

Player discovery is part of the returned world snapshot. A malformed aggregate
player-storage path does not make an otherwise valid `level.dat` world
invalid: `world.state` continues to represent the world metadata, while
`world.playersState` and `world.playersError` report player-list discovery
separately. Individual corrupt player files remain player-local invalid
snapshots.

World icons are read as raw bytes from `<world>/icon.png`. Missing,
non-file or unreadable icon data is represented as `null`; the provider does
not decode, resize or validate PNG image content. Applications can replace an
icon atomically with:

```dart
await info.writeWorldIcon(world, pngBytes);
```

The bytes are persisted as supplied. Image processing remains a caller/UI
responsibility.

This checkpoint intentionally does not normalize version-specific fields such
as difficulty, game mode, spawn, world border or world generation.
`level.dat_old` is not used as an implicit recovery source.

## Java player discovery

`MtnMinecraftInfoWorld.players` contains the player-data snapshots discovered
while reading the world. `MtnMinecraftInfoProvider.readPlayers(world)` remains
available when a caller explicitly wants to re-read the player storage for an
existing world snapshot.

Two on-disk layouts are supported:

```text
pre-26.1:
<world>/playerdata/<uuid>.dat

26.1+:
<world>/players/data/<uuid>.dat
```

When the same canonical UUID exists in both layouts, the modern
`players/data` entry wins deterministically. A corrupt modern entry does not
silently fall back to the legacy copy.

Player identity is derived from the UUID filename. Candidate filenames must use
the standard dashed UUID shape; the public `uuid` value is normalized to
lowercase while `dataFile` preserves the exact discovered filesystem path.

Each player `.dat` file is treated as a gzip container around raw Java NBT:

```text
player .dat bytes
  -> gzip decode
  -> MtnMinecraftNbtCodec.decode()
  -> Compound root
  -> MtnMinecraftInfoPlayer
```

The foundation exposes:

- canonical `uuid`
- exact `dataFile`
- `legacy` / `modern` storage layout
- nullable root `DataVersion`
- nullable root `Dimension`
- nullable three-double `Pos` as `MtnMinecraftInfoPlayerPosition`
- `available` / `invalid` player state
- player-local errors for read, gzip, NBT and schema failures

Missing player-data directories produce an immutable empty list. Results are
deterministically ordered by canonical UUID. Invalid filenames, directories
masquerading as `.dat` files and symlink entries are not treated as players.
One corrupt player does not fail discovery of sibling players.

The supplied world must be a direct child of this provider's `saves`
directory and must still exist as a directory. Invalid storage-directory shapes
remain provider-level path errors.

The player snapshot now also exposes gameplay-core, inventory, ender-chest and
equipment metadata. Item stacks can additionally expose normalized persisted
core properties. Active effects, richer item components and the
singleplayer-player relationship remain separate follow-up foundations.

## Java player gameplay core

Gameplay-core state is parsed from the same player `.dat` snapshot as
`DataVersion`, `Dimension` and `Pos`. No additional player identity or
storage authority is introduced.

The public snapshot can expose:

- `MtnMinecraftInfoPlayerRotation` from root `Rotation`
- current and previous `MtnMinecraftInfoPlayerGameMode`
- nullable `health` and `absorptionAmount`
- grouped `MtnMinecraftInfoPlayerFood`
- grouped `MtnMinecraftInfoPlayerExperience`
- grouped `MtnMinecraftInfoPlayerAbilities`
- nullable selected hotbar slot
- normalized `MtnMinecraftInfoPlayerRespawn`
- nullable `MtnMinecraftInfoPlayerLastDeath`

Persisted values are reported as stored. Missing values remain null; the
provider does not synthesize vanilla defaults.

Player NBT schema parsing is separated from provider filesystem/compression
orchestration through the internal `MtnMinecraftInfoPlayerNbtParser`.
The provider discovers files, reads gzip payloads and decodes raw NBT; the
player parser validates the semantic player schema and produces the immutable
public snapshot.

Game modes are normalized from persisted integer values:

```text
0 -> survival
1 -> creative
2 -> adventure
3 -> spectator
```

A persisted `previousPlayerGameType=-1` is normalized to null. Other unknown
game-mode values are treated as invalid player data.

Respawn storage is normalized into one semantic model across generations:

```text
legacy / 1.20.1-style:
SpawnX / SpawnY / SpawnZ
SpawnAngle
SpawnDimension
SpawnForced

1.21.5-style:
respawn.pos
respawn.angle
respawn.dimension
respawn.forced

1.21.9+:
respawn.pos
respawn.yaw
respawn.pitch
respawn.dimension
respawn.forced
```

When the modern `respawn` compound is present, it is authoritative. A
malformed modern compound does not silently fall back to legacy `Spawn*`
fields.

Inventory, ender-chest contents and equipment are normalized by the next
player-data layer. Item components and active effects remain outside the
gameplay-core checkpoint.

## Java player inventory and equipment

Player inventory/equipment data is parsed from the same player `.dat` snapshot
and exposed without leaking storage-generation slot conventions into callers.

Public models:

```dart
final class MtnMinecraftInfoItemStack {
  final String id;
  final int count;
  final MtnMinecraftInfoItemStackComponents? components;
}

final class MtnMinecraftInfoPlayerEquipment {
  final MtnMinecraftInfoItemStack? head;
  final MtnMinecraftInfoItemStack? chest;
  final MtnMinecraftInfoItemStack? legs;
  final MtnMinecraftInfoItemStack? feet;
  final MtnMinecraftInfoItemStack? offHand;
}
```

`MtnMinecraftInfoPlayer` exposes:

- nullable immutable 36-slot `inventory`
- nullable immutable 27-slot `enderChest`
- nullable normalized `equipment`
- derived nullable `selectedItem` from `selectedItemSlot`

A missing `Inventory` or `EnderItems` tag remains null. A present but empty
list becomes a fixed-size all-null semantic slot list, preserving the
difference between "not persisted" and "persisted empty".

Legacy player inventory slots are normalized as:

```text
0..35  -> player inventory
100    -> feet
101    -> legs
102    -> chest
103    -> head
-106   -> offHand
```

Unknown/future/modded slot numbers are ignored by this foundation rather than
invalidating the entire player snapshot. Duplicate recognized semantic slots
remain invalid player data.

For 1.21.5+ player equipment, the modern `equipment` compound is resolved per
slot. A modern slot value wins for that slot, while an absent modern slot can
fall back to its legacy inventory equivalent. An explicitly present empty
modern slot suppresses legacy fallback for that slot.

Serialized item stacks are parsed through the internal
`MtnMinecraftInfoItemStackNbtParser`. It normalizes:

```text
legacy: Count -> byte
modern: count -> int
missing count -> semantic count 1
```

When both `count` and legacy `Count` exist, the modern `count` field is
authoritative. Zero/non-positive counts and `minecraft:air` normalize to an
empty semantic slot.

Item identifiers are preserved as namespaced strings. The provider does not
need a vanilla or mod registry to expose IDs such as `minecraft:stone`,
`alexsmobs:animal_dictionary` or any other mod namespace.

The inventory/equipment foundation owns item identity/count and storage-slot
routing. Persisted item metadata is delegated to a separate cross-version item
properties parser.

## Java item core properties

`MtnMinecraftInfoItemStack.components` exposes normalized properties that were
explicitly serialized on the stack:

```dart
final class MtnMinecraftInfoItemStackComponents {
  final int? damage;
  final int? repairCost;
  final bool? unbreakable;
  final Map<String, int>? enchantments;
  final Map<String, int>? storedEnchantments;
  final Set<String> removedComponentIds;
}
```

These values are persisted overrides, not a reconstructed effective item from
Minecraft's item registry. Registry defaults are deliberately not synthesized.

Pre-1.20.5 legacy item data is read from `tag`:

```text
Damage
RepairCost
Unbreakable
Enchantments
StoredEnchantments
```

Modern item data is read from the 1.20.5+ `components` patch:

```text
minecraft:damage
minecraft:repair_cost
minecraft:unbreakable
minecraft:enchantments
minecraft:stored_enchantments
```

When a modern `components` compound exists, it is authoritative for this
normalization layer; legacy `tag` is not consulted for the same stack.

Both the 1.20.5-style enchantment payload with a nested `levels` compound and
the later simplified direct enchantment-ID map are normalized to immutable
`Map<String, int>` values. Namespaced enchantment IDs remain open strings so
future and modded enchantments are preserved without a registry.

Modern component-patch removal keys such as `!minecraft:damage` are preserved
as `removedComponentIds`. The provider does not infer the resulting default
value because that requires the item registry.

Unknown legacy tag fields and unknown modern component IDs are tolerated.
Recognized fields remain schema-strict. An explicitly present empty enchantment
collection remains distinguishable from an absent enchantment property.

This first component checkpoint intentionally does not normalize custom
name/lore/text components, custom model data, attribute modifiers, potion data,
container contents, custom data or other richer item metadata.

## Java player statistics

`MtnMinecraftInfoProvider.readPlayerStats(world, player)` reads one
player-owned statistics snapshot on demand. Statistics are not eagerly parsed
by `readWorlds()`, so ordinary world/player discovery does not pay the I/O and
JSON parsing cost for potentially large stats files.

Supported layouts:

```text
pre-26.1:
<world>/stats/<uuid>.json

26.1+:
<world>/players/stats/<uuid>.json
```

Stats storage is resolved independently from the player's data-file layout. A
legacy player-data snapshot can therefore use modern stats, and a modern
player-data snapshot can use legacy stats when that is the data actually
present on disk.

When both stats layouts contain the same UUID, `players/stats` is
authoritative. A corrupt modern file does not silently fall back to an older
legacy copy. Modern storage is resolved first, so an unrelated malformed
legacy stats path does not block valid modern data.

A missing stats file returns `null`. A present file produces
`MtnMinecraftInfoPlayerStats` with:

- canonical player UUID
- exact discovered JSON file
- `legacy` / `modern` stats storage layout
- nullable root `DataVersion`
- `available` / `invalid` state
- `readFailed`, `invalidJson` or `invalidData` error classification
- deeply immutable `Map<String, Map<String, int>> values`

The outer keys are Minecraft statistic categories such as
`minecraft:mined` or `minecraft:custom`; inner keys are the external
statistic/resource identifiers. These keys are intentionally not modeled as a
closed enum so unknown vanilla, future and modded values remain available.

The parser preserves raw integer counters. It does not convert ticks,
centimeters, damage units or other statistic-specific units into higher-level
values.

The supplied player must belong to the supplied world. Player ownership is
validated from the canonical UUID, storage layout and exact player-data path;
a stats JSON file alone never creates a new player identity.

Statistics writing, aggregation/leaderboards and semantic unit conversion are
outside this foundation.

## Java player advancements

`MtnMinecraftInfoProvider.readPlayerAdvancements(world, player)` reads one
player-owned advancement progress snapshot on demand. Advancement progress is
not eagerly parsed by `readWorlds()`.

Supported layouts:

```text
pre-26.1:
<world>/advancements/<uuid>.json

26.1+:
<world>/players/advancements/<uuid>.json
```

Advancement storage is resolved independently from the player's data-file
layout. When both generations contain the same canonical UUID, the modern
`players/advancements` entry is authoritative. A corrupt modern file does
not silently fall back to the legacy copy.

Missing advancement progress returns `null`. A present file produces
`MtnMinecraftInfoPlayerAdvancements` with:

- canonical player UUID
- exact discovered JSON file
- `legacy` / `modern` storage layout
- nullable root `DataVersion`
- `available` / `invalid` state
- `readFailed`, `invalidJson` or `invalidData` error classification
- immutable advancement entries keyed by external resource ID

Each `MtnMinecraftInfoPlayerAdvancement` exposes:

- its external advancement resource ID
- the authoritative stored `done` boolean
- completed criterion names mapped to UTC `DateTime` values

Advancement and criterion identifiers are intentionally preserved as external
strings so vanilla, future and modded namespaces remain available.

The provider does not derive completion from the number of criteria. Progress
requirements belong to advancement definitions, not the player-progress file,
so the stored `done` value remains authoritative.

Player statistics and advancement progress share one internal player-owned JSON
resource reader for UUID/path validation, modern-first storage resolution and
JSON file decoding. Their public models and schema validation remain separate.

Advancement-definition parsing, titles/descriptions/icons, rewards,
requirements, completion percentages, remaining-criteria calculation and
writing are outside this foundation.

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

Real world/player/icon/gameplay/inventory/equipment/item-properties/stats/advancements smoke inspection is available through:

```powershell
dart run tool/query_minecraft_worlds.dart `
  --game-directory "$env:APPDATA\.minecraft"
```

Selecting one world prints its icon path/size:

```powershell
dart run tool/query_minecraft_worlds.dart `
  --game-directory "$env:APPDATA\.minecraft" `
  --world "New World"
```

The tool also prints player gameplay-core state, bounded inventory/ender-chest
previews, normalized equipment, reads player stats and reads advancement
progress on demand. Gameplay output covers rotation, game modes,
health/absorption, food, XP, abilities, selected slot, respawn and last-death.
Inventory output reports occupied slot count, selected item and up to 10
occupied slots. Item preview lines include normalized damage, repair cost,
unbreakable state, enchantments, stored enchantments and removed modern
component IDs. Enchantment/removal previews are bounded. Ender-chest output
uses the same item preview, while equipment prints both the semantic equipment
summary and per-item core properties. Stats output includes layout,
state/error, DataVersion, category count and total counter count. Advancement
output includes layout, state/error, DataVersion,
advancement/completion/criterion counts and a bounded preview of advancement
IDs. Supplying `--set-icon <png>` atomically replaces that world's icon and
re-reads it to verify the persisted bytes.

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
- richer world metadata and cross-version normalization
- richer item-component information: custom name/lore/text, attributes,
  potion/container/custom-data and related properties
- player active effects
- singleplayer UUID relationship
- statistics aggregation / semantic unit conversion / writing
- advancement definitions / semantic progress calculation / writing
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
