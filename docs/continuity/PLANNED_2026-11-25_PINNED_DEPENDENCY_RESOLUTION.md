# Project-only dependency pin reuse — 2026-11-25

Status: Draft PR code prepared; Windows analyzer and tests **not run yet**.

## Observed failure

MTN Launcher Game Package containing Roughly Enough Items (REI) `26.1.819+fabric`
and dependency-only Architectury API `20.1.18+fabric` failed to launch with a
raw `Bad state: Dependency modrinth:lhGA9TYQ conflicts with the selected exact
provider version ZARvDhhO` error. User inspected the installed manifest: REI
declares `required` on Modrinth project `lhGA9TYQ` with **no** provider
version ID and **no** version constraint. Architectury API is selected in
the package, not itself a direct root.

## Correct rule

- Feed exact existing provider version selections (`provider:projectId`) from
  the local package into the existing Content Service graph resolver.
- For *project-only* dependency declarations with no exact version, file name
  or version constraint, prefer the selected release **only when** provider
  project identity, Minecraft version, mod loader and release type match.
- For exact-version, constrained or file-specific declarations, retain the
  established provider resolution behavior. Never invent constraint semantics.
- If a selected release belongs to another project, refuse rather than adopting it.
- If preferred release is incompatible with the environment, existing provider
  resolution and explicit conflict checks still apply. Do not silently update
  a package lock.
- If an actual exact-version mismatch survives resolution, throw a typed
  `MtnMinecraftContentSelectedVersionConflict` with precise requesting source,
  direct root, selected version and proposed version; the linked Launcher
  records the diagnostic before reporting the failure.
- Keep the existing graph, file selection, manifest, RemVibe and installation
  model. No broader dependency solver or automatic bulk updates.

## Verification

Targeted `content_dependency_pinned_version_test.dart` covers REI-like
project-only reuse and persisted REI -> Architectury edge, exact ID
precedence, constraint guard, incompatible selected game version, and
wrong-project rejection. Existing dependency desired-state/install-policy/
package-lock tests are regression gates.

Commands:
```powershell
cd D:\development\cross-platform\minecraft_tools\minecraft_content_service
dart pub get
dart analyze
dart test test/content_dependency_pinned_version_test.dart test/content_dependency_desired_state_test.dart test/content_dependency_install_policy_test.dart test/content_package_dependency_lock_rebuild_test.dart
```
Only user-verified results authorize merge. Keep branch as Draft until accepted.
