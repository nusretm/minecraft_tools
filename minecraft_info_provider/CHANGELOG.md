# Changelog

## 1.0.0-dev.8

Java Edition player discovery foundation.

- Added `MtnMinecraftInfoPlayer`, `MtnMinecraftInfoPlayerPosition` and
  `MtnMinecraftInfoPlayerStorageLayout`.
- Added `MtnMinecraftInfoProvider.readPlayers(world)`.
- Added support for pre-26.1 `playerdata/<uuid>.dat` and 26.1+
  `players/data/<uuid>.dat` layouts.
- Added deterministic modern-over-legacy precedence for duplicate UUIDs without
  silently falling back when the modern entry is corrupt.
- Added filename-based canonical lowercase UUID identity while preserving the
  exact discovered `dataFile`.
- Added gzip decoding around the existing raw NBT codec without changing the
  NBT API.
- Added nullable core player metadata for `DataVersion`, `Dimension` and a
  three-double `Pos`.
- Added player-local `available` / `invalid` state and
  read/compression/NBT/data error classification so one corrupt player does not
  fail sibling discovery.
- Added deterministic UUID ordering, provider/world path validation and
  non-following filesystem discovery behavior.
- Kept inventory, health, hunger, XP, game mode, abilities, effects, spawn,
  stats, advancements and singleplayer UUID association out of this foundation.
- Added deterministic player-discovery coverage; full package validation passes
  with `dart analyze` and 62/62 tests on Windows.

## 1.0.0-dev.7

Java Edition world discovery / `level.dat` foundation.

- Added `MtnMinecraftInfoWorld` and `MtnMinecraftInfoWorldVersion`.
- Added `MtnMinecraftInfoProvider.savesDirectory` and `readWorlds()`.
- Added direct `<gameDirectory>/saves/*/level.dat` discovery.
- Added gzip decoding as a file-format wrapper around the existing raw NBT
  codec without changing the NBT API.
- Added core immutable metadata for `LevelName`, `DataVersion`, `Version` and
  `LastPlayed`.
- Kept filesystem directory identity separate from Minecraft `LevelName`.
- Added world-local `available` / `invalid` state and read/compression/NBT/data
  error classification so one corrupt world does not fail sibling discovery.
- Added deterministic directory ordering and non-following symlink behavior.
- Kept `level.dat_old`, player data, difficulty, spawn, world border and
  world-generation normalization out of this foundation checkpoint.
- Added deterministic world-discovery coverage; full package validation passes
  with `dart analyze` and 47/47 tests on Windows.

## 1.0.0-dev.6

Legacy pre-1.7 Java server-list ping fallback.

- Added transparent legacy fallback after modern status timeout or invalid
  modern packet framing.
- Added Minecraft 1.6 extended `FE 01 FA` / `MC|PingHost` support.
- Added Minecraft 1.4/1.5 `FE 01` support.
- Added pre-1.4 `FE` ping support.
- Added `MtnMinecraftInfoServerStatusFormat` to distinguish modern and
  legacy responses.
- Preserved malformed modern JSON/schema as `invalidResponse` without hiding
  it behind legacy fallback.
- Preserved the existing modern stale/grace lifecycle: a previously modern
  server is not downgraded to a legacy snapshot after a transient timeout.
- Added `allowLegacyFallback` to `MtnMinecraftInfoServer.queryStatus()`
  and `--no-legacy` to the query tool.
- Added legacy ping RTT measurement when latency measurement is enabled.
- Added deterministic transport-level tests for all three legacy request
  variants and strict modern-only behavior.


## 1.0.0-dev.5

Server address normalization and known-server matching foundation.

- Added `MtnMinecraftInfoServerAddress` as the shared Java server address
  parser/normalizer.
- Unified status/SRV routing with the public address parser.
- Canonicalized DNS case, trailing dots, default port 25565, and IPv4/IPv6
  textual forms without mutating persisted `servers.dat` addresses.
- Added `MtnMinecraftInfoKnownServer` and explicit match evidence:
  `exact`, `normalized`, `resolvedEndpoint`, and `none`.
- Kept resolved endpoint matching weaker than user-facing address identity.
- Deliberately excluded protocol, MOTD, version, favicon, and player data from
  server identity inference.
- Added deterministic normalization, IPv6, alias, and resolved-endpoint tests.


## 1.0.0-dev.4

Java Edition SRV discovery foundation.

- Added Pure Dart DNS SRV lookup for `_minecraft._tcp.<host>`.
- Bare hostnames now resolve SRV before Server List Ping.
- Explicit ports bypass SRV resolution.
- Added RFC 2782 priority and weighted ordering.
- Added sequential fallback across multiple SRV candidates.
- Kept the original user-facing hostname in the Server List Ping handshake
  while connecting TCP to the resolved SRV target.
- Bounded multi-nameserver SRV resolution to one shared timeout budget.
- Preserved direct `host:25565` fallback when no usable SRV record exists.
- Added explicit handling for SRV target `.` as service unavailable.
- Exposed `MtnMinecraftInfoSrvResolver` for custom/private DNS resolution.
- Added a default UDP resolver using Cloudflare and Google public DNS.
- Added deterministic local UDP DNS parsing tests and server-routing tests.
- Updated the query tool so omitting `--port` exercises SRV discovery.


## 1.0.0-dev.3

Server availability-state correction.

- Added `MtnMinecraftInfoServerState.online/offline/unavailable`.
- DNS failures and never-seen unreachable targets return
  `state=unavailable` instead of throwing.
- Moved reachability history and grace/offline transitions from the raw status
  client into each `MtnMinecraftInfoServer` instance.
- Added `MtnMinecraftInfoServer.queryStatus()`, read-only runtime `status`,
  and `onChange`.
- The stateless raw status client now reports DNS/timeout/connection
  unavailability reasons.
- A previously online server remains online through transient reachability
  failures for a default one-minute grace period.
- Consecutive reachability failures beyond the grace period transition the
  server to `offline`; a successful response resets the window.
- Grace/offline results retain the last known status snapshot with
  `isStale=true`, `lastSuccessfulAt`, and `failureSince`.
- Stale latency is cleared to null so callers can represent measurement as
  pending/unavailable.
- Malformed Minecraft protocol/JSON responses remain exceptions.
- Ping/pong measurement failure remains non-fatal for an otherwise online
  status response.
- Added deterministic unreachable-endpoint and online-to-offline grace
  coverage.

## 1.0.0-dev.2

Java Edition Server Status/Ping foundation.

- Added modern Java Server List Ping over TCP.
- Added version name, protocol, player counts/sample, MOTD, favicon,
  secure-chat flag and optional ping/pong latency.
- Added modern Forge `forgeData` parsing for mods, channels,
  `fmlNetworkVersion` and truncation state.
- Added legacy FML `modinfo.modList` parsing.
- Kept advertised mods distinct from proven client requirements.
- Added explicit required-channel metadata where Forge provides it.
- Preserved the exact raw status JSON for unmodeled loader/proxy fields.
- Added local TCP protocol tests covering handshake, status framing and
  ping/pong.
- Validated with clean analyzer output, 13/13 automated tests, and a live
  `mc.hypixel.net:25565` Server List Ping including successful latency
  measurement.


## 1.0.0-dev.1

Initial extraction from the MtnLauncher prototype into the standalone
`minecraft_tools/minecraft_info_provider` package.

- Added a Pure Dart Java Edition NBT codec covering all standard payload tags,
  big-endian numeric encoding and Java modified UTF-8.
- Added `MtnMinecraftInfoProvider` and `MtnMinecraftInfoServer`.
- Added uncompressed `servers.dat` read and append support.
- Added `hidden`, icon and nullable `acceptTextures` semantics.
- Preserved unknown existing root/server NBT tags while appending.
- Added serialized same-target operations and atomic replacement with rollback.
- Added focused automated tests and a copy-only real-file validator.
- Removed all MtnLauncher compile-time dependencies.
- Validated with clean analyzer output, 10/10 automated tests, and a real
  Java Edition `servers.dat` preserving all pre-existing server compounds.
