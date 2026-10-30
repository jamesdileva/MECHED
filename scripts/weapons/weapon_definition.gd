extends Resource
## A universal weapon (architecture.md §9/§10): stats only, no mech-specific
## code anywhere. Every mech can equip every weapon; mechs change how a
## weapon BEHAVES through WeaponModifier (S12 formalizes per-weapon
## transformations). One shot per turn is the cooldown.

@export var display_name := "Rocket"
## Launch speed range; charge power interpolates between them.
@export var speed_min := 8.0
@export var speed_max := 30.0
@export var damage_max := 40.0
@export var explosion_radius := 2.5
@export var direct_hit_radius := 0.75
@export var knockback_radius := 5.0
@export var knockback_force := 14.0
## Grenade-style bounces before detonation on non-mech contact; 0 = explode
## on first contact. Direct mech hits always detonate immediately.
@export var bounces := 0
## Physics restitution while bouncing (only meaningful with bounces > 0).
@export var bounciness := 0.0
## Gravity multiplier in flight (energy weapons fly flatter).
@export var gravity_mult := 1.0
## Scales the crater carved into terrain (architecture: terrain damage).
@export var terrain_damage_mult := 1.0


## Effective stats for a mech: the weapon scaled by the mech's modifier.
## Returns a plain dictionary so the simulation layer never touches weapon
## internals directly (S12 replaces multipliers with real transformations).
func effective(modifier: Resource) -> Dictionary:
	var speed_mult := 1.0
	var damage_mult := 1.0
	var knockback_mult := 1.0
	if modifier != null:
		speed_mult = modifier.speed_mult
		damage_mult = modifier.damage_mult
		knockback_mult = modifier.knockback_mult
	return {
		"speed_min": speed_min * speed_mult,
		"speed_max": speed_max * speed_mult,
		"damage_max": damage_max * damage_mult,
		"explosion_radius": explosion_radius,
		"direct_hit_radius": direct_hit_radius,
		"knockback_radius": knockback_radius,
		"knockback_force": knockback_force * knockback_mult,
		"bounces": bounces,
		"bounciness": bounciness,
		"gravity_mult": gravity_mult,
		"terrain_damage_mult": terrain_damage_mult,
	}
