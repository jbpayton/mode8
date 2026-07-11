# scenes/inventory.gd — scene type "inventory" (scene-registry: use/equip/
# discard). Party inventory + members; Use applies menu-usable item effects
# through Game.use_item_on_member (03b accessor), Equip swaps gear on a valid
# member (class_lock + class equip_slots), Discard requires a confirm step
# (ux_conventions: never destructive without confirm; key items refuse).
# Cancel returns to the overworld pause menu (one level back).
extends Control

const UI := preload("res://scenes/ui.gd")

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _phase := "list"      # list | action | member | discard
var _list := UI.Menu.new()
var _action := UI.Menu.new()
var _member := UI.Menu.new()
var _discard := UI.Menu.new()
var _msg: Label = null
var _gold: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	UI.label(self, Vector2(24, 10), "Packs", 20, UI.COL_EMBER)
	UI.panel(self, Rect2(24, 44, 300, 280))
	_list.attach(self, Vector2(38, 56), 14)
	var side := UI.panel(self, Rect2(348, 44, 268, 280))
	_action.attach(side, Vector2(14, 12), 14)
	_member.attach(side, Vector2(14, 12), 13)
	_discard.attach(side, Vector2(14, 12), 14)
	_msg = UI.label(self, Vector2(24, 332), "", 13, UI.COL_WARM)
	_gold = UI.label(self, Vector2(500, 10), "", 14, UI.COL_WARM)
	_rebuild_list()
	_show_phase("list")

func _goods_name(id: String) -> String:
	var d: Dictionary = _db.item(id)
	if d.is_empty():
		d = _db.equip(id)
	return str(d.get("name", id))

func _rebuild_list() -> void:
	_gold.text = "Gold: %d" % _game.gold
	var rows: Array = []
	for id in _game.inventory:
		rows.append({"label": "%s x%d" % [_goods_name(id), _game.item_count(id)], "data": id})
	if rows.is_empty():
		rows.append({"label": "(nothing carried)", "data": "", "disabled": true})
	_list.set_entries(rows)

func _show_phase(p: String) -> void:
	_phase = p
	_action.set_visible(p == "action")
	_member.set_visible(p == "member")
	_discard.set_visible(p == "discard")

func _open_action() -> void:
	var id: String = _list.selected().get("data", "")
	var rows: Array = []
	var idef: Dictionary = _db.item(id)
	if idef.has("use") and "menu" in idef.get("usable_in", []):
		rows.append({"label": "Use", "data": "use"})
	if not _db.equip(id).is_empty():
		rows.append({"label": "Equip", "data": "equip"})
	rows.append({"label": "Discard", "data": "discard", "disabled": idef.get("kind", "") == "key"})
	_action.cursor = 0
	_action.set_entries(rows)
	_show_phase("action")

# Member rows for Use (target-op filtered) or Equip (class/slot filtered).
func _open_member(verb: String) -> void:
	var id: String = _list.selected().get("data", "")
	var rows: Array = []
	for i in _game.party.size():
		var m: Dictionary = _game.party[i]
		var ok := true
		if verb == "use":
			var wants_dead: bool = _db.item(id).get("use", {}).get("target", {}).get("op", "") == "dead"
			ok = wants_dead == (int(m.get("hp", 0)) <= 0)
		else:
			var eq: Dictionary = _db.equip(id)
			var lock: Array = eq.get("class_lock", [])
			ok = (lock.is_empty() or m["class"] in lock) \
					and eq.get("slot", "") in _db.cls(m["class"]).get("equip_slots", [])
		var bits := ""
		for rid in _db.resource_ids():
			var view: Dictionary = _game.stats.member_view(m)
			bits += " %s %d/%d" % [str(rid).to_upper(), int(m.get(rid, 0)), int(view["resources"][rid]["max"])]
		rows.append({"label": str(m["name"]) + bits, "data": i, "disabled": not ok})
	rows.append({"label": "Back", "data": -1})
	_member.cursor = 0
	_member.set_entries(rows)
	_show_phase("member")

func _process(_delta: float) -> void:
	if _leaving:
		return
	match _phase:
		"list":
			_list_input()
		"action":
			_action_input()
		"member":
			_member_input()
		"discard":
			_discard_input()

func _list_input() -> void:
	match _list.nav(_input):
		"cancel":
			_leaving = true
			_game.goto_scene("overworld", {"menu": true,
					"menu_cursor": int(_game.scene_args.get("menu_cursor", 0))})
		"confirm":
			_msg.text = ""
			_open_action()

func _action_input() -> void:
	match _action.nav(_input):
		"cancel":
			_show_phase("list")
		"confirm":
			match _action.selected().get("data", ""):
				"use", "equip":
					_open_member(str(_action.selected()["data"]))
				"discard":
					_discard.cursor = 0
					_discard.set_entries([
						{"label": "Throw one away", "data": "yes"},
						{"label": "Keep it", "data": "no"}])
					_show_phase("discard")

func _member_input() -> void:
	match _member.nav(_input):
		"cancel":
			_show_phase("action")
		"confirm":
			var idx := int(_member.selected().get("data", -1))
			if idx < 0:
				_show_phase("action")
				return
			var id: String = _list.selected().get("data", "")
			if _action.selected().get("data", "") == "use":
				var res: Dictionary = _game.use_item_on_member(id, idx)
				_msg.text = "Used %s on %s." % [_goods_name(id), _game.party[idx]["name"]] \
						if res.get("ok", false) else str(res.get("error", ""))
			else:
				_equip(id, idx)
			_rebuild_list()
			_show_phase("list")

func _equip(id: String, idx: int) -> void:
	var member: Dictionary = _game.party[idx]
	var slot := str(_db.equip(id).get("slot", ""))
	var old := str(member.get("equipment", {}).get(slot, ""))
	member["equipment"][slot] = id
	_game.remove_item(id)
	if old != "":
		_game.add_item(old)
	_msg.text = "%s equips %s." % [member["name"], _goods_name(id)]

func _discard_input() -> void:
	match _discard.nav(_input):
		"cancel":
			_show_phase("action")
		"confirm":
			if _discard.selected().get("data", "") == "yes":
				var id: String = _list.selected().get("data", "")
				_game.remove_item(id)
				_msg.text = "Discarded %s." % _goods_name(id)
				_rebuild_list()
			_show_phase("list")

func m8_scene_type() -> String:
	return "inventory"

func m8_detail() -> Dictionary:
	return {"phase": _phase, "cursor": _list.cursor,
			"item": _list.selected().get("data", ""), "msg": _msg.text}
