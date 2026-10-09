## 1.0.0-dev.1
- Initial Minecraft loader support discovery package, migrated from the v4 standalone prototype.
- Loader-independent catalog, lazy version-specific builds, and one-hour JSON caches.
- Vanilla, Fabric, Quilt, Forge, NeoForge CLI demo plus focused tests.
- Replaced package-local model identities with public re-exports from `minecraft_models` pinned at `51aad868649d4c147f5a4645e2c92111a6cae44e`; cache schema 1 remains compatible and missing channel data restores as `unknown`.
- Added provider-layer loader channel classification while preserving exact upstream version IDs and URLs.
- Added public catalog state and exact/stable-first version resolution with unknown fallback, stale-data safety and per-key discovery results.
- Added network-independent shared-identity, provider parsing, catalog state, resolver, cache and concurrency coverage.
