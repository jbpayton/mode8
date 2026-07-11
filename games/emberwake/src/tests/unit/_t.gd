# tests/unit/_t.gd — assert helpers (engine contract §7).
# T.eq(a, b, msg) / T.ok(cond, msg) / T.err(callable, msg): count failures and
# print "file:method: message". Error convention across the engine: fallible
# calls return a Dictionary with "ok": false and/or an "error" key.
extends RefCounted

static var total := 0
static var failed := 0
static var current_file := ""
static var current_method := ""

static func _fail(msg: String) -> void:
	failed += 1
	print("%s:%s: %s" % [current_file, current_method, msg])

static func ok(cond: bool, msg := "") -> bool:
	total += 1
	if not cond:
		_fail("expected true — " + msg)
	return cond

static func eq(a: Variant, b: Variant, msg := "") -> bool:
	total += 1
	if not deep_eq(a, b):
		_fail("%s != %s — %s" % [str(a), str(b), msg])
		return false
	return true

# err: the callable must return an error-shaped result (see header).
static func err(callable: Callable, msg := "") -> bool:
	total += 1
	var r: Variant = callable.call()
	var is_err: bool = r is Dictionary and (r.get("ok", true) == false or r.has("error"))
	if not is_err:
		_fail("expected an error result, got %s — %s" % [str(r), msg])
	return is_err

# Deep equality with numeric tolerance; ints and equal-valued floats compare
# equal so JSON round-trips (which widen ints) stay comparable.
static func deep_eq(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) <= 1e-6
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not deep_eq(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not deep_eq(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b
