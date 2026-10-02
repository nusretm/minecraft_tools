# Changelog

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
