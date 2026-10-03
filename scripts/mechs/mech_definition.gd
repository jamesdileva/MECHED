extends Resource
## Data-driven mech identity (architecture.md §8): stats and mobility model.
##
## Mechs are Resources, never hardcoded (AGENTS engineering rules). The
## movement controller consumes these values via Mech.apply_definition();
## health flows through MatchState, knockback resistance through mass.

@export var display_name := "Standard"
@export var max_health := 100.0
## Knockback resistance: impulse is divided by this.
@export var mass := 1.2
@export var max_speed := 8.0
@export var acceleration := 40.0
@export var jump_velocity := 10.0
## 0 = this chassis has no dash.
@export var dash_speed := 0.0
@export var dash_cost := 25.0
