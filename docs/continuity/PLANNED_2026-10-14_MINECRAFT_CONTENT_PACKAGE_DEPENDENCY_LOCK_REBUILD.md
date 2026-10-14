# CP-10 — Package Dependency Resolution, Exact Lock Rebuild & Remote Revision Candidate

## Status (2026-10-14)

- Authorized in conversation after CP-09 was squash-merged and local/remote branches cleaned; user's Windows main up to date and clean.
- Implementation branch `feature/minecraft-content-package-dependency-lock-rebuild`; no merge requested or performed.
- Windows Dart SDK validation, focused/full `dart test` and real Modrinth dependency smoke still **PENDING**. Do not claim PASS until user runs commands.
- Pure Dart: do not run `dart format`; respect `docs/WORKING_RULES.md`.

## Authorized API, ownership and invariants

```dart
final desired = await package.resolveDependencies(
  contentService,
  selectedOptionalVersionKeysByRoot: <String, List<String>>{},
);
final rebuilt = package.rebuildLock(
  desired,
  selectedFilesByVersionKey: selectedFiles,
);

package.revisionNum;     // aliases existing portable revision
package.newRevisionNum;  // nullable, transient server-observed newer revision
package.updateAvail;     // revisionNum != (newRevisionNum ?? revisionNum)

// Later, the Content Server client can periodically compare remote revisions:
package.newRevisionNum = observedRemoteRevision;
```

- Package invokes **existing** `MtnMinecraftContentService.resolveDependencyGraph`, `planDependencyInstall`, `composeDependencyInstallPlans` and `MtnMinecraftContentPackageBuilder.build`. No parallel resolver, new editor/manager, download engine, or provider-specific branches.
- Direct roots use the **exact selected provider version**; no implicit upgrade to latest. Existing exact-version choices in local drafts / locks are verified. If resolution would replace a pinned dependency with another exact version, resolution/rebuild does **not** silently mutate it.
- Missing required dependencies and cross-root conflicts remain visible through `desired.installable`, plan `unresolvedInstallEdges` and `conflicts`. Optional dependency versions are selected explicitly using a root-version-key map.
- Selected files are supplied **explicitly** for every exact version (including retained files); Builder verifies file membership and portable hash/file identity.
- `rebuildLock` constructs and validates a complete candidate **before** mutating current Package. If the Builder rejects an incomplete/ambiguous selection, the original package keeps its items, sources, direct flags, enabled preferences and lock unchanged.
- When rebuild succeeds, existing Item objects and source/permission/enable state remain; new resolved dependencies become local dependency items; orphan dependencies drop out. Locked edges and exact file/version IDs become portable; existing public Package and Record schema v2 remain.
- **Revision candidate is separate from mod/item updateList**: `revisionNum` maps to existing `revision`, avoiding a duplicate authority. `newRevisionNum` is a transient nullable observation only for a Package attached to a downloaded `MtnMinecraftContentPackageRecord`. Same, older or absent server revision clears the candidate. `updateAvail` follows user's exact getter expression. No automatic polling, no remote Content Server client, no schema changes, no unapproved interval or invented endpoint. Scheduling the remote query and applying a newly published Package revision are future checkpoints.
- A downloaded Package Record retains its current `remoteId`, `publishedRevision` and `source` semantics; Package and Record continue to reference one another.

## Windows validation

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-dependency-lock-rebuild
git switch feature/minecraft-content-package-dependency-lock-rebuild

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_dependency_lock_rebuild_test.dart -r expanded
dart test
dart run example/content_package_dependency_lock_rebuild.dart 6qAuTtLR 1.21.11 0.16.14

cd ..
git diff --check main...HEAD
git status
```

The live smoke fetches the exact Modrinth Fabric API version previously verified during CP-09 and resolves its graph; if a required dependency cannot be resolved or any artifact cannot be chosen unambiguously, it reports the blocker rather than inventing a file. Its live pass is not yet verified.
