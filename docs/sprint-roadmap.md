# Mech Artillery Tactics

## Sprint Roadmap

This roadmap prioritizes **playable combat and mechanical validation** over content production.

The goal is not to build a large game immediately.

The goal is to prove the core combat loop, then progressively turn that prototype into a complete game.

---

# Development Strategy

## Phase 0 — Combat Prototype

Prove:

> Moving + aiming + shooting + destroying terrain = fun.

No menus.
No online multiplayer.
No progression.
No cosmetic systems.

---

# S01 — Godot Project Foundation

## Goal

Create the base Godot 4.x project and establish the architecture.

### Build

* Godot project
* main scene
* battlefield scene
* camera
* input configuration — device-agnostic action map bound to keyboard + gamepad from day one (see architecture.md, Input & Controller Architecture)
* basic folder structure
* debug HUD

### Verification

Launch project successfully.

Verify:

* scene loads
* camera works
* input works
* debug information displays
* project structure exists

### End State

A clean blank combat sandbox.

---

# S02 — Basic Mech Controller

## Goal

Create one playable mech.

### Build

* mech scene
* movement
* gravity
* jumping
* collision
* basic facing direction
* movement limits

### Verification

Player can:

* move left/right
* jump
* land
* move across uneven terrain
* fall
* recover/reset

### End State

A mech can physically navigate the battlefield.

---

# S03 — Turn System

## Goal

Convert movement into turn-based gameplay.

### Build

```text
PLAYER TURN
    ↓
movement
    ↓
fire
    ↓
AI TURN
    ↓
movement
    ↓
fire
```

Implement:

* turn manager
* active player
* turn timer
* turn transition
* movement allowance

### Verification

Two entities can alternate turns.

A player cannot move during another entity's turn.

### End State

A basic turn-based battlefield exists.

---

# S04 — First Projectile

## Goal

Build the fundamental artillery system.

### Build

* projectile
* angle control
* power control
* gravity
* collision
* explosion
* damage

### Verification

Player can:

* select angle
* select power
* fire
* observe projectile arc
* hit target
* miss target

### End State

GunBound-style artillery exists.

---

# S04B — Controller Support

## Goal

Make the current sandbox fully playable on gamepad and lock in the input architecture while it is still cheap.

### Build

* device-agnostic input action map (Godot Input Map) shared by keyboard and gamepad
* analog stick aiming (angle via stick, power via trigger hold)
* move / jump / fire / weapon cycling on gamepad buttons
* global deadzone configuration
* thin InputLayer between Godot input and gameplay code

### Verification

* every action in the sandbox has both a keyboard and a gamepad binding
* analog aiming precision is comparable to keyboard aiming
* keyboard and gamepad both work in the same session, switchable at any moment
* disconnecting the controller never soft-locks the turn

### End State

Input is device-agnostic. Every future sprint adds gamepad bindings alongside keyboard bindings by default.

### Why this early

Aiming is the core verb. Retrofitting analog aiming into a finished aiming system means reworking input, camera, and UI at once. Declaring the action map now forces every later system (abilities, UI, debug tools) to stay input-agnostic from birth.

---

# S05 — Terrain Destruction

## Goal

Make the battlefield destructible.

### Build

* terrain representation
* explosion crater
* terrain collision update
* visual update

### Verification

Fire at terrain.

Confirm:

* crater forms
* collision changes
* mech can interact with new terrain
* repeated explosions continue modifying terrain

### End State

The battlefield becomes persistent gameplay state.

---

# S06 — Knockback

## Goal

Make positioning matter.

### Build

Explosion force.

Variables:

```text
explosion_force
distance
mech_mass
terrain_contact
```

### Verification

Test:

* direct hit
* near miss
* explosion underneath mech
* explosion beside mech
* explosion at different distances

### End State

Players can strategically push opponents.

---

# S07 — Movement Energy

## Goal

Introduce the first major departure from GunBound.

### Build

Movement energy.

Example:

```text
100 energy

walk = 1 / distance
jump = 10
dash = 25
```

### Verification

Player can:

* move
* spend energy
* stop moving
* fire
* regain energy on future turns

### End State

Movement becomes a strategic resource.

---

# S08 — First Mobility Mech

## Goal

Prove that different mobility models change gameplay.

Create:

## Strider

* high movement
* low armor
* dash

### Verification

Compare:

```text
Standard mech
vs
Strider
```

on identical terrain.

The two should naturally produce different strategies.

### End State

Mobility is now part of mech identity.

---

# S09 — Jetpack Mech

## Goal

Test the user's jetpack concept.

Create:

## Wraith

Abilities:

* jetpack
* limited fuel
* aerial movement
* hover

### Verification

Test:

* crossing gaps
* escaping terrain traps
* aerial firing
* jetpack fuel management
* being knocked while airborne

### Critical Question

Does aerial mobility create interesting decisions or simply make the mech overpowered?

Tune accordingly.

---

# S10 — Tank Mech

## Goal

Create the third archetype.

## Bastion

Properties:

* high mass
* high armor
* low movement
* strong knockback resistance
* anchor ability

### Verification

Test the three archetypes:

```text
Bastion
Strider
Wraith
```

on the same map.

### End State

Three fundamentally different approaches to positioning.

---

# S11 — Universal Weapon Framework

## Goal

Separate weapons from mechs.

Create:

```text
WeaponDefinition
+
MechWeaponModifier
```

### Initial weapons

* Rocket
* Grenade
* Energy Shot

### Verification

Every mech can equip every weapon.

No weapon should require a mech-specific implementation.

### End State

Weapons are universal gameplay building blocks.

---

# S12 — Weapon Transformation

## Goal

Implement the project's signature system.

Example:

### Rocket

Bastion:

> Siege Rocket

Strider:

> Split Rocket

Wraith:

> Guided Rocket

Same base weapon.

Different transformation.

### Verification

Fire the same weapon with all three mechs.

Confirm:

* base projectile remains recognizable
* mech changes behavior
* each transformation creates a meaningful tactical choice

### End State

The game's unique identity starts becoming visible.

---

# S13 — Terrain as Tactical Tool

## Goal

Move beyond "terrain has HP."

Implement:

* tunnels
* cliffs
* bridges
* cover
* ramps
* collapsible platforms

### Verification

Create situations where destroying terrain is strategically better than damaging an opponent.

### End State

Terrain becomes a weapon.

---

# S14 — Wind

## Goal

Introduce classic artillery depth without making aiming the entire game.

Implement:

* wind direction
* wind strength
* projectile influence

### Verification

Confirm wind affects projectiles consistently.

Create:

* tailwind
* headwind
* crosswind
* changing wind

### End State

Players still need to aim, but positioning remains equally important.

---

# S15 — First AI

## Goal

Create a functional AI opponent.

Do NOT start with machine learning.

Use deterministic tactical reasoning.

### AI pipeline

```text
Analyze battlefield
        ↓
Find candidate positions
        ↓
Find candidate targets
        ↓
Select weapon
        ↓
Calculate shot
        ↓
Execute
```

### Verification

AI can:

* move
* select target
* fire
* damage player
* finish a match

### End State

A complete human-vs-AI battle is possible.

---

# S16 — AI Positioning

## Goal

Make AI understand the game's mobility system.

AI evaluates:

* elevation
* cover
* distance
* escape routes
* enemy position
* knockback risk
* movement energy

### Verification

AI should occasionally reposition instead of immediately firing.

### End State

AI demonstrates the game's central design philosophy.

---

# S17 — AI Terrain Awareness

## Goal

Teach AI to use terrain offensively.

AI recognizes:

```text
Direct damage opportunity
        vs
Terrain destruction opportunity
        vs
Positioning opportunity
```

Example:

Instead of shooting the player:

> destroy the platform underneath them.

### Verification

Create a test arena where terrain manipulation is clearly advantageous.

AI should discover the opportunity.

---

# S18 — AI Difficulty

Create four behavioral levels.

### Easy

* limited planning
* imperfect targeting
* simple movement

### Normal

* reasonable positioning
* competent targeting
* ability usage

### Hard

* terrain awareness
* knockback awareness
* multi-step tactics

### Expert

* deeper candidate evaluation
* risk/reward reasoning
* advanced ability combinations

### Important

Difficulty should primarily improve decisions, not simply cheat with accuracy or damage.

---

# S19 — Combat UI

Implement:

* health
* movement energy
* jetpack fuel
* ability cooldowns
* weapon selection
* turn indicator
* aiming indicator
* wind
* mech identity
* controller navigation (focus-based UI, no mouse required)

### Verification

A player can understand the entire combat state without debug information.

---

# S20 — Match Flow

Implement:

```text
Main Menu
    ↓
Mech Select
    ↓
Map Select
    ↓
Battle
    ↓
Victory / Defeat
    ↓
Rematch
```

### End State

The prototype now feels like a game rather than a test scene.

---

# S21 — Map System

Create data-driven maps.

Each map defines:

* terrain
* spawn points
* environmental hazards
* objectives
* wind rules
* boundaries

### Initial maps

1. Canyon
2. Floating Islands
3. Industrial Ruins

### Verification

The same match system can load all three without code changes.

---

# S22 — Environmental Hazards

Prototype:

* lava
* explosive objects
* electric zones
* collapsing structures
* wind tunnels

Do not keep all of them.

Keep only mechanics that create good decisions.

---

# S23 — Mech Ability Pass

Expand each mech.

## Bastion

* Anchor
* Armor Brace
* Siege Mode

## Strider

* Dash
* Wall Climb
* Evasive Burst

## Wraith

* Jetpack
* Hover
* Air Dash

### Verification

Every ability must affect positioning or tactical options.

Avoid passive +10% style abilities unless needed for balance.

---

# S24 — Combat Balance Sandbox

Create an internal test mode.

Allow developers to change:

* health
* movement
* armor
* weapon power
* explosion radius
* knockback
* ability cooldown
* energy
* fuel
* wind

without changing gameplay code.

### End State

Balance iteration becomes fast.

---

# S25 — Physics / Combat Feel Pass

Tune:

* projectile speed
* gravity
* explosion timing
* knockback
* movement acceleration
* jetpack responsiveness
* camera behavior
* impact effects

This sprint is about **feel**, not features.

---

# S26 — Destruction Quality

Improve terrain destruction.

Test:

* repeated explosions
* overlapping craters
* large explosions
* edge cases
* mech falling
* terrain regeneration/reset

### Critical requirement

A match must never become physically broken because of terrain destruction.

---

# S27 — Camera System

Build camera behavior around tactical readability.

Features:

* battlefield framing
* active mech tracking
* projectile tracking
* impact tracking
* optional zoom
* map overview

The player should always understand:

> Where am I?

> Where is my enemy?

> What changed?

---

# S28 — First Complete Vertical Slice

Lock:

* 3 mechs
* 3 weapons
* 1 ability per mech
* 2 maps
* AI
* destruction
* wind
* full match flow

### Verification

A new player can launch the game and complete a match without developer assistance.

---

# S29 — Gameplay Audit

Run structured playtests.

Questions:

1. Is movement fun?
2. Is aiming still satisfying?
3. Is terrain useful?
4. Are mech differences obvious?
5. Is the jetpack interesting?
6. Is knockback too powerful?
7. Does movement overshadow shooting?
8. Does shooting overshadow movement?
9. Are turns too long?
10. Is there enough tactical variety?

Do not add features until these answers are understood.

---

# S30 — Unique Identity Pass

At this point explicitly compare the game against:

* GunBound
* Worms
* ShellShock Live
* modern artillery games
* current mech artillery projects

There are already projects combining destructible artillery with mechs, so differentiation needs to be intentional. *Battle Mech Frontier*, for example, already describes turn-based mech artillery over fully destructible terrain.

Our differentiators should be:

```text
Mobility-first artillery
+
Universal weapons
+
Mech weapon transformation
+
Physics-based positioning
+
Terrain as tactical resource
+
Strong AI
```

---

# S31 — Game Modes

Add:

## Elimination

Primary mode.

## Control

Hold objectives.

## Siege

Attack/defend.

## Mobility

Race through a destructible battlefield while fighting.

The last mode is particularly interesting because it reinforces the game's mobility identity.

---

# S32 — Objective System

Create reusable:

```text
Objective
├── Capture
├── Destroy
├── Escort
├── Survive
└── Reach
```

Objectives should work with the same terrain/combat engine.

---

# S33 — Advanced Terrain

Prototype:

* destructible buildings
* bridges
* vertical structures
* tunnels
* unstable platforms

The objective is to make maps feel like tactical environments rather than shooting galleries.

---

# S34 — Advanced Weapon Transformations

Expand the weapon/mech interaction.

Example:

```text
Grenade
├── Bastion → bunker buster
├── Strider → cluster grenade
└── Wraith → aerial mine
```

The system should produce many combinations from relatively few base weapons.

---

# S35 — AI Tactical Search

Upgrade AI from heuristic selection toward shallow simulation.

For example:

```text
Candidate A:
Move → Rocket

Candidate B:
Move → Destroy terrain

Candidate C:
Dash → Grenade

Candidate D:
Anchor → Rocket
```

Simulate expected results.

Choose the action with the strongest tactical outcome.

This is likely to make the AI dramatically more interesting without requiring an LLM.

---

# S36 — AI Personality

Optional behavioral profiles:

### Aggressive

Prioritizes damage.

### Defensive

Prioritizes survival.

### Mobility

Prioritizes advantageous positioning.

### Siege

Prioritizes terrain destruction.

### Opportunist

Prioritizes knockouts and environmental kills.

This creates variety without needing fundamentally different AI code.

---

# S37 — Match Replay

Record:

* actions
* positions
* shots
* terrain changes
* damage
* abilities

Allow replay.

This is useful both as a player feature and a development/debugging tool.

---

# S38 — Spectator / Battle Viewer

Build a mode where the player can watch AI vs AI.

This is useful for:

* debugging AI
* balance testing
* demonstrations
* future tournament/spectator functionality

---

# S39 — Multiplayer Architecture Prototype

Do not build the entire online game yet.

Create:

```text
Host
+
Client
+
Authoritative Match State
```

Test synchronization of:

* turns
* movement
* firing
* projectiles
* damage
* terrain

Godot's documentation recommends keeping gameplay-critical state server-authoritative rather than trusting client-reported positions or combat outcomes.

---

# S40 — Multiplayer Prototype

Support:

* 1v1
* 2v2

No ranking.
No progression.
No matchmaking.

Only prove:

> Can the actual combat system work online?

---

# S41 — Networked Terrain

Synchronize destruction.

This is one of the highest-risk multiplayer systems.

Test:

* identical crater state
* projectile synchronization
* falling mechs
* simultaneous effects
* reconnect/reset

---

# S42 — Multiplayer Playtest

Run repeated matches.

Track:

* desync
* latency
* turn timing
* disconnect handling
* terrain inconsistencies

Do not proceed until combat state remains authoritative and recoverable.

---

# S43 — Content Expansion

Only now expand:

* mechs
* weapons
* maps
* abilities
* hazards

The engine should already support these through data rather than custom code.

---

# S44 — Progression Decision

Evaluate whether the game even needs progression.

Possible:

* mech unlocks
* cosmetic customization
* pilot cosmetics
* banners
* emotes

Avoid making progression necessary for competitive viability.

---

# S45 — Game Feel / Presentation

Polish:

* explosions
* sparks
* smoke
* debris
* mech animations
* weapon effects
* sound
* camera shake
* terrain destruction feedback

---

# S46 — Tutorial

Teach:

1. Move
2. Aim
3. Fire
4. Destroy terrain
5. Use mobility
6. Use mech ability
7. Knockback
8. Positioning

The tutorial should demonstrate that:

> You don't always need to shoot the enemy to win the turn.

---

# S47 — Beginner AI / Training

Create AI designed to teach mechanics.

Examples:

### Movement AI

Demonstrates positioning.

### Terrain AI

Demonstrates terrain attacks.

### Jetpack AI

Demonstrates aerial positioning.

This becomes a natural single-player learning environment.

---

# S48 — Full Vertical Slice

Target:

* 3–5 mechs
* 5–8 weapons
* 4–6 maps
* multiple abilities
* AI difficulties
* multiple game modes
* complete UI
* complete match flow
* polished destruction

---

# S49 — External Playtest

Give the game to players unfamiliar with the project.

Collect:

* first-match experience
* mech preference
* confusion points
* perceived strategy
* favorite abilities
* frustrating mechanics
* match length
* replay interest

Do not explain the intended design beforehand.

Observe what players naturally discover.

---

# S50 — Final MVP Decision

Determine whether the game has successfully established its identity.

The MVP should answer:

> Is this a mobility-focused artillery game rather than simply a GunBound clone?

Success should look like:

```text
GunBound
    ↓
Artillery foundation

+
    
Mech mobility
    ↓
Positioning

+

Destructible terrain
    ↓
Battlefield manipulation

+

Universal weapons
    ↓
Flexible loadouts

+

Mech transformations
    ↓
Distinct identities

+

AI
    ↓
Single-player depth
```

---

# Post-MVP

Potential systems:

* ranked multiplayer
* matchmaking
* clans
* tournaments
* additional mech classes
* procedural maps
* campaign
* roguelite mode
* co-op PvE
* boss mechs
* map editor
* custom game rules
* replay sharing
* spectator mode
* mod support

---

# Feature Priority Rule

Whenever considering a new feature, ask:

### Does it improve:

1. Positioning?
2. Terrain interaction?
3. Mobility?
4. Physics?
5. Tactical decision-making?
6. Mech identity?

If not, it should probably wait.

---

# Most Important Development Rule

Do not spend months building content before validating:

> **MOVE → POSITION → MODIFY → AIM → FIRE**

That is the game's real experiment.
