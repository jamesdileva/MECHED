# Mech Artillery Tactics

## Implementation Guide

This document describes how the project should actually be implemented after the architecture and sprint roadmap are established.

The implementation should proceed one subsystem at a time.

---

# 1. Recommended Development Order

Do not implement systems in arbitrary order.

Use:

```text
1. Project
2. Battlefield
3. Mech movement
4. Turn system
5. Projectile physics
6. Damage
7. Terrain destruction
8. Knockback
9. Movement resources
10. Multiple mechs
11. Weapon framework
12. Weapon transformation
13. AI
14. UI
15. Maps
16. Multiplayer
```

---

# 2. Core Data Flow

A player action should follow:

```text
Input
 ↓
Action Request
 ↓
TurnManager
 ↓
Combat System
 ↓
Game State
 ↓
Physics
 ↓
Terrain
 ↓
Damage
 ↓
Event Bus
 ↓
Presentation
```

Presentation should not own game logic.

Input devices (keyboard, gamepad) map to the same abstract actions. Gameplay code never reads raw device input. See the Input & Controller Architecture section in architecture.md.

---

# 3. Game State

Maintain a central match state.

```text
MatchState
├── turn
├── active_player
├── players
├── mech_states
├── terrain_state
├── projectiles
├── objectives
├── environmental_state
└── match_result
```

The game should be able to reconstruct the battlefield from this state.

This becomes important for:

* AI
* replay
* debugging
* multiplayer
* save/load
* deterministic testing

---

# 4. TurnManager

Responsibilities:

* determine active entity
* begin turn
* provide movement budget
* enable actions
* prevent invalid actions
* resolve firing
* end turn

Do not put weapon or AI logic inside TurnManager.

---

# 5. Action System

Create a common action abstraction.

```text
Action
├── MoveAction
├── FireAction
├── AbilityAction
└── EndTurnAction
```

This provides a clean foundation for future AI and multiplayer.

AI can eventually generate the same actions a human player generates.

---

# 6. Mech Controller

Separate:

```text
Movement rules
```

from:

```text
Mech identity
```

Example:

```text
MovementController
      +
MechDefinition
      =
Playable Mech
```

This prevents every mech from becoming a completely custom controller.

---

# 7. Weapon Architecture

Use composition.

```text
Weapon
├── ProjectileBehavior
├── ExplosionBehavior
├── DamageBehavior
├── TerrainBehavior
└── KnockbackBehavior
```

A mech modifies these components.

Example:

```text
Rocket
+ BastionModifier
=
Heavy Rocket

Rocket
+ WraithModifier
=
Guided Rocket
```

---

# 8. Ability Architecture

Abilities should implement a common interface.

```text
Ability
├── can_activate()
├── get_cost()
├── preview()
├── execute()
└── cooldown()
```

This allows abilities to work with:

* player input
* AI
* replay
* multiplayer

without separate systems.

---

# 9. Terrain

Initially favor a manageable destruction system rather than immediately committing to full voxel simulation.

The abstraction should remain:

```text
TerrainSystem
├── query_surface()
├── query_collision()
├── destroy()
├── create_crater()
├── restore()
└── serialize()
```

If later testing proves that voxel terrain is required, the rest of the game should not need to know how terrain is internally represented.

---

# 10. Physics

Physics should be responsible for:

* projectile motion
* gravity
* collision
* impulse
* knockback
* falling objects

Gameplay should determine:

* damage
* ability effects
* victory
* turn transitions

Do not mix these responsibilities unnecessarily.

---

# 11. AI

AI should use the same action system as players.

```text
AI
 ↓
Analyze State
 ↓
Generate Actions
 ↓
Evaluate Actions
 ↓
Choose Action
 ↓
Submit Action
```

Avoid:

```text
AI directly modifies player HP
AI teleports
AI bypasses physics
AI receives impossible information
```

The AI should play the same game.

---

# 12. AI Evaluation

Start simple.

For each candidate:

```text
score =
    damage_value
  + position_value
  + terrain_value
  + knockout_probability
  + survival_value
  - movement_cost
  - risk
```

Later, introduce shallow forward simulation.

Example:

```text
Current State

Candidate A
  Move → Fire

Candidate B
  Move → Destroy Terrain

Candidate C
  Ability → Fire

Candidate D
  Defensive Position
```

Simulate each candidate and select the strongest outcome.

---

# 13. Difficulty Implementation

Do not create separate AI codebases.

Use configuration.

```text
Easy
├── fewer candidates
├── lower simulation depth
└── imperfect aim

Normal
├── moderate candidates
└── basic tactical reasoning

Hard
├── terrain awareness
├── deeper simulation
└── stronger positioning

Expert
├── deeper search
├── advanced combinations
└── long-term tactical reasoning
```

---

# 14. Camera

The camera should be independent from the mech controller.

Required states:

```text
Gameplay Camera
Projectile Camera
Impact Camera
Overview Camera
```

Camera movement should never alter gameplay state.

---

# 15. UI

The HUD should communicate:

```text
ACTIVE TURN
HEALTH
MOVEMENT ENERGY
ABILITY
WEAPON
WIND
AIM
```

Do not overwhelm the player with statistics during the first prototype.

Advanced information can be added later.

---

# 16. Testing

Create automated tests around the combat rules.

Important tests:

### Projectile

* gravity
* collision
* explosion radius

### Damage

* direct hit
* partial hit
* armor

### Knockback

* distance
* force
* mass

### Terrain

* destruction
* collision update
* repeated destruction

### Turns

* action restrictions
* turn transitions
* timeout

### AI

* valid actions
* no illegal information
* action execution

---

# 17. Debug Tools

Build development tools early.

Useful controls:

```text
F1 — reset match
F2 — spawn enemy
F3 — toggle terrain debug
F4 — show physics
F5 — show AI reasoning
F6 — infinite movement
F7 — infinite ammo
F8 — force next turn
```

AI debug mode should show:

```text
Candidate:
Move Left
Score: 61

Candidate:
Fire Rocket
Score: 48

Candidate:
Destroy Platform
Score: 73 ← selected
```

This will make AI development dramatically easier.

---

# 18. Data-Driven Content

Do not hardcode every mech.

Use Godot resources/data definitions.

Conceptually:

```text
MechDefinition
WeaponDefinition
AbilityDefinition
MapDefinition
GameModeDefinition
```

This makes balance changes much faster.

---

# 19. Multiplayer Preparation

Even though multiplayer is not MVP, avoid making the game dependent on:

```text
local player variables
```

Instead:

```text
Match State
    ↓
Action
    ↓
Simulation
    ↓
New State
```

This creates a natural future server-authoritative architecture.

---

# 20. Performance

Do not optimize prematurely.

First measure:

* terrain destruction cost
* projectile simulation
* physics bodies
* AI calculation time
* map complexity

The biggest likely performance risks are:

1. Destructible terrain
2. Physics
3. AI search
4. Multiplayer synchronization

Optimize these based on actual profiling.

---

# 21. MVP Technical Definition

MVP is complete when:

```text
Player
  ↓
Selects Mech
  ↓
Loads Map
  ↓
Moves
  ↓
Uses Ability
  ↓
Selects Universal Weapon
  ↓
Mech Transforms Weapon
  ↓
Aims
  ↓
Fires
  ↓
Projectile Simulates
  ↓
Terrain Changes
  ↓
Knockback Resolves
  ↓
AI Takes Turn
  ↓
AI Repositions
  ↓
AI Fires
  ↓
Match Ends
```

and this works repeatedly without developer intervention.

---

# 22. What Not To Build Early

Do not initially build:

* ranked multiplayer
* account system
* progression
* battle pass
* dozens of weapons
* dozens of mechs
* procedural generation
* complex inventory
* cosmetics
* matchmaking
* monetization

The first objective is to prove the combat.

---

# 23. The Core Prototype

The ideal first serious prototype is surprisingly small:

```text
1 Map

3 Mechs
    Bastion
    Strider
    Wraith

3 Weapons
    Rocket
    Grenade
    Energy Shot

3 Mobility Models

3 Mech Transformations

1 AI Opponent

Destructible Terrain

Wind

Knockback

Turn System
```

If **that** is fun, the project is worth expanding.

If it isn't fun, adding 30 mechs won't fix it.

---

# 24. Design North Star

The player should frequently face decisions like:

> "I can shoot him now..."

> "...or spend my movement energy getting above him."

> "I could hit him for 150 damage..."

> "...or destroy the platform underneath him."

> "I could use my special weapon..."

> "...or save it because the terrain is about to change."

That is the game.

The objective is not to eliminate aiming.

The objective is to make **aiming one decision among several equally important tactical decisions.**
