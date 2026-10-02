# Changelog

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
