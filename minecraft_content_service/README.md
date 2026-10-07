# minecraft_content_service

Pure Dart Minecraft content domain and provider-service foundation for reusable catalog, version, file, dependency and ownership metadata.

The package models logical Minecraft content independently from any single provider. The same model family can represent mods, modpacks, resource packs, shader packs and data packs while preserving Modrinth, CurseForge and future provider provenance.

Current foundation includes:

- `MtnMinecraftContentModel` serialization and parsing utilities
- `MtnMinecraftContent` base class with concrete content specializations
- version, file, hash, module and dependency metadata
- flat version-to-version `included` / `embedded` relations
- multiple provider metadata records on one logical content/version/file
- JSON / UTF-8 round-trip through `MtnMinecraftContentList`
- duplicate logical provider identity protection
- version selection where `content.version` uses the explicit selection or falls back to `content.versions.last`
- `MtnMinecraftContentProvider` provider contract
- `MtnMinecraftContentProviderList` explicit provider registry authority
- `MtnMinecraftContentService` registered-provider routing
- provider-independent search and version-list request/result contracts
- `MtnMinecraftContentProviderModrinth` read-only Modrinth v2 search/project/version integration
- Modrinth project, version, file and dependency mapping with raw provider metadata preservation
- `MtnMinecraftContentProviderCurseForge` authenticated CurseForge v1 search/project/file integration
- CurseForge class discovery plus project, file/version, hash, fingerprint, module and dependency mapping
- provider readiness independent from registration, with `readyItems` exposed by the provider registry
- provider-owned serialized request gate and observable `MtnMinecraftContentProviderRateLimit` state
- Modrinth rate-limit header tracking and one bounded HTTP 429 retry when a reset duration is supplied
- CurseForge HTTP 429 / `Retry-After` handling without inventing an undocumented fixed request quota

Multi-provider aggregation, dependency solving and update/materialization reconciliation remain separate later checkpoints.


## CLI example

A small live provider search example is available at `example/mc_content.dart`.

```powershell
dart run example/mc_content.dart --provider modrinth --content mod --filter "Skyblocker" --mc-version 26.1.2 --loader fabric
```

The example currently supports the Modrinth provider and maps provider, content type, query, Minecraft version, and loader arguments into the generic content search request.
