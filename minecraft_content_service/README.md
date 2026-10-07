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

CurseForge integration, multi-provider aggregation, dependency solving and update/materialization reconciliation remain separate later checkpoints.
