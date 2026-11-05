extends Resource
## A mech's weapon modifier (implementation-guide §7): global multipliers
## applied to every weapon the mech fires, plus per-weapon transformations
## (S12) that change behavior — the signature system.
##
## Lookup is by base weapon display name; a weapon without a matching
## transformation keeps its raw (multiplier-scaled) identity.

@export var display_name := "Modifier"
@export var speed_mult := 1.0
@export var damage_mult := 1.0
@export var knockback_mult := 1.0

@export var transformations: Array = []


func transformation_for(base_weapon_name: String) -> Resource:
	for transformation in transformations:
		if transformation != null and transformation.base_weapon == base_weapon_name:
			return transformation
	return null
