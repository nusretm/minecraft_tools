# PRIVATE-1C — Durable Game Package private-layout migration

Date: 2026-11-02
Repository: nusretm/minecraft_tools
Branch: feature/content-private-layout-execution
Base: main at aaa8b904bc7589d7e9faf5940f0dab9b157db16e (PRIVATE-1A/1B merged as PR #90)
Status: architecture-only checkpoint, no production implementation authorized yet.
Related: Launcher Draft PR #64 Logs/Chat and Draft PR #65 .mtn path contract remain untouched.

## Target layout and invariants

Legacy:
  .mtn-content/installation.json
  .mtn-disabled/mods|resourcepacks|shaderpacks/<file>

Target:
  .mtn/content/installation.json
  .mtn/disabled/mods|resourcepacks|shaderpacks/<file>
  .mtn/migration/                     # Content Service durable transaction records
  .mtn/chat/                          # Launcher durable archive, strictly out of scope

- Keep every manifest-owned artifact intact, with its version/file identity, length and hash verified. Enabled mods/resourcepacks/shaderpacks stay in their Minecraft-managed locations.
- Never change, scan for cleanup, or delete the Launcher-owned .mtn/chat, Minecraft logs, screenshots, saves, or untracked files.
- Never delete the last known good manifest or file. Do not blindly merge old/new folder data; unknown occupants and case or link aliases are errors.
- PRIVATE-1B is a snapshot, not an execution permit. Revalidate under exclusive ownership directly before any mutation.
- No modern manifest becomes authoritative until all new-path disabled files are verified. On completed migration every normal Content Service reader, publisher, materializer and activation handler must use the modern layout consistently.

## Audited limitations in current main

1. MtnMinecraftContentInstallationManifestFileSystem.inspectLayout and planPrivateLayoutMigration are read-only, with legacy read/publish still active. Its publication can rollback/commit within one live process, tracking backup and staging through Dart objects; state cannot alone be recovered after process termination.
2. MtnMinecraftContentInstallationActivationFileSystem.synchronize uses the legacy .mtn-disabled paths and manifest publication. Migration cannot be complete until activation and materialization path reservations work with .mtn/content and .mtn/disabled and reject writes into other .mtn locations.
3. MtnMinecraftContentMaterializationFileSystemCoordinator and its transaction operations already hold leases, preflight, stage and rollback data. Reuse these mechanisms. Avoid a parallel generic transaction engine.
4. The static _MaterializationRootGate coordinates access in its Dart runtime. It is NOT a proven cross-process/OS lock; two separate processes can otherwise each act as the sole owner. The migration needs an OS-backed lock or one clearly authoritative writer process with enforceable participation by all Content Service operations.
5. A game process will not cooperate with Content Service locks. Launcher must positively verify no running game/package sessions before invoking mutation. If uncertain, defer.

## Ownership and proposed lifecycle

Content Service is the authority. Suggested API, names to settle in implementation:
- existing inspectLayout(installationRoot), planPrivateLayoutMigration(installationRoot)
- proposed recoverPrivateLayoutMigration(installationRoot), migratePrivateLayout(installationRoot)

The migration executor must acquire exclusive coordinated lease plus cross-process ownership; check for existing journal BEFORE normal dual-manifest inspection; resolve/stop when recovering; recompute source manifest SHA, expected target layout, source file SHA, path safety and inventory. All writers (legacy and modern) must block when a journal exists and is unresolved. Do not promise that in-process root lease protects other isolates/processes.

## Durable transaction record

Content Service-owned .mtn/migration stores:
- schemaVersion, unique migrationId, phase and canonical root identity;
- original manifest length+SHA256 and target manifest length+SHA256;
- all source and target paths as validated relative strings only, per-file length+SHA256, and acknowledged copy steps;
- journal generation/checksum; journal stage and recovery candidates.

Persist journal BEFORE any filesystem mutation. Use stage/write/flush/checksum/rename with a deterministic recovery policy; never claim that renaming or flush of several files across directories is atomic across crashes. Explicitly test Windows filesystem behavior; directory flush durability varies by platform.

Unknown or corrupt journal, unexplained double manifests or an unowned backup is recoveryBlocked: preserve all candidates and provide diagnostics; do not guess and delete.

## State machine and safety rules

absent / alreadyModern: no migration, still reject unclaimed collisions
prepared: durable journal, legacy manifest and source bytes intact
copying: copy (not move) each disabled file to new private layout; verify size+SHA256; retain legacy source
staged: complete verified copies and a non-live staged modern manifest; old manifest still authoritative
cutoverPending: journaled intention to change manifest authority; no normal game/content writes permitted
switched: modern manifest live and verified; original manifest/source still preserved in journal recovery storage
cleaning: remove only exact journal-listed obsolete legacy content after independent modern revalidation
complete: no live journal, only modern layout authority, verified integrity
recoveryBlocked: mismatch/unknown occupant; preserve all files and request explicit intervention

Critical cutover under ownership:
1. Verify the whole stage plus source manifest and all original bytes again.
2. Persist intent to switch.
3. Move legacy live manifest to a journal-tracked backup (do not delete it).
4. Promote the verified new manifest from a non-live staged name to .mtn/content/installation.json.
5. Verify the modern manifest and every disabled target; persist switched.
6. Only now permit modern paths to serve regular Content Service traffic after the recovery gate and path selection are correctly wired.

There is an interruption window between retiring the legacy manifest and promoting the new one. The journal and file checksums must enable deterministic restoration of legacy authority or verified forward promotion. If neither side is provably consistent, stop. Never silently use whichever manifest happens to exist.

Before cutover, rollback may delete only validated staged COPIES, leaving original data intact. After modern commit, prefer verified forward recovery; roll back only when every required original source and original manifest is still independently intact and no irreversible adoption has occurred. Do not erase the sole recovery data.

Cleanup is a separate retryable step: remove only verified journal-listed old artifacts; delete old directories only if genuinely empty and owned. Keep journal until cleanup and final read/activation checks succeed. Repeat migrate/recover must be idempotent.

## Implementation slices and explicit gates

PRIVATE-1C0 (first proposed implementation, awaits user approval):
  Durable journal model/codec, read-only journal/phase detection, safe path and unexpected-state classification, and proof/decision for cross-process ownership. No file copies, directory creation, manifest writes or moves.

PRIVATE-1C1:
  Controlled journal creation, staged verified file copies and staged target manifest, with reversible fault injection. Never retire the live legacy manifest.

PRIVATE-1C2:
  Journal-aware cutover/recovery and modern-path read/publish/activation routing. Normal operations block unresolved migration. Test every interruption boundary, including killed process after each stage.

PRIVATE-1C3:
  Verified cleanup and end-to-end acceptance using disposable copies of actual Windows Game Packages. Verify versions, enable/disable, repeat/restart recovery, case conflicts, links/junctions, missing source, permission errors, mixed roots and .mtn/chat untouched.

PRIVATE-2 in Launcher repository, separate gate:
  After Content Service validation, update git dependency; block migration while any game for package runs; test old/new packages in Windows. Keep Launcher PR #64 and #65 independent.

## Verification discipline

Follow AGENTS.md and docs/WORKING_RULES.md; no dart format for pure Dart unless requested. Each implementation slice requires dart analyze, focused dart test, manifest/materialization/activation regression, git diff --check, and Windows test evidence. Real Game Package data must not be mutated until disposable-fixture and process-kill recovery checks pass.

This branch is currently DOCS ONLY. No executable migration is approved by merely accepting this plan; approval is required for PRIVATE-1C0 implementation. No merge or cleanup at this checkpoint.
