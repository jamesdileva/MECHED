extends Resource
## AI personality (S36): per-component weights applied to the tactical
## search's plan scoring. The same AI code produces different behavior by
## weighting the same evaluation differently — no separate codebases.
##
## Presets per the roadmap: Aggressive (prioritizes damage), Defensive
## (prioritizes survival), Mobility (prioritizes advantageous positioning),
## Siege (prioritizes terrain destruction), Opportunist (prioritizes
## knockouts and environmental kills).

const PRESETS := {
	"Balanced": {
		"name": "Balanced",
		"shot_weight": 1.0,
		"position_weight": 1.0,
		"terrain_weight": 1.0,
		"knockback_weight": 1.0,
		"walk_cost_weight": 1.0,
	},
	"Aggressive": {
		"name": "Aggressive",
		"shot_weight": 2.0,
		"position_weight": 0.5,
		"terrain_weight": 1.0,
		"knockback_weight": 1.0,
		"walk_cost_weight": 0.5,
	},
	"Defensive": {
		"name": "Defensive",
		"shot_weight": 0.5,
		"position_weight": 2.0,
		"terrain_weight": 1.0,
		"knockback_weight": 1.0,
		"walk_cost_weight": 0.5,
	},
	"Mobility": {
		"name": "Mobility",
		"shot_weight": 0.8,
		"position_weight": 2.0,
		"terrain_weight": 0.8,
		"knockback_weight": 1.0,
		"walk_cost_weight": 0.3,
	},
	"Siege": {
		"name": "Siege",
		"shot_weight": 1.0,
		"position_weight": 0.8,
		"terrain_weight": 2.0,
		"knockback_weight": 1.5,
		"walk_cost_weight": 1.0,
	},
	"Opportunist": {
		"name": "Opportunist",
		"shot_weight": 1.5,
		"position_weight": 1.0,
		"terrain_weight": 1.0,
		"knockback_weight": 2.0,
		"walk_cost_weight": 1.0,
	},
}


## Returns a deep copy so driver mutations can never poison the presets.
## Unknown names fall back to Balanced.
static func profile_for(personality_name: String) -> Dictionary:
	var preset: Dictionary = PRESETS.get(personality_name, PRESETS["Balanced"])
	return preset.duplicate(true)
