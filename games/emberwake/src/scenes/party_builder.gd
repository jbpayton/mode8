# scenes/party_builder.gd — scene type "party_builder" (scene-registry;
# GDD cast_model=player_built). One class pick per slot (party size from
# Game.party_size(), GDD binding), default names from class display names
# (duplicate class -> "Name II"); Begin starts the run via Game.new_run
# (G-004 purse) and lands on the overworld at world.start with arrival
# triggers armed (G-005). Cancel steps back one slot, then to title.
extends Control

const UI := preload("res://scenes/ui.gd")

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _class_ids: Array = []
var _picks: Array = []      # {"class": id, "name": String}
var _slot := 0
var _phase := "pick"        # "pick" | "begin"
var _menu := UI.Menu.new()
var _begin_menu := UI.Menu.new()
var _slot_labels: Array = []
var _desc: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	UI.label(self, Vector2(40, 24), "Choose the two who go down", 22, UI.COL_EMBER)
	_class_ids = _db.classes.keys()
	UI.panel(self, Rect2(40, 64, 250, 120))
	for i in _game.party_size():
		_slot_labels.append(UI.label(self, Vector2(56, 80 + i * 28), "", 16))
	_menu.attach(self, Vector2(340, 80), 18)
	_menu.set_entries(_class_ids.map(func(cid: String) -> Dictionary:
		return {"label": _db.cls(cid).get("name", cid), "data": cid}))
	_desc = UI.label(self, Vector2(40, 210), "", 13, UI.COL_BLUE)
	_desc.custom_minimum_size = Vector2(560, 0)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_begin_menu.attach(self, Vector2(340, 80), 18)
	_begin_menu.set_entries([{"label": "Begin the descent", "data": "go"}])
	_begin_menu.set_visible(false)
	_refresh()

func _refresh() -> void:
	for i in _slot_labels.size():
		var text := "Slot %d: —" % (i + 1)
		if i < _picks.size():
			text = "Slot %d: %s (%s)" % [i + 1, _picks[i]["name"], _db.cls(_picks[i]["class"]).get("name", "")]
		elif i == _slot and _phase == "pick":
			text = "Slot %d: choosing..." % (i + 1)
		_slot_labels[i].text = text
		_slot_labels[i].add_theme_color_override("font_color",
				UI.COL_WARM if i < _picks.size() else UI.COL_TEXT)
	if _phase == "pick":
		_desc.text = str(_db.cls(_menu.selected().get("data", "")).get("description", ""))
	else:
		_desc.text = "Cinderfall waits. Cancel to rechoose."
	_menu.set_visible(_phase == "pick")
	_begin_menu.set_visible(_phase == "begin")

func _default_name(cid: String) -> String:
	var base := str(_db.cls(cid).get("name", cid))
	for p in _picks:
		if p["class"] == cid:
			return base + " II"
	return base

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _phase == "pick":
		match _menu.nav(_input):
			"confirm":
				var cid: String = _menu.selected()["data"]
				_picks.append({"class": cid, "name": _default_name(cid)})
				_slot += 1
				if _picks.size() >= _game.party_size():
					_phase = "begin"
			"cancel":
				if _picks.is_empty():
					_leaving = true
					_game.goto_scene("title", {})
					return
				_picks.pop_back()
				_slot -= 1
		_refresh()
	else:
		match _begin_menu.nav(_input):
			"confirm":
				_leaving = true
				_game.new_run(_picks)
				_game.goto_scene("overworld", {"arrive": true})
			"cancel":
				_picks.pop_back()
				_slot -= 1
				_phase = "pick"
				_refresh()

func m8_scene_type() -> String:
	return "party_builder"

func m8_detail() -> Dictionary:
	return {"slot": _slot, "phase": _phase,
			"cursor": _menu.cursor if _phase == "pick" else _begin_menu.cursor,
			"picks": _picks.map(func(p: Dictionary) -> String: return str(p["class"]))}
