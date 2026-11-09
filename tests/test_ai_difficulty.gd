extends "res://tests/test_base.gd"
## S18 AI difficulty: four levels as pure configuration. Difficulty improves
## DECISIONS (candidate counts, positioning granularity, terrain awareness,
## ability usage) and steadies aim with noise — never accuracy/damage cheats.

const DIFFICULTY := "res://scripts/ai/ai_difficulty.gd"
const CONTROLLER := "res://scripts/match/match_controller.gd"


func test_all_four_presets_exist() -> void:
	var d = load(DIFFICULTY)
	for name in ["Easy", "Normal", "Hard", "Expert"]:
		var profile: Dictionary = d.profile_for(name)
		assert_equal(profile["name"], name, "%s preset loads" % name)


func test_unknown_difficulty_falls_back_to_normal() -> void:
	var d = load(DIFFICULTY)
	assert_equal(d.profile_for("Ludicrous")["name"], "Normal", "unknown falls back")


func test_complexity_rises_with_difficulty() -> void:
	var d = load(DIFFICULTY)
	var easy: Dictionary = d.profile_for("Easy")
	var normal: Dictionary = d.profile_for("Normal")
	var hard: Dictionary = d.profile_for("Hard")
	var expert: Dictionary = d.profile_for("Expert")
	# Candidate counts grow (deeper planning, roadmap S18).
	assert_true(easy["angles"].size() < normal["angles"].size()
			and normal["angles"].size() <= hard["angles"].size()
			and hard["angles"].size() <= expert["angles"].size(),
			"angle candidates grow with difficulty")
	assert_true(easy["powers"].size() <= expert["powers"].size(),
			"power candidates grow with difficulty")
	# Positioning granularity tightens (S16 choose_position step).
	assert_true(normal["positioning_step"] > hard["positioning_step"]
			and hard["positioning_step"] > expert["positioning_step"],
			"positioning steps get finer")


func test_easy_is_the_s15_baseline() -> void:
	var easy: Dictionary = load(DIFFICULTY).profile_for("Easy")
	assert_true(easy["positioning"] == false, "Easy does not reposition")
	assert_true(easy["terrain_aware"] == false, "Easy ignores terrain opportunities")
	assert_true(easy["uses_anchor"] == false, "Easy uses no abilities")
	assert_true(easy["aim_noise_deg"] > 4.0, "Easy targeting is sloppy (honest noise)")


func test_terrain_awareness_is_the_hard_line() -> void:
	var d = load(DIFFICULTY)
	assert_true(d.profile_for("Normal")["terrain_aware"] == false,
			"Normal shoots direct-damage only (roadmap: terrain awareness is Hard)")
	assert_true(d.profile_for("Hard")["terrain_aware"], "Hard reads the terrain")
	assert_true(d.profile_for("Expert")["terrain_aware"], "Expert reads the terrain")


func test_expert_never_cheats() -> void:
	var expert: Dictionary = load(DIFFICULTY).profile_for("Expert")
	# The roadmap's rule: difficulty improves decisions, never stats. The
	# profile has no damage/accuracy knobs at all — its only aim lever is
	# NOISE, and Expert's is zero (perfectly honest, still not a damage buff).
	assert_true(expert["aim_noise_deg"] >= 0.0, "aim lever is noise only, >= 0")
	assert_true(not expert.has("damage_mult") and not expert.has("aim_assist"),
			"no damage or aim-assist cheats exist in the profile")


func test_controller_defaults_to_hard() -> void:
	var controller = load(CONTROLLER).new()
	assert_equal(controller.ai_difficulty, "Hard",
			"Hard ships as default so S16/S17 behaviors are enabled")
	controller.free()


func test_solver_honors_candidate_lists() -> void:
	# A one-candidate profile produces exactly that candidate's angle.
	var driver = load("res://scripts/ai/ai_driver.gd")
	var weapon_stats: Array = [{"slot": 0,
			"stats": load("res://data/weapons/rocket.tres").effective(null)}]
	var plan: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2.ZERO, weapon_stats,
			NAN, null, [], [45.0], [0.75])
	assert_equal(plan["angle"], 45.0, "single-candidate profile fires that angle")
	assert_almost_equal(plan["power"], 0.75, 0.0001, "single-candidate profile uses that power")
