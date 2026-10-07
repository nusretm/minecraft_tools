# Minecraft Tools — Minecraft Content Provider Readiness / Rate-Limit Foundation Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-provider-readiness-rate-limit
Implementation: COMPLETE
Validation: COMPLETE
Merge: NOT REQUESTED
Validated production HEAD:
bd2f43c028833a9095cd11840f021090da5c776a
```

Baseline:

```text
main
bbed501912ef540ce3e203becd6f889c301e232b
Merge pull request #32 from nusretm/feature/minecraft-content-provider-curseforge-foundation
```

Package version: `1.0.0-dev.5`.

## Goal

Separate three concepts before multi-provider search is introduced:

```text
registered
ready
can issue a request immediately
```

A registered provider may remain unavailable because its own prerequisites are not configured. A ready provider may temporarily be rate limited without becoming unready.

## Provider readiness contract

`MtnMinecraftContentProvider` now requires:

```dart
bool get ready;
```

The provider itself is authoritative for readiness.

Generic core does not know why a provider is or is not ready.

Examples:

```text
Modrinth
required User-Agent exists at construction
ready = true

CurseForge
API key absent
ready = false

CurseForge
API key configured later
ready = true

future provider
trusted IP/config/certificate/etc.
provider decides
```

`MtnMinecraftContentProviderNotReadyException` represents the registered-but-unusable state.

## Registry behavior

`MtnMinecraftContentProviderList` remains the single registration authority.

New readiness views:

- `readyItems`
- `requireReadyFromName(name)`

Registration does not filter providers out merely because they are not ready.

This allows the launcher to register all supported providers once and display/configure unavailable providers without attempting to use them.

## Service behavior

Explicit service routing now requires both:

1. provider is registered
2. provider is ready

A registered provider with `ready == false` is rejected before dispatch.

Unregistered-provider behavior remains distinct and continues to use the existing registry error.

## CurseForge configuration

The CurseForge constructor no longer requires an API key.

```dart
final provider = MtnMinecraftContentProviderCurseForge();

provider.ready; // false

provider.apiKey = '...';
provider.ready; // true

provider.apiKey = null;
provider.ready; // false
```

Blank or whitespace-only API-key assignments normalize to an absent key.

The key remains private; no getter exposes it.

Queued/network work checks readiness again before using the key.

## Shared request gate

The base provider owns a serialized request gate.

All built-in remote-provider HTTP operations now pass through this gate.

Properties:

- one provider request executes at a time
- later requests preserve queue order
- readiness is checked before queue admission
- readiness is checked again when the queued request starts
- known rate-limit reset state is honored before network execution

This is intentionally conservative foundation behavior. Higher concurrency can be designed later only if provider semantics require it.

## Generic rate-limit state

The base provider exposes an immutable snapshot:

```text
MtnMinecraftContentProviderRateLimit
limit
remaining
resetAt
limited
resetIn
```

Rate-limit state is runtime state and is not persisted into content/provider metadata.

`ready` remains unchanged when the rate limit is exhausted.

## Modrinth behavior

Provider-specific response parsing stays in the Modrinth implementation.

Recognized headers:

```text
X-Ratelimit-Limit
X-Ratelimit-Remaining
X-Ratelimit-Reset
```

These update the generic runtime snapshot.

The documented quota value is not hardcoded into generic or provider scheduling logic. Returned headers are treated as runtime authority.

On HTTP 429:

- use `Retry-After` when available
- otherwise use Modrinth reset information when available
- temporarily throttle the provider request gate
- retry the request at most once
- a second 429 remains a normal provider HTTP failure

## CurseForge behavior

No fixed CurseForge quota is guessed or hardcoded.

On HTTP 429:

- use `Retry-After` only if the response actually provides a valid duration
- throttle the shared provider gate
- retry at most once
- if no usable retry duration exists, surface the provider HTTP failure

This leaves future CurseForge quota/header behavior inside the concrete provider implementation.

## Tests

The package test suite now contains 31 tests.

New coverage includes:

- registered provider remaining visible while not ready
- registry `readyItems`
- registry `requireReadyFromName()`
- service rejection before provider dispatch
- serialized provider request execution
- rate-limit snapshot state independent from readiness
- Modrinth rate-limit header parsing
- Modrinth bounded 429 retry
- CurseForge construction without API key
- CurseForge readiness transitions when key is set/cleared
- no HTTP request while CurseForge is not ready
- CurseForge bounded 429 / Retry-After retry

Existing model/provider mapping tests continue to pass.

## Validation

Authoritative local validation supplied by the user:

```text
dart pub get
Got dependencies!

dart analyze
Analyzing minecraft_content_service...
No issues found!

dart test
00:00 +31: All tests passed!

git diff --check main...HEAD
PASS

git status
nothing to commit, working tree clean

git rev-parse HEAD
bd2f43c028833a9095cd11840f021090da5c776a
```

No `dart format` was run.

## Deliberately not implemented

- multi-provider aggregation/search
- provider-result deduplication
- automatic Modrinth/CurseForge association
- rate-limit persistence
- generic hardcoded provider quotas
- advanced retry/backoff policies
- configurable provider request concurrency
- cancellation of queued provider requests
- dependency solving
- artifact download/materialization
- CurseForge live smoke

## CurseForge live smoke status

Live CurseForge validation remains deferred because an application API key is not currently available.

This no longer blocks provider registration:

```text
registered = true
ready = false
```

When the external prerequisite becomes available, the key can be configured and the same provider instance becomes usable.

## Natural next checkpoint

```text
multi-provider search foundation
```

Intended rules already agreed:

- operate only on registered providers that are currently ready
- skip registered-but-not-ready providers during an all-ready-providers search
- keep Modrinth and CurseForge hits as separate logical results
- do not merge equal names/slugs
- do not add heuristic cross-provider deduplication
- let the caller/user choose which provider result to use

A new implementation checkpoint requires explicit approval.

Merge of this branch requires separate explicit approval.
