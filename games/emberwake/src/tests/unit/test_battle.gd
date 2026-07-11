# test_battle.gd — contract §7: full seeded battle vs FIXTURE monsters (exact
# round count & outcome), AI rule eligibility (when-predicates, cost gating),
# turn order. Every id below is a fixture defined inline — no game content.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const BattleScript := preload("res://engine/battle.gd")
const Algebra := preload("res://engine/algebra.gd")
const RngScript := preload("res://autoload/rng.gd")

class FixtureDb:
	const Alg := preload("res://engine/algebra.gd")
	const Formula := preload("res://engine/formula.gd")
	var errs: Array = []
	var classes_d := {}
	var spells_d := {}
	var items_d := {}
	var equip_d := {}
	var monsters_d := {}
	var curves_d := {
		"curve.fix_hp": {"kind": "table", "values": [20, 28, 36, 44, 52]},
		"curve.fix_xp": {"kind": "formula", "expr": "(source.level - 1) * 100"},
	}

	func _init() -> void:
		classes_d["class.fix_bruiser"] = {"id": "class.fix_bruiser",
				"base_stats": {"atk": 10, "def": 5, "agi": 8}, "growth": {"hp": "curve.fix_hp"}}
		classes_d["class.fix_sage"] = {"id": "class.fix_sage",
				"base_stats": {"atk": 2, "def": 3, "agi": 3}, "growth": {}}
		equip_d["equip.fix_club"] = {"id": "equip.fix_club", "slot": "weapon",
				"attack": {"value": {"op": "formula", "expr": "source.atk * 2"}, "accuracy": null}}
		equip_d["equip.fix_icebrand"] = {"id": "equip.fix_icebrand", "slot": "weapon",
				"attack": {"value": {"op": "formula", "expr": "source.atk * 2"}, "element": "fix_ice", "accuracy": null}}
		equip_d["equip.fix_plate"] = {"id": "equip.fix_plate", "slot": "body",
				"stat_mods": [{"stat": "def", "mod": "add", "value": {"op": "const", "n": 3}}]}
		items_d["item.fix_tonic"] = {"id": "item.fix_tonic", "use": _ab("use.fix_tonic",
				{"op": "single", "side": "ally"}, {"op": "heal", "value": 20})}
		spells_d["spell.fix_bolt"] = {"ability": _ab("spell.fix_bolt",
				{"op": "single", "side": "enemy"},
				{"op": "damage", "value": 30, "element": "fix_storm", "type": "magical"},
				{"mp": 5}), "learn": [{"class": "class.fix_sage", "at_level": 1}]}
		spells_d["spell.fix_mend"] = {"ability": _ab("spell.fix_mend",
				{"op": "single", "side": "ally"}, {"op": "heal", "value": 25}, {"mp": 4}),
				"learn": [{"class": "class.fix_sage", "at_level": 1}]}
		spells_d["spell.fix_brace"] = {"ability": _ab("spell.fix_brace",
				{"op": "single", "side": "ally"},
				{"op": "modify_stat", "stat": "def", "mod": "add", "value": 4, "duration": 3}, {"mp": 2}),
				"learn": [{"class": "class.fix_sage", "at_level": 1}]}
		spells_d["spell.fix_rain"] = {"ability": _ab("spell.fix_rain",
				{"op": "all", "side": "enemy"},
				{"op": "damage", "value": 10, "type": "magical"}, {"mp": 6}),
				"learn": [{"class": "class.fix_bruiser", "at_level": 2}]}
		monsters_d["monster.fix_dummy"] = _mon("monster.fix_dummy", 1,
				{"atk": 4, "def": 2, "agi": 5, "hp": 30},
				[_ab("bonk", {"op": "single", "side": "enemy"},
					{"op": "damage", "value": {"op": "formula", "expr": "source.atk * 2"}, "type": "physical"})],
				[{"weight": 1, "ability": "bonk"}],
				{"xp": 50, "gold": 7, "drops": [{"item": "item.fix_tonic", "chance": 1.0}]})
		monsters_d["monster.fix_racer"] = _mon("monster.fix_racer", 1,
				{"atk": 1, "def": 1, "agi": 8, "hp": 10},
				[_ab("nip", {"op": "single", "side": "enemy"}, {"op": "damage", "value": 1, "type": "fixed"})],
				[{"weight": 1, "ability": "nip"}], {})
		monsters_d["monster.fix_boulder"] = _mon("monster.fix_boulder", 1,
				{"atk": 1, "def": 50, "agi": 1, "hp": 10000},
				[_ab("pebble", {"op": "single", "side": "enemy"}, {"op": "damage", "value": 1, "type": "fixed"})],
				[{"weight": 1, "ability": "pebble"}], {})
		monsters_d["monster.fix_bully"] = _mon("monster.fix_bully", 3,
				{"atk": 30, "def": 5, "agi": 20, "hp": 200},
				[_ab("crush", {"op": "single", "side": "enemy"},
					{"op": "damage", "value": {"op": "formula", "expr": "source.atk * 2"}, "type": "physical"})],
				[{"weight": 1, "ability": "crush"}], {})
		monsters_d["monster.fix_sponge"] = _mon("monster.fix_sponge", 1,
				{"atk": 1, "def": 0, "agi": 1, "hp": 60},
				[_ab("nap", "self", "scan")],
				[{"when": {"op": "hp_below", "who": "source", "pct": 0.0}, "weight": 1, "ability": "nap"}],
				{"affinities": [{"element": "fix_ice", "relation": "absorb"}]})
		monsters_d["monster.fix_phaser"] = _mon("monster.fix_phaser", 1,
				{"atk": 5, "def": 2, "agi": 2, "hp": 40, "mp": 4},
				[_ab("weak_hit", {"op": "single", "side": "enemy"}, {"op": "damage", "value": 2, "type": "fixed"}),
				_ab("strong_hit", {"op": "single", "side": "enemy"}, {"op": "damage", "value": 20, "type": "fixed"}, {"mp": 5})],
				[{"when": {"op": "hp_below", "who": "source", "pct": 0.5}, "weight": 5, "ability": "strong_hit"},
				{"weight": 1, "ability": "weak_hit"},
				{"when": {"op": "hp_below", "who": "source", "pct": 0.5}, "weight": 2, "ability": "weak_hit"}],
				{})

	func _ab(id: String, target: Variant, effect: Variant, costs: Variant = null) -> Dictionary:
		var ab := {"id": id, "name": id, "trigger": "on_use", "target": target, "effect": effect}
		if costs != null:
			ab["costs"] = costs
		return Alg.norm_ability(ab, errs, id)

	func _mon(id: String, level: int, stats_v: Dictionary, abilities: Array, rules: Array, extra: Dictionary) -> Dictionary:
		var index := {}
		for ab in abilities:
			index[ab["id"]] = ab
		for r in rules:
			if r.has("when"):
				r["when"] = Alg.norm_predicate(r["when"], errs, id)
		var m := {"id": id, "name": id, "level": level, "stats": stats_v,
				"abilities": abilities, "_ability_index": index, "ai": {"rules": rules},
				"xp": 0, "gold": 0, "drops": []}
		m.merge(extra, true)
		return m

	func stat_ids() -> Array: return ["atk", "def", "agi"]
	func resource_ids() -> Array: return ["hp", "mp"]
	func stat_range(_s: String) -> Array: return [1, 99]
	func resource_def(rid: String) -> Dictionary:
		return {"hp": {"id": "hp", "max_formula": "source.def * 4"},
				"mp": {"id": "mp", "max_formula": "10"}}[rid]
	func speed_stat() -> String: return "agi"
	func multiplier(rel: String) -> float:
		return {"weak": 2.0, "resist": 0.5, "immune": 0.0, "absorb": -1.0}[rel]
	func curve(id: String) -> Dictionary: return curves_d.get(id, {})
	func xp_curve_id() -> String: return "curve.fix_xp"
	func damage_formula_ast(kind: String) -> Dictionary:
		var exprs := {"physical": "max(1, value - target.def)", "magical": "value"}
		return Formula.parse(exprs[kind], ["value"])["ast"]
	func status_def(id: String) -> Dictionary: return {}
	func cls(id: String) -> Dictionary: return classes_d.get(id, {})
	func spell(id: String) -> Dictionary: return spells_d.get(id, {})
	func item(id: String) -> Dictionary: return items_d.get(id, {})
	func equip(id: String) -> Dictionary: return equip_d.get(id, {})
	func monster(id: String) -> Dictionary: return monsters_d.get(id, {})
	func spells_for_class(class_id: String, level: int) -> Array:
		var out: Array = []
		for sid in spells_d:
			for l in spells_d[sid].get("learn", []):
				if l["class"] == class_id and int(l["at_level"]) <= level:
					out.append(sid)
		out.sort()
		return out

var _nodes: Array = []

func cleanup() -> void:
	for n in _nodes:
		n.free()

func _rng(seed_v: int) -> Node:
	var r: Node = RngScript.new()
	r.set_seed(seed_v)
	_nodes.append(r)
	return r

func _member(cls: String, extra: Dictionary = {}) -> Dictionary:
	var m := {"class": cls, "name": cls, "level": 1, "xp": 0,
			"equipment": {}, "spells": [], "row": "front"}
	m.merge(extra, true)
	return m

func _battle(members: Array, monster_ids: Array, inv: Dictionary = {}, seed_v: int = 42, opts: Dictionary = {}) -> RefCounted:
	return BattleScript.new(FixtureDb.new(), _rng(seed_v), members, monster_ids, inv, opts)

func test_full_battle_exact() -> void:
	# bruiser (club: 20 raw, agi 8, hp 20) vs dummy (hp 30, def 2, bonk 8 raw).
	# R1: 20->hit 18 (30->12), bonk 3 (20->17). R2: hit 18 kills. Win, round 2.
	var member := _member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_club"}})
	var inv := {}
	var b := _battle([member], ["monster.fix_dummy"], inv)
	var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
	T.eq(res["win"], true, "exact outcome: win")
	T.eq(res["rounds"], 2, "exact round count")
	T.eq(res["dmg_dealt"], 36, "damage dealt")
	T.eq(res["dmg_taken"], 3, "damage taken")
	T.eq(res["deaths"], 0, "no deaths")
	T.eq(res["mp_spent"], 0, "no mp spent")
	T.eq(res["party_hp_end_pct"], 0.85, "17/20 hp")
	T.eq(res["ability_usage"], {"attack": 2}, "ability usage")
	T.eq(res["rewards"]["xp"], 50, "xp reward")
	T.eq(res["rewards"]["gold"], 7, "gold reward")
	T.eq(inv, {"item.fix_tonic": 1}, "guaranteed drop applied to inventory")
	T.eq(member["xp"], 50, "xp written to member")
	T.eq(member["level"], 1, "below level 2 threshold (100)")
	T.eq(member["hp"], 17, "current hp written back")
	T.ok(b.events.size() > 0, "battle log emitted")
	for ev in b.events:
		for k in ["turn", "source", "ability", "effect_op", "target", "rolled", "result"]:
			if not ev.has(k):
				T.ok(false, "event missing key " + k)

func test_seeded_battles_reproduce() -> void:
	var r1: Dictionary = _battle([_member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_club"}})],
			["monster.fix_dummy", "monster.fix_dummy"], {}, 777).run(BattleScript.HeuristicV1.new())
	var r2: Dictionary = _battle([_member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_club"}})],
			["monster.fix_dummy", "monster.fix_dummy"], {}, 777).run(BattleScript.HeuristicV1.new())
	T.eq(r1, r2, "same seed, same fixture battle, same result")

func test_level_up_and_spell_learning() -> void:
	var member := _member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_club"}})
	var b := _battle([member], ["monster.fix_dummy", "monster.fix_dummy"])
	var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
	T.eq(res["win"], true, "win vs two dummies")
	T.eq(res["rounds"], 4, "exact rounds vs two dummies")
	T.eq(member["xp"], 100, "xp accumulates")
	T.eq(member["level"], 2, "level up at 100 xp (fixture curve)")
	T.ok("spell.fix_rain" in member["spells"], "level-up learns class spells")
	T.eq(member["hp"], 16, "hp current grew by max delta (8 + 28-20)")

func test_turn_order_speed_and_ties() -> void:
	# bruiser agi 8, racer agi 8 (tie: party first), dummy agi 5, sage agi 3.
	var b := _battle([_member("class.fix_bruiser"), _member("class.fix_sage")],
			["monster.fix_racer", "monster.fix_dummy"])
	b.begin()
	var keys: Array = b._order.map(func(e: Dictionary) -> String: return e["key"])
	T.eq(keys, ["p0", "m0", "m1", "p1"], "agility desc; tie party-first; then list order")
	# two same-speed monsters keep list order
	var b2 := _battle([_member("class.fix_sage")], ["monster.fix_racer", "monster.fix_racer"])
	b2.begin()
	var keys2: Array = b2._order.map(func(e: Dictionary) -> String: return e["key"])
	T.eq(keys2, ["m0", "m1", "p0"], "equal-speed monsters act in list order")

func test_ai_eligibility_when_and_costs() -> void:
	var b := _battle([_member("class.fix_bruiser")], ["monster.fix_phaser"])
	var m: Dictionary = b.monsters[0]
	var full: Array = b.eligible_rules(m)
	T.eq(full.size(), 1, "phase-2 rules gated by when-predicate at full hp")
	T.eq(full[0]["ability"], "weak_hit", "only the unconditional rule")
	m["resources"]["hp"]["cur"] = 10
	var low: Array = b.eligible_rules(m)
	T.eq(low.size(), 2, "when-rules join below 0.5 hp, unpayable costs stay gated")
	T.eq(low[0]["ability"], "weak_hit", "strong_hit filtered (mp 4 < cost 5)")
	T.eq(low[1]["ability"], "weak_hit", "second phase rule eligible")
	m["resources"]["mp"]["cur"] = 10
	m["resources"]["mp"]["max"] = 10
	T.eq(b.eligible_rules(m).size(), 3, "payable cost joins")
	T.eq(b.eligible_rules(m)[0]["ability"], "strong_hit", "rule order preserved")

func test_costs_payable() -> void:
	var b := _battle([_member("class.fix_sage")], ["monster.fix_dummy"], {"item.fix_tonic": 1})
	var sage: Dictionary = b.party[0]  # mp max 10
	T.ok(b.costs_payable(sage, {"id": "x", "costs": {"mp": 10}}), "mp at limit payable")
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"mp": 11}}), "mp over limit")
	T.ok(b.costs_payable(sage, {"id": "x", "costs": {"hp": 5}}), "hp cost payable")
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"hp": 12}}), "hp cost may not self-kill (12/12)")
	T.ok(b.costs_payable(sage, {"id": "x", "costs": {"item": "item.fix_tonic"}}), "item in stock")
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"item": "item.fix_missing"}}), "item out of stock")
	T.ok(b.costs_payable(sage, {"id": "x", "costs": {"row_lock": "front"}}), "row lock match")
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"row_lock": "back"}}), "row lock mismatch")
	sage["used_once"]["x"] = true
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"once_per_battle": true}}), "once per battle spent")
	sage["cooldowns"]["y"] = 2
	T.ok(not b.costs_payable(sage, {"id": "y", "costs": {"cooldown": 3}}), "cooling down")
	T.ok(not b.costs_payable(sage, {"id": "x", "costs": {"class_lock": ["class.fix_bruiser"]}}), "class lock")

func test_heuristic_heals_with_item_then_attacks() -> void:
	var hurt := _member("class.fix_bruiser", {"hp": 5})
	var sage := _member("class.fix_sage", {"spells": ["spell.fix_bolt", "spell.fix_mend"]})
	var b := _battle([hurt, sage], ["monster.fix_sponge"], {"item.fix_tonic": 1}, 42, {"max_rounds": 1})
	b.run(BattleScript.HeuristicV1.new())
	var party_evs: Array = b.events.filter(func(e: Dictionary) -> bool: return e["source"] == "p0" or e["source"] == "p1")
	T.eq(party_evs[0]["ability"], "use.fix_tonic", "rule 1: bruiser uses the heal item on itself")
	T.eq(party_evs[0]["target"], "p0", "heal targets lowest-hp ally")
	T.eq(party_evs[0]["effect_op"], "heal", "item heal applied")
	T.eq(b.metrics["items_used"], {"item.fix_tonic": 1}, "item consumption tracked")
	T.eq(party_evs[1]["ability"], "spell.fix_bolt", "rule 2: sage picks best expected damage (30 > fists 1)")
	T.eq(party_evs[1]["source"], "p1", "sage acted after heal resolved the emergency")

func test_heuristic_spell_heal_and_mp_spent() -> void:
	var hurt := _member("class.fix_bruiser", {"hp": 5, "equipment": {"weapon": "equip.fix_club"}})
	var sage := _member("class.fix_sage", {"spells": ["spell.fix_mend", "spell.fix_bolt"]})
	var b := _battle([hurt, sage], ["monster.fix_sponge"], {}, 42, {"max_rounds": 1})
	b.run(BattleScript.HeuristicV1.new())
	var sage_evs: Array = b.events.filter(func(e: Dictionary) -> bool: return e["source"] == "p1")
	T.eq(sage_evs[0]["ability"], "spell.fix_mend", "rule 1 via spell when no item held")
	T.eq(sage_evs[0]["target"], "p0", "heals the lowest-hp ally")
	T.eq(b.metrics["mp_spent"], 4, "mp cost tracked")

func test_heuristic_defends_when_all_absorbed() -> void:
	var member := _member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_icebrand"}})
	var b := _battle([member], ["monster.fix_sponge"], {}, 42, {"max_rounds": 2})
	var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
	var p_evs: Array = b.events.filter(func(e: Dictionary) -> bool: return e["source"] == "p0")
	T.eq(p_evs[0]["effect_op"], "defend", "rule 3: absorbing enemy is never attacked")
	var m_evs: Array = b.events.filter(func(e: Dictionary) -> bool: return e["source"] == "m0")
	T.eq(m_evs[0]["effect_op"], "defend", "monster with no eligible rules defends")
	T.eq(res["timeout"], true, "stalemate times out")
	T.eq(res["rounds"], 2, "timeout at max_rounds")

func test_wipe_and_deaths() -> void:
	var b := _battle([_member("class.fix_bruiser")], ["monster.fix_bully"])
	var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
	T.eq(res["wipe"], true, "party wiped")
	T.eq(res["win"], false, "no win")
	T.eq(res["rounds"], 1, "one-shot in round 1")
	T.eq(res["deaths"], 1, "death counted")
	T.eq(res["party_hp_end_pct"], 0.0, "no hp left")

func test_modify_stat_and_defend_mechanics() -> void:
	var bruiser := _member("class.fix_bruiser")
	var sage := _member("class.fix_sage", {"spells": ["spell.fix_brace"]})
	var b := _battle([bruiser, sage], ["monster.fix_sponge"])
	b.begin()
	T.eq(b.current_actor()["key"], "p0", "bruiser first (agi 8)")
	b.submit_command({"kind": "defend"})
	T.eq(b.current_actor()["key"], "p1", "sage next")
	b.submit_command({"kind": "spell", "id": "spell.fix_brace", "target": "p0"})
	var p0: Dictionary = b.party[0]
	T.eq(p0["mods"].size(), 1, "buff landed on bruiser")
	T.eq(p0["mods"][0]["duration"], 3, "not yet decremented (bruiser's turn end passed)")
	T.eq(b.stats.effective_stat(p0, "def"), 9.0, "modify_stat raises effective def (5+4)")
	T.ok(not p0["defending"], "defend guard expires at own next turn start")
	b.submit_command({"kind": "defend"})  # round 2, bruiser turn end reached
	T.eq(p0["mods"][0]["duration"], 2, "duration decrements on the affected entity's turn end")

func test_defend_and_row_halve_damage() -> void:
	# dummy bonk raw 8 - def 5 = 3; defending halves to 2 (roundi 1.5).
	var b := _battle([_member("class.fix_bruiser")], ["monster.fix_dummy"])
	b.begin()
	b.submit_command({"kind": "defend"})
	var hit: Dictionary = b.events.filter(func(e: Dictionary) -> bool: return e["effect_op"] == "damage")[0]
	T.eq(hit["result"], 2, "defend halves incoming damage")
	var b2 := _battle([_member("class.fix_bruiser", {"row": "back", "equipment": {"weapon": "equip.fix_club"}})],
			["monster.fix_dummy"])
	b2.begin()
	b2.submit_command({"kind": "attack", "target": "m0"})
	var evs: Array = b2.events.filter(func(e: Dictionary) -> bool: return e["effect_op"] == "damage")
	T.eq(evs[0]["result"], 9, "back row halves physical dealt (18 -> 9)")
	T.eq(evs[1]["result"], 2, "back row halves physical taken (3 -> 1.5 -> 2)")

func test_flee_deterministic() -> void:
	var outcomes: Array = []
	for i in 2:
		var b := _battle([_member("class.fix_bruiser")], ["monster.fix_sponge"], {}, 555, {"max_rounds": 1})
		b.begin()
		b.submit_command({"kind": "flee"})
		outcomes.append(b.outcome)
	T.eq(outcomes[0], outcomes[1], "same seed, same flee outcome")

func test_timeout() -> void:
	var b := _battle([_member("class.fix_bruiser", {"equipment": {"weapon": "equip.fix_club"}})],
			["monster.fix_boulder"], {}, 42, {"max_rounds": 3})
	var res: Dictionary = b.run(BattleScript.HeuristicV1.new())
	T.eq(res["timeout"], true, "unwinnable fight times out")
	T.eq(res["rounds"], 3, "rounds capped at max_rounds")
	T.eq(res["win"], false, "no win on timeout")
	T.eq(res["wipe"], false, "no wipe on timeout")
	T.eq(res["dmg_dealt"], 3, "chip damage floor of 1 per round")

func test_equipment_pipeline_and_rfc001_precedence() -> void:
	var b := _battle([_member("class.fix_bruiser", {"equipment": {"body": "equip.fix_plate"}})],
			["monster.fix_dummy"])
	var p0: Dictionary = b.party[0]
	T.eq(b.stats.effective_stat(p0, "def"), 8.0, "equipment add mod applies (5+3)")
	T.eq(p0["resources"]["hp"]["max"], 20, "growth-bound hp ignores def equipment (RFC-001 order)")
	var m0: Dictionary = b.monsters[0]
	T.eq(m0["resources"]["hp"]["max"], 30, "monster explicit hp override")
	T.eq(m0["resources"]["mp"]["max"], 10, "monster mp falls through to max_formula")
