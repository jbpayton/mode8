# engine/battle.gd — UI-free battle engine (engine contract §5; work order 03a).
# Round-based; per-round turn order = effective speed stat (project setting
# m8/battle/speed_stat via db.speed_stat()) descending; ties party first, then
# build order. Party commands arrive via submit_command (policy interface);
# monster turns run ai.rules (eligible = when-predicate AND costs payable;
# weighted pick + uniform 'single' targeting via Rng; nothing eligible =>
# Defend). Statuses tick per trigger; status + modify_stat durations decrement
# at the affected entity's turn end. Victory applies xp/gold/drops (full xp
# sum to each surviving member; level-ups learn spells and grow currents by
# the max delta). Defend halves incoming damage (not self-inflicted); back
# row halves physical damage dealt and taken. Unarmed basic attack is the
# engine default: physical, value 1, always hits.
# Built-in party policy: heuristic_v1 (contract §5, exact rules).
extends RefCounted

const Formula := preload("res://engine/formula.gd")
const Algebra := preload("res://engine/algebra.gd")
const Stats := preload("res://engine/stats.gd")

var db: Object
var rng: Object
var alg: RefCounted
var stats: RefCounted
var party: Array = []
var monsters: Array = []
var members: Array = []
var inventory: Dictionary = {}
var speed_stat := ""
var max_rounds := 50
var round_no := 0
var turn_no := 0
var outcome := ""  # "" | "win" | "wipe" | "timeout" | "fled"
var events: Array = []
var event_cb: Callable = Callable()
var rewards: Dictionary = {}
var metrics := {"mp_spent": 0, "items_used": {}, "deaths": 0, "dmg_dealt": 0,
		"dmg_taken": 0, "ability_usage": {}}

var _order: Array = []
var _order_idx := 0
var _awaiting: Dictionary = {}
var _by_key: Dictionary = {}

# members: persistent party dicts (contract §4 shape) — mutated on victory.
# monster_ids: content monster ids. inventory: shared {item_id: count} ref.
func _init(p_db: Object, p_rng: Object, p_members: Array, monster_ids: Array,
		p_inventory: Dictionary, opts: Dictionary = {}) -> void:
	db = p_db
	rng = p_rng
	members = p_members
	inventory = p_inventory
	stats = Stats.new(db)
	alg = Algebra.new(db, rng)
	alg.host = self  # weakly held; events arrive via on_battle_event
	alg.flags = opts.get("flags", [])
	speed_stat = db.speed_stat()
	max_rounds = int(opts.get("max_rounds", 50))
	for i in members.size():
		party.append(_build_party_entity(members[i], "p%d" % i, i))
	for i in monster_ids.size():
		monsters.append(_build_monster_entity(monster_ids[i], "m%d" % i, 100 + i))
	for e in party + monsters:
		_by_key[e["key"]] = e

func _build_party_entity(member: Dictionary, key: String, idx: int) -> Dictionary:
	var lvl: int = int(member.get("level", 1))
	var ent := {"key": key, "side": "party", "kind": "party", "order": idx,
			"id": member.get("class", ""), "class": member.get("class", ""),
			"name": member.get("name", key), "level": lvl,
			"stats": stats.class_base_stats(member.get("class", ""), lvl),
			"equipment": member.get("equipment", {}),
			"spells": member.get("spells", []),
			"row": member.get("row", "front"),
			"statuses": [], "mods": [], "affinities": [], "status_immunity": [],
			"alive": true, "defending": false, "used_once": {}, "cooldowns": {},
			"resources": {}}
	for rid in db.resource_ids():
		var mx: int = stats.max_resource(ent, rid)
		ent["resources"][rid] = {"cur": clampi(int(member.get(rid, mx)), 0, mx), "max": mx}
	ent["alive"] = int(ent["resources"]["hp"]["cur"]) > 0
	return ent

func _build_monster_entity(monster_id: String, key: String, idx: int) -> Dictionary:
	var mdef: Dictionary = db.monster(monster_id)
	var base := {}
	var overrides := {}
	for k in mdef.get("stats", {}):
		if k in db.resource_ids():
			overrides[k] = mdef["stats"][k]
		else:
			base[k] = mdef["stats"][k]
	var ent := {"key": key, "side": "monster", "kind": "monster", "order": idx,
			"id": monster_id, "name": mdef.get("name", monster_id),
			"level": int(mdef.get("level", 1)), "stats": base,
			"resource_overrides": overrides, "equipment": {},
			"abilities": mdef.get("_ability_index", {}),
			"ai_rules": mdef.get("ai", {}).get("rules", []),
			"row": "front", "statuses": [], "mods": [],
			"affinities": mdef.get("affinities", []),
			"status_immunity": mdef.get("status_immunity", []),
			"xp": int(mdef.get("xp", 0)), "gold": int(mdef.get("gold", 0)),
			"drops": mdef.get("drops", []),
			"alive": true, "defending": false, "used_once": {}, "cooldowns": {},
			"resources": {}}
	for rid in db.resource_ids():
		var mx: int = stats.max_resource(ent, rid)
		ent["resources"][rid] = {"cur": mx, "max": mx}
	return ent

# ------------------------------------------------------------ battle flow

func begin() -> void:
	round_no = 1
	_build_order()
	_order_idx = 0
	_advance()

func needs_command() -> bool:
	return outcome == "" and not _awaiting.is_empty()

func current_actor() -> Dictionary:
	return _awaiting

func is_over() -> bool:
	return outcome != ""

func submit_command(action: Dictionary) -> void:
	var ent := _awaiting
	_awaiting = {}
	turn_no += 1
	alg.turn_no = turn_no
	_do_party_action(ent, action)
	_turn_end(ent)
	_check_outcome()
	_order_idx += 1
	_advance()

# Run with a policy (object with decide(battle, actor) -> action Dictionary).
func run(policy: Object) -> Dictionary:
	begin()
	while needs_command():
		submit_command(policy.decide(self, current_actor()))
	return result()

func _advance() -> void:
	while outcome == "":
		if _order_idx >= _order.size():
			round_no += 1
			if round_no > max_rounds:
				outcome = "timeout"
				break
			_build_order()
			_order_idx = 0
		var ent: Dictionary = _order[_order_idx]
		if not ent["alive"]:
			_order_idx += 1
			continue
		ent["defending"] = false
		alg.turn_no = turn_no
		alg.run_status_ticks(ent, "on_turn_start")
		_check_outcome()
		if outcome != "":
			break
		if not ent["alive"] or _blocked(ent):
			_turn_end(ent)
			_order_idx += 1
			continue
		if ent["side"] == "party":
			_awaiting = ent
			return
		turn_no += 1
		alg.turn_no = turn_no
		_monster_act(ent)
		_turn_end(ent)
		_check_outcome()
		_order_idx += 1
	_finish()

# Turn order: alive entities, speed stat desc; ties party first, then order.
func _build_order() -> void:
	_order = (party + monsters).filter(func(e: Dictionary) -> bool: return e["alive"])
	_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = stats.effective_stat(a, speed_stat)
		var sb: float = stats.effective_stat(b, speed_stat)
		if sa != sb:
			return sa > sb
		return a["order"] < b["order"])

func _blocked(ent: Dictionary) -> bool:
	for inst in ent["statuses"]:
		if db.status_def(inst["id"]).get("blocks_action", false):
			return true
	return false

func _turn_end(ent: Dictionary) -> void:
	if ent["alive"]:
		alg.run_status_ticks(ent, "on_turn_end")
	alg.expire_statuses(ent)
	alg.expire_mods(ent)
	for k in ent["cooldowns"]:
		ent["cooldowns"][k] = maxi(0, int(ent["cooldowns"][k]) - 1)

func _check_outcome() -> void:
	if outcome != "":
		return
	if party.all(func(e: Dictionary) -> bool: return not e["alive"]):
		outcome = "wipe"
	elif monsters.all(func(e: Dictionary) -> bool: return not e["alive"]):
		outcome = "win"

# ------------------------------------------------------------ monster AI

func eligible_rules(ent: Dictionary) -> Array:
	var out: Array = []
	for rule in ent.get("ai_rules", []):
		if rule.has("when") and not alg.eval_predicate(rule["when"], ent, null):
			continue
		var ab: Dictionary = ent["abilities"].get(rule["ability"], {})
		if ab.is_empty() or not costs_payable(ent, ab):
			continue
		out.append(rule)
	return out

func _monster_act(ent: Dictionary) -> void:
	var elig := eligible_rules(ent)
	if elig.is_empty():
		_defend(ent)
		return
	var idx: int = rng.weighted_index(elig.map(func(r: Dictionary) -> float: return float(r["weight"])))
	var ability: Dictionary = ent["abilities"][elig[idx]["ability"]]
	use_ability(ent, ability, null)

# --------------------------------------------------------------- actions
# action: {"kind": "attack"|"spell"|"item"|"defend"|"row"|"flee",
#          "id": spell/item id, "target": entity key}

func _do_party_action(ent: Dictionary, action: Dictionary) -> void:
	var tgt: Variant = _by_key.get(action.get("target", ""), null)
	match action.get("kind", "defend"):
		"attack":
			_count_use("attack")
			use_ability(ent, basic_attack_ability(ent), tgt)
		"spell":
			_count_use(action["id"])
			use_ability(ent, db.spell(action["id"])["ability"], tgt)
		"item":
			var iid: String = action["id"]
			if inventory.get(iid, 0) > 0 and db.item(iid).has("use"):
				_consume_item(iid)
				metrics["items_used"][iid] = int(metrics["items_used"].get(iid, 0)) + 1
				_count_use(iid)
				use_ability(ent, db.item(iid)["use"], tgt)
		"defend":
			_count_use("defend")
			_defend(ent)
		"row":
			ent["row"] = "back" if ent["row"] == "front" else "front"
			_emit_battle_event(ent, ent, "row", "row", null, ent["row"])
		"flee":
			_count_use("flee")
			var roll: float = rng.randf()
			if roll < 0.5:  # engine default: flat 50% party escape
				outcome = "fled"
			_emit_battle_event(ent, ent, "flee", "flee", roll, 1 if outcome == "fled" else 0)

func _count_use(id: String) -> void:
	metrics["ability_usage"][id] = int(metrics["ability_usage"].get(id, 0)) + 1

func _defend(ent: Dictionary) -> void:
	ent["defending"] = true
	_emit_battle_event(ent, ent, "defend", "defend", null, 1)

# Basic attack: the equipped weapon's attack block, else unarmed (value 1).
func basic_attack_ability(ent: Dictionary) -> Dictionary:
	var effect := {"op": "damage", "value": {"op": "const", "n": 1.0}, "type": "physical"}
	var accuracy: Variant = null
	for eq_id in ent.get("equipment", {}).values():
		var atk: Dictionary = db.equip(eq_id).get("attack", {})
		if not atk.is_empty():
			effect["value"] = atk["value"]
			if atk.get("element", "") != "":
				effect["element"] = atk["element"]
			accuracy = atk.get("accuracy", null)
			break
	return {"id": "attack", "trigger": {"op": "on_use"},
			"target": {"op": "single", "side": "enemy"},
			"accuracy": accuracy, "effect": effect}

# Interpreter contract §2 resolution order: costs check+pay -> target
# resolution -> accuracy roll (per resolved target) -> effect tree.
func use_ability(src: Dictionary, ability: Dictionary, designated: Variant) -> void:
	pay_costs(src, ability)
	var targets := resolve_targets(src, ability.get("target", {"op": "self"}), designated)
	var acc: Variant = ability.get("accuracy", null)
	for tgt in targets:
		if acc != null:
			var roll: float = rng.randf()
			if roll >= float(acc):
				_emit_battle_event(src, tgt, str(ability.get("id", "?")), "miss", roll, 0)
				continue
		alg.apply_effect(ability["effect"], src, tgt, str(ability.get("id", "?")))

# Decrement a shared-inventory count, erasing at <=0 so snapshots never
# carry phantom zero-count stacks (PT-001; mirrors Game.add_item semantics).
func _consume_item(iid: String) -> void:
	inventory[iid] = int(inventory.get(iid, 0)) - 1
	if int(inventory.get(iid, 0)) <= 0:
		inventory.erase(iid)

func costs_payable(ent: Dictionary, ability: Dictionary) -> bool:
	var costs: Dictionary = ability.get("costs", {})
	for k in costs:
		match k:
			"item":
				if inventory.get(costs["item"], 0) <= 0:
					return false
			"row_lock":
				if ent["row"] != costs["row_lock"]:
					return false
			"once_per_battle":
				if ent["used_once"].has(ability.get("id", "")):
					return false
			"cooldown":
				if int(ent["cooldowns"].get(ability.get("id", ""), 0)) > 0:
					return false
			"class_lock":
				if not (ent.get("class", "") in costs["class_lock"]):
					return false
			"charge", "range":
				pass  # not used by menu_rows battles (v0.1)
			_:  # resource cost; hp must not self-kill
				var cur: int = int(ent["resources"].get(k, {}).get("cur", 0))
				if (k == "hp" and cur <= int(costs[k])) or cur < int(costs[k]):
					return false
	return true

func pay_costs(ent: Dictionary, ability: Dictionary) -> void:
	var costs: Dictionary = ability.get("costs", {})
	for k in costs:
		match k:
			"item":
				_consume_item(costs["item"])
			"once_per_battle":
				ent["used_once"][ability.get("id", "")] = true
			"cooldown":
				ent["cooldowns"][ability.get("id", "")] = int(costs[k]) + 1
			"row_lock", "class_lock", "charge", "range":
				pass
			_:
				var pool: Dictionary = ent["resources"].get(k, {})
				if not pool.is_empty():
					pool["cur"] = int(pool["cur"]) - int(costs[k])
					if ent["side"] == "party" and k != "hp":
						metrics["mp_spent"] += int(costs[k])

# ------------------------------------------------------------- targeting

func _side_of(side_sel: String, src: Dictionary) -> Array:
	var own: Array = party if src["side"] == "party" else monsters
	var other: Array = monsters if src["side"] == "party" else party
	match side_sel:
		"ally": return own
		"enemy": return other
		_: return own + other

func resolve_targets(src: Dictionary, sel: Dictionary, designated: Variant) -> Array:
	var op: String = sel.get("op", "self")
	if op == "self":
		return [src]
	var pool := _side_of(sel.get("side", "enemy"), src)
	var cands: Array
	if op == "dead":
		cands = pool.filter(func(e: Dictionary) -> bool: return not e["alive"] and not e.get("fled", false))
	else:
		cands = pool.filter(func(e: Dictionary) -> bool: return e["alive"])
	if cands.is_empty():
		return []
	match op:
		"single", "dead":
			if designated is Dictionary and designated in cands:
				return [designated]
			return [rng.choice(cands)]  # uniform via Rng (monster AI / no pick)
		"all":
			return cands
		"row":
			return cands.filter(func(e: Dictionary) -> bool: return e["row"] == sel.get("which", "front"))
		"random":
			var picks: Array = []
			var left := cands.duplicate()
			for i in mini(int(sel.get("n", 1)), left.size()):
				picks.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
			return picks
		"lowest":
			var best: Dictionary = cands[0]
			for e in cands:
				if stats.effective_stat(e, sel["stat"]) < stats.effective_stat(best, sel["stat"]):
					best = e
			return [best]
	push_warning("battle: unsupported selector " + op)
	return []

# ----------------------------------------------------------- host hooks

func stat_value(ent: Dictionary, name: String) -> float:
	if not ent.get("ctx", {}).has(name) and name in db.stat_ids():
		return stats.effective_stat(ent, name)
	return Formula.resolve_entity_var(ent, name)

# Damage scaling: back row halves physical (attacker and defender); defending
# halves anything not self-inflicted (so your own burn tick is never guarded).
func damage_scale(src: Dictionary, tgt: Dictionary, type: String) -> float:
	var s := 1.0
	if type == "physical":
		if tgt.get("row", "front") == "back":
			s *= 0.5
		if src.get("row", "front") == "back":
			s *= 0.5
	if tgt.get("defending", false) and src != tgt:
		s *= 0.5
	return s

func on_death(ent: Dictionary) -> void:
	if ent["side"] == "party":
		metrics["deaths"] += 1

func on_flee(ent: Dictionary) -> void:
	ent["alive"] = false
	ent["fled"] = true

func _emit_battle_event(src: Dictionary, tgt: Dictionary, ability: String, op: String, rolled: Variant, result: Variant) -> void:
	on_battle_event({"turn": turn_no, "source": src["key"], "ability": ability,
			"effect_op": op, "target": tgt["key"], "rolled": rolled, "result": result})

func on_battle_event(ev: Dictionary) -> void:
	events.append(ev)
	if ev["effect_op"] == "damage":
		var tgt: Dictionary = _by_key.get(ev["target"], {})
		if tgt.get("side", "") == "monster":
			metrics["dmg_dealt"] += maxi(0, int(ev["result"]))
		elif tgt.get("side", "") == "party":
			metrics["dmg_taken"] += maxi(0, int(ev["result"]))
	if event_cb.is_valid():
		event_cb.call(ev)

# contract §5: expectation = mean value of the damage node x element
# multiplier vs. that target (no mitigation/accuracy/variance).
func expected_damage(ability: Dictionary, src: Dictionary, tgt: Dictionary) -> float:
	return alg.expected_damage_of(ability["effect"], src, tgt)

# --------------------------------------------------------------- wrap-up

func _finish() -> void:
	if outcome == "win":
		_apply_victory()
	for i in party.size():  # write battle state back to persistent members
		var ent: Dictionary = party[i]
		for rid in db.resource_ids():
			members[i][rid] = int(ent["resources"][rid]["cur"])
		members[i]["row"] = ent["row"]

func _apply_victory() -> void:
	var xp_sum := 0
	var gold_sum := 0
	var drops := {}
	for m in monsters:
		if m.get("fled", false):
			continue
		xp_sum += m["xp"]
		gold_sum += m["gold"]
		for d in m.get("drops", []):
			if rng.randf() < float(d["chance"]):
				drops[d["item"]] = int(drops.get(d["item"], 0)) + 1
	for iid in drops:
		inventory[iid] = int(inventory.get(iid, 0)) + int(drops[iid])
	var levels := {}
	for i in party.size():
		if not party[i]["alive"]:
			continue
		var member: Dictionary = members[i]
		member["xp"] = int(member.get("xp", 0)) + xp_sum
		var before: Dictionary = stats.member_view(member)
		var lvl: int = int(member["level"])
		while int(member["xp"]) >= stats.xp_to_reach(lvl + 1) and stats.xp_to_reach(lvl + 1) > stats.xp_to_reach(lvl):
			lvl += 1
		if lvl != int(member["level"]):
			member["level"] = lvl
			levels[party[i]["key"]] = lvl
			for sid in db.spells_for_class(member.get("class", ""), lvl):
				if not (sid in member["spells"]):
					member["spells"].append(sid)
			var after: Dictionary = stats.member_view(member)
			for rid in db.resource_ids():  # grow currents by the max delta
				var delta: int = int(after["resources"][rid]["max"]) - int(before["resources"][rid]["max"])
				party[i]["resources"][rid]["max"] = int(after["resources"][rid]["max"])
				party[i]["resources"][rid]["cur"] = clampi(int(party[i]["resources"][rid]["cur"]) + delta, 0, int(after["resources"][rid]["max"]))
	rewards = {"xp": xp_sum, "gold": gold_sum, "drops": drops, "level_ups": levels}

func result() -> Dictionary:
	var hp_cur := 0
	var hp_max := 0
	for e in party:
		hp_cur += int(e["resources"]["hp"]["cur"])
		hp_max += int(e["resources"]["hp"]["max"])
	return {"outcome": outcome, "win": outcome == "win", "wipe": outcome == "wipe",
			"timeout": outcome == "timeout", "rounds": mini(round_no, max_rounds),
			"party_hp_end_pct": float(hp_cur) / maxf(1.0, float(hp_max)),
			"mp_spent": metrics["mp_spent"], "items_used": metrics["items_used"],
			"deaths": metrics["deaths"], "dmg_dealt": metrics["dmg_dealt"],
			"dmg_taken": metrics["dmg_taken"], "ability_usage": metrics["ability_usage"],
			"rewards": rewards}

# ------------------------------------------------- heuristic_v1 (contract §5)
# 1. any ally hp_pct < 0.35 AND a heal is available (payable spell, else
#    usable item) -> strongest heal on the lowest-hp living ally;
# 2. else best expected-damage option (basic attack vs each payable damage
#    spell) on the lowest-hp enemy that isn't immune/absorbing;
# 3. else Defend. Ties break by list order; items only for rule 1.
class HeuristicV1:
	func decide(b: RefCounted, actor: Dictionary) -> Dictionary:
		var hurt := false
		var low: Dictionary = {}
		for al in b.party:
			if not al["alive"]:
				continue
			var hp: Dictionary = al["resources"]["hp"]
			if float(hp["cur"]) / maxf(1.0, float(hp["max"])) < 0.35:
				hurt = true
			if low.is_empty() or int(hp["cur"]) < int(low["resources"]["hp"]["cur"]):
				low = al
		if hurt:
			var heal := _best_heal(b, actor, low)
			if not heal.is_empty():
				return heal
		var atk := _best_attack(b, actor)
		if not atk.is_empty():
			return atk
		return {"kind": "defend"}

	func _best_heal(b: RefCounted, actor: Dictionary, low: Dictionary) -> Dictionary:
		var best := {}
		var best_val := 0.0
		for sid in actor.get("spells", []):
			var ab: Dictionary = b.db.spell(sid).get("ability", {})
			if ab.is_empty() or not b.alg.tree_has_op(ab["effect"], "heal") or not b.costs_payable(actor, ab):
				continue
			var v: float = b.alg.expected_heal_of(ab["effect"], actor, low)
			if v > best_val:
				best_val = v
				best = {"kind": "spell", "id": sid, "target": low["key"]}
		if not best.is_empty():
			return best
		for iid in b.inventory:
			if int(b.inventory[iid]) <= 0:
				continue
			var use: Dictionary = b.db.item(iid).get("use", {})
			if use.is_empty() or not b.alg.tree_has_op(use["effect"], "heal"):
				continue
			var v: float = b.alg.expected_heal_of(use["effect"], actor, low)
			if v > best_val:
				best_val = v
				best = {"kind": "item", "id": iid, "target": low["key"]}
		return best

	func _best_attack(b: RefCounted, actor: Dictionary) -> Dictionary:
		var options: Array = [{"kind": "attack", "ability": b.basic_attack_ability(actor)}]
		for sid in actor.get("spells", []):
			var ab: Dictionary = b.db.spell(sid).get("ability", {})
			if not ab.is_empty() and b.alg.tree_has_op(ab["effect"], "damage") and b.costs_payable(actor, ab):
				options.append({"kind": "spell", "id": sid, "ability": ab})
		var best := {}
		var best_val := 0.0
		for opt in options:
			var tgt := {}
			var exp := 0.0
			for e in b.monsters:  # lowest-hp enemy that isn't immune/absorbing
				if not e["alive"]:
					continue
				var v: float = b.expected_damage(opt["ability"], actor, e)
				if v <= 0.0:
					continue
				if tgt.is_empty() or int(e["resources"]["hp"]["cur"]) < int(tgt["resources"]["hp"]["cur"]):
					tgt = e
					exp = v
			if tgt.is_empty():
				continue
			if exp > best_val:  # strict: ties keep earlier option (list order)
				best_val = exp
				best = {"kind": opt["kind"], "target": tgt["key"]}
				if opt.has("id"):
					best["id"] = opt["id"]
				else:
					best.erase("id")
		return best
