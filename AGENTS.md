# AGENTS.md

Working agreement for AI agents (and humans) contributing to this repository.

## Project

**MECHED — Mech Artillery Tactics**: turn-based mech artillery with destructible terrain, physics-driven positioning, and AI opponents. Godot 4.x, GDScript, PC first, single-player + AI before multiplayer.

Read these before writing any code:

| File | Purpose |
| --- | --- |
| `docs/architecture.md` | What the game is, system breakdown, design pillars, input/controller architecture |
| `docs/implementation-guide.md` | How to implement, correct order, anti-patterns to avoid |
| `docs/sprint-roadmap.md` | The sprint list (S01…) with per-sprint verification criteria |
| `worklog.md` | What has been done; newest entries first |

## Sprint Workflow (required for every sprint)

1. **Plan + scope.** Restate the sprint goal from `docs/sprint-roadmap.md`, list exactly what will be built, and write the scope into `worklog.md` before implementing.
2. **Implement.** Build only what was scoped. If scope must change mid-sprint, record why in `worklog.md`.
3. **Verify.** Run the automated tests and the sprint's manual verification checklist. A sprint is not done until its Verification section passes.
4. **Commit + push.** Small, descriptive commits with conventional prefixes: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`.
5. **Update `worklog.md`.** Date, sprint id, what was built, verification results, known issues, next steps — then push.

Never start the next sprint before the current one is verified and logged.

## Engineering Rules

- Godot 4.x, GDScript only. Do not introduce C#/GDExtension without an explicit decision recorded in `worklog.md`.
- **Combat engine first, game second** (architecture.md §19). No content before systems.
- Data-driven content: mechs, weapons, abilities, maps are Godot Resources — never hardcoded.
- Simulation is separate from presentation; `MatchState` is the source of truth.
- AI uses the same action system as players — no cheating.
- Input is device-agnostic: gameplay reads named actions only, and keyboard + gamepad bindings are always added together (architecture.md §18).
- Tests are written with the system, not in a later pass: **gdUnit4** (preferred) or GUT from S01 onward, runnable headless.
- Keep the project always runnable: after every change, a headless import/check must pass without script errors (see Commands).
- Never commit generated files (`.godot/`) or export credentials.

## Commands

Godot 4.7.2-stable is installed via **winget** (package `GodotEngine.GodotEngine`). The winget shim has no bare `godot` executable for Git Bash — call it with the `.cmd` extension:

```bash
# version check
"$LOCALAPPDATA/Microsoft/WinGet/Links/godot.cmd" --version

# headless import / script-error check (must exit clean after every change)
"$LOCALAPPDATA/Microsoft/WinGet/Links/godot.cmd" --headless --path . --import --quit
```

PowerShell/CMD expose it as `godot` directly. CI (to be added in S01) installs Godot independently of winget — keep the version pinned to 4.7.2-stable.

## Code Style

- Follow the official Godot GDScript style guide: tabs for indentation, `snake_case` files and functions, `PascalCase` classes, `UPPER_SNAKE` constants.
- Use static typing where practical.
- Folder layout follows architecture.md §17: `scenes/`, `scripts/`, `data/`, `assets/`, `tests/` at repo root, `project.godot` at repo root.
- Comments state constraints the code cannot show — never history or narration.

## Docs Discipline

- `docs/` is the source of truth for design. If code and docs disagree, fix one of them deliberately — never silently.
- Decisions that change design go into the relevant doc **and** `worklog.md`.
- `worklog.md` is append-only: never rewrite past entries.
