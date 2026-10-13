# CP-06 — Encrypted Local Package Record & Portable Lock Builder (2026-10-14)

## Status

- Branch: `feature/minecraft-content-package-record-lock-integration`; base: merged CP-05 `main` (`70686577774cbde808fe25c533db7392e86eee81`).
- **Implementation authored; Windows Dart analyzer/tests and a real launcher run are NOT YET EXECUTED.**
- User approved separation of portable package vs local/downloaded record, future Content Server–supplied encryption key, AES-256-GCM, authenticated `keyId`, and existing multi-root plan → locked package adapter.
- No merge without user approval. No `dart format`.

## Layer ownership

- `MtnMinecraftContentPackage`: public portable definition and exact lock. Existing schema v1, `toMap/toJson/encode` still **refuse an unlocked draft**.
- `MtnMinecraftContentPackageRecord`: device-local `source` (`local` or `downloaded`), `remoteId`, `publishedRevision` and the editable current package. This local record is **not** part of portable export. `toLocalMap/fromLocalMap` are for the encrypted storage path and may contain a draft package without a lock.
- `MtnMinecraftContentPackageRecordCodec`: AES-256-GCM envelope only; plaintext local record serialization stays inside the encrypted payload. `encrypt(record, key:, keyId:)`, `decrypt(bytes, key:, expectedKeyId:)`, and unauthenticated `readKeyId(bytes)` for key selection. No hardcoded key, Content Server connection or key lookup in the library. Only **unit tests** use a fixed test key. A future caller may obtain the key from MTN Content Server and pass 32 bytes explicitly.
- `MtnMinecraftContentPackageBuilder`: transforms **existing** `MtnMinecraftContentDependencyDesiredState` and caller-selected `Map<version.key, MtnMinecraftContentFile>` into a complete portable lock + package, without implementing a new provider resolver, file selector or downloader.

## Encrypted envelope

```text
MTNCR ASCII magic (5 bytes)
formatVersion (1 byte; 1)
keyId byte length (1 byte; 1..255)
UTF-8 keyId (that length)
random 12-byte nonce
AES-256-GCM ciphertext (encrypted JSON local record)
16-byte authentication tag
```

Magic, format and keyId are AES-GCM **additional authenticated data**; wrong key or tampering fails authentication. `readKeyId` only parses the untrusted header. The server or launcher must enforce publisher identity independently — successful decryption or `source == local` does not prove publication rights. No production fixed key is stored anywhere in this library.

## Builder invariants

- Must start from an `installable` composed DesiredState (no unresolved install edges or version/incompatibility conflicts).
- Every desired version must have exactly one explicitly selected available file. The existing file-selection stage covers **install/replace**, not **retain**; retained versions require their own caller-provided selection. Nothing is silently guessed.
- Derive provider project and exact version IDs only from matching provider identity metadata. Ambiguous or absent provider identity is rejected.
- Lock exact selected provider file ID when available, and strongest supported actual file hash (SHA-512, SHA-256, SHA-1, MD5). Reject unidentifiable artifacts.
- Preserve only already-selected `plan.installEdges`: required, embedded-library and selected optional. Unselected optional, incompatible, tool, bundled edges do not become installed edges.
- Combine multi-root/shared dependencies into one package item. Reject different versions of one provider/project identity. Duplicate root-edge reports are deduplicated; graph reachability remains enforced by the existing package constructor.
- Retain explicit per-item permissions; **do not implement UI toggles**. `source` and `local` editing policy remain launcher/UI-level decisions.

## Explicit non-goals

- No hardcoded production key; no credential, authentication, signing, remote publisher ownership or MTN Content Server API.
- No download, install, disk persistence transaction, archive embedding, key-store, key rotation implementation, TTL/cache, or UI behavior.
- No automatic selection of unknown retained artifact and no provider-specific switch inside the builder.
- No automatic promotion of local draft to published revision: publication requires a separate explicit workflow and immutable server-side snapshot.

## Validation gate

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-package-record-lock-integration
git switch feature/minecraft-content-package-record-lock-integration

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_package_record_codec_test.dart -r expanded
dart test test/content_package_builder_test.dart -r expanded
dart test

# Executes the actual AES-GCM codec with a fresh in-memory example key.
dart run example/content_package_record.dart

cd ..
git diff --check main...HEAD
git status
```

The fixed encryption key is deliberately confined to tests. The executable smoke uses a newly generated ephemeral key, not a hardcoded application key. Do not run `dart format`. Local commands have not been run yet in the agent environment; record the owner's PowerShell evidence separately. 
