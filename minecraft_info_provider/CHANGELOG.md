# Changelog

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
