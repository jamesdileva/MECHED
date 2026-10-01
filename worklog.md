# Worklog

Append-only development log. One entry per sprint/session, newest first.
Each entry: date, sprint, scope, what was built, verification results, known issues, next steps.

---

## 2026-09-30 — S03 · Turn System

**Scope (planned):** per roadmap S03 — convert movement into turn-based gameplay. Pure, headless-testable simulation split per implementation-guide §3/§4/§5: `MatchState` (data + queries: turn number, active entity, phase, movement budget, turn timer, match_result placeholder) and `TurnManager` (begin/advance/end turns, budget movement, validate actions — no weapon/AI logic inside it). Discrete `MatchAction` abstraction starting with `EndTurnAction` (Q / gamepad B), submitted via `submit_action()`; continuous movement goes through `apply_movement()` which consumes the per-turn movement budget (3.0s of moving, tunable) — deliberate split, documented: discrete actions for replay, continuous intent for locomotion. `MatchController` (Node shim) reads InputLayer ONLY for the active player entity and zeroes intent for all others — the structural guarantee behind "no moving during another entity's turn"; the dummy opponent (second mech on PlatformB) idles and passes via the turn timer (15s). Mech rework: intent (`move_axis`/`want_jump`) is set externally per tick; the body never reads devices. Fire phase arrives with S04; energy replaces the time budget in S07.

**Done:**

- `scripts/match/` — `match_state.gd` (pure data + queries), `turn_manager.gd` (turn flow, budget, validation; consts TURN_TIME 15s / MOVE_BUDGET 3.0s), `match_action.gd` + `action_end_turn.gd` (discrete action base + first action), `match_controller.gd` (presentation shim: active-entity-only input, zeroes everyone else, `status_line()` for the HUD).
- `mech.gd` reworked to intent-driven: `move_axis`/`want_jump` set externally per tick, `want_jump` consumed after use (edge semantics); `respawn_point` is now an export so the dummy overrides it. Body never touches input devices.
- `end_turn` action added to the input map — Q + gamepad B/Circle — keeping the both-devices contract; architecture.md §18 map updated.
- Main scene: `MatchController` node (processed before mechs so intent lands same-frame) + `DummyMech` instance on PlatformB.
- Debug HUD shows the turn line: `turn N | <name> | move X.Xs | timer Y.Ys`.
- Test harness hardened twice this sprint: (1) zero-assertion tripwire — a test that crashes mid-run used to silently "pass"; the runner now fails any test making no assertions; (2) parse-error guard — a test file that fails to parse aborted the whole run with exit 0; the runner now records it as a failure via `can_instantiate()` and continues.

**Fixed during verification:**

- TurnManager/MatchState are RefCounted: test handles must stay untyped (`-> Node` annotation rejects RefCounted at runtime, aborting tests before any assert) and must NOT go through `_add_cleanup` (Node-only); RefCounted self-releases.
- Caught by the new tripwire while fixing the above: script errors inside tests produce silent PASSes — hence the harness changes above.

**Verification (roadmap S03 checklist):**

- `--import` exit 0; `--quit` smoke run exit 0, no script errors.
- Tests: **22/22 passed** — 9 new turn-system tests cover the roadmap verification directly: two entities alternate turns (end-turn action + wrap-around + turn numbering), a non-active entity cannot move and cannot end the turn (simulation-level rejection), turn timer expiry passes the turn, movement budget consumes only while moving and does not auto-end the turn; plus S01/S02 suites still green and `end_turn` now enforced in the both-devices action contract.
- Still manual (needs eyes/desktop): F5 → turns alternate between Mech and DummyMech (HUD turn line), player moves only on their own turn (input is dead during the dummy's 15s timer), Q/gamepad-B ends the turn early, F1 still resets.

**Next:** S04 — First Projectile (angle/power aiming, ballistic arc, explosion, damage — the FIRE phase slots into the turn between movement and end).

---

## 2026-09-28 — S02 · Basic Mech Controller

**Scope (planned):** per roadmap S02 — one playable mech. `mech.tscn` (CharacterBody3D) with a generic `MechMovementController` node whose kinematics are pure functions (acceleration toward an axis intent, gravity when airborne, jump impulse, movement-limit clamps) so the movement rules are unit-testable without stepping physics. Mech root reads input exclusively via `InputLayer` and feeds the controller `move_axis` / `want_jump` — the same interface an AI driver will use later (implementation-guide §6/§11). Basic facing (visual yaw toward movement), battlefield X bounds + locked side-plane Z, kill-plane respawn, F1 debug reset (implementation-guide §17; raw debug keys are intentionally outside the device-agnostic action contract). Camera3D follows the mech side-on. Debug HUD gains a mech state line. Tests: controller kinematics, clamps, respawn, scene structure.

**Done:**

- `scenes/mechs/mech.tscn` — CharacterBody3D with collision, visual rig (body + orange barrel marking facing), and `Movement` controller child.
- `scripts/movement/mech_movement_controller.gd` — generic movement rules; `compute_velocity()` / `clamp_position()` are pure functions (accel/decel toward axis intent, gravity when airborne, jump impulse, X bounds ±27, Z locked to side plane). Stats are exported for future MechDefinition-driven data.
- `scripts/mechs/mech.gd` — player driver: InputLayer → controller intent, move_and_slide, facing yaw lerp, kill-plane respawn (respawn point (0,3,0), kill plane y<-10). Respawn/kill-plane rules use battlefield-local `position` (Main never moves) — keeps rules tree-independent and testable, matching the MatchState direction.
- `main.gd` — camera follows mech; F1 respawns the mech (debug tools use raw keys by design, outside the action contract).
- Debug HUD shows mech pos/vel/floor state; camera start moved to frame the spawn.
- Test harness upgraded: runner now calls `cleanup()` after each test method; test_base owns Node instances (Nodes are not RefCounted — the first run leaked 6 controller nodes and the exit warnings caught it).

**Fixed during verification:**

- Discovered that in headless `-s` script mode, nodes added to root during `_initialize` never enter the tree (is_inside_tree stays false) — so global_position-based rules can't be tested detached; resolved by making kill-plane/respawn rules battlefield-local.
- Runner now frees Node instances owned by tests (leak warnings at exit eliminated).

**Verification (roadmap S02 checklist):**

- `--import` exit 0; `--quit` smoke run exit 0, no script errors.
- Tests: **13/13 passed** — controller kinematics (accelerate, decelerate-to-stop, jump impulse, gravity while airborne, Z plane lock), battlefield clamps, kill-plane respawn, mech scene structure, plus all S01 tests still green.
- Still manual (needs eyes/desktop): drive the mech with keyboard (A/D, Space, Shift) and gamepad (left stick / d-pad, A, X); confirm camera pans side-on, facing flips, crate/platforms collide, falling off is impossible due to clamps (kill plane verified by test; F1 resets).

**Next:** S03 — Turn System.

---

## 2026-09-28 — S01 · Godot Project Foundation

**Scope (planned):** per roadmap S01 — Godot 4.x project at repo root; main + battlefield scenes (3D side-on per architecture.md); Camera3D; device-agnostic input action map bound to keyboard + gamepad (architecture.md §18); `InputLayer` autoload as the only input access path for gameplay; debug HUD showing engine status + raw action state; folder skeleton per architecture.md §17; automated tests runnable headless; GitHub Actions CI (headless import + tests + smoke run, Godot pinned 4.7.2-stable). Also: MIT license (user-approved this session).

**Decision — test harness:** using a built-in zero-dependency runner (`tests/run_tests.gd`, `extends SceneTree`) instead of vendoring gdUnit4/GUT for S01. Rationale: CI stays dependency-free, S01 tests are structural (InputMap contract, scene graph). Revisit gdUnit4 when mocking / scene-runner tooling is actually needed; the switch will be recorded here.

**Done:**

- Godot 4.7.2 project at repo root (`project.godot`, `icon.svg`), renderer defaults, 1280×720.
- Input action map per architecture.md §18 — all 10 actions bound to keyboard AND gamepad simultaneously (WASD/arrows/space/shift/enter/tab/E/esc + d-pad, left stick, right stick, A/X, LB/RB, LT/RT, Start); deadzone 0.25.
- `scripts/input/input_layer.gd` — `InputLayer` autoload; the only input path gameplay code may use.
- `scenes/main/main.tscn` — Main (Node3D) with WorldEnvironment + sun, battlefield instance, side-on Camera3D (`game_camera.gd`, static framing with optional follow target for later sprints), debug HUD (`debug_hud.gd`) showing engine version, FPS, camera position, and live action state.
- `scenes/battlefield/battlefield.tscn` — ground + two platforms (StaticBody3D) and one falling crate (RigidBody3D) so physics is visibly alive.
- Folder skeleton per architecture.md §17 (`scenes/`, `scripts/`, `data/`, `assets/`, `tests/` subfolders).
- Test harness: `tests/run_tests.gd` runner + `test_base.gd` asserts + `test_input_actions.gd` (enforces the both-devices binding contract) + `test_scenes.gd` (scene structure).
- CI: `.github/workflows/ci.yml` — headless import, tests, one-frame smoke run on ubuntu-latest with Godot 4.7.2-stable.
- Fixed during verification: runner discovered `*_test.gd` while tests are named `test_*.gd` (prefix convention) — discovery filter corrected; RefCounted instances must not be `free()`d.

**Verification (roadmap S01 checklist):**

- `godot --headless --path . --import` → exit 0, no script errors.
- `godot --headless --path . -s res://tests/run_tests.gd` → **6/6 tests passed** (action map exists; every action has keyboard + gamepad binding; deadzones configured; main scene assembled; battlefield ground solid; main-scene setting correct).
- `godot --headless --path . --quit` → main scene loads, autoloads + one frame process cleanly, exit 0.
- CI on GitHub Actions: green (checked after push).

**Still manual (needs eyes on a desktop):** run the project from the editor/CLI and confirm the sandbox window renders, the debug HUD updates when pressing keyboard keys and a gamepad stick/buttons. Everything else is automated.

**Next:** S02 — Basic Mech Controller.

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
