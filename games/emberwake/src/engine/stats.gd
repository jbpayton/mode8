# engine/stats.gd — effective-stat resolution (engine contract §1, work order
# 03a step 4; RFC-001 resource maxima).
# Base stats: a class stat bound in `growth` reads its curve at level (class
# base_stats anchor curve(1)); unbound stats fall back to base_stats. Monsters
# use their flat stats block.
# Effective stat pipeline, in this order (each stage applies add, then mul,
# then set — last set wins), clamped to the stat-model range at the end:
#   1. base (class curve @ level / monster stats)
#   2. equipment stat_mods
#   3. status stat_mods, then modify_stat battle mods
# Resource maxima (RFC-001): explicit resource id in a monster's stats ->
# class growth binding the resource to a curve -> stat-model max_formula.
# max_formula evaluates against PERSISTENT stats (base + equipment only), so
# battle-scoped debuffs never move a max.
extends RefCounted

const Formula := preload("res://engine/formula.gd")

var db: Object

func _init(p_db: Object) -> void:
	db = p_db

func class_base_stats(class_id: String, level: int) -> Dictionary:
	var cdef: Dictionary = db.cls(class_id)
	var growth: Dictionary = cdef.get("growth", {})
	var out: Dictionary = {}
	for sid in db.stat_ids():
		if growth.has(sid):
			out[sid] = curve_value(growth[sid], level)
		else:
			out[sid] = float(cdef.get("base_stats", {}).get(sid, 0))
	return out

func curve_value(curve_id: String, level: int) -> float:
	var c: Dictionary = db.curve(curve_id)
	if c.is_empty():
		push_error("stats: unknown curve " + curve_id)
		return 0.0
	if c.get("kind") == "table":
		var vals: Array = c["values"]
		return float(vals[clampi(level - 1, 0, vals.size() - 1)])
	var p: Dictionary = Formula.parse(c["expr"])
	return Formula.evaluate(p["ast"], {"source": {"level": level}}) if p["ok"] else 0.0

func effective_stat(ent: Dictionary, stat_id: String, persistent_only := false) -> float:
	var v: float = float(ent.get("stats", {}).get(stat_id, 0))
	var equip_mods: Array = []
	for eq_id in ent.get("equipment", {}).values():
		if eq_id == null or eq_id == "":
			continue
		for m in db.equip(eq_id).get("stat_mods", []):
			if m["stat"] == stat_id:
				equip_mods.append(m)
	v = _apply_mods(v, equip_mods, ent)
	if not persistent_only:
		var battle_mods: Array = []
		for inst in ent.get("statuses", []):
			for m in db.status_def(inst["id"]).get("stat_mods", []):
				if m["stat"] == stat_id:
					battle_mods.append(m)
		for m in ent.get("mods", []):
			if m["stat"] == stat_id:
				battle_mods.append(m)
		v = _apply_mods(v, battle_mods, ent)
	var r: Array = db.stat_range(stat_id)
	if r.size() == 2:
		v = clampf(v, float(r[0]), float(r[1]))
	return v

func _apply_mods(base: float, mods: Array, ent: Dictionary) -> float:
	var v := base
	for m in mods:
		if m["mod"] == "add":
			v += _mod_value(m, ent)
	for m in mods:
		if m["mod"] == "mul":
			v *= _mod_value(m, ent)
	for m in mods:
		if m["mod"] == "set":
			v = _mod_value(m, ent)
	return v

# Status stat_mod values are normalized Value nodes; battle mods store plain
# floats (evaluated at cast time). Formula values here read BASE stats to
# keep resolution non-recursive.
func _mod_value(m: Dictionary, ent: Dictionary) -> float:
	var val: Variant = m["value"]
	if val is Dictionary:
		if val["op"] == "const":
			return float(val["n"])
		if val["op"] == "formula":
			var p: Dictionary = Formula.parse(val["expr"])
			if p["ok"]:
				return Formula.evaluate(p["ast"], {"source": {"stats": ent.get("stats", {}), "level": ent.get("level", 1)}})
		push_warning("stats: unsupported stat_mod value node " + str(val))
		return 0.0
	return float(val)

# Persistent-stat resolver for max_formula evaluation (no battle-scoped mods).
func persistent_var(ent: Dictionary, name: String) -> float:
	if name == "level":
		return float(ent.get("level", 1))
	if name in db.stat_ids():
		return effective_stat(ent, name, true)
	return Formula.resolve_entity_var(ent, name)

func max_resource(ent: Dictionary, res_id: String) -> int:
	var overrides: Dictionary = ent.get("resource_overrides", {})
	if overrides.has(res_id):
		return int(overrides[res_id])
	var cid: String = ent.get("class", "")
	if cid != "":
		var growth: Dictionary = db.cls(cid).get("growth", {})
		if growth.has(res_id):
			return roundi(curve_value(growth[res_id], int(ent.get("level", 1))))
	var rdef: Dictionary = db.resource_def(res_id)
	var p: Dictionary = Formula.parse(rdef.get("max_formula", "0"))
	if not p["ok"]:
		return 0
	return roundi(Formula.evaluate(p["ast"], {"source": ent, "stat_cb": persistent_var}))

# Total XP required to have reached `level` (xp_curve is cumulative).
func xp_to_reach(level: int) -> int:
	return roundi(curve_value(db.xp_curve_id(), level))

# Pseudo-entity over a persistent party-member dict (Game.party shape), for
# stat/max queries outside battle.
func member_view(member: Dictionary) -> Dictionary:
	var lvl: int = int(member.get("level", 1))
	var view := {"kind": "party", "class": member.get("class", ""), "level": lvl,
			"stats": class_base_stats(member.get("class", ""), lvl),
			"equipment": member.get("equipment", {}), "statuses": [], "mods": [],
			"resources": {}}
	for rid in db.resource_ids():
		var mx := max_resource(view, rid)
		view["resources"][rid] = {"cur": clampi(int(member.get(rid, mx)), 0, mx), "max": mx}
	return view
