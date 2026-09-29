extends SceneTree
## Built-in headless test runner — zero dependencies (decision in worklog S01).
##
## Usage:
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Discovers res://tests/test_*.gd, runs every method whose name starts with
## "test_", prints PASS/FAIL per test, exits nonzero on any failure.

const TEST_DIR := "res://tests"


func _initialize() -> void:
	# Script mode does not guarantee InputMap is populated from project settings.
	InputMap.load_from_project_settings()
	var failed := _run_all()
	quit(1 if failed else 0)


func _run_all() -> bool:
	var any_failed := false
	var total := 0
	for path in _discover():
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL <load> %s" % path)
			any_failed = true
			continue
		var instance: RefCounted = script.new()
		for method in _test_methods(instance):
			total += 1
			instance.call(method)
			if instance.has_method("cleanup"):
				instance.cleanup()
			if instance.failures.is_empty():
				print("  PASS %s.%s" % [path.get_file(), method])
			else:
				any_failed = true
				for failure in instance.failures:
					printerr("  FAIL %s.%s — %s" % [path.get_file(), method, failure])
			instance.failures.clear()
		# Instances are RefCounted — released when the local reference drops.
	print("--- %d test(s) run, %s" % [total, "FAILURES" if any_failed else "all passed"])
	return any_failed


func _discover() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("cannot open %s" % TEST_DIR)
		return found
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(TEST_DIR.path_join(file))
	found.sort()
	return found


func _test_methods(instance: RefCounted) -> PackedStringArray:
	var seen := {}
	var names: PackedStringArray = []
	for entry in instance.get_method_list():
		var method: String = entry["name"]
		if method.begins_with("test_") and not seen.has(method):
			seen[method] = true
			names.append(method)
	names.sort()
	return names
