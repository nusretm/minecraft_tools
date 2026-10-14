# CP-07 — Portable Package Metadata v2 & Encrypted Local Record Storage (2026-10-14)

## Status and authorization

- Branch: `feature/minecraft-content-package-local-storage-metadata` based on clean merged CP-06 main `db5d6f69485c2612d1c682f341f02437f8d2a37c`.
- User explicitly approved implementation of the **expanded GamePackage metadata** and encrypted local record persistence.
- **Initial Windows run: metadata tests 3/3 PASS, disk smoke PASS, storage tests 6/7, full suite 292 passed and 1 failed, analyzer 2 info notices. Targeted corrections committed; post-fix rerun pending. Merge is NOT authorized.**
- Scope only `minecraft_content_service/` and `docs/continuity/`. Do not run `dart format`.

## Public portable package metadata

`MtnMinecraftContentPackage` schema is **2** (the project is pre-release; no schema 1 migration shim):

- `id`, `title`, Markdown-capable `description`, `iconUrl`;
- `minecraftVersion`, `modLoader`, `loaderVersion?` (required for non-Vanilla; forbidden for Vanilla), `ramMiB` (positive MiB), `serverAddress?` (trimmed, no whitespace);
- `ownerName` (nonblank display name, **not proof of publisher authorization**), UTC `createdAt` and `updatedAt` with `updatedAt >= createdAt`, `revision` (positive);
- existing `mutationPolicy`, `items`, `lock` and graph-derived effective item enablement remain intact.

All required schema v2 metadata is supplied explicitly during package construction, including through `MtnMinecraftContentPackageBuilder.build`. Serializer/deserializer preserve UTC ISO-8601 and markdown verbatim. Creation/update timestamps are caller-controlled based on actual edits; **save() never mutates dates or publication revision**. Portable published exports still need an exact complete lock; local encrypted records may store unlocked drafts. Previous schema 1 import is intentionally rejected, not auto-migrated. Previously run Modrinth hydration example now accepts an explicit fourth loader build argument when the chosen loader is not Vanilla.

## Encrypted local storage

`MtnMinecraftContentPackageRecordStorage(directory:, codec:)` adds `save(recordId, record, key:, keyId:)`, `load(recordId, key:)`, `getKeyId(recordId)`, `listRecordIds()`, `delete(recordId)`. The existing `MtnMinecraftContentPackageRecordCodec` remains responsible for AES-256-GCM encryption/authentication; **no key is embedded, fetched, or managed** in the storage or package.

Disk layout:

```text
<storageDirectory>/
  <record-uuid>/
    000000000001.mtncr
    000000000002.mtncr
    .000000000003.mtncr.<random>.tmp  # incomplete stage ignored
```

- The record ID is an independent **canonical lowercase UUID** (distinct from portable package ID / Content Server remote ID), validated before any filesystem access. File generations are integer counters with 12 zero-padded digits, distinct from portable `revision` / `publishedRevision`.
- Save: AES-GCM encrypt with caller-supplied key and keyId, write and flush a random temporary path inside the record directory, then rename to an **unused** next generation file. Previously completed generations remain available; no automatic pruning yet.
- Read: use the newest **completed** generation. Unfinished `.tmp` files are ignored. If newest generation is corrupt, has incorrect key, or fails authentication, raise the error; **do not silently fall back** to an old version or delete the record.
- Missing ID: `load/getKeyId` return null; `delete` returns false; `listRecordIds` lists only IDs with completed generations. `getKeyId` is unauthenticated until `load` verifies AAD and authentication tag; the launcher must not treat it as trusted publisher identity.
- Single storage instance serializes writes and deletes per UUID. Multiple-process writers and adversarial concurrent filesystem manipulation are **not supported**. Flush + rename of unused generation names improves recovery but does **not** guarantee absolute crash durability on all systems/filesystems.
- Storage root and ID directories must be real directories, not symlinks; generation entries must be regular files. Delete refuses to remove unknown files rather than recursively deleting a directory.
- Remote publisher authorization remains Content Server responsibility; neither `source=local` nor successful decryption grants publish privileges.

## Explicit non-goals

- No UI toggle rules; no network key provisioning, Content Server API, signing, publisher authentication, remote publication, server revision creation or package install/download.
- No write-back on every read, auto-modifying timestamps, local date-driven revision increments, schema 1 compatibility, automatic snapshot pruning or multi-process file locks.

## Windows verification gate — pending

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-local-storage-metadata
git switch feature/minecraft-content-package-local-storage-metadata

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_metadata_v2_test.dart -r expanded
dart test test/content_package_record_storage_test.dart -r expanded
dart test test/content_package_foundation_test.dart -r expanded
dart test test/content_package_record_codec_test.dart -r expanded
dart test test/content_package_builder_test.dart -r expanded
dart test
dart run example/content_package_storage.dart

cd ..
git diff --check main...HEAD
git status
```

The storage example performs **real** disk writes and reads, wrong-key rejection and deletion under `Directory.systemTemp` (fresh random in-memory demo key). The metadata-only online Modrinth example for modded content now requires an explicit fourth loader build argument and is separate from the offline filesystem proof. Any reported PASS status must be supported by the user's Windows output. Draft PR and separate merge approval required.
