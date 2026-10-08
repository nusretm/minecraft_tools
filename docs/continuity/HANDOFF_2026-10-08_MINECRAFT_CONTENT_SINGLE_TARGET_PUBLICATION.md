# Minecraft Tools — Single-target Safe Publication Foundation Handoff

Date: 2026-10-08

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Checkpoint: dev.23 — Single-target Safe Publication Foundation
Branch: feature/minecraft-content-single-target-publication
Baseline main: 58f598e2d43ecd1c75a49c83c88de4f8091e3feb
Production/test HEAD: eba5888e36847ca504cac59ea26a28ab49e0bed0
Validated feature HEAD: 494fc3769267d5a0366eefc7d249aec2ab853174
Implementation: COMPLETE
Actual-diff review: COMPLETE
Validation: COMPLETE
Continuity: CLOSED
Merge: NOT REQUESTED
Package version: 1.0.0-dev.23
```

No `dart format` was run.

## Delivered boundary

```text
safe dev.22 preflight
        ↓
single canonical install/replacement target
        ↓
caller-owned source
        ↓
target-parent sibling staging
        ↓
integrity revalidation
        ↓
same-parent promotion
        ↓
reversible publication handle
        ├─ commit
        └─ rollback
```

## Locked behavior

- publication stays on the explicit IO surface
- caller-owned source is read-only and never consumed
- source and installation may be on different volumes
- canonical integrity is revalidated after copying
- metadata-less publication uses transient SHA-256 safety snapshots
- stale dev.22 preflight state is rechecked before mutation
- missing parents are created one segment at a time
- same-target publication is serialized across cooperating authority instances
- successful publication owns its lock until commit or rollback
- existing managed targets are preserved as same-parent backups
- commit revalidates published content before deleting backup state
- rollback revalidates published content and backup state before restoration
- failed promotion attempts immediate managed-backup restoration
- irrecoverable recovery failures preserve candidate files
- dev.22 filesystem implementation body remains unchanged apart from publication wiring
- RemVibe public integrity contract remains intact through the shared internal integrity authority

## Authoritative validation

```text
HEAD:
494fc3769267d5a0366eefc7d249aec2ab853174

dart analyze:
No issues found!

publication focused:
14/14 passed

preflight focused:
12/12 passed

RemVibe integrity:
9/9 passed

RemVibe execution:
7/7 passed

materialization plan:
9/9 passed

installation manifest:
9/9 passed

full dart test:
176/176 passed

git diff --check:
PASS

working tree:
clean
```

## Remaining boundary

Still not implemented:

- whole-plan install/replacement execution
- remove execution
- multi-artifact transaction ordering
- multi-artifact rollback
- installation-manifest filesystem persistence
- RemVibe batch-to-publication orchestration
- staging-root cleanup
- TaskService orchestration

## Next natural checkpoint

```text
completed RemVibe batch
        ↓
dev.22 preflight
        ↓
dev.23 single-target reversible publication
        ↓
dev.24 whole-plan materialization transaction
```

Dev.24 should orchestrate install/replacement publications, removal backup/restore, reverse-order rollback and final commit boundaries without changing the proven single-target primitive.

Merge requires separate explicit user approval.
