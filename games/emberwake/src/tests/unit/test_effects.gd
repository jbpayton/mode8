# test_effects.gd — contract §7: damage routing (physical/magical/fixed,
# element x, variance seeded, pierce, crit), heal clamps, apply_status
# stacking + tick + expiry, modify_stat duration, resource, revive,
# seq/choice/repeat/branch + conditional normalization. All ids are FIXTURES.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const Algebra := preload("res://engine/algebra.gd")
const RngScript := preload("res://autoload/rng.gd")

class FakeDb:
	const Formula := preload("res://engine/formula.gd")
	var statuses := {
		"st.fix_venom": {"id": "st.fix_venom", "stacking": "refresh",
			"tick": {"trigger": {"op": "on_turn_end"},
				"effect": {"op": "damage", "value": {"op": "formula", "expr": "source.potency"}, "type": "fixed"}}},
		"st.fix_brittle": {"id": "st.fix_brittle", "stacking": "stack", "max_stacks": 2},
		"st.fix_dazed": {"id": "st.fix_dazed", "stacking": "ignore"},
	}
	func status_def(id: String) -> Dictionary:
		return statuses.get(id, {})
	func multiplier(rel: String) -> float:
		return {"weak": 2.0, "resist": 0.5, "immune": 0.0, "absorb": -1.0}[rel]
	func damage_formula_ast(kind: String) -> Dictionary:
		var exprs := {"physical": "max(1, value - target.def)",
				"magical": "max(1, value * 100 / (100 + target.res * 2))"}
		return Formula.parse(exprs[kind], ["value"])["ast"]

var _nodes: Array = []
var events: Array = []

func cleanup() -> void:
	for n in _nodes:
		n.free()

func _alg(seed_v: int = 1) -> Object:
	var rng: Node = RngScript.new()
	rng.set_seed(seed_v)
	_nodes.append(rng)
	var a: Object = Algebra.new(FakeDb.new(), rng)
	events = []
	a.log_cb = func(e: Dictionary) -> void: events.append(e)
	a.turn_no = 9
	return a

func _ent(key: String, stats: Dictionary = {}, hp := 40, hp_max := 40) -> Dictionary:
	return {"key": key, "id": key, "level": 1, "stats": stats, "alive": true,
			"resources": {"hp": {"cur": hp, "max": hp_max}, "mp": {"cur": 10, "max": 30}},
			"statuses": [], "mods": [], "affinities": [], "status_immunity": []}

func _dmg(value: Variant, type := "physical", extra := {}) -> Dictionary:
	var e := {"op": "damage", "value": value, "type": type}
	e.merge(extra)
	var errs: Array = []
	e = Algebra.norm_effect(e, errs, "fix")
	T.eq(errs, [], "fixture normalizes clean")
	return e

func test_damage_physical() -> void:
	var a := _alg()
	var src := _ent("s", {"atk": 10})
	var tgt := _ent("t", {"def": 6})
	a.apply_effect(_dmg({"op": "formula", "expr": "source.atk * 2"}), src, tgt, "fix.hit")
	T.eq(tgt["resources"]["hp"]["cur"], 26, "20 raw - 6 def = 14")
	T.eq(events.size(), 1, "one battle-log event")
	var ev: Dictionary = events[0]
	T.eq(ev["effect_op"], "damage", "event op")
	T.eq(ev["result"], 14, "event result")
	T.eq(ev["turn"], 9, "event turn")
	T.eq(ev["source"], "s", "event source key")
	T.eq(ev["target"], "t", "event target key")
	T.eq(ev["ability"], "fix.hit", "event ability")

func test_damage_magical() -> void:
	var a := _alg()
	var tgt := _ent("t", {"res": 10})
	a.apply_effect(_dmg(20, "magical"), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 23, "20*100/120 = 16.67 -> 17")

func test_damage_fixed_bypasses_all() -> void:
	var a := _alg()
	var tgt := _ent("t", {"def": 99})
	tgt["affinities"] = [{"element": "fix_fire", "relation": "weak"}]
	a.apply_effect(_dmg(5, "fixed", {"element": "fix_fire"}), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 35, "fixed ignores defense and affinity")

func test_element_multipliers() -> void:
	for pair in [["weak", 16], ["resist", 34], ["immune", 40]]:
		var a := _alg()
		var tgt := _ent("t", {"res": 0})
		tgt["affinities"] = [{"element": "fix_fire", "relation": pair[0]}]
		a.apply_effect(_dmg(12, "magical", {"element": "fix_fire"}), _ent("s"), tgt, "fix")
		T.eq(tgt["resources"]["hp"]["cur"], pair[1], "%s multiplier" % pair[0])
	var a2 := _alg()
	var ab := _ent("t", {"res": 0}, 20)
	ab["affinities"] = [{"element": "fix_fire", "relation": "absorb"}]
	a2.apply_effect(_dmg(12, "magical", {"element": "fix_fire"}), _ent("s"), ab, "fix")
	T.eq(ab["resources"]["hp"]["cur"], 32, "absorb heals")
	T.eq(events[0]["result"], -12, "absorb result is negative")

func test_variance_seeded() -> void:
	var a := _alg(77)
	var tgt := _ent("t", {"def": 0})
	a.apply_effect(_dmg(20, "physical", {"variance": 0.1}), _ent("s"), tgt, "fix")
	var ref: Node = RngScript.new()
	ref.set_seed(77)
	var expected := roundi(maxf(1.0, 20.0 * ref.randf_range(0.9, 1.1)))
	ref.free()
	T.eq(tgt["resources"]["hp"]["cur"], 40 - expected, "variance draws exactly one seeded roll")
	var b := _alg(77)
	var tgt2 := _ent("t", {"def": 0})
	b.apply_effect(_dmg(20, "physical", {"variance": 0.1}), _ent("s"), tgt2, "fix")
	T.eq(tgt2["resources"]["hp"]["cur"], tgt["resources"]["hp"]["cur"], "same seed same damage")

func test_pierce() -> void:
	var a := _alg()
	var tgt := _ent("t", {"def": 8})
	a.apply_effect(_dmg(10, "physical", {"pierce": 1.0}), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 30, "pierce 1.0 bypasses mitigation")
	var tgt2 := _ent("t", {"def": 8})
	a.apply_effect(_dmg(10, "physical", {"pierce": 0.5}), _ent("s"), tgt2, "fix")
	T.eq(tgt2["resources"]["hp"]["cur"], 34, "pierce 0.5 blends raw and mitigated")

func test_crit() -> void:
	var a := _alg()
	var tgt := _ent("t")
	a.apply_effect(_dmg(10, "fixed", {"crit": {"rate": 1.0, "mult": 2.0}}), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 20, "guaranteed crit doubles")
	T.eq(events[0]["rolled"]["crit"], true, "crit recorded in event roll")
	var tgt2 := _ent("t")
	a.apply_effect(_dmg(10, "fixed", {"crit": {"rate": 0.0, "mult": 2.0}}), _ent("s"), tgt2, "fix")
	T.eq(tgt2["resources"]["hp"]["cur"], 30, "rate 0 never crits")

func test_damage_kills_and_clamps() -> void:
	var a := _alg()
	var tgt := _ent("t", {}, 5)
	tgt["statuses"] = [{"id": "st.fix_dazed", "duration": null, "potency": null}]
	a.apply_effect(_dmg(99, "fixed"), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 0, "hp clamps at 0")
	T.ok(not tgt["alive"], "death at 0 hp")
	T.eq(tgt["statuses"], [], "statuses drop on death")

func test_heal_clamps() -> void:
	var a := _alg()
	var tgt := _ent("t", {}, 20, 30)
	a.apply_effect(Algebra.norm_effect({"op": "heal", "value": 50}, [], "fix"), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 30, "heal clamps to max")
	T.eq(events[0]["result"], 10, "event reports actual healed")
	var dead := _ent("d", {}, 0)
	dead["alive"] = false
	a.apply_effect(Algebra.norm_effect({"op": "heal", "value": 50}, [], "fix"), _ent("s"), dead, "fix")
	T.eq(dead["resources"]["hp"]["cur"], 0, "heal cannot touch the dead")
	T.ok(not dead["alive"], "dead stay dead")

func test_apply_status_stacking() -> void:
	var a := _alg()
	var tgt := _ent("t")
	var venom := {"op": "apply_status", "status": "st.fix_venom", "duration": 3, "potency": 5, "chance": 1.0}
	venom = Algebra.norm_effect(venom, [], "fix")
	a.apply_effect(venom, _ent("s"), tgt, "fix")
	T.eq(tgt["statuses"].size(), 1, "applied")
	T.eq(tgt["statuses"][0]["duration"], 3, "duration from apply_status")
	a.expire_statuses(tgt)
	T.eq(tgt["statuses"][0]["duration"], 2, "duration ticked down")
	a.apply_effect(venom, _ent("s"), tgt, "fix")
	T.eq(tgt["statuses"][0]["duration"], 3, "refresh stacking resets the clock")
	T.eq(tgt["statuses"].size(), 1, "refresh does not add instances")
	var brittle : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_brittle", "duration": 2, "chance": 1.0}, [], "fix")
	for i in 3:
		a.apply_effect(brittle, _ent("s"), tgt, "fix")
	var count := 0
	for s in tgt["statuses"]:
		if s["id"] == "st.fix_brittle":
			count += 1
	T.eq(count, 2, "stack stacking respects max_stacks")
	var dazed : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_dazed", "duration": 4, "chance": 1.0}, [], "fix")
	a.apply_effect(dazed, _ent("s"), tgt, "fix")
	tgt["statuses"][-1]["duration"] = 1
	a.apply_effect(dazed, _ent("s"), tgt, "fix")
	T.eq(tgt["statuses"][-1]["duration"], 1, "ignore stacking does nothing on re-application")

func test_apply_status_chance_and_immunity() -> void:
	var a := _alg()
	var tgt := _ent("t")
	var never : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_venom", "duration": 3, "chance": 0.0}, [], "fix")
	a.apply_effect(never, _ent("s"), tgt, "fix")
	T.eq(tgt["statuses"], [], "chance 0 never lands")
	T.eq(events[0]["result"], 0, "failed application emits result 0")
	var immune := _ent("i")
	immune["status_immunity"] = ["st.fix_venom"]
	var always : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_venom", "duration": 3, "chance": 1.0}, [], "fix")
	a.apply_effect(always, _ent("s"), immune, "fix")
	T.eq(immune["statuses"], [], "status immunity blocks")

func test_status_tick_and_expiry() -> void:
	var a := _alg()
	var tgt := _ent("t", {}, 20)
	var venom : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_venom", "duration": 2, "potency": {"op": "formula", "expr": "source.mag"}, "chance": 1.0}, [], "fix")
	var caster := _ent("s", {"mag": 4})
	a.apply_effect(venom, caster, tgt, "fix")
	T.eq(tgt["statuses"][0]["potency"], 4.0, "potency evaluated against the CASTER at apply time")
	a.run_status_ticks(tgt, "on_turn_end")
	T.eq(tgt["resources"]["hp"]["cur"], 16, "tick deals fixed potency damage")
	T.eq(events[-1]["ability"], "st.fix_venom", "tick event attributed to the status")
	a.expire_statuses(tgt)
	T.eq(tgt["statuses"][0]["duration"], 1, "one round left")
	a.run_status_ticks(tgt, "on_turn_end")
	a.expire_statuses(tgt)
	T.eq(tgt["resources"]["hp"]["cur"], 12, "second tick")
	T.eq(tgt["statuses"], [], "expired after duration")
	a.run_status_ticks(tgt, "on_turn_end")
	T.eq(tgt["resources"]["hp"]["cur"], 12, "no tick after expiry")
	var forever : Dictionary = Algebra.norm_effect({"op": "apply_status", "status": "st.fix_dazed", "duration": null, "chance": 1.0}, [], "fix")
	a.apply_effect(forever, caster, tgt, "fix")
	a.expire_statuses(tgt)
	T.eq(tgt["statuses"].size(), 1, "duration null persists until cured")

func test_cure_status() -> void:
	var a := _alg()
	var tgt := _ent("t")
	tgt["statuses"] = [{"id": "st.fix_venom", "duration": 2, "potency": 1},
			{"id": "st.fix_dazed", "duration": null, "potency": null}]
	a.apply_effect(Algebra.norm_effect({"op": "cure_status", "statuses": ["st.fix_venom"]}, [], "fix"), _ent("s"), tgt, "fix")
	T.eq(tgt["statuses"].size(), 1, "only listed statuses cured")
	T.eq(tgt["statuses"][0]["id"], "st.fix_dazed", "other status kept")
	T.eq(events[0]["result"], 1, "cure count in event")

func test_modify_stat_duration() -> void:
	var a := _alg()
	var tgt := _ent("t", {"def": 6})
	var buff : Dictionary = Algebra.norm_effect({"op": "modify_stat", "stat": "def", "mod": "add",
			"value": {"op": "formula", "expr": "source.def // 2"}, "duration": 2}, [], "fix")
	var caster := _ent("s", {"def": 9})
	a.apply_effect(buff, caster, tgt, "fix")
	T.eq(tgt["mods"].size(), 1, "mod recorded")
	T.eq(tgt["mods"][0]["value"], 4.0, "value evaluated at cast time against caster (9//2)")
	a.expire_mods(tgt)
	T.eq(tgt["mods"][0]["duration"], 1, "duration decrements on affected entity's turn end")
	a.expire_mods(tgt)
	T.eq(tgt["mods"], [], "mod expires at 0")

func test_resource() -> void:
	var a := _alg()
	var tgt := _ent("t")
	a.apply_effect(Algebra.norm_effect({"op": "resource", "pool": "mp", "delta": 99}, [], "fix"), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["mp"]["cur"], 30, "resource clamps to max")
	T.eq(events[0]["result"], 20, "event reports applied delta")
	a.apply_effect(Algebra.norm_effect({"op": "resource", "pool": "mp", "delta": -99}, [], "fix"), _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["mp"]["cur"], 0, "resource clamps to 0")
	a.apply_effect(Algebra.norm_effect({"op": "resource", "pool": "hp", "delta": -99}, [], "fix"), _ent("s"), tgt, "fix")
	T.ok(not tgt["alive"], "draining hp to 0 kills")

func test_revive() -> void:
	var a := _alg()
	var dead := _ent("d", {}, 0)
	dead["alive"] = false
	a.apply_effect(Algebra.norm_effect({"op": "revive", "pct": 0.5}, [], "fix"), _ent("s"), dead, "fix")
	T.ok(dead["alive"], "revived")
	T.eq(dead["resources"]["hp"]["cur"], 20, "revive to pct of max")
	a.apply_effect(Algebra.norm_effect({"op": "revive", "pct": 0.5}, [], "fix"), _ent("s"), dead, "fix")
	T.eq(events[-1]["result"], 0, "revive on living does nothing")

func test_seq_and_repeat() -> void:
	var a := _alg()
	var tgt := _ent("t")
	var seq : Dictionary = Algebra.norm_effect({"op": "seq", "effects": [
			{"op": "damage", "value": 3, "type": "fixed"},
			{"op": "damage", "value": 4, "type": "fixed"}]}, [], "fix")
	a.apply_effect(seq, _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 33, "seq applies in order to same target")
	T.eq(events.size(), 2, "each atomic emits")
	var rep : Dictionary = Algebra.norm_effect({"op": "repeat", "n": 3, "effect": {"op": "damage", "value": 2, "type": "fixed"}}, [], "fix")
	a.apply_effect(rep, _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 27, "repeat n times")

func test_choice_seeded() -> void:
	var first : Dictionary = Algebra.norm_effect({"op": "choice", "options": [
			{"weight": 1, "effect": {"op": "damage", "value": 5, "type": "fixed"}},
			{"weight": 0, "effect": {"op": "damage", "value": 50, "type": "fixed"}}]}, [], "fix")
	var a := _alg()
	var tgt := _ent("t")
	a.apply_effect(first, _ent("s"), tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 35, "zero-weight option never picked")
	var mixed : Dictionary = Algebra.norm_effect({"op": "choice", "options": [
			{"weight": 2, "effect": {"op": "damage", "value": 1, "type": "fixed"}},
			{"weight": 3, "effect": {"op": "damage", "value": 2, "type": "fixed"}}]}, [], "fix")
	var b := _alg(1234)
	var c := _alg(1234)
	var tb := _ent("t")
	var tc := _ent("t")
	for i in 6:
		b.apply_effect(mixed, _ent("s"), tb, "fix")
	events = []
	for i in 6:
		c.apply_effect(mixed, _ent("s"), tc, "fix")
	T.eq(tb["resources"]["hp"]["cur"], tc["resources"]["hp"]["cur"], "seeded weighted picks reproduce")

func test_branch_and_conditional_normalization() -> void:
	var a := _alg()
	var hurt := _ent("s", {}, 10)
	var fine := _ent("s2", {}, 40)
	var tgt := _ent("t")
	var br : Dictionary = Algebra.norm_effect({"op": "branch",
			"if": {"op": "hp_below", "who": "source", "pct": 0.5},
			"then": {"op": "damage", "value": 8, "type": "fixed"},
			"else": {"op": "damage", "value": 2, "type": "fixed"}}, [], "fix")
	a.apply_effect(br, hurt, tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 32, "then branch")
	a.apply_effect(br, fine, tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 30, "else branch")
	var errs: Array = []
	var cond: Variant = Algebra.norm_effect({"op": "conditional",
			"if": {"op": "hp_below", "who": "source", "pct": 0.5},
			"then": {"op": "damage", "value": 8, "type": "fixed"}}, errs, "fix")
	T.eq(errs, [], "conditional accepted")
	T.eq(cond["op"], "branch", "conditional normalizes to branch (RFC-000)")
	a.apply_effect(cond, fine, tgt, "fix")
	T.eq(tgt["resources"]["hp"]["cur"], 30, "branch without else is a no-op when false")

func test_set_flag() -> void:
	var a := _alg()
	a.apply_effect(Algebra.norm_effect({"op": "set_flag", "id": "flag.fix_won"}, [], "fix"), _ent("s"), _ent("t"), "fix")
	T.ok("flag.fix_won" in a.flags, "flag set")
	T.ok(a.eval_predicate({"op": "flag", "id": "flag.fix_won"}, null, null), "flag readable by predicates")

func test_unknown_effect_op_rejected() -> void:
	var errs: Array = []
	Algebra.norm_effect({"op": "seq", "effects": [{"op": "detonate_moon"}]}, errs, "fix")
	T.ok(errs.size() == 1, "unknown op is a load-time error")
	T.ok("detonate_moon" in errs[0], "error names the op")
