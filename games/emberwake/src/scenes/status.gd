# scenes/status.gd — scene type "status" (scene-registry): one party member's
# full sheet — level/xp, resources, effective stats (through Game.stats, so
# equipment mods show), equipment slots, learned spells. move_left/right
# cycles members; cancel returns to the overworld pause menu.
extends Control

const UI := preload("res://scenes/ui.gd")

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _idx := 0
var _name: Label = null
var _sheet: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	UI.label(self, Vector2(24, 10), "Status", 20, UI.COL_EMBER)
	UI.label(self, Vector2(430, 16), "left/right: member", 12, UI.COL_BLUE)
	UI.panel(self, Rect2(24, 44, 592, 290))
	_name = UI.label(self, Vector2(40, 54), "", 18, UI.COL_WARM)
	_sheet = UI.label(self, Vector2(40, 84), "", 14)
	_render()

func _render() -> void:
	if _game.party.is_empty():
		_name.text = "(no party)"
		return
	_idx = clampi(_idx, 0, _game.party.size() - 1)
	var m: Dictionary = _game.party[_idx]
	var cdef: Dictionary = _db.cls(m["class"])
	var view: Dictionary = _game.stats.member_view(m)
	_name.text = "%s — %s, level %d" % [m["name"], cdef.get("name", ""), int(m["level"])]
	var lines: Array = []
	var next_lvl: int = int(m["level"]) + 1
	lines.append("XP %d  (next level at %d)" % [int(m["xp"]), _game.stats.xp_to_reach(next_lvl)])
	var res_bits: Array = []
	for rid in _db.resource_ids():
		res_bits.append("%s %d/%d" % [str(rid).to_upper(), int(m.get(rid, 0)),
				int(view["resources"][rid]["max"])])
	lines.append("  ".join(res_bits) + "    row: " + str(m.get("row", "front")))
	lines.append("")
	for sid in _db.stat_ids():
		lines.append("%-4s %3d" % [str(sid).to_upper(), roundi(_game.stats.effective_stat(view, sid))])
	lines.append("")
	for slot in cdef.get("equip_slots", []):
		var eq := str(m.get("equipment", {}).get(slot, ""))
		lines.append("%s: %s" % [slot, _db.equip(eq).get("name", "—") if eq != "" else "—"])
	lines.append("")
	var spell_names: Array = m.get("spells", []).map(func(sid: String) -> String:
		return str(_db.spell(sid).get("ability", {}).get("name", sid)))
	lines.append("Spells: " + (", ".join(spell_names) if not spell_names.is_empty() else "—"))
	_sheet.text = "\n".join(lines)

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _input.is_just_pressed("move_left"):
		_idx = (_idx - 1 + _game.party.size()) % maxi(1, _game.party.size())
		_render()
	elif _input.is_just_pressed("move_right"):
		_idx = (_idx + 1) % maxi(1, _game.party.size())
		_render()
	elif _input.is_just_pressed("cancel"):
		_leaving = true
		_game.goto_scene("overworld", {"menu": true,
				"menu_cursor": int(_game.scene_args.get("menu_cursor", 0))})

func m8_scene_type() -> String:
	return "status"

func m8_detail() -> Dictionary:
	return {"member": _idx}
