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
  const MtnMinecraftInfoServer(
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

- server status/ping
- known-server matching
- address normalization/deduplication policy
- world discovery / `level.dat`
- playerdata
- statistics
- installed-content information
- client-mod activity discovery
