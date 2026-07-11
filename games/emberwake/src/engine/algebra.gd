# engine/algebra.gd — effect-algebra interpreter.
# Contract: ontology/effect-algebra.md §Interpreter contract + CONVENTIONS.md.
#  - normalize_*: shorthand strings -> {"op":..}, bare numbers -> const,
#    conditional -> branch; unknown op is a LOAD-TIME error (collected into
#    the caller's errors array; ContentDB refuses to load on any).
#  - damage pipeline: value -> variance -> crit -> route through stat-model
#    damage_formula (CONTEXTVAR value; pierce p blends p*raw + (1-p)*mitigated)
#    -> element multiplier -> host damage_scale (row/defend) -> round -> clamp
#    >= 0 (absorb: negative result heals). `fixed` skips all of it.
#  - every atomic application emits {turn, source, ability, effect_op, target,
#    rolled, result} through log_cb.
# Instance deps are injected: db (ContentDB), rng (Rng), log_cb, optional host
# (battle) providing stat_value/max_resource/damage_scale/on_death/on_flee.
extends RefCounted

const Formula := preload("res://engine/formula.gd")

const VALUE_OPS := ["const", "stat", "dice", "formula", "scaling"]
const EFFECT_OPS := ["damage", "heal", "apply_status", "cure_status", "modify_stat",
		"resource", "revive", "summon", "steal", "scan", "flee", "transform", "set_flag",
		"move", "knockback", "seq", "choice", "repeat", "branch", "combo"]
const PRED_OPS := ["has_status", "element_affinity", "hp_below", "hp_above", "flag",
		"terrain", "and", "or", "not"]
const TARGET_OPS := ["self", "single", "all", "row", "random", "lowest", "dead",
		"radius", "line", "cone", "cell", "adjacent"]
const TRIGGER_OPS := ["on_use", "on_hit", "on_crit", "on_kill", "on_damage_taken",
		"on_turn_start", "on_turn_end", "on_equip", "on_battle_start", "on_hp_below", "aura"]

var db: Object = null
var rng: Object = null
var log_cb: Callable = Callable()
var flags: Array = []
var turn_no: int = 0

# host is weakly held (the battle owns the algebra; a strong back-reference
# would leak the pair as a RefCounted cycle).
var _host_wr: WeakRef = null
var host: Object:
	get:
		return _host_wr.get_ref() if _host_wr != null else null
	set(v):
		_host_wr = weakref(v) if v != null else null

func _init(p_db: Object = null, p_rng: Object = null) -> void:
	db = p_db
	rng = p_rng

# ------------------------------------------------------------ normalization

static func _tag(node: Variant) -> Variant:
	return {"op": node} if node is String else node

static func norm_value(v: Variant, errors: Array, path: String) -> Variant:
	if v is float or v is int:
		return {"op": "const", "n": float(v)}
	v = _tag(v)
	if not (v is Dictionary) or not v.has("op"):
		errors.append("%s: not a Value node" % path)
		return v
	match v["op"]:
		"const", "stat", "dice":
			pass
		"formula":
			var p: Dictionary = Formula.parse(v.get("expr", ""))
			if not p["ok"]:
				errors.append("%s: formula '%s': %s (pos %d)" % [path, v.get("expr", ""), p["error"], p["pos"]])
		"scaling":
			v["level"] = norm_value(v.get("level", 1), errors, path + ".level")
		_:
			errors.append("%s: unknown value op '%s'" % [path, str(v["op"])])
	return v

static func norm_predicate(p: Variant, errors: Array, path: String) -> Variant:
	p = _tag(p)
	if not (p is Dictionary) or not p.has("op"):
		errors.append("%s: not a Predicate node" % path)
		return p
	match p["op"]:
		"has_status", "element_affinity", "hp_below", "hp_above", "flag", "terrain":
			pass
		"and", "or":
			var preds: Array = p.get("preds", [])
			for i in preds.size():
				preds[i] = norm_predicate(preds[i], errors, "%s.preds[%d]" % [path, i])
		"not":
			p["pred"] = norm_predicate(p.get("pred", {}), errors, path + ".pred")
		_:
			errors.append("%s: unknown predicate op '%s'" % [path, str(p["op"])])
	return p

static func norm_target(t: Variant, errors: Array, path: String) -> Variant:
	t = _tag(t)
	if not (t is Dictionary) or not t.has("op"):
		errors.append("%s: not a Selector node" % path)
		return t
	if not (t["op"] in TARGET_OPS):
		errors.append("%s: unknown target op '%s'" % [path, str(t["op"])])
	return t

static func norm_trigger(t: Variant, errors: Array, path: String) -> Variant:
	t = _tag(t)
	if not (t is Dictionary) or not t.has("op"):
		errors.append("%s: not a Trigger node" % path)
		return t
	if not (t["op"] in TRIGGER_OPS):
		errors.append("%s: unknown trigger op '%s'" % [path, str(t["op"])])
	return t

static func norm_effect(e: Variant, errors: Array, path: String) -> Variant:
	e = _tag(e)
	if not (e is Dictionary) or not e.has("op"):
		errors.append("%s: not an Effect node" % path)
		return e
	if e["op"] == "conditional":  # RFC-000: conditional == branch without else
		e["op"] = "branch"
	match e["op"]:
		"damage":
			e["value"] = norm_value(e.get("value", 0), errors, path + ".value")
			if not e.has("type"):
				e["type"] = "physical"
		"heal":
			e["value"] = norm_value(e.get("value", 0), errors, path + ".value")
		"apply_status":
			if e.has("potency"):
				e["potency"] = norm_value(e["potency"], errors, path + ".potency")
		"modify_stat":
			e["value"] = norm_value(e.get("value", 0), errors, path + ".value")
			if not (e.get("mod") in ["add", "mul", "set"]):
				errors.append("%s: bad modify_stat mod '%s'" % [path, str(e.get("mod"))])
		"resource":
			e["delta"] = norm_value(e.get("delta", 0), errors, path + ".delta")
		"seq":
			var effs: Array = e.get("effects", [])
			for i in effs.size():
				effs[i] = norm_effect(effs[i], errors, "%s.effects[%d]" % [path, i])
		"choice":
			for i in e.get("options", []).size():
				e["options"][i]["effect"] = norm_effect(e["options"][i].get("effect", {}), errors, "%s.options[%d]" % [path, i])
		"repeat":
			e["n"] = norm_value(e.get("n", 1), errors, path + ".n")
			e["effect"] = norm_effect(e.get("effect", {}), errors, path + ".effect")
		"branch":
			e["if"] = norm_predicate(e.get("if", {}), errors, path + ".if")
			e["then"] = norm_effect(e.get("then", {}), errors, path + ".then")
			if e.has("else"):
				e["else"] = norm_effect(e["else"], errors, path + ".else")
		"combo":
			e["effect"] = norm_effect(e.get("effect", {}), errors, path + ".effect")
		"cure_status", "revive", "summon", "steal", "scan", "flee", "transform", "set_flag", "move", "knockback":
			pass
		_:
			errors.append("%s: unknown effect op '%s'" % [path, str(e["op"])])
	return e

static func norm_ability(ab: Dictionary, errors: Array, path: String) -> Dictionary:
	ab["trigger"] = norm_trigger(ab.get("trigger", "on_use"), errors, path + ".trigger")
	if ab.has("target"):
		ab["target"] = norm_target(ab["target"], errors, path + ".target")
	ab["effect"] = norm_effect(ab.get("effect", {}), errors, path + ".effect")
	return ab

# ------------------------------------------------------------------- values

func _fctx(src: Variant, tgt: Variant, vars: Dictionary = {}) -> Dictionary:
	var ctx := {"source": src, "target": tgt, "flags": flags, "vars": vars}
	if host != null:
		ctx["stat_cb"] = Callable(host, "stat_value")
	return ctx

func stat_of(ent: Dictionary, name: String) -> float:
	if host != null:
		return float(host.stat_value(ent, name))
	return Formula.resolve_entity_var(ent, name)

func eval_value(v: Dictionary, src: Variant, tgt: Variant) -> float:
	match v["op"]:
		"const":
			return float(v["n"])
		"stat":
			var who: Variant = tgt if v.get("of", "source") == "target" else src
			if who == null:
				return 0.0
			return stat_of(who, v["ref"])
		"dice":
			var d := _parse_dice(v["d"])
			var total: int = d["k"]
			for i in d["n"]:
				total += rng.randi_range(1, d["m"])
			return float(total)
		"formula":
			var p: Dictionary = Formula.parse(v["expr"])
			if not p["ok"]:
				push_error("formula failed at eval time: " + str(p["error"]))
				return 0.0
			return Formula.evaluate(p["ast"], _fctx(src, tgt))
		"scaling":
			var lvl := int(eval_value(v["level"], src, tgt))
			return eval_curve(v["curve"], lvl)
	push_error("bad value node: " + str(v))
	return 0.0

# Mean of a Value node (no rng): dice use their expectation; others evaluate.
func mean_value(v: Dictionary, src: Variant, tgt: Variant) -> float:
	if v["op"] == "dice":
		var d := _parse_dice(v["d"])
		return d["n"] * (d["m"] + 1) * 0.5 + d["k"]
	if v["op"] == "formula" or v["op"] == "scaling" or v["op"] == "const" or v["op"] == "stat":
		return eval_value(v, src, tgt)
	return 0.0

static func _parse_dice(spec: String) -> Dictionary:
	var k := 0
	var body := spec
	var plus := spec.find("+")
	var minus := spec.find("-")
	if plus > 0:
		k = int(spec.substr(plus + 1))
		body = spec.substr(0, plus)
	elif minus > 0:
		k = -int(spec.substr(minus + 1))
		body = spec.substr(0, minus)
	var parts := body.split("d")
	return {"n": int(parts[0]), "m": int(parts[1]) if parts.size() > 1 else 1, "k": k}

func eval_curve(curve_id: String, level: int) -> float:
	var c: Dictionary = db.curve(curve_id)
	if c.is_empty():
		push_error("unknown curve " + curve_id)
		return 0.0
	if c["kind"] == "table":
		var vals: Array = c["values"]
		return float(vals[clampi(level - 1, 0, vals.size() - 1)])
	var p: Dictionary = Formula.parse(c["expr"])
	return Formula.evaluate(p["ast"], {"source": {"level": level}}) if p["ok"] else 0.0

# --------------------------------------------------------------- predicates

func eval_predicate(p: Dictionary, src: Variant, tgt: Variant) -> bool:
	match p["op"]:
		"and":
			for q in p["preds"]:
				if not eval_predicate(q, src, tgt):
					return false
			return true
		"or":
			for q in p["preds"]:
				if eval_predicate(q, src, tgt):
					return true
			return false
		"not":
			return not eval_predicate(p["pred"], src, tgt)
		"flag":
			return p["id"] in flags
		"terrain":
			return false  # SRPG-only; menu_rows battles have no terrain
	var who: Variant = tgt if p.get("who") == "target" else src
	if who == null:
		return false
	match p["op"]:
		"has_status":
			for s in who.get("statuses", []):
				if s["id"] == p["status"]:
					return true
			return false
		"element_affinity":
			for a in who.get("affinities", []):
				if a["element"] == p["element"] and a["relation"] == p["relation"]:
					return true
			return false
		"hp_below":
			return _hp_pct(who) < float(p["pct"])
		"hp_above":
			return _hp_pct(who) > float(p["pct"])
	push_error("bad predicate: " + str(p))
	return false

static func _hp_pct(ent: Dictionary) -> float:
	var hp: Dictionary = ent["resources"]["hp"]
	return float(hp["cur"]) / maxf(1.0, float(hp["max"]))

# ------------------------------------------------------------------ effects

func element_multiplier(ent: Dictionary, element: Variant) -> float:
	if element == null:
		return 1.0
	for a in ent.get("affinities", []):
		if a["element"] == element:
			return float(db.multiplier(a["relation"]))
	return 1.0

func _emit(op: String, src: Dictionary, tgt: Variant, ability: String, rolled: Variant, result: Variant) -> void:
	var ev := {"turn": turn_no, "source": src.get("key", src.get("id", "?")),
			"ability": ability, "effect_op": op,
			"target": tgt.get("key", tgt.get("id", "?")) if tgt is Dictionary else "",
			"rolled": rolled, "result": result}
	if log_cb.is_valid():
		log_cb.call(ev)
	else:
		var h := host
		if h != null and h.has_method("on_battle_event"):
			h.on_battle_event(ev)

func apply_effect(e: Dictionary, src: Dictionary, tgt: Dictionary, ability: String) -> void:
	match e["op"]:
		"seq":
			for sub in e["effects"]:
				apply_effect(sub, src, tgt, ability)
		"choice":
			var weights: Array = []
			for o in e["options"]:
				weights.append(o["weight"])
			var i: int = rng.weighted_index(weights)
			if i >= 0:
				apply_effect(e["options"][i]["effect"], src, tgt, ability)
		"repeat":
			for i in int(eval_value(e["n"], src, tgt)):
				apply_effect(e["effect"], src, tgt, ability)
		"branch":
			if eval_predicate(e["if"], src, tgt):
				apply_effect(e["then"], src, tgt, ability)
			elif e.has("else"):
				apply_effect(e["else"], src, tgt, ability)
		"combo":
			apply_effect(e["effect"], src, tgt, ability)  # participant gating is battle's job
		"damage":
			_apply_damage(e, src, tgt, ability)
		"heal":
			if tgt.get("alive", true):
				var amt := maxi(0, roundi(eval_value(e["value"], src, tgt)))
				var hp: Dictionary = tgt["resources"]["hp"]
				var healed: int = mini(amt, int(hp["max"]) - int(hp["cur"]))
				hp["cur"] = int(hp["cur"]) + healed
				_emit("heal", src, tgt, ability, amt, healed)
		"apply_status":
			_apply_status(e, src, tgt, ability)
		"cure_status":
			var before: int = tgt.get("statuses", []).size()
			tgt["statuses"] = tgt.get("statuses", []).filter(func(s: Dictionary) -> bool: return not (s["id"] in e["statuses"]))
			_emit("cure_status", src, tgt, ability, null, before - tgt["statuses"].size())
		"modify_stat":
			var val := eval_value(e["value"], src, tgt)
			tgt.get_or_add("mods", []).append({"stat": e["stat"], "mod": e["mod"],
					"value": val, "duration": e.get("duration")})
			_emit("modify_stat", src, tgt, ability, null, val)
		"resource":
			if tgt.get("alive", true):
				var pool: Dictionary = tgt["resources"][e["pool"]]
				var delta := roundi(eval_value(e["delta"], src, tgt))
				var next: int = clampi(int(pool["cur"]) + delta, 0, int(pool["max"]))
				var applied: int = next - int(pool["cur"])
				pool["cur"] = next
				_emit("resource", src, tgt, ability, delta, applied)
				if e["pool"] == "hp" and next == 0:
					_kill(tgt)
		"revive":
			if not tgt.get("alive", true):
				var hp2: Dictionary = tgt["resources"]["hp"]
				hp2["cur"] = maxi(1, roundi(float(hp2["max"]) * float(e["pct"])))
				tgt["alive"] = true
				_emit("revive", src, tgt, ability, null, hp2["cur"])
			else:
				_emit("revive", src, tgt, ability, null, 0)
		"set_flag":
			if not (e["id"] in flags):
				flags.append(e["id"])
			_emit("set_flag", src, tgt, ability, null, e["id"])
		"flee":
			if host != null and host.has_method("on_flee"):
				host.on_flee(src)
			_emit("flee", src, tgt, ability, null, 1)
		"scan":
			_emit("scan", src, tgt, ability, null, tgt.get("id", ""))
		_:
			# steal/summon/transform/move/knockback: valid algebra ops unused by
			# this game; recognized at load, inert at runtime.
			_emit(e["op"], src, tgt, ability, null, 0)

func _apply_damage(e: Dictionary, src: Dictionary, tgt: Dictionary, ability: String) -> void:
	if not tgt.get("alive", true):
		return
	var raw := eval_value(e["value"], src, tgt)
	if e.has("variance"):
		var v: float = e["variance"]
		raw *= rng.randf_range(1.0 - v, 1.0 + v)
	var crit := false
	if e.has("crit"):
		crit = rng.randf() < float(e["crit"]["rate"])
		if crit:
			raw *= float(e["crit"]["mult"])
	var dealt: int
	if e["type"] == "fixed":
		dealt = maxi(0, roundi(raw))
	else:
		var ast: Dictionary = db.damage_formula_ast(e["type"])
		var mitigated := Formula.evaluate(ast, _fctx(src, tgt, {"value": raw}))
		var pierce: float = e.get("pierce", 0.0)
		var x: float = pierce * raw + (1.0 - pierce) * mitigated
		x *= element_multiplier(tgt, e.get("element"))
		if host != null and host.has_method("damage_scale"):
			x *= float(host.damage_scale(src, tgt, e["type"]))
		dealt = roundi(x)
	var hp: Dictionary = tgt["resources"]["hp"]
	if dealt >= 0:
		hp["cur"] = maxi(0, int(hp["cur"]) - dealt)
	else:  # absorb: negative damage heals, clamped to max
		hp["cur"] = mini(int(hp["max"]), int(hp["cur"]) - dealt)
	_emit("damage", src, tgt, ability, {"raw": roundi(raw), "crit": crit}, dealt)
	if int(hp["cur"]) == 0:
		_kill(tgt)

func _apply_status(e: Dictionary, src: Dictionary, tgt: Dictionary, ability: String) -> void:
	if not tgt.get("alive", true):
		return
	var chance: float = e.get("chance", 1.0)
	var roll: Variant = null
	if chance < 1.0:
		roll = rng.randf()
		if roll >= chance:
			_emit("apply_status", src, tgt, ability, roll, 0)
			return
	if e["status"] in tgt.get("status_immunity", []):
		_emit("apply_status", src, tgt, ability, roll, 0)
		return
	var sdef: Dictionary = db.status_def(e["status"])
	var potency: Variant = null
	if e.has("potency"):
		potency = eval_value(e["potency"], src, tgt)
	var inst: Variant = null
	for s in tgt.get_or_add("statuses", []):
		if s["id"] == e["status"]:
			inst = s
	if inst != null:
		match sdef.get("stacking", "refresh"):
			"refresh":  # statuses.json: re-application resets the clock
				inst["duration"] = e.get("duration")
				inst["potency"] = potency
			"stack":
				var count := 0
				for s in tgt["statuses"]:
					if s["id"] == e["status"]:
						count += 1
				if count < int(sdef.get("max_stacks", 99)):
					tgt["statuses"].append({"id": e["status"], "duration": e.get("duration"), "potency": potency})
			"ignore":
				pass
	else:
		tgt["statuses"].append({"id": e["status"], "duration": e.get("duration"), "potency": potency})
	_emit("apply_status", src, tgt, ability, roll, 1)

func _kill(ent: Dictionary) -> void:
	if ent.get("alive", true):
		ent["alive"] = false
		ent["statuses"] = []
		ent["mods"] = []
		if host != null and host.has_method("on_death"):
			host.on_death(ent)

# ----------------------------------------------------------- status upkeep

# Run tick effects whose trigger matches. Source AND target are the afflicted
# entity; apply_status potency is exposed as source.potency (ctx overlay).
func run_status_ticks(ent: Dictionary, trigger_op: String) -> void:
	if not ent.get("alive", true):
		return
	for inst in ent.get("statuses", []).duplicate():
		var sdef: Dictionary = db.status_def(inst["id"])
		var tick: Dictionary = sdef.get("tick", {})
		if tick.is_empty() or tick["trigger"]["op"] != trigger_op:
			continue
		var overlay: Dictionary = ent.get_or_add("ctx", {})
		overlay["potency"] = inst["potency"] if inst.get("potency") != null else 0.0
		apply_effect(tick["effect"], ent, ent, inst["id"])
		overlay.erase("potency")

# Decrement finite durations at the afflicted entity's turn end; remove at 0.
# duration null = until cured. Same rule for modify_stat battle mods.
func expire_statuses(ent: Dictionary) -> void:
	ent["statuses"] = _tick_down(ent.get("statuses", []))

func expire_mods(ent: Dictionary) -> void:
	ent["mods"] = _tick_down(ent.get("mods", []))

static func _tick_down(items: Array) -> Array:
	var keep: Array = []
	for it in items:
		if it.get("duration") == null:
			keep.append(it)
			continue
		it["duration"] = int(it["duration"]) - 1
		if int(it["duration"]) > 0:
			keep.append(it)
	return keep

# ---------------------------------------------------- expectation (policy)
# Mean damage of an effect tree vs a target: mean(value) x element multiplier
# (contract §5 heuristic_v1 — no mitigation, variance mean 1). fixed: x1.

func expected_damage_of(e: Dictionary, src: Dictionary, tgt: Dictionary) -> float:
	match e["op"]:
		"damage":
			var mult := 1.0 if e["type"] == "fixed" else element_multiplier(tgt, e.get("element"))
			return mean_value(e["value"], src, tgt) * mult
		"seq":
			var sum := 0.0
			for sub in e["effects"]:
				sum += expected_damage_of(sub, src, tgt)
			return sum
		"repeat":
			return mean_value(e["n"], src, tgt) * expected_damage_of(e["effect"], src, tgt)
		"choice":
			var tot := 0.0
			var acc := 0.0
			for o in e["options"]:
				tot += float(o["weight"])
				acc += float(o["weight"]) * expected_damage_of(o["effect"], src, tgt)
			return acc / tot if tot > 0.0 else 0.0
		"branch":
			return expected_damage_of(e["then"], src, tgt)
		"combo":
			return expected_damage_of(e["effect"], src, tgt)
	return 0.0

func expected_heal_of(e: Dictionary, src: Dictionary, tgt: Dictionary) -> float:
	match e["op"]:
		"heal":
			return mean_value(e["value"], src, tgt)
		"seq":
			var sum := 0.0
			for sub in e["effects"]:
				sum += expected_heal_of(sub, src, tgt)
			return sum
		"repeat":
			return mean_value(e["n"], src, tgt) * expected_heal_of(e["effect"], src, tgt)
		"branch":
			return expected_heal_of(e["then"], src, tgt)
	return 0.0

# True if the effect tree contains the given atomic op (heuristic eligibility).
static func tree_has_op(e: Dictionary, op: String) -> bool:
	if e["op"] == op:
		return true
	for key in ["then", "else", "effect"]:
		if e.has(key) and e[key] is Dictionary and tree_has_op(e[key], op):
			return true
	for sub in e.get("effects", []):
		if tree_has_op(sub, op):
			return true
	for o in e.get("options", []):
		if tree_has_op(o["effect"], op):
			return true
	return false
