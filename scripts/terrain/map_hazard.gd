extends Resource
## A map hazard (S22): damage zones ("lava") and explosive objects (barrels),
## defined per map as data. Zones are checked every tick against mech body
## centers; explosives detonate when a shell blast reaches them and chain
## into other barrels. Evaluated-and-dropped per the roadmap: electric zones
## (= lava reskin), wind tunnels (= global wind S14), collapsing structures
## (= S13 anchor-collapse).

@export var hazard_name := "hazard"
@export_enum("zone", "explosive") var kind := "zone"

## Zone: the XY region whose interior burns mech body centers (z ignored).
@export var region := Rect2(0, -2, 2, 1)
@export var damage_per_second := 15.0

## Explosive: spawn position and blast stats (no terrain carve — barrels
## reshape the fight, not the ground).
@export var position := Vector3(0, 1.5, 0)
@export var explosion_radius := 3.0
@export var damage_max := 30.0
@export var knockback_force := 12.0


## Pure: damage a mech body center takes this tick from a zone.
## 0.0 when the center is outside the region.
static func zone_damage(region: Rect2, body_pos: Vector3, dps: float,
		delta: float) -> float:
	if body_pos.x < region.position.x or body_pos.x > region.end.x \
			or body_pos.y < region.position.y or body_pos.y > region.end.y:
		return 0.0
	return dps * delta
