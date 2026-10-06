# Handoff — Minecraft Info Provider Server Management + Health Check

Date: 2026-10-06

## Purpose

This note closes the saved-server CRUD and automatic server-status monitoring checkpoint.

It extends the earlier server foundation without replacing its status-query, SRV, legacy fallback, address normalization, or `MtnMinecraftText` behavior.

## Repository

```text
Repository: nusretm/minecraft_tools
Local:      D:\development\cross-platform\minecraft_tools
Package:    minecraft_info_provider/
```

`docs/WORKING_RULES.md` remains authoritative. `hypixel_api/` is unrelated.

Main baseline before merge:

```text
58287599b2377a751d433a37fb4feb12affffab0
Reorganize minecraft info provider source layout
```

Validated feature branch before continuity update:

```text
feature/servers-dat-example
eebdafa6a3d3090924607b06eac644763e106b02
Fix constructor member ordering lint
```

User explicitly approved continuity update and merge after validation.

## Saved-server CRUD completed

`MtnMinecraftInfoProvider` now supports:

```dart
readServers()
addServer(server)
addServer(server, first: true)
updateServer(server)
removeServer(address)
```

### Add

Default behavior remains append.

`first: true` inserts the new Compound at index 0 while preserving every existing entry and unknown NBT tag.

No implicit provider-side deduplication is performed.

### Update

`updateServer(server)` finds the first canonical identity match using `MtnMinecraftInfoServerAddress.sameIdentity()`.

It updates the known saved-server fields in place while preserving:

- list position
- unknown/future tags on the matched server Compound
- unrelated root tags
- every unrelated server entry

It returns `false` when no target exists.

### Remove

`removeServer(address)` uses the same canonical identity semantics.

It removes only the first matching entry, preserves the remaining order, and returns `false` when no target exists.

### Canonical identity

Examples treated as the same default endpoint:

```text
oyna.provanas.com
oyna.provanas.com:25565
```

Persisted addresses are not silently rewritten merely for comparison.

## Automatic server checks

`MtnMinecraftInfoServer` owns the timer/query lifecycle.

Runtime API:

```dart
bool autoCheck
int autoCheckSec
void dispose()
```

Defaults:

```text
autoCheck = false
autoCheckSec = 15
minimumAutoCheckSec = 15
```

Any lower requested interval is clamped to 15 seconds.

### Scheduling

Automatic checks use one-shot scheduling rather than an overlapping periodic timer.

Effective sequence:

```text
query completes
-> wait autoCheckSec
-> query
-> wait autoCheckSec
-> query
...
```

A query is never intentionally launched while the previous automatic query for the same server is still active.

Changing `autoCheckSec` while waiting reschedules the next timer.

### Disposal

`MtnMinecraftInfoServer.dispose()`:

- marks the server disposed
- disables auto-check
- cancels a waiting timer
- clears `onChange`

If a network query was already in flight, transport completion is allowed, but the disposed server cannot publish a new status callback or schedule another timer afterward.

Disposed servers reject later manual query/auto-check reactivation attempts.

## Health-check coordinator

Public class:

```text
MtnMinecraftInfoServerHealthCheck
```

The checker does not own a polling timer. Each server owns its own timer.

The checker owns:

- managed server membership
- shared `intervalSec`
- start/stop orchestration
- lifecycle callbacks

Public callbacks:

```dart
onAdd(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onChange(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
onRemove(MtnMinecraftInfoServerHealthCheck checker, MtnMinecraftInfoServer server)
```

### add

`add(server)`:

1. rejects duplicate object membership
2. clamps/applies checker interval to the server
3. chains any existing server `onChange`
4. adds the server
5. emits `onAdd`
6. immediately starts one `queryStatus()`

The initial query does not wait 15 seconds.

If `start()` happens during the initial query, no second query is launched. Once the initial query finishes, the normal auto-check delay begins.

### start / stop

`start()` enables auto-check for managed servers once any pending initial query has completed.

`stop()` cancels future automatic checks without disposing current server status snapshots.

### interval propagation

Changing:

```dart
checker.intervalSec = 30;
```

updates every managed server's `autoCheckSec`.

Checker intervals below 15 seconds are clamped to 15.

### remove

`remove(server)`:

1. removes membership/pending-initial-check state
2. disposes the server
3. emits `onRemove`

This ordering prevents a removed server from publishing later health-check events.

### checker dispose

`checker.dispose()` disposes all remaining managed servers, emits `onRemove` for each, clears membership, and releases checker callbacks.

## Examples

### servers_dat.dart

Path:

```text
minecraft_info_provider/example/servers_dat.dart
```

Actions:

```text
--add
--update
--remove
```

The current example targets `oyna.provanas.com`:

- add only when missing
- insert at the first position
- resource packs enabled
- update title/resource-pack policy when present
- remove by canonical identity

### server_checker.dart

Path:

```text
minecraft_info_provider/example/server_checker.dart
```

Input is a concrete `servers.dat` path.

The example:

- reads all saved servers
- adds each server to a checker
- prints `onAdd`
- queries each server immediately
- prints `onChange` for status changes
- continues until Ctrl+C
- disposes the checker
- prints `onRemove`
- deliberately omits icon/favicon output

MOTD output uses the existing:

```dart
status.motd?.plainText
```

so Minecraft status text is normalized through `MtnMinecraftText` rather than a second plain-text parser.

## Validation

Final local validation supplied by the user:

```text
dart analyze
No issues found!

dart test
00:03 +256: All tests passed!

git diff --check
PASS

git status
On branch feature/servers-dat-example
Your branch is up to date with 'origin/feature/servers-dat-example'.
nothing to commit, working tree clean
```

No `dart format` was run.

## Real live status smoke test

Real launcher profile:

```text
C:\Provanas\profiles\919ffebe-f609-4019-afed-fe31537e3e5f\servers.dat
```

Observed entries:

```text
Provanas       oyna.provanas.com
Hypixel        mc.hypixel.net
Minecraft Server / ZenitMC  play.zenitmc.com
```

The live checker demonstrated:

- immediate first status checks after add/start
- modern online responses
- player counts
- latency
- version text
- dynamic MOTD changes
- repeated checks without overlap
- clean `onRemove` callbacks during Ctrl+C shutdown

Example MOTD rendering visibly preserved multiline plain text from real servers.

## Architecture boundaries retained

This checkpoint does not:

- reimplement modern/legacy Minecraft server ping
- add a second status parser
- add a global polling engine
- infer sub-game/runtime server identity
- infer authentication/join compatibility
- persist auto-check settings into `servers.dat`
- persist runtime status into `servers.dat`

`queryStatus()` remains the single server status authority.

`MtnMinecraftText` remains the text authority.

The health checker is orchestration only.

## Next likely work

No new checkpoint is automatically active after merge.

Current launcher-facing priorities favor installed-content discovery next:

- Minecraft mod loader
- installed mod list
- mod metadata
- later namespace/localization/item-model asset resolution

A new implementation still requires explicit user approval.
