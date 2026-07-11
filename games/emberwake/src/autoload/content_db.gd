# ContentDB — content loading/validation/normalization (engine contract §1).
# Loads every collection under res://content (a symlink to the game's content
# dir), normalizes effect-algebra shorthand on load (CONVENTIONS.md), caches
# formula ASTs (Formula's parse cache), and cross-validates every reference.
# Unknown ops / broken refs are LOAD-TIME hard errors: load_all() returns
# false and load_errors lists each problem. Engine code contains no
# game-content ids; the turn-order stat binding lives in project.godot
# (m8/battle/speed_stat) and is validated here against the stat model.
extends Node

const Formula := preload("res://engine/formula.gd")
const Algebra := preload("res://engine/algebra.gd")

const COST_KEYS := ["item", "charge", "cooldown", "row_lock", "range", "class_lock", "once_per_battle"]

var stat_model: Dictionary = {}
var elements: Dictionary = {}
var mults: Dictionary = {}
var statuses: Dictionary = {}
var items: Dictionary = {}
var equipment: Dictionary = {}
var spells: Dictionary = {}
var classes: Dictionary = {}
var monsters: Dictionary = {}
var encounters: Dictionary = {}
var world_data: Dictionary = {}
var story_data: Dictionary = {}
var dialogues: Dictionary = {}
var maps: Dictionary = {}
var curves: Dictionary = {}
var load_errors: Array = []
var loaded := false

var _dmg_ast: Dictionary = {}
var _ref_names: Array = []

func _ready() -> void:
	if not load_all():
		for e in load_errors:
			push_error("ContentDB: " + str(e))

# ------------------------------------------------------------------ access

func stat_ids() -> Array:
	return stat_model.get("stats", []).map(func(s: Dictionary) -> String: return s["id"])

func resource_ids() -> Array:
	return stat_model.get("resources", []).map(func(r: Dictionary) -> String: return r["id"])

func stat_range(stat_id: String) -> Array:
	for s in stat_model.get("stats", []):
		if s["id"] == stat_id:
			return s.get("range", [])
	return []

func resource_def(res_id: String) -> Dictionary:
	for r in stat_model.get("resources", []):
		if r["id"] == res_id:
			return r
	return {}

func speed_stat() -> String:
	return str(ProjectSettings.get_setting("m8/battle/speed_stat", ""))

func multiplier(relation: String) -> float:
	return float(mults.get(relation, 1.0))

func curve(id: String) -> Dictionary:
	return curves.get(id, {})

func xp_curve_id() -> String:
	return stat_model.get("xp_curve", "")

func damage_formula_ast(kind: String) -> Dictionary:
	return _dmg_ast.get(kind, {})

func status_def(id: String) -> Dictionary:
	return statuses.get(id, {})

func item(id: String) -> Dictionary:
	return items.get(id, {})

func equip(id: String) -> Dictionary:
	return equipment.get(id, {})

func spell(id: String) -> Dictionary:  # full entry; ability under "ability"
	return spells.get(id, {})

func cls(id: String) -> Dictionary:
	return classes.get(id, {})

func monster(id: String) -> Dictionary:
	return monsters.get(id, {})

func encounter(id: String) -> Dictionary:
	return encounters.get(id, {})

func map_def(id: String) -> Dictionary:
	return maps.get(id, {})

func dialogue(id: String) -> Dictionary:
	return dialogues.get(id, {})

func world() -> Dictionary:
	return world_data

func story() -> Dictionary:
	return story_data

func shop(id: String) -> Dictionary:
	for s in world_data.get("shops", []):
		if s["id"] == id:
			return s
	return {}

func treasure_table(id: String) -> Dictionary:
	for t in world_data.get("treasure_tables", []):
		if t["id"] == id:
			return t
	return {}

func spells_for_class(class_id: String, level: int) -> Array:
	var out: Array = []
	for sid in spells:
		for l in spells[sid].get("learn", []):
			if l["class"] == class_id and int(l["at_level"]) <= level:
				out.append(sid)
	out.sort()
	return out

# ----------------------------------------------------------------- loading

func load_all(root := "res://content") -> bool:
	load_errors = []
	loaded = false
	stat_model = _read(root + "/stat-model.json")
	var elems: Dictionary = _read(root + "/elements.json")
	for e in elems.get("elements", []):
		elements[e["id"]] = e
	mults = elems.get("multipliers", {})
	for c in stat_model.get("growth_curves", []):
		curves[c["id"]] = c
	_ref_names = ["level"]
	for sid in stat_ids():
		_ref_names.append(sid)
	for rid in resource_ids():
		_ref_names.append(rid)
		_ref_names.append("max_" + str(rid))
		_ref_names.append(str(rid) + "_pct")
	_load_stat_model_formulas()
	for s in _read(root + "/statuses.json").get("entries", []):
		statuses[s["id"]] = _norm_status(s)
	for c in _read(root + "/classes.json").get("entries", []):
		classes[c["id"]] = c
	for e in _read(root + "/equipment.json").get("entries", []):
		if e.has("attack"):
			e["attack"]["value"] = Algebra.norm_value(e["attack"]["value"], load_errors, e["id"] + ".attack.value")
		for m in e.get("stat_mods", []):
			m["value"] = Algebra.norm_value(m["value"], load_errors, e["id"] + ".stat_mods")
		equipment[e["id"]] = e
	for it in _read(root + "/items.json").get("entries", []):
		if it.has("use"):
			it["use"] = Algebra.norm_ability(it["use"], load_errors, it["id"] + ".use")
		items[it["id"]] = it
	for sp in _read(root + "/spells.json").get("entries", []):
		sp["ability"] = Algebra.norm_ability(sp["ability"], load_errors, sp["ability"].get("id", "?"))
		spells[sp["ability"]["id"]] = sp
	for m in _read(root + "/monsters.json").get("entries", []):
		monsters[m["id"]] = _norm_monster(m)
	for enc in _read(root + "/encounters.json").get("entries", []):
		encounters[enc["id"]] = enc
	world_data = _read(root + "/world.json")
	story_data = _read(root + "/story.json")
	for d in _read(root + "/dialogue.json").get("entries", []):
		dialogues[d["id"]] = d
	var mdir := DirAccess.open(root + "/maps")
	if mdir == null:
		load_errors.append("maps dir missing under " + root)
	else:
		for f in mdir.get_files():
			if f.ends_with(".json"):
				var mp: Dictionary = _read(root + "/maps/" + f)
				if mp.has("id"):
					maps[mp["id"]] = mp
	_validate()
	loaded = load_errors.is_empty()
	return loaded

func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_errors.append("cannot open " + path)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		load_errors.append("bad JSON in " + path)
		return {}
	return data

func _load_stat_model_formulas() -> void:
	for kind in stat_model.get("damage_formulas", {}):
		var expr: String = stat_model["damage_formulas"][kind]
		var p: Dictionary = Formula.parse(expr, ["value"])  # RFC-002: 'value' only here
		if not p["ok"]:
			load_errors.append("damage_formulas.%s: %s" % [kind, p["error"]])
		else:
			_dmg_ast[kind] = p["ast"]
			_check_formula_refs(expr, [], "damage_formulas." + kind, ["value"])
	for r in stat_model.get("resources", []):
		_check_formula_refs(r.get("max_formula", "0"), [], "resources." + r["id"])
	for cid in curves:
		var c: Dictionary = curves[cid]
		if c.get("kind") == "formula":
			_check_formula_refs(c["expr"], [], cid)

func _norm_status(s: Dictionary) -> Dictionary:
	if s.has("tick"):
		s["tick"]["trigger"] = Algebra.norm_trigger(s["tick"]["trigger"], load_errors, s["id"] + ".tick.trigger")
		s["tick"]["effect"] = Algebra.norm_effect(s["tick"]["effect"], load_errors, s["id"] + ".tick.effect")
	for m in s.get("stat_mods", []):
		m["value"] = Algebra.norm_value(m["value"], load_errors, s["id"] + ".stat_mods")
	return s

func _norm_monster(m: Dictionary) -> Dictionary:
	var index := {}
	for ab in m.get("abilities", []):
		index[ab["id"]] = Algebra.norm_ability(ab, load_errors, m["id"] + "." + ab.get("id", "?"))
	m["_ability_index"] = index
	for rule in m.get("ai", {}).get("rules", []):
		if rule.has("when"):
			rule["when"] = Algebra.norm_predicate(rule["when"], load_errors, m["id"] + ".ai.when")
	return m

# -------------------------------------------------------------- validation

func _err(cond: bool, msg: String) -> void:
	if not cond:
		load_errors.append(msg)

func _validate() -> void:
	_err(speed_stat() in stat_ids(), "m8/battle/speed_stat '%s' not in stat model" % speed_stat())
	_err(curves.has(xp_curve_id()), "xp_curve '%s' missing" % xp_curve_id())
	for id in statuses:
		var s: Dictionary = statuses[id]
		for m in s.get("stat_mods", []):
			_err(m["stat"] in stat_ids(), "%s.stat_mods: unknown stat %s" % [id, m["stat"]])
		if s.has("tick"):
			_walk_effect(s["tick"]["effect"], id + ".tick", ["potency"])
	for id in classes:
		var c: Dictionary = classes[id]
		for k in c.get("growth", {}):
			_err(k in stat_ids() or k in resource_ids(), "%s.growth: unknown stat/resource %s" % [id, k])
			_err(curves.has(c["growth"][k]), "%s.growth.%s: unknown curve %s" % [id, k, c["growth"][k]])
	for id in equipment:
		var e: Dictionary = equipment[id]
		for cl in e.get("class_lock", []):
			_err(classes.has(cl), "%s.class_lock: unknown class %s" % [id, cl])
		for m in e.get("stat_mods", []):
			_err(m["stat"] in stat_ids(), "%s.stat_mods: unknown stat %s" % [id, m["stat"]])
		if e.has("attack"):
			_walk_value(e["attack"]["value"], id + ".attack", [])
			_err(not e["attack"].has("element") or elements.has(e["attack"]["element"]), "%s.attack: unknown element" % id)
	for id in items:
		if items[id].has("use"):
			_walk_ability(items[id]["use"], id + ".use")
	for id in spells:
		_walk_ability(spells[id]["ability"], id)
		for l in spells[id].get("learn", []):
			_err(classes.has(l["class"]), "%s.learn: unknown class %s" % [id, l["class"]])
	for id in monsters:
		var m: Dictionary = monsters[id]
		for sid in stat_ids():
			_err(m.get("stats", {}).has(sid), "%s.stats: missing stat %s" % [id, sid])
		for k in m.get("stats", {}):
			_err(k in stat_ids() or k in resource_ids(), "%s.stats: unknown key %s" % [id, k])
		for a in m.get("affinities", []):
			_err(elements.has(a["element"]), "%s.affinities: unknown element %s" % [id, a["element"]])
		for st in m.get("status_immunity", []):
			_err(statuses.has(st), "%s.status_immunity: unknown status %s" % [id, st])
		for d in m.get("drops", []):
			_err(items.has(d["item"]), "%s.drops: unknown item %s" % [id, d["item"]])
		for ab in m.get("abilities", []):
			_walk_ability(ab, id + "." + ab["id"])
		for rule in m.get("ai", {}).get("rules", []):
			_err(m["_ability_index"].has(rule["ability"]), "%s.ai: unknown ability %s" % [id, rule["ability"]])
			if rule.has("when"):
				_walk_predicate(rule["when"], id + ".ai.when")
	for id in encounters:
		for g in encounters[id].get("groups", []):
			for mid in g["monsters"]:
				_err(monsters.has(mid), "%s: unknown monster %s" % [id, mid])
	_validate_world_story_maps()

func _validate_world_story_maps() -> void:
	var start: Dictionary = world_data.get("start", {})
	_err(maps.has(start.get("map", "")), "world.start: unknown map %s" % start.get("map", ""))
	if maps.has(start.get("map", "")):
		_err(_map_entity(start["map"], start.get("spawn", "")) != null, "world.start: spawn %s missing" % start.get("spawn", ""))
	for region in world_data.get("regions", []):
		for place in region.get("places", []):
			for mid in place.get("maps", []):
				_err(maps.has(mid), "%s: unknown map %s" % [place["id"], mid])
	for s in world_data.get("shops", []):
		for gid in s.get("stock", []):
			_err(items.has(gid) or equipment.has(gid), "%s.stock: unknown goods %s" % [s["id"], gid])
	for t in world_data.get("treasure_tables", []):
		for roll in t.get("rolls", []):
			_err(items.has(roll["item"]), "%s: unknown item %s" % [t["id"], roll["item"]])
	var node_ids: Array = story_data.get("nodes", []).map(func(n: Dictionary) -> String: return n["id"])
	for n in story_data.get("nodes", []):
		if n.has("dialogue"):
			_err(dialogues.has(n["dialogue"]), "%s: unknown dialogue %s" % [n["id"], n["dialogue"]])
		if n.has("next"):
			_err(n["next"] in node_ids, "%s: unknown next node %s" % [n["id"], n["next"]])
		for mid in n.get("monsters", []):
			_err(monsters.has(mid), "%s: unknown monster %s" % [n["id"], mid])
		for iid in n.get("requires_items", []):
			_err(items.has(iid), "%s: unknown item %s" % [n["id"], iid])
	for mid in maps:
		var mp: Dictionary = maps[mid]
		var legend: Dictionary = mp.get("legend", {})
		for row in mp.get("tiles", []):
			for ch in row:
				_err(legend.has(ch), "%s: tile '%s' not in legend" % [mid, ch])
		for ch in legend:
			if legend[ch].has("encounter_table"):
				_err(encounters.has(legend[ch]["encounter_table"]), "%s: unknown encounter table" % mid)
		for ent in mp.get("entities", []):
			match ent.get("kind", ""):
				"portal":
					_err(maps.has(ent.get("to_map", "")), "%s.%s: unknown map" % [mid, ent["id"]])
					if maps.has(ent.get("to_map", "")):
						_err(_map_entity(ent["to_map"], ent.get("to_spawn", "")) != null, "%s.%s: unknown spawn" % [mid, ent["id"]])
				"npc":
					if ent.has("dialogue"):
						_err(dialogues.has(ent["dialogue"]), "%s.%s: unknown dialogue" % [mid, ent["id"]])
				"chest":
					_err(not treasure_table(ent.get("treasure", "")).is_empty(), "%s.%s: unknown treasure table" % [mid, ent["id"]])
			if ent.has("story_node"):
				_err(ent["story_node"] in node_ids, "%s.%s: unknown story node" % [mid, ent["id"]])

func _map_entity(map_id: String, ent_id: String) -> Variant:
	for e in maps.get(map_id, {}).get("entities", []):
		if e["id"] == ent_id:
			return e
	return null

# ------------------------------------------------- effect-tree ref walking

func _walk_ability(ab: Dictionary, path: String) -> void:
	if ab.has("target"):
		var t: Dictionary = ab["target"]
		if t.get("op") == "lowest":
			_err(t.get("stat") in stat_ids(), "%s.target: unknown stat" % path)
	_walk_effect(ab.get("effect", {}), path, [])
	var costs: Dictionary = ab.get("costs", {})
	for k in costs:
		_err(k in COST_KEYS or k in resource_ids(), "%s.costs: unknown cost key %s" % [path, k])
	if costs.has("item"):
		_err(items.has(costs["item"]), "%s.costs: unknown item" % path)
	for cl in costs.get("class_lock", []):
		_err(classes.has(cl), "%s.costs: unknown class %s" % [path, cl])

func _walk_effect(e: Dictionary, path: String, extra: Array) -> void:
	match e.get("op", ""):
		"damage":
			_err(not e.has("element") or elements.has(e["element"]), "%s: unknown element %s" % [path, e.get("element")])
			_walk_value(e["value"], path, extra)
		"heal":
			_walk_value(e["value"], path, extra)
		"apply_status":
			_err(statuses.has(e["status"]), "%s: unknown status %s" % [path, e.get("status")])
			if e.has("potency"):
				_walk_value(e["potency"], path, extra)
		"cure_status":
			for st in e["statuses"]:
				_err(statuses.has(st), "%s: unknown status %s" % [path, st])
		"modify_stat":
			_err(e["stat"] in stat_ids(), "%s: unknown stat %s" % [path, e.get("stat")])
			_walk_value(e["value"], path, extra)
		"resource":
			_err(e["pool"] in resource_ids(), "%s: unknown pool %s" % [path, e.get("pool")])
			_walk_value(e["delta"], path, extra)
		"seq":
			for sub in e["effects"]:
				_walk_effect(sub, path, extra)
		"choice":
			for o in e["options"]:
				_walk_effect(o["effect"], path, extra)
		"repeat":
			_walk_value(e["n"], path, extra)
			_walk_effect(e["effect"], path, extra)
		"branch":
			_walk_predicate(e["if"], path)
			_walk_effect(e["then"], path, extra)
			if e.has("else"):
				_walk_effect(e["else"], path, extra)
		"combo":
			_walk_effect(e["effect"], path, extra)

func _walk_predicate(p: Dictionary, path: String) -> void:
	match p.get("op", ""):
		"has_status":
			_err(statuses.has(p["status"]), "%s: unknown status %s" % [path, p.get("status")])
		"element_affinity":
			_err(elements.has(p["element"]), "%s: unknown element %s" % [path, p.get("element")])
		"and", "or":
			for q in p["preds"]:
				_walk_predicate(q, path)
		"not":
			_walk_predicate(p["pred"], path)

func _walk_value(v: Dictionary, path: String, extra: Array) -> void:
	match v.get("op", ""):
		"stat":
			_err(v["ref"] in _ref_names, "%s: unknown stat ref %s" % [path, v.get("ref")])
		"formula":
			_check_formula_refs(v["expr"], extra, path)
		"scaling":
			_err(curves.has(v["curve"]), "%s: unknown curve %s" % [path, v.get("curve")])
			_walk_value(v["level"], path, extra)

# Validate source./target. ref names in a formula against the stat model
# (+ context extras like 'potency' inside status ticks). game.* is the open
# flag namespace.
func _check_formula_refs(expr: String, extra: Array, path: String, ctx_vars: Array = []) -> void:
	var p: Dictionary = Formula.parse(expr, ctx_vars)
	if not p["ok"]:
		load_errors.append("%s: formula '%s': %s" % [path, expr, p["error"]])
		return
	_walk_ast_refs(p["ast"], extra, path)

func _walk_ast_refs(ast: Dictionary, extra: Array, path: String) -> void:
	if ast["k"] == "ref" and ast["scope"] != "game":
		_err(ast["name"] in _ref_names or ast["name"] in extra, "%s: unknown formula ref %s.%s" % [path, ast["scope"], ast["name"]])
	for key in ["l", "r", "e"]:
		if ast.has(key):
			_walk_ast_refs(ast[key], extra, path)
	for a in ast.get("args", []):
		_walk_ast_refs(a, extra, path)
