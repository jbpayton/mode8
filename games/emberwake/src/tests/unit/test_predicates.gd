# test_predicates.gd — contract §7: every predicate op incl. and/or/not.
# All ids below are FIXTURES.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const Algebra := preload("res://engine/algebra.gd")

func _alg() -> Object:
	return Algebra.new(null, null)

func _src() -> Dictionary:
	return {"key": "s", "statuses": [{"id": "st.fix_venom", "duration": 2, "potency": 3}],
			"affinities": [{"element": "fix_fire", "relation": "weak"}],
			"resources": {"hp": {"cur": 10, "max": 40}}, "alive": true}

func _tgt() -> Dictionary:
	return {"key": "t", "statuses": [], "affinities": [{"element": "fix_fire", "relation": "immune"}],
			"resources": {"hp": {"cur": 30, "max": 40}}, "alive": true}

func test_has_status() -> void:
	var a := _alg()
	T.ok(a.eval_predicate({"op": "has_status", "who": "source", "status": "st.fix_venom"}, _src(), _tgt()), "source has status")
	T.ok(not a.eval_predicate({"op": "has_status", "who": "target", "status": "st.fix_venom"}, _src(), _tgt()), "target lacks status")
	T.ok(not a.eval_predicate({"op": "has_status", "who": "source", "status": "st.fix_other"}, _src(), _tgt()), "different status id")

func test_element_affinity() -> void:
	var a := _alg()
	T.ok(a.eval_predicate({"op": "element_affinity", "who": "source", "element": "fix_fire", "relation": "weak"}, _src(), _tgt()), "weak match")
	T.ok(a.eval_predicate({"op": "element_affinity", "who": "target", "element": "fix_fire", "relation": "immune"}, _src(), _tgt()), "immune match")
	T.ok(not a.eval_predicate({"op": "element_affinity", "who": "source", "element": "fix_fire", "relation": "immune"}, _src(), _tgt()), "relation mismatch")
	T.ok(not a.eval_predicate({"op": "element_affinity", "who": "source", "element": "fix_frost", "relation": "weak"}, _src(), _tgt()), "element mismatch")

func test_hp_below_above() -> void:
	var a := _alg()
	T.ok(a.eval_predicate({"op": "hp_below", "who": "source", "pct": 0.5}, _src(), _tgt()), "10/40 below 0.5")
	T.ok(not a.eval_predicate({"op": "hp_below", "who": "source", "pct": 0.25}, _src(), _tgt()), "exactly 0.25 is not below (strict)")
	T.ok(a.eval_predicate({"op": "hp_above", "who": "target", "pct": 0.5}, _src(), _tgt()), "30/40 above 0.5")
	T.ok(not a.eval_predicate({"op": "hp_above", "who": "target", "pct": 0.75}, _src(), _tgt()), "exactly 0.75 is not above (strict)")

func test_flag() -> void:
	var a := _alg()
	a.flags = ["flag.fix_started"]
	T.ok(a.eval_predicate({"op": "flag", "id": "flag.fix_started"}, null, null), "set flag")
	T.ok(not a.eval_predicate({"op": "flag", "id": "flag.fix_other"}, null, null), "unset flag")

func test_terrain_is_false_for_menu_rows() -> void:
	var a := _alg()
	T.ok(not a.eval_predicate({"op": "terrain", "type": "fix_lava"}, _src(), _tgt()), "terrain never true outside grid battles")

func test_and_or_not() -> void:
	var a := _alg()
	var yes := {"op": "hp_below", "who": "source", "pct": 0.5}
	var no := {"op": "hp_below", "who": "source", "pct": 0.1}
	T.ok(a.eval_predicate({"op": "and", "preds": [yes, yes]}, _src(), _tgt()), "and true")
	T.ok(not a.eval_predicate({"op": "and", "preds": [yes, no]}, _src(), _tgt()), "and short-circuits false")
	T.ok(a.eval_predicate({"op": "or", "preds": [no, yes]}, _src(), _tgt()), "or true")
	T.ok(not a.eval_predicate({"op": "or", "preds": [no, no]}, _src(), _tgt()), "or false")
	T.ok(a.eval_predicate({"op": "not", "pred": no}, _src(), _tgt()), "not")
	var nested := {"op": "not", "pred": {"op": "and", "preds": [yes, {"op": "not", "pred": no}]}}
	T.ok(not a.eval_predicate(nested, _src(), _tgt()), "nested composition")

func test_normalize_and_unknown_op() -> void:
	var errs: Array = []
	var p: Variant = Algebra.norm_predicate({"op": "and", "preds": [{"op": "hp_below", "who": "source", "pct": 0.5}]}, errs, "fix")
	T.eq(errs, [], "valid predicate normalizes clean")
	T.ok(p is Dictionary and p["op"] == "and", "shape preserved")
	Algebra.norm_predicate({"op": "is_tuesday"}, errs, "fix")
	T.ok(errs.size() == 1, "unknown predicate op collected at load time")

func test_null_who_is_false() -> void:
	# Monster AI 'when' predicates evaluate with no target bound.
	var a := _alg()
	T.ok(not a.eval_predicate({"op": "has_status", "who": "target", "status": "st.fix_venom"}, _src(), null), "target-pred with null target is false")
