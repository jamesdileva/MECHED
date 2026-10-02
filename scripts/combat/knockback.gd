extends RefCounted
## Pure knockback math (implementation-guide §10/§16): explosion force scaled
## by distance, mech mass, and terrain contact.
##
## Knockback reaches farther than damage (radius 5m vs damage 2.5m) so blasts
## exert positioning pressure even on misses. The returned vector is a
## velocity delta in m/s; the caller adds it to the mech's physics velocity —
## the physics simulation owns what happens next (arcs, walls, falling).

const KNOCKBACK_FORCE := 14.0
const KNOCKBACK_RADIUS := 5.0
const DIRECT_KNOCKBACK_RADIUS := 1.0
## Grounded mechs lose this fraction of the impulse to ground friction.
const GROUND_ABSORPTION := 0.5


## Velocity delta applied to a mech hit by an explosion at explosion_pos.
static func impulse(mech_pos: Vector3, explosion_pos: Vector3, on_ground: bool,
		mass: float) -> Vector3:
	var to_mech := mech_pos - explosion_pos
	var dist := to_mech.length()
	var factor := falloff(dist)
	if factor <= 0.0:
		return Vector3.ZERO
	# Explosion directly at the mech's origin (degenerate direction): launch up.
	var dir := to_mech / dist if dist > 0.01 else Vector3.UP
	var speed := KNOCKBACK_FORCE * factor / maxf(mass, 0.1)
	if on_ground:
		speed *= 1.0 - GROUND_ABSORPTION
	return dir * speed


## Full force inside direct_radius, linear falloff to zero at radius.
static func falloff(distance: float, radius := KNOCKBACK_RADIUS,
		direct_radius := DIRECT_KNOCKBACK_RADIUS) -> float:
	if distance >= radius:
		return 0.0
	if distance <= direct_radius:
		return 1.0
	var t := (distance - direct_radius) / (radius - direct_radius)
	return 1.0 - t
