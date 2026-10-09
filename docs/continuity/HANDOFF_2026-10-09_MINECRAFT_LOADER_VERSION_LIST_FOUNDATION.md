# Minecraft Loader Version List — Foundation Handoff (2026-10-09)

## Ownership and state

- Repository: `nusretm/minecraft_tools`
- Package: `minecraft_loader_version_list/`
- Branch: `feature/minecraft-loader-version-list-foundation`
- Remote baseline HEAD: `86d3e4461ca709e7f2fed8d6ad1f89c624ab7cd9`
- PR: #57, open and draft
- Package version remains `1.0.0-dev.1`.
- This is a standalone pure-Dart package. `mtn_launcher` and sibling packages were not changed.
- `docs/WORKING_RULES.md` remains authoritative; package-specific constraints are in `minecraft_loader_version_list/WORKING_RULES.md`.

No commit, push, PR update or merge was performed during LVL-1A through LVL-1D.

## Completed levels

### LVL-1A — Shared identity migration

- `minecraft_models` is pinned to `51aad868649d4c147f5a4645e2c92111a6cae44e`.
- Package-local duplicates of `MtnLauncherGameLoaderVersion` and `MtnLauncherGameVersionType` were removed.
- The public barrel re-exports the shared model identities, including `MtnLauncherGameLoaderChannel`.
- Existing schema-1 cache remains readable; a missing legacy `channel` restores as `unknown`.

### LVL-1B — Provider channel classification

- Classification remains in `example/loader_versions.dart`, outside generic VersionList core.
- Vanilla uses `unknown`.
- Fabric maps official `stable == true` to `stable`; `false` alone remains `unknown`.
- Quilt, Forge and NeoForge map only explicit beta, alpha or experimental markers.
- Ordinary Maven versions are not inferred as stable.
- Exact upstream build IDs and provider-owned URLs remain unchanged.

### LVL-1C — Catalog state and resolver

- Added `MtnLauncherGameLoaderCatalogState`: `notLoaded`, `fresh`, `stale`, `unavailable`.
- Added public `catalogState` while retaining `hasMinecraftVersionCatalog` and `supportsMinecraftVersion()`.
- A successfully loaded empty catalog is available and fresh.
- Failed refresh with usable expired data remains stale rather than unavailable.
- Added `resolveVersion()` with exact case-sensitive ID selection and stable-first automatic selection.
- Automatic selection optionally falls back to `unknown`; it never selects beta, alpha or experimental builds.
- Exact requests may select any channel and reject conflicting models/URLs for the same ID.
- Small catalog/per-key discovery results distinguish successful empty metadata, unavailable metadata and stale fallback without relying on global `errorCode`.
- Concurrent catalog and same-key build discovery remain coalesced.

### LVL-1D — Documentation and final validation

- Added package working rules.
- Updated README and CHANGELOG to match the real public API and fixed shared-model dependency.
- Extended the example output with catalog state, channel counts and automatic resolver results.
- Completed real Windows provider smoke for Minecraft `1.21.1` and Forge legacy target `1.8.9`.
- Restored the pre-existing ignored `.mtn_loader_cache` after smoke; no smoke artifact entered Git status.

## Public API contract

The public barrel is:

```dart
import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';
```

Shared identities re-exported from `minecraft_models`:

- `MtnLauncherGameLoaderMinecraftVersion`
- `MtnLauncherGameLoaderVersion`
- `MtnLauncherGameVersionType`
- `MtnLauncherGameLoaderChannel`

VersionList-owned API:

- `MtnLauncherGameLoaderVersionList`
- `MtnLauncherGameLoaderCatalogState`
- `load()`
- `catalogState`
- `hasMinecraftVersionCatalog`
- `supportsMinecraftVersion()`
- `loadMinecraftVersion()`
- `getFromMinecraftVersion()`
- `resolveVersion()`
- `downloadUrl()` and diagnostic `errorCode` / `errorMessage`

Provider callbacks own support discovery, channel classification and source URLs. `onLoadFromWeb` returns the complete Minecraft support catalog. `onGenerateMinecraftVersionList` lazily returns concrete builds for an exact upstream game ID. Core does not know provider endpoints or wire formats.

Each provider uses one schema-1 JSON cache with an independent catalog timestamp and per-game-ID generated timestamps. Default freshness is one hour. Writes retain temporary-file/replace publication and stale-data fallback.

## Windows validation

Final LVL-1D validation from `minecraft_loader_version_list/`:

```text
dart pub get       PASS
dart analyze       No issues found
dart test          35/35 PASS
git diff --check   PASS
```

Focused coverage includes 6 provider parsing tests and 16 catalog/resolver tests. The remaining tests cover shared identity, cache compatibility, timestamps, stale fallback, HTTP errors and coalescing.

## Real provider smoke

The first run used an empty temporary smoke cache and contacted the real upstream endpoints. Exact IDs and generated URLs below are the values observed on 2026-10-09.

### Minecraft 1.21.1

| Provider | Catalog | Supported | Builds | Channels | Automatic resolver |
| --- | ---: | --- | ---: | --- | --- |
| Vanilla | fresh, 918 entries | yes | 2 | unknown=2 | `1.21.1-rc1` (`unknown`) |
| Fabric | fresh, 530 entries | yes | 506 | stable=2, unknown=504 | `0.19.5` (`stable`) |
| Quilt | fresh, 441 entries | yes | 614 | beta=498, unknown=116 | `0.30.1` (`unknown`) |
| Forge | fresh, 77 entries | yes | 66 | unknown=66 | `1.21.1-52.1.16` (`unknown`) |
| NeoForge | fresh, 30 entries | yes | 254 | unknown=254 | `21.1.257` (`unknown`) |

Observed exact URL examples:

- Vanilla: `https://piston-meta.mojang.com/v1/packages/cedfc3b6dcbca34e2b478d498bf1d56a8fa2f404/1.21.1.json`
- Fabric: `https://meta.fabricmc.net/v2/versions/loader/1.21.1/0.19.5/profile/json`
- Quilt: `https://meta.quiltmc.org/v3/versions/loader/1.21.1/0.30.1/profile/json`
- Forge: `https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.1-52.1.16/forge-1.21.1-52.1.16-installer.jar`
- NeoForge: `https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.257/neoforge-21.1.257-installer.jar`

Channel output matched the conservative provider rules. Fabric selected official stable metadata. Quilt excluded explicit beta builds from automatic selection and used an unknown build. Forge and NeoForge did not reinterpret ordinary Maven versions as stable.

Vanilla's unfiltered automatic resolver selected `1.21.1-rc1`: both the release and grouped release-candidate IDs have `unknown` loader channel, and best-effort natural ordering ranks the longer RC ID higher. Launcher integration must pass the selected Minecraft `type` when it requires the release entry.

### Minecraft 1.8.9

| Provider | Catalog | Supported | Builds | Channels | Automatic resolver |
| --- | ---: | --- | ---: | --- | --- |
| Vanilla | fresh, 918 entries | yes | 1 | unknown=1 | `1.8.9` (`unknown`) |
| Fabric | fresh, 530 entries | no | not requested | — | — |
| Quilt | fresh, 441 entries | no | not requested | — | — |
| Forge | fresh, 77 entries | yes | 114 | unknown=114 | `1.8.9-11.15.1.2318-1.8.9` (`unknown`) |
| NeoForge | fresh, 30 entries | no | not requested | — | — |

The Forge full upstream version and generated URL were preserved:

```text
1.8.9-11.15.1.2318-1.8.9
https://maven.minecraftforge.net/net/minecraftforge/forge/1.8.9-11.15.1.2318-1.8.9/forge-1.8.9-11.15.1.2318-1.8.9-installer.jar
```

Maven metadata proves publication of coordinates only. The smoke did not download, validate or execute installer artifacts, so artifact existence and runtime usability are not guaranteed by these results.

## Known limitations

- Natural ordering is deterministic best-effort ordering, not verified provider release chronology or SemVer.
- Callers should pass Minecraft `types` when grouped release candidates/snapshots must not participate in selection.
- Forge and NeoForge Minecraft compatibility is inferred from Maven version notation rather than artifact inspection.
- NeoForge legacy `net.neoforged:forge` is outside the example.
- Week-numbered snapshots are not assigned to later releases without authoritative mapping.
- Example-generated profile/installer URLs are provider-owned but are not artifact-health checks.
- `errorCode` and `errorMessage` are diagnostics shared by the list instance; resolver correctness uses operation/key-specific internal results.
- No launcher UI, download, checksum, installation or instance-management integration is included.

## MTN Launcher integration handoff

- Consume only the package public barrel and shared `minecraft_models` identities.
- Register loader-specific callbacks in the launcher's loader/provider layer; do not add provider switches to VersionList core.
- Pass the selected Minecraft version type into `supportsMinecraftVersion`, lazy loading and `resolveVersion` where grouped IDs exist.
- Represent `notLoaded`, `fresh`, `stale` and `unavailable` distinctly in launcher state/UI.
- Treat resolver `StateError` as unavailable/incomplete metadata, not as authoritative unsupported status.
- Persist exact selected upstream build IDs and URLs without normalization.
- Choose launcher-owned cache directory/lifecycle and surface stale fallback appropriately.
- Validate/download installer artifacts in the installation layer; Maven metadata alone is insufficient.

## PR #57 pre-merge checklist

- [x] LVL-1A shared identity migration implemented and tested.
- [x] LVL-1B provider channel classification implemented and tested.
- [x] LVL-1C catalog state and resolver implemented and tested.
- [x] LVL-1D package rules, README, CHANGELOG and continuity updated.
- [x] Windows `dart pub get`, analyzer, full tests and diff check pass.
- [x] Real Vanilla, Fabric, Quilt, Forge and NeoForge smoke completed for `1.21.1`.
- [x] Vanilla/Forge legacy smoke completed for `1.8.9`; unsupported providers reported without fabrication.
- [x] Cache schema remains 1 and no sibling package implementation changed.
- [x] Review the complete tracked and untracked diff.
- [x] Commit LVL-1A/B/C/D changes with user approval.
- [x] Push the branch and update PR #57 with user approval.
- [ ] Perform final PR review and remove draft status only with user approval.
- [ ] Merge PR #57 only with separate explicit user approval.
