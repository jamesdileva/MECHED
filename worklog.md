# Worklog

Append-only development log. One entry per sprint/session, newest first.
Each entry: date, sprint, scope, what was built, verification results, known issues, next steps.

---

## 2026-09-28 — S00 · Repository & Documentation Foundation

**Scope (planned):** set up repo + docs, adopt the sprint workflow, add the controller-support plan. No game code yet.

**Done:**

- Reviewed `architecture.md`, `implementation-guide.md`, `sprint-roadmap.md`; moved them into `docs/`.
- Added **Input & Controller Architecture** section to architecture.md (§18): device-agnostic actions, initial keyboard/gamepad action map, analog aiming rules, focus-based UI navigation.
- Added **S04B — Controller Support** sprint to the roadmap (after S04 First Projectile); S01 and S19 updated so gamepad bindings and controller-navigable UI are part of those sprints from the start.
- implementation-guide.md §2 now states gameplay must read abstract actions, never raw device input.
- Created README.md, AGENTS.md (sprint workflow + engineering rules + winget Godot commands), .gitignore (Godot 4).
- Initialized git; created public GitHub repo `jamesdileva/MECHED` and pushed.

**Environment notes:**

- Godot 4.7.2-stable installed via winget (`GodotEngine.GodotEngine`). The shim is `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.cmd`; bare `godot` does not resolve in Git Bash (`.cmd` needs the extension there) but works in PowerShell/CMD.

**Process adopted:** every sprint = plan+scope → implement → verify (tests + checklist) → commit+push → worklog update.

**Next:** S01 — Godot Project Foundation (project.godot at repo root, main + battlefield scenes, camera, device-agnostic input action map incl. gamepad, debug HUD, gdUnit4 test harness, headless CI check).
