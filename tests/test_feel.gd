extends "res://tests/test_base.gd"
## S25 feel pass: the remaining feel constants (charge ramp, shell lifetime)
## are data on the balance table and per-weapon definitions — tunable without
## code changes.

const CONFIG := "res://scripts/core/balance_config.gd"
const ROCKET := "res://data/weapons/rocket.tres"
const EPS := 0.0001


func test_charge_time_is_tunable() -> void:
	var cfg: Resource = load(CONFIG).new()
	assert_almost_equal(cfg.charge_time, 1.2, EPS, "shipped charge ramp default")


func test_shell_lifetime_is_weapon_data() -> void:
	var rocket: Resource = load(ROCKET)
	assert_almost_equal(rocket.lifetime, 8.0, EPS, "rocket lifetime default")
	# effective() passes lifetime through so the spawn path reads it.
	var stats: Dictionary = rocket.effective(null)
	assert_almost_equal(stats["lifetime"], 8.0, EPS, "lifetime flows through stats")


func test_shell_lifetime_is_per_weapon() -> void:
	# Two weapons can tune their own lifetimes without code changes.
	var rocket: Resource = load(ROCKET)
	var grenade: Resource = load("res://data/weapons/grenade.tres")
	var old: float = rocket.lifetime
	rocket.lifetime = 5.0
	assert_almost_equal(grenade.lifetime, 8.0, EPS, "per-weapon independence")
	rocket.lifetime = old
