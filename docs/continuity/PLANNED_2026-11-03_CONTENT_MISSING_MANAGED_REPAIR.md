# Content missing managed artifact repair — 2026-11-03

Repository: `nusretm/minecraft_tools`  
Branch: `feature/content-missing-managed-repair`  
Status: code and tests drafted; Windows/Dart analyzer and runtime verification **pending**.

## Reproduction

A second Windows machine launched a Game Package once, then user deleted
`mods/aaron-mod-3.0.1+26.1.2.jar` and two Minecraft asset folders.
Subsequent launch from either `C:\MTNLauncher` or
`%APPDATA%\MTNLauncher\bin` failed before download:
`Materialization filesystem preflight is unsafe before transfer.`
Read-only manifest audit located exactly one missing managed artifact at
`%APPDATA%\MTNLauncher\packages\0518b2bf-35d8-4bfb-9f50-1539094a373f\mods\aaron-mod-3.0.1+26.1.2.jar`.
The earlier `CERTIFICATE_VERIFY_FAILED` is a **separate** failure mode,
not demonstrated to be caused by deleting this JAR.

## Narrow fix

- Add read-only `MtnMinecraftContentMaterializationFileSystem.missingManagedVersionKeys`
  that inspects authoritative manifest-owned paths without following links or
  accepting invalid/ambiguous/inaccessible path components.
- Add an explicit `repairVersionKeys` option to reconciliation. A missing
  same-version managed file is modeled as a replacement marked `isRepair`,
  **not** a normal retain. The existing file selection, provider URL resolution,
  RemVibe Download Service, hash verification, preflight, coordinated publication,
  and manifest commit remain the sole authorities.
- Launcher filters missing keys to exact desired versions. For each repair,
  preserve the original manifest-owned relative path and require that the
  selected file identity (name/size/hashes) matches the manifest's exact file.
  Healthy retains and unrelated personal files are not touched.
- No automatic repair for corrupt (present) files in this initial scope;
  existing integrity checks continue to reject invalid bytes. No SSL changes,
  manifest deletion, full reinstall, alternate download framework, or bypass
  of the filesystem preflight.

## Focused tests

- Reconciliation: normal retain vs explicit same-version repair; unknown repair
  identity rejected.
- Full RemVibe execution with local HTTP fixture: missing JAR restored, another
  healthy managed JAR retained, persisted manifest valid, exactly one request.
- Invalid downloaded SHA-256 rejected: missing source remains missing, retained
  JAR unchanged, existing manifest retained.
- Existing filesystem link/path and materialization tests continue to apply.

## Validation on Windows — pending

From `D:\development\cross-platform\minecraft_tools\minecraft_content_service`:

```powershell
dart pub get
dart analyze
dart test test/content_dependency_reconciliation_test.dart test/content_materialization_file_system_preflight_test.dart test/content_materialization_plan_test.dart test/content_installation_execution_remvibe_test.dart
```

Merge only after Windows validation and user approval. The Launcher integration
must be pinned to the tested Content Service revision; do not update
`main` or delete branches ahead of user permission.
