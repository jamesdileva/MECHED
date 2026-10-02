extends "res://tests/test_base.gd"
## S06 knockback rules (implementation-guide §16: distance, force, mass, plus
## terrain contact). Pure static functions — verified headless. The roadmap's
## scenario list (direct hit, near miss, explosion underneath / beside, at
## different distances) maps to these cases by geometry.

const KNOCKBACK := "res://scripts/combat/knockback.gd"
const EPS := 0.0001


func test_direct_hit_launches_strongest() -> void:
	var k = load(KNOCKBACK)
	# Explosion at the mech's feet: mostly upward, full force, grounded.
	var v: Vector3 = k.impulse(Vector3(0, 1, 0), Vector3(0, 0, 0), true, 1.0)
	assert_almost_equal(v.length(), k.KNOCKBACK_FORCE * 0.5, EPS,
			"grounded direct hit = full force minus ground absorption")
	assert_true(v.y > 0.0, "direct hit from below launches upward")


func test_near_miss_pushes_away_from_blast() -> void:
	var k = load(KNOCKBACK)
	# Explosion beside (left of) an airborne mech: pushed right, weaker than direct.
	var v: Vector3 = k.impulse(Vector3(3, 0, 0), Vector3(0, 0, 0), false, 1.0)
	assert_true(v.x > 0.0, "mech is pushed away from the blast")
	assert_almost_equal(v.x, k.KNOCKBACK_FORCE * k.falloff(3.0), EPS,
			"speed follows the distance falloff")


func test_falloff_at_different_distances() -> void:
	var k = load(KNOCKBACK)
	var close: float = k.falloff(1.0)
	var mid: float = k.falloff(3.0)
	assert_almost_equal(close, 1.0, EPS, "inside direct radius = full force")
	assert_true(mid > 0.0 and mid < 1.0, "mid distance is partially pushed")
	assert_almost_equal(k.falloff(k.KNOCKBACK_RADIUS), 0.0, EPS, "at radius = no push")
	assert_almost_equal(k.falloff(k.KNOCKBACK_RADIUS + 5.0), 0.0, EPS,
			"beyond radius = no push")


func test_mass_resists_knockback() -> void:
	var k = load(KNOCKBACK)
	var light: Vector3 = k.impulse(Vector3(2, 0, 0), Vector3.ZERO, false, 1.0)
	var heavy: Vector3 = k.impulse(Vector3(2, 0, 0), Vector3.ZERO, false, 2.0)
	assert_almost_equal(heavy.length(), light.length() * 0.5, EPS,
			"double mass = half the velocity change")


func test_ground_contact_absorbs_half() -> void:
	var k = load(KNOCKBACK)
	var air: Vector3 = k.impulse(Vector3(2, 0, 0), Vector3.ZERO, false, 1.0)
	var ground: Vector3 = k.impulse(Vector3(2, 0, 0), Vector3.ZERO, true, 1.0)
	assert_almost_equal(ground.length(), air.length() * 0.5, EPS,
			"terrain contact absorbs half the impulse")


func test_zero_distance_falls_back_up() -> void:
	var k = load(KNOCKBACK)
	var v: Vector3 = k.impulse(Vector3.ZERO, Vector3.ZERO, false, 1.0)
	assert_true(v.y > 0.0, "degenerate blast direction launches up")


func test_beyond_radius_returns_zero() -> void:
	var k = load(KNOCKBACK)
	var v: Vector3 = k.impulse(Vector3(10, 0, 0), Vector3.ZERO, false, 1.0)
	assert_equal(v, Vector3.ZERO, "no impulse outside the knockback radius")
