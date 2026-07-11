# engine/formula.gd — Formula DSL parser + evaluator.
# Contract: effect-algebra.md §Formula DSL grammar (+ RFC-002 CONTEXTVAR).
#   expr := term (('+'|'-') term)* ; term := unary (('*'|'/'|'//'|'%') unary)*
#   unary := '-' unary | factor
#   factor := NUMBER | ref | CONTEXTVAR | func '(' expr (',' expr)* ')' | '(' expr ')'
#   ref := ('source'|'target'|'game') '.' IDENT ; func := min|max|floor|ceil|round|abs|clamp
# CONTEXTVARs are legal only when declared by the caller (damage_formulas: ["value"]).
# parse() returns {"ok":true,"ast":..} or {"ok":false,"error":..,"pos":..}; ASTs are cached.
# '/' is float division, '//' floors, '%' is fmod; consumers round final Values to int.
extends RefCounted

const SCOPES := ["source", "target", "game"]
const FUNCS := {"min": [2, 8], "max": [2, 8], "floor": [1, 1], "ceil": [1, 1],
		"round": [1, 1], "abs": [1, 1], "clamp": [3, 3]}

static var _cache: Dictionary = {}

# ---------------------------------------------------------------- tokenizer

static func _tokenize(src: String) -> Dictionary:
	var toks: Array = []
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			i += 1
			continue
		if c >= "0" and c <= "9":
			var j := i
			var seen_dot := false
			while j < n and ((src[j] >= "0" and src[j] <= "9") or (src[j] == "." and not seen_dot and j + 1 < n and src[j + 1] >= "0" and src[j + 1] <= "9")):
				if src[j] == ".":
					seen_dot = true
				j += 1
			toks.append({"t": "num", "v": src.substr(i, j - i).to_float(), "pos": i})
			i = j
			continue
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_":
			var j := i
			while j < n and ((src[j] >= "a" and src[j] <= "z") or (src[j] >= "A" and src[j] <= "Z") or (src[j] >= "0" and src[j] <= "9") or src[j] == "_"):
				j += 1
			toks.append({"t": "ident", "v": src.substr(i, j - i), "pos": i})
			i = j
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "/":
			toks.append({"t": "op", "v": "//", "pos": i})
			i += 2
			continue
		if c in "+-*/%(),.":
			toks.append({"t": "op", "v": c, "pos": i})
			i += 1
			continue
		return {"ok": false, "error": "unexpected character '%s'" % c, "pos": i}
	toks.append({"t": "eof", "v": "", "pos": n})
	return {"ok": true, "toks": toks}

# ------------------------------------------------------------------ parser

class Parser:
	var toks: Array
	var pos := 0
	var err: Dictionary = {}
	var ctx_vars: Array

	func _init(t: Array, cv: Array) -> void:
		toks = t
		ctx_vars = cv

	func peek() -> Dictionary:
		return toks[pos]

	func take() -> Dictionary:
		var t: Dictionary = toks[pos]
		pos += 1
		return t

	func fail(msg: String, at: Dictionary) -> Variant:
		if err.is_empty():
			err = {"ok": false, "error": msg, "pos": at["pos"]}
		return null

	func is_op(v: String) -> bool:
		return peek()["t"] == "op" and peek()["v"] == v

	func expect_op(v: String) -> bool:
		if is_op(v):
			take()
			return true
		fail("expected '%s'" % v, peek())
		return false

	func expr() -> Variant:
		var l = term()
		if l == null:
			return null
		while peek()["t"] == "op" and (peek()["v"] == "+" or peek()["v"] == "-"):
			var op: String = take()["v"]
			var r = term()
			if r == null:
				return null
			l = {"k": "bin", "op": op, "l": l, "r": r}
		return l

	func term() -> Variant:
		var l = unary()
		if l == null:
			return null
		while peek()["t"] == "op" and peek()["v"] in ["*", "/", "//", "%"]:
			var op: String = take()["v"]
			var r = unary()
			if r == null:
				return null
			l = {"k": "bin", "op": op, "l": l, "r": r}
		return l

	func unary() -> Variant:
		if is_op("-"):
			take()
			var e = unary()
			if e == null:
				return null
			return {"k": "neg", "e": e}
		return factor()

	func factor() -> Variant:
		var t := peek()
		if t["t"] == "num":
			take()
			return {"k": "num", "v": t["v"]}
		if is_op("("):
			take()
			var e = expr()
			if e == null:
				return null
			if not expect_op(")"):
				return null
			return e
		if t["t"] == "ident":
			take()
			var name: String = t["v"]
			if name in SCOPES:
				if not expect_op("."):
					return null
				var f := peek()
				if f["t"] != "ident":
					return fail("expected identifier after '%s.'" % name, f)
				take()
				return {"k": "ref", "scope": name, "name": f["v"]}
			if FUNCS.has(name):
				return _call(name, t)
			if name in ctx_vars:
				return {"k": "var", "name": name}
			return fail("unknown identifier '%s' (not a scope, function, or context var)" % name, t)
		return fail("unexpected token '%s'" % str(t["v"]), t)

	func _call(fn: String, at: Dictionary) -> Variant:
		if not expect_op("("):
			return null
		var args: Array = []
		var a = expr()
		if a == null:
			return null
		args.append(a)
		while is_op(","):
			take()
			a = expr()
			if a == null:
				return null
			args.append(a)
		if not expect_op(")"):
			return null
		var arity: Array = FUNCS[fn]
		if args.size() < arity[0] or args.size() > arity[1]:
			return fail("%s() takes %d..%d args, got %d" % [fn, arity[0], arity[1], args.size()], at)
		return {"k": "call", "fn": fn, "args": args}

# parse(expr, ctx_vars) — ctx_vars: declared CONTEXTVAR names (RFC-002).
static func parse(src: String, ctx_vars: Array = []) -> Dictionary:
	var key := ",".join(ctx_vars) + "|" + src
	if _cache.has(key):
		return _cache[key]
	var tk := _tokenize(src)
	var out: Dictionary
	if not tk["ok"]:
		out = tk
	else:
		var p := Parser.new(tk["toks"], ctx_vars)
		var ast = p.expr()
		if ast == null:
			out = p.err if not p.err.is_empty() else {"ok": false, "error": "parse error", "pos": 0}
		elif p.peek()["t"] != "eof":
			out = {"ok": false, "error": "unexpected trailing '%s'" % str(p.peek()["v"]), "pos": p.peek()["pos"]}
		else:
			out = {"ok": true, "ast": ast}
	_cache[key] = out
	return out

# ---------------------------------------------------------------- evaluator
# ctx: {"source": entity?, "target": entity?, "flags": Array/Dict of flag ids,
#       "vars": {name: number}, "stat_cb": Callable(entity, name) -> float (optional)}
# Default entity resolution: entity.ctx overlay -> "level" -> resource pools
# (cur / max_<pool> / <pool>_pct on entity.resources) -> entity.stats.

static func evaluate(ast: Dictionary, ctx: Dictionary) -> float:
	match ast["k"]:
		"num":
			return ast["v"]
		"var":
			var vars: Dictionary = ctx.get("vars", {})
			if not vars.has(ast["name"]):
				push_warning("formula: context var '%s' not bound" % ast["name"])
				return 0.0
			return float(vars[ast["name"]])
		"neg":
			return -evaluate(ast["e"], ctx)
		"ref":
			return _ref(ast, ctx)
		"bin":
			var a := evaluate(ast["l"], ctx)
			var b := evaluate(ast["r"], ctx)
			return _bin(ast["op"], a, b)
		"call":
			var vals: Array[float] = []
			for arg in ast["args"]:
				vals.append(evaluate(arg, ctx))
			return _fn(ast["fn"], vals)
	push_warning("formula: bad AST node")
	return 0.0

static func _bin(op: String, a: float, b: float) -> float:
	match op:
		"+": return a + b
		"-": return a - b
		"*": return a * b
		"/":
			if b == 0.0:
				push_warning("formula: division by zero")
				return 0.0
			return a / b
		"//":
			if b == 0.0:
				push_warning("formula: division by zero")
				return 0.0
			return floorf(a / b)
		"%":
			if b == 0.0:
				push_warning("formula: modulo by zero")
				return 0.0
			return fmod(a, b)
	return 0.0

static func _fn(fn: String, v: Array[float]) -> float:
	match fn:
		"min":
			var m := v[0]
			for x in v: m = minf(m, x)
			return m
		"max":
			var m := v[0]
			for x in v: m = maxf(m, x)
			return m
		"floor": return floorf(v[0])
		"ceil": return ceilf(v[0])
		"round": return roundf(v[0])
		"abs": return absf(v[0])
		"clamp": return clampf(v[0], v[1], v[2])
	return 0.0

static func _ref(ast: Dictionary, ctx: Dictionary) -> float:
	var scope: String = ast["scope"]
	var name: String = ast["name"]
	if scope == "game":
		var flags = ctx.get("flags", [])
		var fid := "flag." + name
		var hit: bool = (fid in flags) if flags is Array else flags.has(fid)
		return 1.0 if hit else 0.0
	var ent = ctx.get(scope)
	if ent == null:
		push_warning("formula: no %s bound" % scope)
		return 0.0
	var cb = ctx.get("stat_cb")
	if cb is Callable and cb.is_valid():
		return float(cb.call(ent, name))
	return resolve_entity_var(ent, name)

static func resolve_entity_var(ent: Dictionary, name: String) -> float:
	var overlay: Dictionary = ent.get("ctx", {})
	if overlay.has(name):
		return float(overlay[name])
	if name == "level":
		return float(ent.get("level", 0))
	var res: Dictionary = ent.get("resources", {})
	if res.has(name):
		return float(res[name]["cur"])
	if name.begins_with("max_") and res.has(name.substr(4)):
		return float(res[name.substr(4)]["max"])
	if name.ends_with("_pct") and res.has(name.trim_suffix("_pct")):
		var pool: Dictionary = res[name.trim_suffix("_pct")]
		return float(pool["cur"]) / maxf(1.0, float(pool["max"]))
	var stats: Dictionary = ent.get("stats", {})
	if stats.has(name):
		return float(stats[name])
	push_warning("formula: unknown ref '%s'" % name)
	return 0.0
