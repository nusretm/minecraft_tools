# Changelog

## 1.0.0-dev.4

- Add authenticated `MtnMinecraftContentProviderCurseForge` foundation.
- Discover Minecraft CurseForge content classes through the categories endpoint instead of hardcoding class IDs.
- Add CurseForge v1 search, project/description and paginated file/version requests.
- Map CurseForge file IDs, hashes, fingerprints, modules and dependency relation types into the generic model.
- Preserve raw provider response maps without exposing API keys.
- Keep unsupported multi-class and multi-version-file filter shapes explicit instead of returning incorrect pagination.

## 1.0.0-dev.3

- Add read-only `MtnMinecraftContentProviderModrinth` foundation.
- Add Modrinth v2 search, project and project-version requests.
- Map Modrinth project/version/file/dependency metadata into the generic content model.
- Preserve full provider response maps alongside normalized fields.
- Require an application-specific Modrinth User-Agent.
- Keep pagination and release-type filtering compatible with the generic provider contract.

## 1.0.0-dev.2

- Add `MtnMinecraftContentProvider` base contract.
- Add explicit `MtnMinecraftContentProviderList` registry authority.
- Add `MtnMinecraftContentService` routing for registered providers.
- Add provider-independent search and version-list request/result contracts.
- Keep concrete provider HTTP/API behavior outside the generic core.

## 1.0.0-dev.1

- Add reusable Minecraft content model foundation.
- Add content specializations for mods, modpacks, resource packs, shader packs and data packs.
- Add version, file, dependency and version-to-version relation models.
- Add provider metadata preservation for multi-provider logical content.
- Add JSON/UTF-8 serialization and content-list graph restoration.
