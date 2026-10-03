extends "res://tests/test_base.gd"
## S04 ballistics and damage math (implementation-guide §16: gravity, flight,
## direct/partial damage). Pure static functions — verified headless against
## closed-form expectations. The engine-integrated projectile itself is
## verified in-game; the math here is the deterministic contract both the
## projectile and the future AI shot planner must satisfy.

const BALLISTICS := "res://scripts/combat/ballistics.gd"
const EPS := 0.0001


func test_speed_scales_between_min_and_max() -> void:
	var b = load(BALLISTICS)
	assert_almost_equal(b.speed_for_power(0.0), b.MIN_SPEED, EPS, "zero power = min speed")
	assert_almost_equal(b.speed_for_power(1.0), b.MAX_SPEED, EPS, "full power = max speed")
	var mid: float = b.speed_for_power(0.5)
	assert_true(mid > b.MIN_SPEED and mid < b.MAX_SPEED, "half power sits between")


func test_launch_velocity_45_degrees_is_symmetric() -> void:
	var b = load(BALLISTICS)
	var v: Vector3 = b.launch_velocity(45.0, 1.0, 0.5)
	assert_almost_equal(v.x, v.y, EPS, "45 degrees splits x and y evenly")
	assert_true(v.x > 0.0, "facing +1 launches toward +x")
	var mirrored: Vector3 = b.launch_velocity(45.0, -1.0, 0.5)
	assert_almost_equal(mirrored.x, -v.x, EPS, "facing -1 mirrors x")
	assert_almost_equal(mirrored.y, v.y, EPS, "facing never changes elevation")


func test_launch_velocity_clamps_extreme_angles() -> void:
	var b = load(BALLISTICS)
	var up: Vector3 = b.launch_velocity(90.0, 1.0, 0.5)
	assert_almost_equal(up.x, 0.0, EPS, "90 degrees is straight up")
	assert_almost_equal(up.y, b.speed_for_power(0.5), EPS, "90 degrees uses full speed on y")
	var flat: Vector3 = b.launch_velocity(0.0, 1.0, 0.5)
	assert_almost_equal(flat.y, 0.0, EPS, "0 degrees is flat")
	var over: Vector3 = b.launch_velocity(120.0, 1.0, 0.5)
	assert_almost_equal(over.x, 0.0, EPS, "angles clamp to 90")


func test_below_horizon_angles_aim_at_own_feet() -> void:
	var b = load(BALLISTICS)
	var down: Vector3 = b.launch_velocity(b.MIN_ANGLE_DEG, 1.0, 0.5)
	assert_true(down.y < 0.0, "-10 degrees fires downward")
	var clamped: Vector3 = b.launch_velocity(-30.0, 1.0, 0.5)
	assert_almost_equal(clamped.y, down.y, EPS, "angles clamp at the lower bound")


func test_time_of_flight_matches_analytic_drop() -> void:
	var b = load(BALLISTICS)
	var t: float = b.time_of_flight(Vector3(0, 1, 0), Vector3.ZERO)
	assert_almost_equal(t, sqrt(2.0 / b.MATCH_GRAVITY), EPS, "pure 1m drop: t = sqrt(2h/g)")


func test_range_grows_with_power() -> void:
	var b = load(BALLISTICS)
	var origin := Vector3(0, 1, 0)
	var slow: float = b.range_on_ground(origin, b.launch_velocity(45.0, 1.0, 0.3))
	var fast: float = b.range_on_ground(origin, b.launch_velocity(45.0, 1.0, 0.9))
	assert_true(fast > slow, "more power means more range (%.2f vs %.2f)" % [fast, slow])


func test_damage_full_in_direct_hit() -> void:
	var b = load(BALLISTICS)
	assert_almost_equal(b.damage_falloff(0.2), b.MAX_DAMAGE, EPS, "close impact = full damage")
	assert_almost_equal(b.damage_falloff(b.DIRECT_HIT_RADIUS), b.MAX_DAMAGE, EPS,
			"direct hit boundary = full damage")


func test_damage_falls_off_linearly() -> void:
	var b = load(BALLISTICS)
	var mid: float = (b.DIRECT_HIT_RADIUS + b.EXPLOSION_RADIUS) * 0.5
	assert_almost_equal(b.damage_falloff(mid), b.MAX_DAMAGE * 0.5, EPS,
			"midway between direct and radius = half damage")


func test_damage_zero_beyond_radius() -> void:
	var b = load(BALLISTICS)
	assert_almost_equal(b.damage_falloff(b.EXPLOSION_RADIUS), 0.0, EPS, "at radius = zero")
	assert_almost_equal(b.damage_falloff(b.EXPLOSION_RADIUS + 1.0), 0.0, EPS,
			"beyond radius = zero")
