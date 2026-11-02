# Game Package .mtn folder consolidation — simplified implementation

Date: 2026-11-02
Repository: nusretm/minecraft_tools
Branch: feature/content-private-layout-execution (Draft PR #91)
Status: Source changed; Windows analyzer, tests and real Game Package smoke **pending**.

## Required directory change

Before:
- .mtn-content/installation.json
- .mtn-disabled/mods|resourcepacks|shaderpacks/<file>

After:
- .mtn/content/installation.json
- .mtn/disabled/mods|resourcepacks|shaderpacks/<file>

The Launcher owns .mtn/chat. Never touch chat, user logs, screenshots, worlds or unmanaged files.

## Implemented approach

- Retain read-only dual-layout discovery and the previously tested migration planner. Read may resolve a legacy manifest until explicit migration. New manifest publications and activation use modern paths.
- Explicit `MtnMinecraftContentInstallationManifestFileSystem.migratePrivateLayout(installationRoot: ...)` is the ONLY migration authority. Launcher invokes it at pre-launch preparation only when no game session for that package is running.
- Under the existing in-isolate/exclusive OS writer lock: revalidate the old plan and SHA256; rename the two directories into the existing or new .mtn parent; verify moved disabled file SHA256 and lengths; stage, verify and promote the manifest with rewritten inactive artifact.relativePath values; delete the temporary original manifest backup after success.
- If an ordinary error happens during migration, attempt to restore original manifest and directory names. On a rollback failure, preserve physical data and surface a clear error; never guess, overwrite occupied destinations or delete unmanaged occupants.
- Reject orphan/unknown legacy files, links, case collisions, occupied modern targets and unexpected previous experimental migration metadata. Already-modern or absent roots are no-ops. Do not automatically migrate while Minecraft is running.
- All Content Service writers use a single shared check that rejects legacy Content Service root folders before mutation. The existing OS lock file remains persistent but does not lock Minecraft processes.
- The journal codec, separate recovery inspector and crash-recovery machinery were removed by user's explicit simplification decision. Power-loss and killed-process recovery are not covered. This is an ordinary in-process reversible folder rename, not a transactional storage engine.

## Acceptance

Windows:
```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin
git switch feature/content-private-layout-execution
git pull --ff-only origin feature/content-private-layout-execution
cd minecraft_content_service
dart analyze
dart test test/content_installation_private_layout_plan_test.dart test/content_installation_manifest_file_system_test.dart
dart test test/content_installation_activation_file_system_test.dart test/content_materialization_file_system_preflight_test.dart
dart test test/content_materialization_file_system_publication_test.dart test/content_materialization_file_system_coordination_test.dart test/content_materialization_file_system_transaction_test.dart
dart test test/content_writer_os_lock_test.dart
cd ..
git diff --check origin/main...HEAD
git status -sb
```

Launcher Draft PR #65 consumes this implementation via a pinned commit. Draft PR #64 Chat History stays isolated. No merge/cleanup until explicit user acceptance. Do not commit user's local pubspec.lock.
