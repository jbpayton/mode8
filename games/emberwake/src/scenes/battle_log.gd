# scenes/battle_log.gd — renders interpreter battle-log events
# ({turn, source, ability, effect_op, target, rolled, result} —
# effect-algebra.md §Interpreter contract) as human-readable text lines for
# the battle_menu scene. Names resolve from battle entities and content
# lookups; ids never render raw unless nothing knows them. Not a scene type.
extends RefCounted

static func line(ev: Dictionary, names: Dictionary, db: Node, battle: RefCounted) -> String:
	var src: String = names.get(ev["source"], "?")
	var tgt: String = names.get(ev["target"], "?")
	var ab := ability_name(db, battle, str(ev["source"]), str(ev["ability"]))
	match str(ev["effect_op"]):
		"damage":
			var n := int(ev["result"])
			return "%s absorbs %d (%s)" % [tgt, -n, ab] if n < 0 else "%s takes %d (%s)" % [tgt, n, ab]
		"heal":
			return "%s recovers %d (%s)" % [tgt, int(ev["result"]), ab]
		"miss":
			return "%s: %s misses %s" % [src, ab, tgt]
		"apply_status":
			return "%s: %s takes hold on %s" % [src, ab, tgt] if bool(ev["result"]) else "%s resists %s" % [tgt, ab]
		"cure_status":
			return "%s is cleansed (%s)" % [tgt, ab]
		"modify_stat":
			return "%s: %s shifts %s" % [src, ab, tgt]
		"resource":
			return "%s: %+d (%s)" % [tgt, int(ev["result"]), ab]
		"revive":
			return "%s rises! (%s)" % [tgt, ab]
		"defend":
			return "%s guards" % src
		"row":
			return "%s moves to the %s row" % [src, str(ev["result"])]
		"flee":
			return "The party flees!" if bool(ev["result"]) else "Can't escape!"
	return ""

# Display name for an ability id: engine "attack" -> spell entry -> the
# source entity's own ability table (monsters) -> item whose use block owns
# the id -> prettified id tail.
static func ability_name(db: Node, battle: RefCounted, src_key: String, id: String) -> String:
	if id == "attack":
		return "Attack"
	var sp: Dictionary = db.spell(id)
	if not sp.is_empty():
		return str(sp["ability"].get("name", id))
	for e in battle.monsters + battle.party:
		if e["key"] == src_key and e.get("abilities", {}).has(id):
			return str(e["abilities"][id].get("name", id))
	for iid in db.items:
		if db.item(iid).get("use", {}).get("id", "") == id:
			return str(db.item(iid).get("name", id))
	return id.get_slice(".", 1).capitalize() if id.contains(".") else id.capitalize()
