extends RefCounted
## S35 AI tactical search: joint position + weapon + shot plan evaluation.
##
## For each candidate position within the energy budget, for each weapon,
## for each (angle, power) candidate, simulate the flight and score the
## impact — positioning score + shot tactical value − walk cost, all in one
## number. The best plan wins. Pure — headless-testable.
##
## The joint optimization discovers combos the S15/S16 two-step couldn't:
## a position further away with a better angle + a terrain-destruction shot
## can outrank a closer direct hit.

const Ballistics := preload("res://scripts/combat/ballistics.gd")
const Positioning := preload("res://scripts/ai/ai_positioning.gd")
const AIDriver := preload("res://scripts/ai/ai_driver.gd")

const MOVE_COST_PER_M := 0.05
const CANDIDATE_STEP := 2.0


## Scores a single plan: shot tactical value at the impact + positioning
## score at the move position − walk cost from the current position.
static func plan_value(impact_pos: Vector3, move_x: float, current_x: float,
		enemy_pos: Vector3, enemy_surface_y: float, terrain, structures: Array) -> float:
	var breakdown: Dictionary = AIDriver.shot_value(impact_pos, {
		"damage_max": 40.0, "explosion_radius": 2.5,
		"direct_hit_radius": 0.75, "knockback_force": 14.0,
		"knockback_radius": 5.0,
	}, enemy_pos, enemy_surface_y, terrain, structures)
	var shot: float = breakdown["total"]
	var position_score: float = Positioning.score_position(
			move_x, enemy_surface_y, enemy_pos, terrain)
	var walk_cost: float = MOVE_COST_PER_M * absf(move_x - current_x)
	return shot + position_score - walk_cost


## Generates and scores all candidate plans. Returns an array of
## {move_x, weapon_slot, angle, power, impact, value, positioning} dicts
## sorted by value (best first).
##
## weapon_stats entries are {slot: int, stats: Dictionary} in firing order.
## The origin's y is used for all candidate positions (the AI is on the same
## surface height it currently stands on).
static func generate_plans(origin_y: float, current_x: float, enemy_pos: Vector3,
		enemy_surface_y: float, wind: Vector2, weapon_stats: Array, terrain,
		structures: Array, walk_range: float, angles: Array, powers: Array,
		weights := {}) -> Array:
	var plans: Array = []
	var lo: float = maxf(current_x - walk_range, -27.0)
	var hi: float = minf(current_x + walk_range, 27.0)
	var move_x := lo
	while move_x <= hi + 0.001:
		var move_origin := Vector3(move_x, origin_y, 0.0)
		var to_target := enemy_pos.x - move_x
		var dir_sign := signf(to_target) if to_target != 0.0 else 1.0
		var positioning: float = Positioning.score_position(
				move_x, enemy_surface_y, enemy_pos, terrain)
		var walk_cost: float = MOVE_COST_PER_M * absf(move_x - current_x)
		for entry in weapon_stats:
			var stats: Dictionary = entry["stats"]
			for angle in angles:
				for power in powers:
					var vel: Vector3 = Ballistics.launch_velocity(
							angle, dir_sign, power, stats["speed_min"], stats["speed_max"])
					var result: Dictionary = Ballistics.simulate_flight(
							move_origin, vel, wind, 1.0 / 60.0, 0.0, 30.0)
					var impact: Vector3 = result["position"]
					var breakdown: Dictionary = AIDriver.shot_value(impact, stats,
							enemy_pos, enemy_surface_y, terrain, structures)
					var shot: float = AIDriver.weighted_shot_value(breakdown, weights)
					var value: float = shot + positioning - walk_cost
					plans.append({
						"move_x": move_x,
						"weapon_slot": entry["slot"],
						"angle": angle,
						"power": power,
						"impact": impact,
						"value": value,
						"positioning": positioning,
					})
		move_x += CANDIDATE_STEP
	plans.sort_custom(func(a, b): return a["value"] > b["value"])
	return plans


## Returns the highest-value plan from a sorted list (plans[0] after
## generate_plans).
static func best_plan(plans: Array) -> Dictionary:
	if plans.is_empty():
		return {"move_x": 0.0, "weapon_slot": -1, "angle": 45.0,
				"power": 1.0, "impact": Vector3.ZERO, "value": -INF,
				"positioning": 0.0}
	return plans[0]
