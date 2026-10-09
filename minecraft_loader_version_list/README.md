# minecraft_loader_version_list

Independent pure-Dart package for selecting Minecraft loader providers. Migrated
from the v4 version-list prototype; no dependency on `mtn_launcher`.

## Contract

- `MtnLauncherGameLoaderVersionList.load()` obtains and caches the **complete supported Minecraft version catalog** for one loader.
- `supportsMinecraftVersion(mcVersion, [types])` is synchronous and reads that catalog. Call `load()` first; if `hasMinecraftVersionCatalog` is false, support is unknown, not disproven.
- `loadMinecraftVersion(mcVersion, [types])` fetches the compatible loader builds on demand.
- `getFromMinecraftVersion(mcVersion, [types])` filters only already generated/cached loader builds.
- `MtnLauncherGameLoaderVersion.url` is provided by the loader's callback and persisted verbatim.
- A single JSON file per loader stores the support catalog and lazily generated builds, with independent one-hour timestamps. Expired data remains available if a refresh fails.
- `downloadUrl()` sets `errorCode` / `errorMessage` and throws; callbacks need no catch. The list's load methods catch and retain prior data when possible.

The supported version record `(mcVersion, versionId, type)` keeps the exact
upstream version identifier for API requests, distinct from a grouped Minecraft
version (e.g. `1.21.1-pre1` versus `1.21.1`).

## Five loader examples

`example/loader_versions.dart` demonstrates Vanilla, Fabric, Quilt, Forge and NeoForge
using the same two core classes and provider-specific callbacks. Fabric/Quilt
obtain compatibility from their game-version and version-specific loader APIs.
Forge/NeoForge infer support from published Maven coordinates; published metadata
does not by itself guarantee that every installer artifact exists or works.
NeoForge historical `net.neoforged:forge` is not included in this example.

```powershell
cd minecraft_loader_version_list
dart pub get
dart analyze
dart test
dart run example/loader_versions.dart 1.21.1
```

See `test/` for cache, filter, error-handling and provider-parser coverage.
