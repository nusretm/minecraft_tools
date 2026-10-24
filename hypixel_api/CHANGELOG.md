# Changelog

## Unreleased — Late Winter SkyBlock event calendar correction (Windows validation pending)

- Align the existing Season of Jerry event with the full Late Winter workshop-open period (days 1–31, 10h20m), rather than the previous three-day event.
- Place Defend Jerry's Workshop on Late Winter days 25–26 and New Year Celebration on the final two days 30–31 (each 40m), preserving the existing parent event relationship and exclusive end times.
- Update Year 521 calendar boundary regression tests; no additional event type, server call, UI change or revised SkyBlock epoch. Windows analyzer and tests pending.

## 1.0.0-dev.1

Final prototype hardening checkpoint before MtnLauncher integration.

- Consolidated Pure Dart SkyBlock calendar/event APIs.
- Added persistent mayor/election/special-state/scheduled-event history.
- Added Bingo resource, player history/statistics and lifecycle reminders.
- Added official SkyBlock news feed with persistent history.
- Added request caching and rate-limit response state.
- Removed the embedded prototype Hypixel development key.
- Added CLI API-key injection through `--api-key` or `HYPIXEL_API_KEY`.
- Added CLI help and basic argument validation.
- Refreshed README around the final public integration boundary.
