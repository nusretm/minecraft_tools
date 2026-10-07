# Changelog

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
