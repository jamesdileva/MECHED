# MECHED — Mech Artillery Tactics

[![CI](https://github.com/jamesdileva/MECHED/actions/workflows/ci.yml/badge.svg)](https://github.com/jamesdileva/MECHED/actions/workflows/ci.yml)

Turn-based tactical artillery with mechs: destructible terrain, ballistic projectiles, wind, and physics-driven positioning. The GunBound artillery core, rebuilt around **movement, positioning, and battlefield manipulation**.

**Status:** S01 complete — Godot project foundation with a blank 3D combat sandbox, device-agnostic input (keyboard + gamepad), debug HUD, tests, and CI. Next: S02, the basic mech controller. See the [sprint roadmap](docs/sprint-roadmap.md).

## What Makes It Different

- **Positioning > precision** — a perfect shot is not the only path to success; movement energy, elevation, cover, and knockback matter as much as aim.
- **Terrain is a weapon** — destroying the ground under an enemy is often better than hitting them.
- **Universal weapons, transformed by mechs** — every mech changes how the same weapon behaves (Rocket → Siege / Split / Guided Rocket).
- **AI is a first-class feature** — the AI plays by the same rules and reasons about positioning and terrain rather than getting accuracy cheats.

Built with **Godot 4.x** (GDScript). The MVP is single-player vs AI; the architecture is prepared for future server-authoritative multiplayer.

## Repository Layout

- `docs/` — [architecture](docs/architecture.md), [implementation guide](docs/implementation-guide.md), [sprint roadmap](docs/sprint-roadmap.md)
- [worklog.md](worklog.md) — append-only development log, one entry per sprint
- [AGENTS.md](AGENTS.md) — working agreement for AI/human contributors (sprint workflow, engineering rules)
- `project.godot` + `scenes/`, `scripts/`, `data/`, `assets/` — the game (data-driven content per the architecture doc)
- `tests/` — headless test suite (`test_*.gd`, run via `tests/run_tests.gd`)

## Development Setup

1. Install Godot 4.x — via winget: `winget install GodotEngine.GodotEngine`
   The executable shim lands in `%LOCALAPPDATA%\Microsoft\WinGet\Links\`; PowerShell/CMD expose it as `godot`, Git Bash needs `godot.cmd` (with extension).
2. Open the repository root in Godot and press F5 — you should see the combat sandbox with a debug HUD.

Verification without opening the editor:

```bash
"$LOCALAPPDATA/Microsoft/WinGet/Links/godot.cmd" --headless --path . -s res://tests/run_tests.gd
```

## Process

Every sprint follows the same loop (details in [AGENTS.md](AGENTS.md), history in [worklog.md](worklog.md)):

```text
plan + scope → implement → verify (tests + checklist) → commit + push → update worklog
```

## License

[MIT](LICENSE)
