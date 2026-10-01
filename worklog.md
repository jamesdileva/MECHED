# Worklog

Append-only development log. One entry per sprint/session, newest first.
Each entry: date, sprint, scope, what was built, verification results, known issues, next steps.

---

## 2026-10-01 — S05 · Terrain Destruction

**Scope (planned):** per roadmap S05 — the battlefield becomes persistent destructible state, following architecture.md §5's "Destruction Mask" and implementation-guide §9 (manageable system now, voxel only if ever proven necessary). Representation decision: a **2D cell mask in the X–Y gameplay plane, extruded into a fixed Z slab** — the side-on game plays entirely in X–Y, and a 2D mask supports tunnels/overhangs later (S13) where a heightmap would not, and serializes as a byte array for future replay/multiplayer sync. Layers: `terrain_grid.gd` (pure RefCounted: cell mask, `destroy_circle`, surface query, `is_solid_world`, serialize/deserialize — fully headless-testable), `terrain_mesher.gd` (pure static: builds visual+collision triangle geometry per chunk from the mask — only exposed faces, grass tops over dirt, front cross-section caps), `terrain_system.gd` (Node3D: chunked rebuilds — 0.25m cells, 32-cell chunks, one ConcavePolygonShape3D + ArrayMesh per touched chunk; `apply_explosion/restore/serialize/query_surface_y`). Integration: battlefield's box Ground is replaced by the generated TerrainSystem (flat 4m-deep ground, top at y=0); MatchController carves a crater at every projectile impact (before finishing resolution). Unshaded vertex-colored material + backface collision chosen deliberately so winding/normals can never make terrain invisible or uncollidable. The old StaticBody3D platforms remain as (not-yet-destructible) structures.

**Done:**

- `scripts/terrain/terrain_grid.gd` — pure mask: 0.25m cells, row 0 = top, `destroy_circle` (returns cells removed), `destroy_rect`-ready, `query_surface_y` (NAN when dug through), `is_solid_world`, byte-exact `serialize`/`deserialize`.
- `scripts/terrain/terrain_mesher.gd` — pure static: per-chunk triangles from the mask; only exposed faces (top/bottom/sides span the Z slab, front cross-section caps), grass tops over dirt via per-vertex colors; the same triangle array drives mesh AND ConcavePolygonShape3D so visuals and collision cannot drift.
- `scripts/terrain/terrain_system.gd` + scene — chunked rebuilds (32-cell chunks, 8×2 chunks over the 60×12m field); `apply_explosion` carves then rebuilds only overlapping chunks; `restore`/`serialize`/`deserialize`/`query_surface_y` exposed. Empty chunks drop their mesh+shape.
- Battlefield: box Ground removed, generated TerrainSystem in its place (flat 4m slab, top y=0); platforms remain as structures. MatchController carves a crater at every impact before finishing resolution; Main wires the reference.

**Fixed during verification:**

- **Inverted-row bug caught by the new tests before it could ship:** the mask's row axis runs top-to-bottom (inverted vs world y), so `destroy_circle`'s lo..hi cell range was empty for any descending box — nothing was ever carved (tests reported 0 cells removed). Fixed with per-axis min/max in both the grid and the chunk-dirty computation.
- Same repeated GDScript lesson: `:=` cannot infer through untyped `load()` handles — explicit types in terrain_system and the mesher.
- Two test-geometry errors of my own corrected against the real slab: a 2.5m blast at mid-depth punches clean through 4m of ground (surface query → NAN), and a bottom-centered 1.5m blast hollows the floor without opening a through-hole.

**Verification (roadmap S05 checklist):**

- `--import` exit 0; `--quit` smoke run exit 0; tests **46/46 passed** — 10 terrain tests cover crater carving (mask + plausible πr² count), repeated explosions keep carving, surface query drops with craters, through-dug pits (no surface), serialize roundtrip, mesher reflects destruction, empty chunks emit nothing; battlefield scene test now asserts the TerrainSystem; all prior suites green.
- Still manual (needs eyes/desktop): F5 → fire at the ground → crater forms visibly (grass rim, dirt cross-section), mechs can walk in/fall into craters, shell collisions use the new geometry, repeated shots keep deforming the battlefield, terrain never renders invisible (unshaded + cull-disabled by design).

**Next:** S06 — Knockback (explosion force: distance × mech mass; pushes positioning forward).

---

## 2026-10-01 — S04B · Controller Support (verification sprint)

**Scope (planned):** most of S04B's build list was deliberately front-loaded by the from-day-one input architecture: the both-devices action map (S01), the InputLayer facade (S01), analog stick aiming + trigger fire (S04), end_turn on Q/B (S03), and per-action deadzones as global config (0.25, project.godot). What remained for this sprint:

- Automated half (already green): every sandbox action has a keyboard AND gamepad binding — enforced by `test_input_actions.gd` in CI.
- Analog aiming precision: rate-based stick aim (70°/s at full deflection) is inherently finer-grained than the keyboard's fixed rate — variable deflection gives variable speed. No response curve added for now; tune only if playtesting asks.
- Both devices in one session, switchable at any moment: by design (both bindings feed the same named actions; InputLayer merges them).
- Controller disconnect never soft-locks a turn: guaranteed by the turn timer — `test_turn_system.gd` proves a turn passes with zero input.

Weapon cycling (Tab/LB/RB) has no weapons to cycle until S11 — bindings verified, gameplay deferred.

**Verification (manual — pending user playtest):** (1) move/jump on both keyboard and gamepad in the same session; (2) stick aiming precision feels comparable to keyboard aiming; (3) unplug the controller mid-turn — the turn still passes via timer and keyboard keeps working; (4) camera pans with movement; (5) dummy HP visibly drops; (6) crate clear of spawn.

**Status:** **CLOSED 2026-10-01** — user playtest passed: both devices work in one session with free switching, stick aim precision good, turns always progressed. Literal mid-turn disconnect untested by hand, but the guarantee is turn-timer-based and proven by `test_turn_system.gd` (a turn passes with zero input), so the sprint closes per its verification criteria.

**Next:** S05 — Terrain Destruction.

---

## 2026-10-01 — S04.1 · Playtest Fixes

**Scope (planned):** first user playtest of S02–S04 found: (1) mech could not move or jump although the HUD showed the inputs arriving and the movement budget draining — a regression from S03; (2) the crate spawns onto the player mech's head; (3) damage to the DummyMech was invisible (HUD only showed the player's health); (4) no in-world power readout while charging (S19 combat UI will own that; the debug HUD has the numbers). Dash/ability inputs having no gameplay is expected (S08+/S23).

**Root cause (1):** S03's mech rewrite moved driver intent onto the mech but `compute_velocity()` still read the controller's own `move_axis`/`want_jump` variables, which nothing set anymore — the mech permanently saw axis 0 / no jump. The S02 tests covered the controller in isolation; the mech↔controller wiring has no automated coverage (it needs physics frames). Fix is structural, not just the one-line restore: intent now flows as explicit arguments — `compute_velocity(current, axis, jump, on_floor, delta)` — and the controller stores no intent state at all, so this class of silent wiring bug is impossible by construction. Kinematics tests updated to the pure signature (+1 direction test).

**Also fixed:** (2) crate spawn moved off the player (0,8,0 → 5,8,0). (3) HUD combat line now lists every entity's health straight from `MatchState.mech_health` (the source of truth) plus player aim/charge — dummy damage is visible. (4) Polish found while in there: jump and fire-charging are now move-phase-gated in the match layer, so nothing movement-related can happen while a shell is in flight.

**Verification:** import exit 0; smoke run exit 0; tests **37/37 passed**; CI green. Manual re-check pending (doubles as the S04B checklist below): move/jump on keyboard and gamepad, camera pan, facing flip, dummy HP drop in HUD, crate clear of spawn.

---

## 2026-09-30 — S04 · First Projectile

**Scope (planned):** per roadmap S04 — the fundamental artillery system. Pure math module `scripts/combat/ballistics.gd` (RefCounted, static): power→speed (8–30 m/s), angle+facing→launch velocity, analytic time-of-flight/range on a ground plane, explosion damage falloff (direct hit ≤0.75m = full 40 dmg, linear to 0 at 2.5m radius) — one deterministic source of truth for the projectile, the future AI shot planner, and tests (guide §16: gravity, flight, direct/partial damage). Turn flow inserts FIRE→RESOLVING: `FireAction` (carries charge 0–1) accepted only in MOVE phase → RESOLVING (movement/aim/fire/end-turn all blocked, timer paused) → `finish_resolution()` ends the turn. Presentation: RigidBody3D projectile (physics owns flight per guide §10; CCD on) launched from a new mech AimPivot/Muzzle; aiming = aim_up/down rotates barrel 0–90° (persistent per mech), hold-fire charges ~1.2s, release fires; expanding-sphere explosion FX; damage applied by MatchController via deferred sphere query (space-lock safe), health tracked in MatchState (`mech_health` — the state object is the source of truth; mech node holds a synced mirror for the HUD). Design decision recorded: aiming runs in parallel with movement during the turn (GunBound-style) rather than a strict sequential weapon phase — architecture.md §7 annotated; sequential phases return when abilities exist (S08+). Known trade-off: engine-integrated projectiles are not cross-machine deterministic — flagged for S39/S41 multiplayer work.

**Done:**

- `scripts/combat/ballistics.gd` — pure static math: power→speed, angle+facing→launch vector, analytic time-of-flight/range, damage falloff (direct ≤0.75m full 40 dmg → linear to 0 at 2.5m). One source of truth for projectile + future AI planner + tests.
- `action_fire.gd` (carries charge 0–1); TurnManager handles FIRE→RESOLVING: accepted only in MOVE phase, movement/aim/fire/end-turn all locked while resolving, turn timer pauses during flight, `finish_resolution()` passes play on.
- `MatchState`: RESOLVING phase, `mech_health` dict (authoritative health; `apply_damage` clamps at 0), `is_resolving()`.
- `projectile.tscn` — RigidBody3D with CCD + contact monitoring (no tunneling at 30 m/s), match gravity 30 via gravity_scale; `explosion_effect.tscn` — self-expiring expanding blast (pure presentation).
- mech: AimPivot (0–90° barrel elevation, persists between turns) + Muzzle marker; aim/charge intent set by MatchController; `facing()` signs the launch vector; health mirror via `sync_health()`.
- MatchController: hold-fire charges over ~1.2s, release submits FireAction → spawns shell from muzzle with ballistics velocity; impact resolves deferred (space-lock safe) via sphere query → falloff damage through MatchState → finish_resolution.
- HUD combat line: `hp | aim° | pow`; debug turn line shows `resolving` during flight.

**Fixed during verification:**

- Parse error caught by the S03 harness guard before it could hide: MatchController is a plain Node — `get_world_3d()` doesn't exist there; the space query now goes through `get_viewport().world_3d.direct_space_state`.
- test_ballistics inference errors (`:=` from untyped `load()` handle) — explicit types; the parse guard recorded the broken file as FAIL instead of silently voiding it.

**Verification (roadmap S04 checklist):**

- `--import` exit 0; `--quit` smoke run exit 0, no script errors.
- Tests: **36/36 passed** — 8 ballistics/damage tests (speed scaling, 45° symmetry + facing mirror, angle clamps, analytic drop time, power→range, direct/partial/zero damage falloff), 4 new fire-phase turn tests (fire→resolving, everything locked while resolving + timer paused, finish_resolution advances, health tracked/clamped in MatchState), 2 new scene-structure tests (projectile CCD/contact flags, explosion mesh); all S01–S03 suites still green.
- Still manual (needs eyes/desktop): F5 → aim with Up/Down or right stick (HUD shows angle), hold Enter/RT to charge (HUD pow bar), release to fire, watch the arc + explosion, land hits on the DummyMech (hp drops in HUD), miss → shell explodes on terrain; turn passes after resolution.

**Next:** S04B — Controller Support (analog aiming quality, both devices live in one session), then S05 — Terrain Destruction.

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
