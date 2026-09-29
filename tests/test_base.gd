extends RefCounted
## Assertion base for the built-in headless test runner (tests/run_tests.gd).
## Test scripts extend this by path and implement `test_*` methods.

var failures: PackedStringArray = []
var _context := ""


func _init() -> void:
	_context = get_script().resource_path.get_file()


func assert_true(condition: bool, what: String) -> void:
	if not condition:
		failures.append("expected true: %s" % what)


func assert_equal(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [what, expected, actual])
