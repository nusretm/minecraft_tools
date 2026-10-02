# Handoff — Minecraft Info Provider Server Foundation

Date: 2026-10-02

## Purpose

This note captures the complete server-information foundation at the end of
the legacy pre-1.7 ping checkpoint so a new conversation can continue without
reconstructing server behavior from Git history.

## Repository state

Repository:

```text
nusretm/minecraft_tools
```

Local path:

```text
D:\development\cross-platform\minecraft_tools
```

Current work is only under:

```text
minecraft_info_provider/
```

`hypixel_api/` is unrelated and must not be changed by this work.

Merged baseline before the active checkpoint:

```text
main
ad3eb84922e54401c825c69d789a78786cea546a
```

Active branch:

```text
feature/minecraft-legacy-server-ping
```

Validated implementation commit:

```text
82de274ab3513558fff1107679ff43bc1f1411b1
```

## Completed checkpoints

### NBT / servers.dat

Public types include:

- `MtnMinecraftNbtType`
- `MtnMinecraftNbtException`
- `MtnMinecraftNbtList`
- `MtnMinecraftNbtValue`
- `MtnMinecraftNbtDocument`
- `MtnMinecraftNbtCodec`

Codec behavior:

- Java big-endian NBT
- all standard payload types
- Java Modified UTF-8
- malformed/truncated/trailing invalid data rejected
- raw codec does not own compression

`MtnMinecraftInfoProvider` owns `servers.dat` operations.

Locked semantics:

- missing file/list -> immutable empty list
- root must be Compound
- `servers` must be List<Compound>
- name/ip are required strings
- unknown tags preserved
- add is append-only
- no implicit deduplication
- serialized same-target writes
- temporary sibling replacement + rollback

### Modern Java status

Primary API:

```dart
final status = await server.queryStatus();
```

Modern status exposes:

- version name
- protocol
- online/max players
- optional player sample
- MOTD
- favicon
- secure-chat flag
- optional latency
- raw JSON
- Forge/FML advertised metadata

The raw modern client is stateless. Server history belongs to each
`MtnMinecraftInfoServer` instance.

### Availability lifecycle

`MtnMinecraftInfoServerState`:

- `online`
- `offline`
- `unavailable`

A previously successful server remains online through transient non-DNS
failures for the grace period. The grace period begins at the first consecutive
failure, not at the previous successful query.

Default grace: one minute.

Stale snapshots retain previous server data but clear latency.

`onChange` runs only when effective public status changes.

### SRV discovery

Bare hostnames query:

```text
_minecraft._tcp.<host>
```

Rules:

- explicit port -> no SRV
- lower SRV priority first
- equal priority -> weight selection
- failed candidate -> next candidate
- SRV target `.` -> service unavailable
- no usable record -> direct host:25565
- status TCP target may differ from user-facing handshake hostname

### Address normalization

Shared parser:

```text
MtnMinecraftInfoServerAddress
```

Examples:

```text
Example.COM.            -> example.com
example.com:25565       -> example.com
example.com:25566       -> example.com:25566
2001:0db8::1            -> [2001:db8::1]
[2001:db8::1]:25565     -> [2001:db8::1]
```

Persisted `server.address` is never silently canonicalized.

### Known-server matching

Public model:

```text
MtnMinecraftInfoKnownServer
MtnMinecraftInfoServerMatch
MtnMinecraftInfoServerMatchKind
```

Evidence order:

```text
exact
normalized
resolvedEndpoint
none
```

Resolved backend equality is only supporting evidence, never stronger than the
user-facing address.

### Legacy pre-1.7 ping

Fallback chain:

```text
modern
  -> 1.6 extended FE 01 FA / MC|PingHost
  -> 1.4/1.5 FE 01
  -> pre-1.4 FE
```

Status format:

```dart
enum MtnMinecraftInfoServerStatusFormat {
  modern,
  legacy16,
  legacy14,
  legacyPre14,
}
```

Fallback boundaries:

- modern timeout -> legacy may be attempted
- modern invalid packet framing -> legacy may be attempted
- malformed modern JSON/schema -> `invalidResponse`, no fallback
- previously successful modern server + later transient timeout -> preserve
  modern stale/grace snapshot; do not downgrade to legacy
- `allowLegacyFallback: false` disables fallback
- CLI equivalent: `--no-legacy`

## Latest validation

Windows validation on 2026-10-02:

```text
dart analyze
No issues found!

dart test
00:02 +36: All tests passed!
```

Live modern query:

```text
address=oyna.provanas.com
target=oyna.provanas.com:25565
state=online
format=modern
version=Velocity 1.7.2-26.2
protocol=776
players=170/171
latencyMs=6
```

Strict modern-only query:

```text
--no-legacy
state=online
format=modern
protocol=776
latencyMs=7
```

## Package version

```text
minecraft_info_provider 1.0.0-dev.6
```

## Important non-goals / deferred work

The server status response does not prove:

- authentication success
- loader negotiation success
- final join compatibility
- that every advertised mod is client-required

Still deferred:

- world discovery and `level.dat`
- player data
- statistics / advancements
- installed mods/resource packs/shaders/data packs
- client-mod activity discovery
- write-side address deduplication policy

## Continuation protocol

For a new conversation:

1. Read `docs/continuity/CURRENT_TARGET.md`.
2. Read this handoff.
3. Inspect current Git branch/HEAD and working tree.
4. Treat the validation and locked architecture above as authoritative.
5. Do not implement a new checkpoint until the user explicitly approves it.
