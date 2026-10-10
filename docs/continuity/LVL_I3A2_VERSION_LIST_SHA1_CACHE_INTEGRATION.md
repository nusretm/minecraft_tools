# LVL-I3A2 — VersionList model pin + SHA-1 cache round-trip

Date: 2026-10-10
Repository: `nusretm/minecraft_tools`
Package: `minecraft_loader_version_list/`
Baseline main: `3d48fdd7981eb8b4b7739b915e4e84f53ff42c49`
Upstream model: `nusretm/minecraft_models` squash merge `a083d402a13ef742d4968a161d2893f4f50482ff` (PR #5)
Status: **IMPLEMENTED / WINDOWS VALIDATED / SQUASH MERGED / CLEANUP COMPLETE (2026-10-10).**
PR: [minecraft_tools #59](https://github.com/nusretm/minecraft_tools/pull/59)
Squash merge commit: `2cf19060aa77d44c3ddf1b5d8c1443d4449c2a82`
Feature commit before squash: `4adf568d495acc7810781f4a54a206cf197bb496`

## Authority and scope

- `minecraft_models` owns immutable `MtnLauncherGameLoaderVersion`, including optional SHA-1 source metadata.
- `minecraft_loader_version_list` owns provider-agnostic lazy catalog, generated builds, resolver, and schema-1 disk cache.
- Pin `minecraft_models` by exact merged SHA, not drifting `main` or duplicate domain types.
- Cache write already calls `item.toJson()`; cache read already calls `MtnLauncherGameLoaderVersion.fromJson()`. These model methods own optional SHA-1 persistence, so no changes to VersionList core or schema number.
- SHA-1 is unverified upstream metadata for the bytes at the exact stored URL, not a verified digest, artifact install plan, or downloader action.

## Regression evidence to establish on Windows

1. Publish a generated build with exact mixed-case URL and uppercase SHA-1, assert schema 1 and presence of the exact `sha1` in the on-disk `generated.items` entry.
2. Recreate VersionList from the same disk cache with callbacks that throw if invoked; assert fresh offline read, restored build structural equality, checksum and exact `url`, and successful exact `resolveVersion`.
3. Publish/restore a model without SHA-1; existing historical schema-1 record lacks the key and restores as nullable `sha1 == null`. Do not introduce the missing key on serialization.
4. For explicitly malformed present SHA-1 (null, non-string, empty/whitespace-only), reject the corrupt cache rather than silently accepting or losing metadata. Reacquire the catalog with the existing VersionList behavior.
5. Confirm the public barrel and direct `minecraft_models` import refer to the same Dart type, including the optional field on a const model.

## Explicit non-goals and deferred risks

- No modification to `minecraft_models`, `mtn_launcher`, Forge, Vanilla, provider example parsing, cache publication/concurrency, downloader or manifest verification.
- Do not conflate syntactic validation with checksum verification. The value model intentionally accepts nonempty opaque source metadata without recomputing digest bytes.
- Existing `resolveVersion` duplicate exact-version metadata consistency does not compare the SHA-1 field. Its behavior must be assessed in a separately approved resolver checkpoint, before LVL-I3B relies on multiple candidate records for the same exact build.
- Current generic cache failure behavior (including primary/backup fallbacks and no-network handling) is preserved. Malformed cache test asserts catalog reacquisition, not a new error code.

## Validation gate

From `minecraft_loader_version_list/` on Windows:

```powershell
dart pub get
dart analyze
dart test test/version_list_test.dart
dart test test/shared_identity_test.dart
dart test
```

From repository root: `git diff --check`, `git diff --stat`, `git status`, inspect exact changed paths and full diff.
No `dart format` on pure Dart. Focused tests are synthetic/offline; no live Mojang validation claimed.

## Actual Windows validation (2026-10-10)

- `dart pub get`: successful; `minecraft_models` resolved at `a083d4`.
- `dart analyze`: no issues.
- `dart test test/version_list_test.dart`: 15/15 passed.
- `dart test test/shared_identity_test.dart`: 1/1 passed.
- Full package regression: 46/46 passed.
- `git diff --cached --check`: passed.
- Independent changed-file and architecture audit: passed.
- Tests are offline/synthetic; no live Mojang verification claimed.
- VersionList production cache logic unchanged.
- Implementation commit and feature branch push completed with user approval; PR #59 created and independently reviewed as mergeable/clean.
- PR #59 squash merge completed with explicit user approval; GitHub verified `merged=true` and `main` at `2cf19060aa77d44c3ddf1b5d8c1443d4449c2a82`.
- User verified local `main` fast-forwarded and clean, feature worktree removed, local and remote feature branches deleted, and `git fetch --prune` completed.
- Other pre-existing feature branches remained untouched.

## Closed checkpoint and next design gate

LVL-I3A2 acceptance and cleanup are complete. No additional production work belongs to this checkpoint. The `minecraft_models` SHA-1 field is source metadata, not digest verification. Do not claim MtnLauncher Vanilla integration from these cache tests.

**Next (separate approval required):** decide how `resolveVersion` handles multiple candidates with identical exact build IDs and matching URL/type/channel but differing source SHA-1; then design LVL-I3B Vanilla VersionList callback/state ownership and exact Mojang profile URL + SHA-1 propagation. Do not begin implementation, commit, PR or merge in those checkpoints without user approval.
