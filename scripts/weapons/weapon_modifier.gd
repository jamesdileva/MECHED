extends Resource
## A mech's weapon modifier (implementation-guide §7): multipliers applied to
## every weapon the mech fires. S11 ships this multiplier form to prove the
## pipeline; S12 replaces it with per-weapon transformations (Rocket ->
## Siege/Split/Guided).

@export var display_name := "Modifier"
@export var speed_mult := 1.0
@export var damage_mult := 1.0
@export var knockback_mult := 1.0
