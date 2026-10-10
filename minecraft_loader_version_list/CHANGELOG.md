## Unreleased — LVL-I3A2 shared model pin and SHA-1 cache coverage
- Pin `minecraft_models` to LVL-I3A squash merge `a083d402a13ef742d4968a161d2893f4f50482ff`.
- Validate optional source SHA-1 preservation through schema-1 cache publication and offline restore, legacy SHA-less items, and rejection of malformed present values.
- Confirm shared identity of the const source SHA-1 model; no VersionList production-cache algorithm change.

## 1.0.0-dev.1
- Initial Minecraft loader support discovery package, migrated from the v4 standalone prototype.
- Loader-independent catalog, lazy version-specific builds, and one-hour JSON caches.
- Vanilla, Fabric, Quilt, Forge, NeoForge CLI demo plus focused tests.
- Replaced package-local model identities with public re-exports from `minecraft_models` pinned at `51aad868649d4c147f5a4645e2c92111a6cae44e`; cache schema 1 remains compatible and missing channel data restores as `unknown`.
- Added provider-layer loader channel classification while preserving exact upstream version IDs and URLs.
- Added public catalog state and exact/stable-first version resolution with unknown fallback, stale-data safety and per-key discovery results.
- Added network-independent shared-identity, provider parsing, catalog state, resolver, cache and concurrency coverage.
