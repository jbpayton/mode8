# Game — run state (engine contract §4): party, inventory, gold, flags, map,
# pos, opened chests, playtime. snapshot() emits pure JSON-serializable types
# with exactly the contract shape; restore(snapshot()) then snapshot() is
# deep-equal (restore coerces JSON-widened numbers back to int).
# Scene transitions go through goto_scene(type, args) — the single choke
# point that emits the M8Debug "scene" trace line (contract §8).
extends Node

const Save := preload("res://engine/save.gd")
const Stats := preload("res://engine/stats.gd")
const BattleScript := preload("res://engine/battle.gd")
const Algebra := preload("res://engine/algebra.gd")

var party: Array = []
var inventory: Dictionary = {}
var gold: int = 0
var flags: Array = []
var map: String = ""
var pos: Array = [0, 0]
var opened: Array = []
var playtime_s: float = 0.0
var scene_args: Dictionary = {}

var stats: RefCounted = null
var _db: Node = null

func _ready() -> void:
	var db_node := get_node_or_null("/root/ContentDB")
	if db_node != null:
		setup(db_node)

# Dependency seam (tests construct Game with a fresh ContentDB).
func setup(p_db: Node) -> void:
	_db = p_db
	stats = Stats.new(_db)

func db() -> Node:
	return _db

func _process(delta: float) -> void:
	playtime_s += delta

# -------------------------------------------------------------- run state

func new_game() -> void:
	party = []
	inventory = {}
	gold = 0
	flags = []
	opened = []
	playtime_s = 0.0
	var start: Dictionary = _db.world().get("start", {})
	map = start.get("map", "")
	pos = [0, 0]
	for e in _db.map_def(map).get("entities", []):
		if e["id"] == start.get("spawn", ""):
			pos = [int(e["x"]), int(e["y"])]

# Creates a level-1 member of the class with full resources and its level-1
# spells (cast_model=player_built: the party_builder scene calls this).
func add_party_member(class_id: String, member_name: String) -> Dictionary:
	var member := {"class": class_id, "name": member_name, "level": 1, "xp": 0,
			"equipment": {}, "spells": _db.spells_for_class(class_id, 1), "row": "front"}
	var view: Dictionary = stats.member_view(member)
	for rid in _db.resource_ids():
		member[rid] = int(view["resources"][rid]["max"])
	party.append(member)
	return member

# --- 03b flagged additions (API.md gaps; scene layer has no other path) ---

# Work order 03b + G-004: start a fresh run from party_builder picks
# ([{class, name}]). Purse from m8/run/start_gold (decision G-004: 120g,
# empty inventory, no equipment — new_game/add_party_member already grant
# neither equipment nor items).
func new_run(picks: Array) -> void:
	new_game()
	for p in picks:
		add_party_member(str(p["class"]), str(p["name"]))
	gold = int(ProjectSettings.get_setting("m8/run/start_gold", 0))

# GDD party.size binding (m8/run/party_size) for the party_builder scene.
func party_size() -> int:
	return int(ProjectSettings.get_setting("m8/run/party_size", 2))

# Save-slot visibility for title (Continue) and save_load (slot summaries);
# scenes may not touch engine/save.gd directly.
func save_slots() -> Array:
	return Save.list_slots()

func peek_save(slot: int) -> Dictionary:
	return Save.load_slot(slot)

# Menu-context item use ("usable_in": ["menu"]): heal/resource/revive apply
# to the persistent member; cure_status is a no-op outside battle (statuses
# are battle-scoped, contract §8). Returns {"ok": bool [, "error"]}.
func use_item_on_member(item_id: String, member_idx: int) -> Dictionary:
	var use: Dictionary = _db.item(item_id).get("use", {})
	if use.is_empty() or item_count(item_id) <= 0:
		return {"ok": false, "error": "item not usable"}
	if member_idx < 0 or member_idx >= party.size():
		return {"ok": false, "error": "no such member"}
	var member: Dictionary = party[member_idx]
	var wants_dead: bool = use.get("target", {}).get("op", "") == "dead"
	if wants_dead != (int(member.get("hp", 0)) <= 0):
		return {"ok": false, "error": "invalid target"}
	remove_item(item_id)
	_apply_menu_effect(use.get("effect", {}), member)
	return {"ok": true}

# Inn service (world place services.inn_price): restore every resource pool
# to its max for all members.
func rest_party() -> void:
	for member in party:
		var view: Dictionary = stats.member_view(member)
		for rid in _db.resource_ids():
			member[rid] = int(view["resources"][rid]["max"])

# Minimal out-of-battle effect walk (seq + heal/resource/revive/cure_status);
# values evaluate through the algebra against the member's stat view.
func _apply_menu_effect(e: Dictionary, member: Dictionary) -> void:
	var view: Dictionary = stats.member_view(member)
	match e.get("op", ""):
		"seq":
			for sub in e["effects"]:
				_apply_menu_effect(sub, member)
		"heal":
			var alg: RefCounted = Algebra.new(_db, get_node("/root/Rng"))
			var amt: int = roundi(alg.eval_value(e["value"], view, view))
			member["hp"] = clampi(int(member.get("hp", 0)) + amt, 0, int(view["resources"]["hp"]["max"]))
		"resource":
			var alg2: RefCounted = Algebra.new(_db, get_node("/root/Rng"))
			var delta: int = roundi(alg2.eval_value(e["delta"], view, view))
			var pool: String = e["pool"]
			member[pool] = clampi(int(member.get(pool, 0)) + delta, 0, int(view["resources"][pool]["max"]))
		"revive":
			if int(member.get("hp", 0)) <= 0:
				member["hp"] = maxi(1, roundi(float(view["resources"]["hp"]["max"]) * float(e.get("pct", 0.5))))
		"cure_status":
			pass  # battle-scoped statuses; nothing persists to cure
		_:
			push_warning("Game: unsupported menu effect op " + str(e.get("op", "")))

# ------------------------------------------------------------- flags/items

func set_flag(id: String) -> void:
	if not (id in flags):
		flags.append(id)

func has_flag(id: String) -> bool:
	return id in flags

func add_item(id: String, n := 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + n
	if int(inventory[id]) <= 0:
		inventory.erase(id)

func remove_item(id: String, n := 1) -> bool:
	if int(inventory.get(id, 0)) < n:
		return false
	add_item(id, -n)
	return true

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

# ---------------------------------------------------------------- battles

# Battle mutates party members and inventory by reference; call
# apply_battle_result afterwards to bank the gold.
func start_battle(monster_ids: Array, opts: Dictionary = {}) -> RefCounted:
	var o := opts.duplicate()
	o["flags"] = flags
	return BattleScript.new(_db, get_node("/root/Rng"), party, monster_ids, inventory, o)

func apply_battle_result(result: Dictionary) -> void:
	gold += int(result.get("rewards", {}).get("gold", 0))

# ------------------------------------------------------------- scene flow

func goto_scene(type: String, args: Dictionary = {}) -> void:
	scene_args = args
	var m8d := get_node_or_null("/root/M8Debug")
	if m8d != null:
		m8d.trace_scene(type, args)
	var path := "res://scenes/%s.tscn" % type
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file.call_deferred(path)
	else:
		push_error("Game.goto_scene: missing scene " + path)

# --------------------------------------------------------- snapshot (§4)

func snapshot() -> Dictionary:
	var psnap: Array = []
	for m in party:
		var ms := {"class": str(m["class"]), "name": str(m["name"]),
				"level": int(m["level"]), "xp": int(m["xp"])}
		for rid in _db.resource_ids():
			ms[rid] = int(m.get(rid, 0))
		ms["equipment"] = m.get("equipment", {}).duplicate()
		ms["spells"] = m.get("spells", []).duplicate()
		ms["row"] = str(m.get("row", "front"))
		psnap.append(ms)
	return {"party": psnap, "inventory": inventory.duplicate(),
			"gold": gold, "flags": flags.duplicate(), "map": map,
			"pos": pos.duplicate(), "opened": opened.duplicate(),
			"playtime_s": playtime_s}

func restore(snap: Dictionary) -> void:
	party = []
	for ms in snap.get("party", []):
		var m := {"class": str(ms["class"]), "name": str(ms["name"]),
				"level": int(ms["level"]), "xp": int(ms["xp"])}
		for rid in _db.resource_ids():
			m[rid] = int(ms.get(rid, 0))
		m["equipment"] = {}
		for slot in ms.get("equipment", {}):
			m["equipment"][slot] = str(ms["equipment"][slot])
		m["spells"] = []
		for sid in ms.get("spells", []):
			m["spells"].append(str(sid))
		m["row"] = str(ms.get("row", "front"))
		party.append(m)
	inventory = {}
	for iid in snap.get("inventory", {}):
		inventory[iid] = int(snap["inventory"][iid])
	gold = int(snap.get("gold", 0))
	flags = []
	for f in snap.get("flags", []):
		flags.append(str(f))
	map = str(snap.get("map", ""))
	pos = [int(snap.get("pos", [0, 0])[0]), int(snap.get("pos", [0, 0])[1])]
	opened = []
	for o in snap.get("opened", []):
		opened.append(str(o))
	playtime_s = float(snap.get("playtime_s", 0.0))

func save_game(slot: int) -> bool:
	return Save.save_slot(slot, snapshot())

func load_game(slot: int) -> bool:
	var snap := Save.load_slot(slot)
	if snap.has("error"):
		return false
	restore(snap)
	return true
