# test_values.gd — contract §7: const/stat/dice (seeded)/formula/scaling
# + shorthand promotion (bare number -> const). All ids below are FIXTURES.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const Algebra := preload("res://engine/algebra.gd")
const RngScript := preload("res://autoload/rng.gd")

class FakeDb:
	var curves := {
		"curve.fix_lin": {"kind": "formula", "expr": "source.level * 2 + 1"},
		"curve.fix_tab": {"kind": "table", "values": [5, 10, 15]},
	}
	func curve(id: String) -> Dictionary:
		return curves.get(id, {})
	func multiplier(rel: String) -> float:
		return {"weak": 2.0, "resist": 0.5, "immune": 0.0, "absorb": -1.0}[rel]

var _nodes: Array = []

func _alg(seed_v: int = 1) -> Object:
	var rng: Node = RngScript.new()
	rng.set_seed(seed_v)
	_nodes.append(rng)
	return Algebra.new(FakeDb.new(), rng)

func cleanup() -> void:
	for n in _nodes:
		n.free()

func _src() -> Dictionary:
	return {"key": "s", "level": 4, "stats": {"atk": 9, "mag": 6},
			"resources": {"hp": {"cur": 20, "max": 40}}, "alive": true}

func _tgt() -> Dictionary:
	return {"key": "t", "level": 2, "stats": {"def": 3},
			"resources": {"hp": {"cur": 10, "max": 10}}, "alive": true}

func test_const_and_shorthand() -> void:
	var a := _alg()
	var errs: Array = []
	var v: Variant = Algebra.norm_value(7, errs, "fix")
	T.eq(errs, [], "bare number normalizes clean")
	T.eq(v, {"op": "const", "n": 7.0}, "bare number -> const node")
	T.eq(a.eval_value(v, _src(), _tgt()), 7.0, "const evaluates")
	T.eq(a.eval_value({"op": "const", "n": -2.5}, null, null), -2.5, "negative const")

func test_stat_node() -> void:
	var a := _alg()
	T.eq(a.eval_value({"op": "stat", "ref": "atk"}, _src(), _tgt()), 9.0, "stat defaults to source")
	T.eq(a.eval_value({"op": "stat", "ref": "def", "of": "target"}, _src(), _tgt()), 3.0, "stat of target")
	T.eq(a.eval_value({"op": "stat", "ref": "hp"}, _src(), _tgt()), 20.0, "resource current via stat node")

func test_dice_seeded() -> void:
	var a := _alg(42)
	var b := _alg(42)
	var node := {"op": "dice", "d": "2d6+3"}
	var r1: float = a.eval_value(node, null, null)
	T.ok(r1 >= 5.0 and r1 <= 15.0, "2d6+3 in range")
	T.eq(b.eval_value(node, null, null), r1, "same seed -> same roll")
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 5:
		seq_a.append(a.eval_value({"op": "dice", "d": "1d20-1"}, null, null))
		seq_b.append(b.eval_value({"op": "dice", "d": "1d20-1"}, null, null))
	T.eq(seq_a, seq_b, "seeded stream reproduces")
	for r in seq_a:
		T.ok(r >= 0.0 and r <= 19.0, "1d20-1 in range")

func test_formula_node() -> void:
	var a := _alg()
	var v := {"op": "formula", "expr": "source.mag * 2 + 6"}
	T.eq(a.eval_value(v, _src(), _tgt()), 18.0, "formula over source")
	T.eq(a.eval_value({"op": "formula", "expr": "source.mag - target.def"}, _src(), _tgt()), 3.0, "formula over both")

func test_scaling_node() -> void:
	var a := _alg()
	var errs: Array = []
	var v: Variant = Algebra.norm_value({"op": "scaling", "curve": "curve.fix_lin", "level": 3}, errs, "fix")
	T.eq(errs, [], "scaling level promotes bare number")
	T.eq(a.eval_value(v, null, null), 7.0, "formula curve at level 3")
	var tab := {"op": "scaling", "curve": "curve.fix_tab", "level": {"op": "const", "n": 2}}
	T.eq(a.eval_value(tab, null, null), 10.0, "table curve lookup")
	var over := {"op": "scaling", "curve": "curve.fix_tab", "level": {"op": "const", "n": 99}}
	T.eq(a.eval_value(over, null, null), 15.0, "table clamps past end")
	var lvl_ref := {"op": "scaling", "curve": "curve.fix_lin", "level": {"op": "formula", "expr": "source.level"}}
	T.eq(a.eval_value(lvl_ref, _src(), _tgt()), 9.0, "level from source (4*2+1)")

func test_mean_value() -> void:
	var a := _alg()
	T.eq(a.mean_value({"op": "dice", "d": "2d6+3"}, null, null), 10.0, "dice mean")
	T.eq(a.mean_value({"op": "const", "n": 4}, null, null), 4.0, "const mean")
	T.eq(a.mean_value({"op": "formula", "expr": "source.atk * 2"}, _src(), _tgt()), 18.0, "formula mean")

func test_unknown_value_op() -> void:
	var errs: Array = []
	Algebra.norm_value({"op": "hexadice"}, errs, "fix")
	T.ok(errs.size() == 1, "unknown value op collected at normalize (load) time")
