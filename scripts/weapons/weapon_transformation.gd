extends Resource
## A per-mech weapon transformation (S12, architecture.md Pillar 3): how a
## mech changes a base weapon's behavior. Matched to a base weapon by name;
## stat multipliers layer on top of the S11 modifier, and the behavior fields
## add what multipliers cannot express: multi-shot spread and homing.

@export var display_name := "Transformed Weapon"
## The base weapon this transformation applies to (WeaponDefinition.display_name).
@export var base_weapon := "Rocket"

@export var speed_mult := 1.0
@export var damage_mult := 1.0
@export var blast_mult := 1.0
@export var knockback_mult := 1.0
@export var terrain_mult := 1.0

## Multi-shot (Split Rocket): shells fired per trigger pull and their angular
## spread. 1 shell / 0 degrees = single shot.
@export var projectile_count := 1
@export var spread_degrees := 0.0

## Guidance (Guided Rocket): steering turn rate toward the locked target
## (higher = tighter tracking); 0 = unguided.
@export var homing_strength := 0.0


## Layers this transformation onto already-modifier-scaled weapon stats.
func apply(stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	out["speed_min"] = stats.get("speed_min", 0.0) * speed_mult
	out["speed_max"] = stats.get("speed_max", 0.0) * speed_mult
	out["damage_max"] = stats.get("damage_max", 0.0) * damage_mult
	out["explosion_radius"] = stats.get("explosion_radius", 0.0) * blast_mult
	out["terrain_damage_mult"] = stats.get("terrain_damage_mult", 1.0) * terrain_mult
	out["knockback_force"] = stats.get("knockback_force", 0.0) * knockback_mult
	out["projectile_count"] = projectile_count
	out["spread_degrees"] = spread_degrees
	out["homing_strength"] = homing_strength
	out["transformation_name"] = display_name
	return out
