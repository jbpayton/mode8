# test_content.gd — contract §7: real game content loads; every cross-ref
# resolves; an unknown-op fixture is rejected at load time. Content ids are
# never hardcoded here — everything is derived from the loaded data.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const DbScript := preload("res://autoload/content_db.gd")
const StatsScript := preload("res://engine/stats.gd")

var _nodes: Array = []

func cleanup() -> void:
	for n in _nodes:
		n.free()

func _db() -> Node:
	var db: Node = DbScript.new()
	_nodes.append(db)
	return db

func _loaded_db() -> Node:
	var db := _db()
	db.load_all()
	return db

func test_real_content_loads() -> void:
	var db := _db()
	var ok: bool = db.load_all()
	T.eq(db.load_errors, [], "no load errors — every cross-ref resolves")
	T.ok(ok, "load_all reports success")
	T.ok(db.classes.size() > 0, "classes loaded")
	T.ok(db.monsters.size() > 0, "monsters loaded")
	T.ok(db.spells.size() > 0, "spells loaded")
	T.ok(db.items.size() > 0, "items loaded")
	T.ok(db.equipment.size() > 0, "equipment loaded")
	T.ok(db.statuses.size() > 0, "statuses loaded")
	T.ok(db.encounters.size() > 0, "encounters loaded")
	T.ok(db.maps.size() > 0, "maps loaded")
	T.ok(db.dialogues.size() > 0, "dialogue loaded")
	T.ok(not db.story().get("nodes", []).is_empty(), "story loaded")
	T.ok(not db.world().get("start", {}).is_empty(), "world start present")
	T.ok(db.speed_stat() in db.stat_ids(), "turn-order stat binding valid")
	T.ok(db.stat_ids().size() > 0 and db.resource_ids().size() > 0, "stat model populated")
	T.ok(db.resource_ids().has("hp"), "hp pool exists (engine built-in)")

func test_shorthand_normalized_on_load() -> void:
	var db := _loaded_db()
	for sid in db.spells:
		var ab: Dictionary = db.spell(sid)["ability"]
		T.ok(ab["trigger"] is Dictionary and ab["trigger"].has("op"), "%s trigger normalized" % sid)
		T.ok(ab["effect"] is Dictionary and ab["effect"].has("op"), "%s effect normalized" % sid)
	for mid in db.monsters:
		for ab in db.monster(mid)["abilities"]:
			T.ok(ab["target"] is Dictionary and ab["target"].has("op"), "%s.%s target normalized (string shorthand)" % [mid, ab["id"]])
	for stid in db.statuses:
		var s: Dictionary = db.status_def(stid)
		if s.has("tick"):
			T.ok(s["tick"]["trigger"] is Dictionary, "%s tick trigger normalized" % stid)
		for m in s.get("stat_mods", []):
			T.ok(m["value"] is Dictionary and m["value"].has("op"), "%s stat_mod value promoted to const" % stid)
	T.ok(not db.damage_formula_ast("physical").is_empty(), "physical damage formula AST cached")
	T.ok(not db.damage_formula_ast("magical").is_empty(), "magical damage formula AST cached")

func test_class_growth_resolution() -> void:
	var db := _loaded_db()
	var st: RefCounted = StatsScript.new(db)
	for cid in db.classes:
		var c: Dictionary = db.cls(cid)
		var at1: Dictionary = st.class_base_stats(cid, 1)
		var at5: Dictionary = st.class_base_stats(cid, 5)
		for sid in db.stat_ids():
			if c.get("growth", {}).has(sid):
				T.eq(at1[sid], float(c["base_stats"][sid]), "%s.%s: curve(1) matches base_stats anchor" % [cid, sid])
			T.ok(float(at5[sid]) >= float(at1[sid]), "%s.%s does not shrink with level" % [cid, sid])

func test_resource_maxima_rfc001() -> void:
	var db := _loaded_db()
	var st: RefCounted = StatsScript.new(db)
	for cid in db.classes:  # class growth binding a resource wins over max_formula
		var growth: Dictionary = db.cls(cid).get("growth", {})
		var view := {"kind": "party", "class": cid, "level": 3,
				"stats": st.class_base_stats(cid, 3), "equipment": {}, "statuses": [], "mods": []}
		for rid in db.resource_ids():
			var mx: int = st.max_resource(view, rid)
			T.ok(mx > 0, "%s max %s positive" % [cid, rid])
			if growth.has(rid):
				T.eq(mx, roundi(st.curve_value(growth[rid], 3)), "%s.%s from growth curve" % [cid, rid])
	var saw_override := false
	for mid in db.monsters:  # explicit resource id in a monster's stats wins
		var m: Dictionary = db.monster(mid)
		var overrides := {}
		for k in m["stats"]:
			if k in db.resource_ids():
				overrides[k] = m["stats"][k]
		var ent := {"kind": "monster", "level": m["level"], "stats": m["stats"],
				"resource_overrides": overrides, "equipment": {}, "statuses": [], "mods": []}
		for rid in db.resource_ids():
			var mx: int = st.max_resource(ent, rid)
			T.ok(mx > 0, "%s max %s positive" % [mid, rid])
			if overrides.has(rid):
				saw_override = true
				T.eq(mx, int(overrides[rid]), "%s.%s explicit override wins" % [mid, rid])
	T.ok(saw_override, "content exercises the RFC-001 override path")

func test_spell_learning_gates() -> void:
	var db := _loaded_db()
	var gated := 0
	for sid in db.spells:
		for l in db.spell(sid).get("learn", []):
			var learned: Array = db.spells_for_class(l["class"], int(l["at_level"]))
			T.ok(sid in learned, "%s learnable at its level" % sid)
			if int(l["at_level"]) > 1:
				gated += 1
				T.ok(not (sid in db.spells_for_class(l["class"], int(l["at_level"]) - 1)), "%s gated below its level" % sid)
	T.ok(gated > 0, "content exercises level gating")

func test_unknown_op_fixture_rejected_at_load() -> void:
	var root := "user://tampered_content"
	DirAccess.make_dir_recursive_absolute(root + "/maps")
	var cdir := DirAccess.open("res://content")
	for f in cdir.get_files():
		if f.ends_with(".json"):
			_copy("res://content/" + f, root + "/" + f)
	for f in DirAccess.open("res://content/maps").get_files():
		if f.ends_with(".json"):
			_copy("res://content/maps/" + f, root + "/maps/" + f)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "/spells.json"))
	raw["entries"][0]["ability"]["effect"] = {"op": "detonate_moon_fixture"}
	var out := FileAccess.open(root + "/spells.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw, "  "))
	out.close()
	var db := _db()
	T.ok(not db.load_all(root), "tampered content refused at load time")
	var named := false
	for e in db.load_errors:
		if "detonate_moon_fixture" in str(e):
			named = true
	T.ok(named, "load error names the unknown op")

func _copy(from: String, to: String) -> void:
	var out := FileAccess.open(to, FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(from))
	out.close()
