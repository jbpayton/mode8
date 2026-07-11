# test_formula.gd — contract §7: parser precedence, //, unary minus, funcs,
# source/target/game refs, parse errors (with position). RFC-002 context vars.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const F := preload("res://engine/formula.gd")

func _ev(expr: String, ctx: Dictionary = {}, ctx_vars: Array = []) -> float:
	var p := F.parse(expr, ctx_vars)
	if not T.ok(p["ok"], "parse '%s': %s" % [expr, str(p.get("error"))]):
		return -99999.0
	return F.evaluate(p["ast"], ctx)

func test_precedence() -> void:
	T.eq(_ev("2 + 3 * 4"), 14.0, "mul binds tighter than add")
	T.eq(_ev("(2 + 3) * 4"), 20.0, "parens")
	T.eq(_ev("2 - 3 - 4"), -5.0, "left-assoc subtraction")
	T.eq(_ev("12 / 4 / 3"), 1.0, "left-assoc division")
	T.eq(_ev("10 - 2 * 3"), 4.0, "precedence with sub")
	T.eq(_ev("7 % 4 + 1"), 4.0, "modulo")
	T.eq(_ev("5 / 2"), 2.5, "float division")

func test_floor_div() -> void:
	T.eq(_ev("7 // 2"), 3.0, "floor division")
	T.eq(_ev("-7 // 2"), -4.0, "floor division floors toward -inf")
	T.eq(_ev("9 // 3 // 2"), 1.0, "left-assoc floor division")

func test_unary_minus() -> void:
	T.eq(_ev("-3 + 5"), 2.0, "leading negation")
	T.eq(_ev("--3"), 3.0, "double negation")
	T.eq(_ev("2 * -3"), -6.0, "negation in term")
	T.eq(_ev("-(2 + 3)"), -5.0, "negated parens")

func test_funcs() -> void:
	T.eq(_ev("min(2, 5)"), 2.0, "min")
	T.eq(_ev("max(2, 5)"), 5.0, "max")
	T.eq(_ev("max(1, 2, 7)"), 7.0, "variadic max")
	T.eq(_ev("floor(2.7)"), 2.0, "floor")
	T.eq(_ev("ceil(2.1)"), 3.0, "ceil")
	T.eq(_ev("round(2.5)"), 3.0, "round")
	T.eq(_ev("abs(-4)"), 4.0, "abs")
	T.eq(_ev("clamp(5, 1, 3)"), 3.0, "clamp high")
	T.eq(_ev("clamp(0, 1, 3)"), 1.0, "clamp low")
	T.eq(_ev("max(1, 26 - 4)"), 22.0, "nested expr arg")

func test_refs() -> void:
	var src := {"level": 3, "stats": {"atk": 7, "mag": 4},
			"resources": {"hp": {"cur": 30, "max": 60}}}
	var tgt := {"level": 2, "stats": {"def": 5}, "resources": {"hp": {"cur": 10, "max": 40}}}
	var ctx := {"source": src, "target": tgt, "flags": ["flag.brave"]}
	T.eq(_ev("source.atk * 2", ctx), 14.0, "source stat")
	T.eq(_ev("target.def + 1", ctx), 6.0, "target stat")
	T.eq(_ev("source.level * 10", ctx), 30.0, "level builtin")
	T.eq(_ev("source.hp", ctx), 30.0, "resource current")
	T.eq(_ev("source.max_hp", ctx), 60.0, "resource max builtin")
	T.eq(_ev("source.hp_pct", ctx), 0.5, "resource pct builtin")
	T.eq(_ev("game.brave", ctx), 1.0, "flag set reads 1")
	T.eq(_ev("game.unset_flag", ctx), 0.0, "flag unset reads 0")
	T.eq(_ev("source.ctx_extra", {"source": {"ctx": {"ctx_extra": 9}}}), 9.0, "entity ctx overlay (status potency channel)")

func test_context_vars() -> void:
	# RFC-002: 'value' only where declared (stat-model damage_formulas).
	T.eq(_ev("max(1, value - target.def)", {"target": {"stats": {"def": 4}}, "vars": {"value": 10}}, ["value"]), 6.0, "declared context var")
	T.err(func(): return F.parse("value + 1"), "bare 'value' rejected without context")
	T.err(func(): return F.parse("potency * 2"), "undeclared context var rejected")

func test_parse_errors() -> void:
	T.err(func(): return F.parse("2 +"), "dangling operator")
	T.err(func(): return F.parse("source.atk +* 2"), "double operator")
	T.err(func(): return F.parse("min(2)"), "min arity")
	T.err(func(): return F.parse("clamp(1, 2)"), "clamp arity")
	T.err(func(): return F.parse("sqrt(2)"), "unknown function")
	T.err(func(): return F.parse("source"), "scope without member")
	T.err(func(): return F.parse("world.atk"), "unknown scope")
	T.err(func(): return F.parse("2 & 3"), "illegal character")
	T.err(func(): return F.parse("(2 + 3"), "unclosed paren")
	T.err(func(): return F.parse("2 3"), "trailing token")
	var e := F.parse("2 + @")
	T.ok(not e["ok"] and e.has("pos") and e["pos"] == 4, "error carries position")

func test_ast_cache() -> void:
	var a := F.parse("1 + 2")
	var b := F.parse("1 + 2")
	T.ok(a["ast"] == b["ast"], "repeated parse returns cached AST")
