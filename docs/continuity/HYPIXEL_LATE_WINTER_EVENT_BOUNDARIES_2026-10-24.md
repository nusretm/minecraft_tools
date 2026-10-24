# Hypixel SkyBlock — Late Winter event calendar correction (2026-10-24)

## State

- The user compared **a live Hypixel in-game Year 521, Late Winter calendar screenshot** with the MTN Launcher App daily timeline. The app showed `Defend Jerry's Workshop` and `Season of Jerry` at identical times, and `Season of Jerry` lasted only one real hour.
- Calendar source inspection located the bug in `hypixel_api/lib/src/skyblock/events/hypixel_skyblock_event_calendar.dart`: both Jerry entries used `Late Winter 24` through three days later, and the New Year event used `Late Winter 29` through three days later.
- User explicitly approved correction limited to the existing Hypixel API calendar and tests. **No Launcher UI work**, new event type, separate short one-hour Season of Jerry or runtime date-offset overrides.
- Feature branch `fix/hypixel-late-winter-event-boundaries`; tests and Windows validation **pending**. Merge requires separate explicit approval.

## Authoritative requested meanings and boundaries

`HypixelSkyBlockCalendar.skyBlockDay == Duration(minutes: 20)`; starts inclusive, ends exclusive. Dates are derived using the existing SkyBlock calendar epoch.

| Existing event type | Meaning used in MTN Launcher | Start (SkyBlock date) | Exclusive end | Real duration |
| --- | --- | --- | --- | --- |
| `seasonOfJerry` | Jerry's Workshop open season, named **Season of Jerry** in app | Late Winter 1, 00:00 | Next year Early Spring 1, 00:00 | 31 SB days = 10h 20m |
| `defendJerrysWorkshop` | Defend event on the live in-game calendar | Late Winter 25, 00:00 | Late Winter 27, 00:00 | 2 SB days = 40m |
| `newYearCelebration` | New Year Celebration on the last two in-game calendar days | Late Winter 30, 00:00 | Next year Early Spring 1, 00:00 | 2 SB days = 40m |

- `defendJerrysWorkshop.parentType` remains `seasonOfJerry`.
- No modification to the pre-existing **three-day** Spooky Festival, Traveling Zoo or their test behavior.
- Do not treat the in-game calendar's 2-day labeled event windows as precise wave-level server telemetry; these are user-requested **calendar windows**.

## Acceptance criteria

- `dart analyze` for `hypixel_api` clean.
- `dart test test/skyblock_events_test.dart -r expanded` PASS, including Year 521 event start/end, duration, parent relation, and no inclusion at exclusive boundaries.
- `dart test` full Hypixel API package PASS.
- `git diff --check main...HEAD` clean and feature working tree clean.
- Optional user UI smoke: repeat the original Late Winter period in MTN Launcher App to see `Season of Jerry` span all Late Winter, `Defend` only days 25–26, and `New Year` only days 30–31. **No UI integration work is authorized here.**

## Windows commands

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin fix/hypixel-late-winter-event-boundaries
git switch --track origin/fix/hypixel-late-winter-event-boundaries

cd hypixel_api
dart pub get
dart analyze
dart test test/skyblock_events_test.dart -r expanded
dart test

cd ..
git diff --check main...HEAD
git status
```
