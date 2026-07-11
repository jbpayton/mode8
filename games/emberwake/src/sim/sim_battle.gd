# sim/sim_battle.gd — m8-balancer's entrypoint (engine contract §5).
# godot --headless --path src --script res://sim/sim_battle.gd -- <spec.json> <out.jsonl>
# Spec: {"seed": int, "battles": [{"party": [{"class", "level", "equipment",
# "spells", "items"}], "monsters": [ids], "max_rounds": 50}]}
# Runs each battle UI-free under the fixed heuristic_v1 policy and writes one
# JSON result line per battle (contract-fixed fields). Exit 0 on success.
extends SceneTree

const BattleScript := preload("res://engine/battle.gd")
const Stats := preload("res://engine/stats.gd")

func _initialize() -> void:
	var files: Array = Array(OS.get_cmdline_user_args()).filter(
			func(a: String) -> bool: return not a.begins_with("--"))
	if files.size() < 2:
		push_error("usage: sim_battle.gd -- <spec.json> <out.jsonl>")
		quit(1)
		return
	var db := root.get_node_or_null("ContentDB")
	if db != null and not db.loaded:
		db.load_all()  # _initialize runs before autoload _ready in script mode
	if db == null or not db.loaded:
		push_error("sim_battle: content failed to load: " + str(db.load_errors if db else []))
		quit(1)
		return
	var rng := root.get_node("Rng")
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(files[0]))
	if not (spec is Dictionary):
		push_error("sim_battle: cannot parse spec " + files[0])
		quit(1)
		return
	var out := FileAccess.open(files[1], FileAccess.WRITE)
	if out == null:
		push_error("sim_battle: cannot open output " + files[1])
		quit(1)
		return
	rng.set_seed(int(spec.get("seed", 0)))
	var stats: RefCounted = Stats.new(db)
	var i := 0
	for bs in spec.get("battles", []):
		var members: Array = []
		var inventory := {}
		for pm in bs.get("party", []):
			var lvl: int = int(pm.get("level", 1))
			members.append({"class": pm.get("class", ""), "name": pm.get("class", ""),
					"level": lvl, "xp": stats.xp_to_reach(lvl),
					"equipment": pm.get("equipment", {}),
					"spells": pm.get("spells", []), "row": pm.get("row", "front")})
			for iid in pm.get("items", {}):
				inventory[iid] = int(inventory.get(iid, 0)) + int(pm["items"][iid])
		var b: RefCounted = BattleScript.new(db, rng, members, bs.get("monsters", []),
				inventory, {"max_rounds": int(bs.get("max_rounds", 50))})
		var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
		out.store_line(JSON.stringify({"i": i, "win": res["win"], "wipe": res["wipe"],
				"timeout": res["timeout"], "rounds": res["rounds"],
				"party_hp_end_pct": res["party_hp_end_pct"], "mp_spent": res["mp_spent"],
				"items_used": res["items_used"], "deaths": res["deaths"],
				"dmg_dealt": res["dmg_dealt"], "dmg_taken": res["dmg_taken"],
				"ability_usage": res["ability_usage"]}))
		i += 1
	out.close()
	quit(0)
