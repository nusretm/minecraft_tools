# Minecraft Tools — Current Target

Last updated: 2026-10-02

## Repository

- Repository: `nusretm/minecraft_tools`
- Local path: `D:\development\cross-platform\minecraft_tools`
- Repository layout:
  - `hypixel_api/` — unrelated to the current Minecraft info work
  - `minecraft_info_provider/` — current package
- Do not modify `hypixel_api/` for `minecraft_info_provider` checkpoints.

## Authoritative baseline

Merged `main` baseline before the active checkpoint:

```text
main
ad3eb84922e54401c825c69d789a78786cea546a
```

This baseline includes:

- Java NBT codec
- `servers.dat` read/append with unknown-tag preservation
- modern Java Server List Ping
- server-owned online/offline/unavailable lifecycle
- `MtnMinecraftInfoServer.onChange`
- Forge/FML advertised status metadata
- Minecraft SRV discovery
- server address normalization
- known-server matching
- IPv4/IPv6 canonicalization

## Active checkpoint

Legacy pre-1.7 Java server-list ping fallback.

Current branch:

```text
feature/minecraft-legacy-server-ping
```

Validated implementation commit before continuity-only changes:

```text
82de274ab3513558fff1107679ff43bc1f1411b1
```

Package version:

```text
1.0.0-dev.6
```

### Implemented behavior

`MtnMinecraftInfoServer.queryStatus()` remains the lifecycle owner.

Modern Server List Ping is always attempted first.

Legacy fallback order:

1. Minecraft 1.6 extended ping — `FE 01 FA` + `MC|PingHost`
2. Minecraft 1.4/1.5 ping — `FE 01`
3. pre-1.4 ping — `FE`

Public status format:

```dart
enum MtnMinecraftInfoServerStatusFormat {
  modern,
  legacy16,
  legacy14,
  legacyPre14,
}
```

`MtnMinecraftInfoServerStatus.format` reports the successful wire format.

Public query option:

```dart
server.queryStatus(
  allowLegacyFallback: true,
);
```

Default: `true`.

CLI strict-modern switch:

```text
--no-legacy
```

### Locked fallback semantics

Legacy fallback is protocol fallback, not a general connectivity fallback.

Fallback may run when:

- the modern status request times out after reaching the endpoint
- modern packet framing is invalid (`invalidPacket`)

Fallback must not hide a malformed modern JSON/schema response:

```text
invalidResponse -> exception, no legacy fallback
```

A server instance that has already produced a successful modern response must
not be downgraded to legacy because of a transient later timeout. Existing
stale/grace lifecycle behavior remains authoritative.

DNS/connect failures retain the existing unavailable semantics.

### Legacy response semantics

1.6 / 1.4-style responses may expose:

- protocol
- displayed version
- MOTD
- online player count
- max player count
- legacy request/response latency

Very old pre-1.4 responses expose:

- MOTD
- online player count
- max player count

For pre-1.4:

- `protocol == null`
- `versionName == null`

Legacy responses do not provide modern JSON-only data such as:

- favicon
- secure-chat state
- player sample
- Forge/FML JSON status metadata
- raw JSON

## Validation status

Validated on Windows on 2026-10-02:

```text
dart pub get   PASS
dart analyze   PASS — No issues found
dart test      PASS — 36/36
```

Live modern regression:

```text
host: oyna.provanas.com
state: online
format: modern
versionName: Velocity 1.7.2-26.2
protocol: 776
players observed: 170/171
latency observed: 6 ms
```

Strict modern-only regression with `--no-legacy` also passed:

```text
state: online
format: modern
protocol: 776
latency observed: 7 ms
```

Therefore the implementation at commit
`82de274ab3513558fff1107679ff43bc1f1411b1` is:

```text
IMPLEMENTED / VALIDATED
```

It has not yet been merged to `main`.

Continuity-document commits after that validation do not change runtime code
and do not invalidate the validation result.

## Locked server architecture

### Runtime ownership

```text
MtnMinecraftInfoServer
├─ persisted server entry fields
├─ parsedAddress
├─ status
├─ onChange
├─ queryStatus()
└─ per-instance failure/grace history
```

Raw transport clients are stateless.

### Status lifecycle

States:

```text
online
offline
unavailable
```

Rules:

- successful response -> online, fresh snapshot
- DNS failure -> unavailable
- SRV target `.` -> unavailable
- after a previous success, first consecutive non-DNS reachability failure
  starts the grace window
- within grace -> online + stale
- after grace -> offline + stale
- success resets the failure window
- stale snapshots retain known server data and clear latency

Default grace:

```text
1 minute
```

### SRV behavior

For a bare hostname:

```text
_minecraft._tcp.<host>
```

Explicit ports bypass SRV.

No usable SRV record falls back to the original host on port 25565.

The TCP socket connects to the resolved SRV target, while Server List Ping
keeps the original user-facing hostname in the handshake.

### Address normalization

`MtnMinecraftInfoServerAddress` is the single shared address parser.

Canonical comparison covers:

- surrounding whitespace
- DNS case folding
- trailing DNS root dot
- default port 25565 equivalence
- IPv4 normalization
- IPv6 byte-level canonicalization and stable zero compression

Canonicalization never rewrites the persisted `servers.dat` address.

### Known-server matching

`MtnMinecraftInfoKnownServer.match(server)` evidence order:

1. `exact`
2. `normalized`
3. `resolvedEndpoint`
4. `none`

Resolved endpoint evidence is intentionally weaker than user-facing address
identity because multiple domains may share one proxy/backend.

Protocol, version, MOTD, favicon and player counts are not identity evidence.

## Development rules

- Do not start implementation without explicit user approval.
- Keep checkpoints small and independently reviewable.
- Do not commit/push/merge/tag unless the current task explicitly calls for it.
- Prefer deterministic automated tests before live smoke tests.
- Do not introduce Flutter or MtnLauncher dependencies into
  `minecraft_info_provider`.
- Preserve Pure Dart operation.
- Do not add backward-compatibility layers unless explicitly requested.

## Next action

The active legacy ping checkpoint is validated and ready for merge when the
user approves it.

After merge, reassess the next `minecraft_info_provider` target before
implementation. Likely remaining domains include:

- world discovery / `level.dat`
- player data
- statistics / advancements
- installed content discovery
- address deduplication/write policy

Do not assume one of these is selected until the user chooses the next target.
