# Mech Artillery Tactics

## Architecture

**Working title:** Mech Artillery Tactics
**Genre:** Turn-based tactical artillery / mech combat
**Primary platform:** PC
**Engine:** Godot 4.x
**Initial perspective:** 2.5D / side-on 3D
**Multiplayer:** Designed for future multiplayer, but MVP is single-player + AI
**MVP priority:** Combat sandbox → AI → polished single-player match

---

# 1. Vision

Create a modern turn-based artillery game inspired by the core strengths of GunBound:

* destructible terrain
* ballistic projectiles
* wind/environmental effects
* turn-based combat
* distinct combat vehicles

but shift the emphasis toward:

* movement
* positioning
* mobility abilities
* terrain manipulation
* physics
* mech-specific transformations
* AI opponents

The player's turn should contain meaningful tactical decisions before the shot is fired.

## Core turn

```text
TURN START
    ↓
Assess battlefield
    ↓
Move / reposition
    ↓
Use mobility or mech ability
    ↓
Select universal weapon
    ↓
Mech transforms weapon behavior
    ↓
Aim
    ↓
Fire
    ↓
Physics simulation
    ↓
Damage / knockback / terrain destruction
    ↓
Battlefield state updates
    ↓
Next turn
```

---

# 2. Design Pillars

## Pillar 1: Positioning > Precision

Aim remains important, but a perfect shot should not be the only path to success.

Good positioning should create advantages:

* better angles
* cover
* elevation
* escape routes
* knockback opportunities
* access to weak points
* control of terrain

---

## Pillar 2: Terrain Is Part of Combat

Terrain is not decoration.

It should affect:

* movement
* line of sight
* projectile paths
* cover
* knockback
* elevation
* survivability

Destroying terrain should often be strategically useful even when no damage is dealt.

---

## Pillar 3: Mechs Change How Weapons Work

Weapons are universal.

Mechs modify their behavior.

Example:

```text
BASE WEAPON
    Rocket
       │
       ├── Bastion → Siege Rocket
       ├── Strider → Split Rocket
       └── Wraith → Guided Rocket
```

This separates:

**weapon identity**

from

**mech identity**

and makes the system extensible.

---

## Pillar 4: Physics Creates Emergent Gameplay

The game should reward players for understanding:

* momentum
* projectile arcs
* terrain
* knockback
* gravity
* wind
* explosion placement

---

## Pillar 5: AI Is a First-Class Feature

AI opponents should understand the same battlefield concepts as players.

The AI should eventually reason about:

* positioning
* terrain
* movement
* weapon choice
* knockback
* cover
* escape routes
* objective control

AI should not simply receive accuracy bonuses.

---

# 3. Recommended Visual Direction

## 2.5D First

Although the game can ultimately become fully 3D, MVP should use:

* 3D models
* 3D physics
* 3D terrain
* side-on camera
* limited depth

This preserves the readability of classic artillery games while allowing:

* verticality
* ramps
* caves
* bridges
* destructible structures
* 3D effects
* future camera freedom

The goal is **3D simulation with 2D/2.5D readability**.

---

# 4. Technology Stack

## Engine

**Godot 4.x**

Primary responsibilities:

* rendering
* physics
* input
* animation
* audio
* UI
* scene management
* AI execution
* future multiplayer

Godot's multiplayer architecture also supports a server-authoritative model, which is appropriate if competitive multiplayer is eventually added.

---

# 5. Terrain Architecture

MVP should not begin with an extremely complicated voxel world.

Use a modular terrain representation.

### Initial representation

```text
Battlefield
├── Terrain Surface
├── Collision
├── Destruction Mask
├── Material Data
└── Gameplay Regions
```

The destruction system should expose operations such as:

```text
destroy_circle()
destroy_rectangle()
destroy_polygon()
apply_explosion()
apply_crater()
```

Later, this can evolve toward voxel terrain if necessary.

Godot-compatible voxel terrain tooling already exists and supports multiplayer synchronization, making voxel terrain a viable future direction rather than something that must be committed to immediately.

---

# 6. Combat Architecture

```text
CombatManager
│
├── TurnManager
├── WeaponSystem
├── ProjectileSystem
├── DamageSystem
├── KnockbackSystem
├── TerrainSystem
├── AbilitySystem
├── StatusEffectSystem
└── VictorySystem
```

---

# 7. Turn System

Each turn contains a limited action budget.

Initial MVP:

```text
Movement Phase
    ↓
Ability Phase
    ↓
Weapon Phase
    ↓
Projectile Resolution
    ↓
Turn End
```

The player should normally be able to:

* move
* use one mobility/utility ability
* fire one weapon

The exact action economy should remain tunable.

---

# 8. Mech System

Each mech is defined primarily through data.

```text
MechDefinition
├── stats
├── movement_model
├── abilities
├── weapon_modifiers
├── armor
├── energy
├── mass
└── visual_scene
```

Example:

```text
Bastion
├── high_mass
├── high_armor
├── low_movement
├── anchor
└── explosive_weapon_modifier
```

---

# 9. Weapon System

Weapons should be modular.

```text
WeaponDefinition
├── projectile
├── velocity
├── gravity
├── explosion
├── damage
├── terrain_damage
├── knockback
├── cooldown
└── tags
```

Mechs can apply modifiers:

```text
Weapon
    +
Mech Modifier
    =
Final Weapon
```

This permits combinations without creating an individual weapon implementation for every mech.

---

# 10. Initial Weapons

MVP:

### Rocket

Reliable general-purpose projectile.

### Grenade

Bounces and creates terrain disruption.

### Rail / Energy Shot

Fast projectile with lower terrain destruction.

### Special

Mech-specific transformation of a base weapon.

Do not create 30 weapons initially.

The system is more important than the quantity.

---

# 11. Mobility System

Movement is a major gameplay system rather than a basic character controller.

```text
MobilityController
├── GroundMovement
├── Jump
├── Dash
├── Jetpack
├── Knockback
├── Momentum
└── TerrainInteraction
```

Different mechs implement different subsets.

---

# 12. AI Architecture

```text
AIController
│
├── BattlefieldAnalyzer
├── PositionEvaluator
├── TargetSelector
├── WeaponSelector
├── MovementPlanner
├── ShotPlanner
├── AbilityPlanner
└── ActionExecutor
```

The AI should evaluate possible actions rather than simply receive artificial aim assistance.

Future architecture:

```text
Current State
      ↓
Generate Candidate Actions
      ↓
Simulate / Evaluate
      ↓
Score Outcomes
      ↓
Choose Action
      ↓
Execute
```

This allows difficulty to scale by improving decision quality rather than simply increasing accuracy.

---

# 13. Difficulty

Difficulty should primarily modify:

* planning depth
* target selection
* terrain awareness
* ability usage
* movement quality
* risk tolerance

Avoid:

```text
Easy = 50% damage
Hard = 150% damage
```

Prefer:

```text
Easy → obvious actions

Normal → competent positioning

Hard → terrain-aware tactics

Expert → multi-step planning
```

---

# 14. Match Architecture

```text
Match
├── MatchRules
├── Battlefield
├── Players
├── Teams
├── TurnManager
├── ObjectiveManager
├── CombatManager
├── AIControllers
└── MatchResult
```

This allows future modes without rewriting the combat engine.

---

# 15. Initial Game Modes

MVP:

### Elimination

Destroy all opposing mechs.

Future:

### Control Point

Hold battlefield locations.

### Payload

Move an objective through destructible terrain.

### King of the Hill

Control the center.

### Siege

One team attacks a fortified position.

### Extraction

Reach an extraction zone before being destroyed.

---

# 16. Future Multiplayer Architecture

MVP remains offline.

The game should nevertheless keep gameplay state separate from presentation.

Future:

```text
Client
   ↓
Match Server
   ↓
Authoritative Game State
```

Important state:

* positions
* movement energy
* weapon selection
* projectile state
* damage
* terrain state
* abilities
* cooldowns
* victory state

should eventually be server-authoritative.

---

# 17. Project Structure

```text
project/
│
├── scenes/
│   ├── main/
│   ├── battlefield/
│   ├── mechs/
│   ├── projectiles/
│   ├── ui/
│   └── menus/
│
├── scripts/
│   ├── core/
│   ├── combat/
│   ├── weapons/
│   ├── mechs/
│   ├── movement/
│   ├── input/
│   ├── terrain/
│   ├── ai/
│   ├── match/
│   └── ui/
│
├── data/
│   ├── mechs/
│   ├── weapons/
│   ├── abilities/
│   ├── maps/
│   └── balance/
│
├── assets/
│   ├── models/
│   ├── textures/
│   ├── effects/
│   ├── audio/
│   └── ui/
│
└── tests/
    ├── combat/
    ├── physics/
    ├── terrain/
    ├── ai/
    └── match/
```

---

# 18. Input & Controller Architecture

Controller support is planned from the beginning, not retrofitted.

## Principle: Device-Agnostic Actions

Gameplay code never reads raw device input.

All input is expressed as named actions:

```text
Input Device (keyboard / gamepad)
        ↓
Input Map (action bindings)
        ↓
Input Layer
        ↓
Action Request
```

Every action is bound to keyboard and gamepad at the same time.

## Initial Action Map

```text
Action             Keyboard              Gamepad
move_left          A / Left              D-pad left, Left stick left
move_right         D / Right             D-pad right, Left stick right
jump               Space                 A / Cross
dash               Shift                 X / Square
aim_up             Up arrow              Right stick up
aim_down           Down arrow            Right stick down
fire               Enter (hold = power)  RT / R2 (hold = power)
cycle_weapon       Tab                   LB / RB
use_ability        E                     LT / L2
end_turn           Q                     B / Circle
pause              Esc                   Start
```

The map is a starting point. The rule that matters:

> Adding an action means binding it to every supported device at once.

## Analog Rules

* sticks and triggers expose normalized strength, not booleans
* deadzones are global configuration, not per-system logic
* keyboard aim steps and analog stick aim must converge on the same ActionRequest
* analog aiming should be at least as precise as keyboard aiming

## UI Navigation

* menus and HUD are navigable by gamepad as soon as they exist
* focus-based UI first, mouse optional

## Deferred Until Needed

* remapping UI
* device-specific button prompts
* rumble / haptics

---

# 19. Architectural Principle

Build:

> **Combat engine first, game second.**

The underlying systems should be reusable:

```text
Terrain
Physics
Weapons
Mechs
Abilities
Movement
AI
Turn Management
Objectives
```

The first game mode is simply one configuration of those systems.
