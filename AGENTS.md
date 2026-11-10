# Minecraft Tools — Codex Repository Instructions

Before planning, implementing, or reviewing, read `docs/WORKING_RULES.md` and the relevant entries under `docs/continuity/` (especially `CURRENT_TARGET.md` and the active target handoff/plan).

- Respect each package's own boundaries and public API. The former `minecraft_loader_version_list/` package is retired; loader version metadata is owned by `nusretm/minecraft_models`. Read `docs/continuity/LEGACY_VERSION_LIST_REMOVAL.md` for the removal scope and separate consumer migration gates.
- Treat `docs/WORKING_RULES.md` as this repository's authoritative engineering standard; repository and package rules refine global user instructions.
- Do not begin implementation, modify sibling packages, merge, or expand the approved checkpoint without explicit user approval.
- For pure Dart, do not run `dart format` unless explicitly requested. Verify appropriate analysis/tests and inspect actual source diffs independently.
- Preserve unrelated work and documented decisions. Report checks actually executed, outstanding issues and synthetic versus live/runtime validation accurately.

## Codex visual-acceptance boundary (2026-11-10)

- **Do not delegate visual/UI acceptance to Codex.** Codex must not use computer-use, screenshots, remote desktop, GUI automation, or manual window inspection to perform or claim visual verification. Do not request permission to do so.
- **The user performs visual acceptance.** If visual inspection is required, stop at that gate, give the user concise manual verification steps, and record the result as **NOT VISUALLY VERIFIED** until the user explicitly reports acceptance.
- Non-visual work remains allowed: source review, implementation, automated tests (including widget/integration tests), static analysis, builds, CLI/API checks, artifact integrity, executable metadata, and logs. These checks are not substitutes for user-observed UI acceptance.
- Never assert that a window rendered correctly, an interaction looked right, or visual acceptance passed solely from test results, process existence, screenshots, or tool output.
