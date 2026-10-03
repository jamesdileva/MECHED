extends RefCounted
## Pure ballistics and damage math (implementation-guide §10/§16).
##
## The projectile node integrates the same constants through the physics
## engine; these static functions exist so aiming, tests, and the future AI
## shot planner (S15+) share one deterministic source of truth. Gameplay
## tuning (S25 feel pass) happens here and in the exported projectile config.

const MATCH_GRAVITY := 30.0
const MIN_SPEED := 8.0
const MAX_SPEED := 30.0
const MIN_ANGLE_DEG := -10.0
const EXPLOSION_RADIUS := 2.5
const DIRECT_HIT_RADIUS := 0.75
const MAX_DAMAGE := 40.0


static func speed_for_power(power: float) -> float:
	return lerpf(MIN_SPEED, MAX_SPEED, clampf(power, 0.0, 1.0))


## Side-plane launch vector: angle in degrees relative to the horizon
## (−10..90 — slightly below horizon lets a mech blast the ground at its own
## feet), toward the facing sign (mirrors x). Matches the mech's AimPivot
## rotation convention.
static func launch_velocity(angle_deg: float, facing: float, power: float) -> Vector3:
	var a := deg_to_rad(clampf(angle_deg, MIN_ANGLE_DEG, 90.0))
	return Vector3(facing * cos(a), sin(a), 0.0) * speed_for_power(power)


## Analytic flight time to a horizontal plane y = ground_y: solves
## 0.5 g t² − vy t − (y0 − ground_y) = 0 for the positive root.
static func time_of_flight(origin: Vector3, velocity: Vector3, ground_y := 0.0) -> float:
	var disc := velocity.y * velocity.y + 2.0 * MATCH_GRAVITY * (origin.y - ground_y)
	return (velocity.y + sqrt(maxf(disc, 0.0))) / MATCH_GRAVITY


static func range_on_ground(origin: Vector3, velocity: Vector3, ground_y := 0.0) -> float:
	return absf(velocity.x) * time_of_flight(origin, velocity, ground_y)


## Full damage inside direct_radius, linear falloff to zero at radius.
static func damage_falloff(distance: float, radius := EXPLOSION_RADIUS,
		max_damage := MAX_DAMAGE, direct_radius := DIRECT_HIT_RADIUS) -> float:
	if distance >= radius:
		return 0.0
	if distance <= direct_radius:
		return max_damage
	var t := (distance - direct_radius) / (radius - direct_radius)
	return max_damage * (1.0 - t)
