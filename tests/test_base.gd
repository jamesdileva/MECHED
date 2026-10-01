extends RefCounted
## Assertion base for the built-in headless test runner (tests/run_tests.gd).
## Test scripts extend this by path and implement `test_*` methods.

var failures: PackedStringArray = []
var assertions_made := 0
var _context := ""
var _owned_nodes: Array[Node] = []


func _init() -> void:
	_context = get_script().resource_path.get_file()


## Tests register every manually created Node here — Nodes are not
## reference-counted, and the runner calls cleanup() after each test method.
func _add_cleanup(node: Node) -> void:
	_owned_nodes.append(node)


## Called by the runner after every test method.
func cleanup() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()


func assert_true(condition: bool, what: String) -> void:
	assertions_made += 1
	if not condition:
		failures.append("expected true: %s" % what)


func assert_equal(actual: Variant, expected: Variant, what: String) -> void:
	assertions_made += 1
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [what, expected, actual])


func assert_almost_equal(actual: float, expected: float, epsilon: float, what: String) -> void:
	assertions_made += 1
	if absf(actual - expected) > epsilon:
		failures.append("%s: expected ~%s, got %s" % [what, expected, actual])
