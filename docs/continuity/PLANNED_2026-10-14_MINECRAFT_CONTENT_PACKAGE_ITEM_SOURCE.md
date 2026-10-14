# CP-08 — Shared Package / Item Source (2026-10-14)

## Authorization and scope

- User explicitly rejected an editor service, override object, item-origin enum, and protected boolean. Approved reusing the existing `MtnMinecraftContentPackageSource { local, downloaded }` for `MtnMinecraftContentPackageRecord.source` and `MtnMinecraftContentPackageItem.source`.
- Branch: `feature/minecraft-content-package-item-source`, based on merged/clean CP-07 main `6b5aed8cc7b6cd8a6f9af0c0bae3dbe303b49a66`.
- **Windows runtime/tests PASS: focused item-source 4/4, AES-GCM codec 5/5, storage 7/7, complete suite 297/297, live encrypted disk smoke PASS, diff and working tree clean. Initial analyzer reported one strict raw-type warning in a test; follow-up fix committed, post-fix `dart analyze` clean, `git diff --check` clean, working tree clean. User explicitly approved merge of PR #68.**
- No extra editor/override/protected classes, no new enum, no UI implementation and no Content Server key/publishing integration.

## Contract

| Record source | Item source | Meaning for UI |
| --- | --- | --- |
| `local` | `local` | Publisher's local item; package and per-item policies decide options |
| `downloaded` | `downloaded` | Received from published package; UI can protect it under read-only or append-only rules |
| `downloaded` | `local` | User added this item locally to the downloaded package; package policy and item permissions decide options |

- The existing enum was moved to the shared package `minecraft_content_package_source.dart` file, with the public library exporting the same `MtnMinecraftContentPackageSource` type. This is **not a second enum**.
- New `MtnMinecraftContentPackageItem` objects default to `source: local`.
- `MtnMinecraftContentPackage.fromMap/decode` import a portable snapshot and mark every received item `downloaded`. A portable source field is rejected rather than trusted.
- `MtnMinecraftContentPackageItem.toMap()` and portable `MtnMinecraftContentPackage.toMap/toJson/encode` **never export** item provenance. Package portable schema stays **v2**; existing locked graph identity and revisions remain unchanged.
- `MtnMinecraftContentPackageItem.toLocalMap()/fromLocalMap()` and `MtnMinecraftContentPackage.toLocalMap()/fromLocalMap()` persist each item's source. Encryption remains exclusively the existing AES-256-GCM `MtnMinecraftContentPackageRecordCodec` and `MtnMinecraftContentPackageRecordStorage`; no new persistence layer.
- Local `MtnMinecraftContentPackageRecord` schema incremented **v1 → v2** because encrypted records now require explicit item sources. Earlier local record schema is intentionally not auto-migrated before release. **This does not change** the AES-GCM envelope format, package portable schema or content server protocol.
- UI remains responsible for combining record source + item source + `mutationPolicy` + existing `permissions`. No new automatic mutation or policy engine; no overrides/snapshots. Existing `MtnMinecraftContentPackageItemState` remains the unrelated hydration state.

## Initial Windows validation evidence (2026-10-14)

User-provided PowerShell run at feature branch before the follow-up test lint fix:

- `dart pub get`: **PASS**; dependency update notices only.
- `dart analyze`: **1 strict_raw_type warning** at `test/content_package_item_source_test.dart:103`: `isA<List>()` omitted type arguments. Corrected to `isA<List<Object?>>()` in subsequent commit; **post-fix analyzer rerun pending**.
- Focused item-source tests: **4/4 PASS**.
- Existing AES-GCM record codec tests: **5/5 PASS**.
- Existing encrypted record storage tests: **7/7 PASS**.
- Full `dart test`: **297/297 PASS**.
- `dart run example/content_package_item_source.dart`: **live Windows filesystem PASS** — downloaded item and locally added item retained distinct sources after encrypted disk reload.
- `git diff --check main...HEAD`: **clean**.
- `git status`: up to date with remote, clean working tree before follow-up commit.

**Post-fix confirmation (user-provided Windows PowerShell):** user fast-forwarded feature branch to `71e77bf`; `dart analyze` returned **No issues found!**, `git diff --check main...HEAD` returned no errors and `git status` showed a clean tracking branch. Earlier full suite **297/297**, focused source **4/4**, codec **5/5**, storage **7/7**, and real disk smoke **PASS** remain valid because the intervening source change fixed only a test matcher generic type. User explicitly approved squash merge; PR #68 merge pending.

## Validation gate (Windows PowerShell)

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-item-source
git switch feature/minecraft-content-package-item-source

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_item_source_test.dart -r expanded
dart test test/content_package_record_codec_test.dart -r expanded
dart test test/content_package_record_storage_test.dart -r expanded
dart test test/content_package_foundation_test.dart -r expanded
dart test
dart run example/content_package_item_source.dart

cd ..
git diff --check main...HEAD
git status
```

The new focused tests cover local constructor defaults, portable export without item source, portable import marking items downloaded, mixed downloaded/local provenance surviving encrypted record codec roundtrip, strict invalid source rejection and local record schema v1 rejection. The new executable example writes a downloaded record with one publisher item and one user-added item into a real temporary directory, reloads and validates both item sources, then deletes the record.

**No Dart SDK in agent execution environment.** Evidence must come from Windows execution; `dart format` must not be run on pure Dart files. Separate approval required to merge.
