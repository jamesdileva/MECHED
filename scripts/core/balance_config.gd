extends Resource
## Match-level balance tuning (S24): the values a balancer touches across a
## whole match, editable in data/balance/balance.tres without gameplay code
## changes. Per-item tuning lives on MechDefinition/WeaponDefinition/MapDef.
##
## Multipliers scale whole families at match setup: health_mult scales every
## chassis's max health, move_speed_mult every chassis's top speed,
## damage_mult every shell's damage, knockback_mult every blast's push.

@export var turn_time := 15.0
@export var energy_per_turn := 100.0
@export var walk_cost_per_m := 1.0
@export var jump_cost := 10.0

@export var health_mult := 1.0
@export var move_speed_mult := 1.0
@export var damage_mult := 1.0
@export var knockback_mult := 1.0

@export var wind_max := 5.0
@export var gravity := 30.0
## Fraction of blast impulse a grounded mech loses (S06).
@export var ground_absorption := 0.5
