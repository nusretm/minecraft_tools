# minecraft_loader_version_list

Independent pure-Dart support catalog, lazy build discovery and version resolver for Minecraft game loaders. The package has no dependency on `mtn_launcher` and keeps provider-specific metadata outside its core.

## Shared models

`MtnLauncherGameLoaderVersion`, `MtnLauncherGameLoaderMinecraftVersion`, `MtnLauncherGameVersionType` and `MtnLauncherGameLoaderChannel` come from `minecraft_models` and are re-exported by this package's public barrel. The dependency is pinned to commit `51aad868649d4c147f5a4645e2c92111a6cae44e`; this package does not define duplicate model identities.

Minecraft version type and loader publication channel are independent. For example, a loader beta may target a Minecraft release. An `unknown` loader channel is not treated as `stable`.

## Public API

Import the public barrel:

```dart
import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';
```

`MtnLauncherGameLoaderVersionList` owns one provider's support catalog and lazily discovered builds:

- `load()` obtains the complete supported-Minecraft catalog from a fresh cache or the provider callback.
- `catalogState` reports `notLoaded`, `fresh`, `stale` or `unavailable` through `MtnLauncherGameLoaderCatalogState`.
- `hasMinecraftVersionCatalog` distinguishes an available catalog, including a successfully loaded empty catalog, from no usable catalog.
- `supportsMinecraftVersion(mcVersion, [types])` synchronously checks the currently available catalog. A negative result from stale or unavailable metadata is not authoritative.
- `loadMinecraftVersion(mcVersion, [types])` lazily discovers compatible loader builds.
- `getFromMinecraftVersion(mcVersion, [types])` returns only builds already generated or restored from cache.
- `resolveVersion(...)` performs exact or automatic selection and triggers the required lazy discovery.

```dart
Future<MtnLauncherGameLoaderVersion?> selectLoader(
  MtnLauncherGameLoaderVersionList versions,
) async {
  await versions.load();

  if (versions.catalogState == MtnLauncherGameLoaderCatalogState.unavailable) {
    throw StateError('Loader catalog is unavailable');
  }

  return versions.resolveVersion(mcVersion: '1.21.1');
}
```

Provider callbacks return the supported record `(mcVersion, versionId, type)` and concrete `MtnLauncherGameLoaderVersion` instances. `versionId`, build `version` and `url` remain exact provider-owned values; core does not normalize IDs or reconstruct source URLs.

## Resolution

With `version` supplied, `resolveVersion()` accepts only exact, case-sensitive `candidate.version == version` matches. It does not compare display text, partial IDs or normalized values. An explicitly requested beta, alpha or experimental build is eligible. Conflicting models or URLs for the same exact ID raise `StateError`.

Without `version`, automatic selection:

1. chooses the highest build classified `stable` using deterministic best-effort natural ordering;
2. falls back to the highest `unknown` build only when `allowUnknownChannelFallback` is true;
3. never automatically selects `beta`, `alpha` or `experimental` builds.

Natural ordering is not a provider-specific semantic-version parser and does not guarantee upstream publication chronology.

## Cache and errors

Each provider uses one schema-1 JSON file. Catalog and generated-build entries have independent timestamps and a one-hour default lifetime. Publication uses a temporary file and replacement step. Expired catalog/build data remains usable as a stale fallback if refresh fails.

Successful empty metadata is different from a failed request. When no usable catalog or build metadata exists, `resolveVersion()` raises `StateError` instead of reporting an authoritative unsupported/no-build result. `errorCode` and `errorMessage` remain diagnostic fields; resolver decisions use operation/key-specific results rather than the global error fields.

## Provider examples

`example/loader_versions.dart` demonstrates Vanilla, Fabric, Quilt, Forge and NeoForge callbacks:

- Vanilla build channels remain `unknown`.
- Fabric uses official `stable == true` metadata; `stable == false` alone remains `unknown`.
- Quilt, Forge and NeoForge only classify explicit beta, alpha or experimental markers; ordinary versions are not assumed stable.
- Fabric and Quilt use their metadata APIs.
- Forge and NeoForge infer compatibility from Maven coordinates. Maven metadata does not prove that an installer artifact exists or is runnable.
- Legacy NeoForge `net.neoforged:forge` is outside the example.

```powershell
cd minecraft_loader_version_list
dart pub get
dart analyze
dart test
dart run example/loader_versions.dart 1.21.1
dart run example/loader_versions.dart 1.8.9
```

See `test/` for catalog state, resolver, cache, error handling and provider parsing coverage.
