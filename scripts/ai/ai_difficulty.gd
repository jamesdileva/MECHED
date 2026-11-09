extends RefCounted
## AI difficulty presets (S18, implementation-guide §13): four behavioral
## levels as pure configuration for the one ai_driver — never separate
## codebases, never accuracy/damage cheats. Difficulty improves DECISIONS:
## candidate counts, aim steadiness (noise, not cheats), positioning
## granularity, terrain awareness, and ability usage.

const PRESETS := {
	"Easy": {
		"name": "Easy",
		"angles": [45.0],
		"powers": [0.75],
		"aim_noise_deg": 6.0,
		"positioning": false,
		"positioning_step": 4.0,
		"terrain_aware": false,
		"uses_anchor": false,
	},
	"Normal": {
		"name": "Normal",
		"angles": [30.0, 45.0, 60.0],
		"powers": [0.5, 0.75, 1.0],
		"aim_noise_deg": 2.5,
		"positioning": true,
		"positioning_step": 4.0,
		"terrain_aware": false,
		"uses_anchor": true,
	},
	"Hard": {
		"name": "Hard",
		"angles": [20.0, 30.0, 45.0, 60.0, 75.0],
		"powers": [0.25, 0.5, 0.75, 1.0],
		"aim_noise_deg": 1.0,
		"positioning": true,
		"positioning_step": 2.0,
		"terrain_aware": true,
		"uses_anchor": true,
	},
	"Expert": {
		"name": "Expert",
		"angles": [15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0],
		"powers": [0.25, 0.4, 0.55, 0.7, 0.85, 1.0],
		"aim_noise_deg": 0.0,
		"positioning": true,
		"positioning_step": 1.0,
		"terrain_aware": true,
		"uses_anchor": true,
	},
}


## Returns a deep copy so driver mutations can never poison the presets.
## Unknown names fall back to Normal.
static func profile_for(difficulty_name: String) -> Dictionary:
	var preset: Dictionary = PRESETS.get(difficulty_name, PRESETS["Normal"])
	return preset.duplicate(true)
