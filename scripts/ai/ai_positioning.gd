extends RefCounted
## Position evaluation for the AI (S16) — implementation-guide §12's scoring
## shape as pure statics over terrain queries.
##
## The AI scores candidate standing spots on: standoff band, elevation above
## the enemy, cover along the head-height line, and knockback risk (edge
## drops near blast-prone feet) — minus the movement cost to get there.
## Terrain is the pure grid wrapper (or null → flat-world fallback, which is
## exactly the S15 behavior).

const PREFERRED_MIN := 6.0
const PREFERRED_MAX := 18.0
const BAND_IN_SCORE := 2.0
const BAND_OUT_PENALTY_PER_M := 0.3
const BAND_OUT_CAP := 3.0
const ELEVATION_PER_M := 1.0
const ELEVATION_CAP := 3.0
const COVER_PER_BLOCK := 0.5
const COVER_CAP := 2.0
const EDGE_PROBE_M := 2.0
const EDGE_DROP_M := 1.5
const EDGE_RISK_PENALTY := 2.0
const MOVEMENT_COST_PER_M := 0.05
const CANDIDATE_STEP := 2.0


## Standoff band: inside is good, outside decays with distance.
static func band_value(dist: float) -> float:
	if dist >= PREFERRED_MIN and dist <= PREFERRED_MAX:
		return BAND_IN_SCORE
	var outside := minf(minf(absf(dist - PREFERRED_MIN), absf(dist - PREFERRED_MAX)),
			BAND_OUT_CAP / BAND_OUT_PENALTY_PER_M)
	return BAND_IN_SCORE - outside * BAND_OUT_PENALTY_PER_M


## Height above the enemy is artillery high ground.
static func elevation_value(my_y: float, enemy_y: float) -> float:
	return clampf((my_y - enemy_y) * ELEVATION_PER_M, -ELEVATION_CAP, ELEVATION_CAP)


## Samples the head-height line to the enemy through the mask: solid samples
## are cover (an artillery mech lobbing over the wall keeps the bonus).
static func cover_value(my_head: Vector3, enemy_head: Vector3, terrain) -> float:
	if terrain == null:
		return 0.0
	var blocked := 0
	for t in [0.25, 0.5, 0.75]:
		var probe: Vector3 = my_head.lerp(enemy_head, t)
		if terrain.is_solid_world(Vector2(probe.x, probe.y)):
			blocked += 1
	return minf(blocked * COVER_PER_BLOCK, COVER_CAP)


## A drop of EDGE_DROP_M or more within EDGE_PROBE_M is a knockback-shove-off
## risk (S06 physics makes it lethal next to the ravine). A NAN probe means
## the neighbouring column is carved clean through — the biggest risk of all.
static func edge_risk(x: float, my_surface_y: float, terrain) -> float:
	if terrain == null:
		return 0.0
	for dx in [-EDGE_PROBE_M, -1.0, 1.0, EDGE_PROBE_M]:
		var s: float = terrain.query_surface_y(x + dx)
		if is_nan(s) or my_surface_y - s >= EDGE_DROP_M:
			return EDGE_RISK_PENALTY
	return 0.0


static func score_position(x: float, surface_y: float, enemy_pos: Vector3,
		terrain) -> float:
	if is_nan(surface_y):
		# A dug-through column cannot be stood on.
		return -INF
	var dist := absf(x - enemy_pos.x)
	var score := band_value(dist)
	score += elevation_value(surface_y, enemy_pos.y)
	score += cover_value(Vector3(x, surface_y, 0.0) + Vector3(0, 1.2, 0),
			enemy_pos + Vector3(0, 1.2, 0), terrain)
	score -= edge_risk(x, surface_y, terrain)
	return score


## Picks the best reachable standing spot. Returns
## {x, score, current_score, improved} — `improved` is the "reposition
## instead of immediately firing" trigger.
static func choose_position(current_x: float, enemy_pos: Vector3, walk_range: float,
		terrain, bounds_min := -27.0, bounds_max := 27.0) -> Dictionary:
	var current_score := -INF
	var current_surface: float = terrain.query_surface_y(current_x) \
			if terrain != null else 0.0
	if not is_nan(current_surface):
		current_score = score_position(current_x, current_surface, enemy_pos, terrain)

	var best_x := current_x
	var best_score := current_score
	var lo: float = maxf(current_x - walk_range, bounds_min)
	var hi: float = minf(current_x + walk_range, bounds_max)
	var x := lo
	while x <= hi + 0.001:
		var surface: float = terrain.query_surface_y(x) if terrain != null else 0.0
		if not is_nan(surface):
			var score := score_position(x, surface, enemy_pos, terrain) \
					- MOVEMENT_COST_PER_M * absf(x - current_x)
			if score > best_score + 0.001:
				best_score = score
				best_x = x
		x += CANDIDATE_STEP
	return {
		"x": best_x,
		"score": best_score,
		"current_score": current_score,
		"improved": absf(best_x - current_x) > 0.5 and best_score > current_score + 0.05,
	}
