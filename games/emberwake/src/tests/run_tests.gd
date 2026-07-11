# tests/run_tests.gd — unit-test runner (engine contract §7).
# Discovers tests/unit/test_*.gd, instantiates each, calls every zero-arg
# method starting "test_". Prints "TESTS: <pass>/<total> PASSED"; exit 1 on
# any failure. Run: godot --headless --path src --script res://tests/run_tests.gd
extends SceneTree

const T := preload("res://tests/unit/_t.gd")

func _initialize() -> void:
	var dir := DirAccess.open("res://tests/unit")
	if dir == null:
		push_error("tests/unit not found")
		quit(1)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():
			T.total += 1
			T.failed += 1
			print("%s: failed to load" % f)
			continue
		var inst: Object = script.new()
		T.current_file = f
		var seen := {}
		for m in inst.get_method_list():
			var name: String = m["name"]
			if name.begins_with("test_") and m["args"].is_empty() and not seen.has(name):
				seen[name] = true
				T.current_method = name
				inst.call(name)
		if inst.has_method("cleanup"):
			inst.call("cleanup")
		if inst is Node:
			inst.free()
	print("TESTS: %d/%d PASSED" % [T.total - T.failed, T.total])
	quit(0 if T.failed == 0 else 1)
