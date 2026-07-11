# scenes/title.gd — scene type "title" (scene-registry; engine contract §8).
# New Game / Continue; Continue hidden when no save slots exist (title is the
# project main scene, so it renders before any Game run exists).
extends Control

const UI := preload("res://scenes/ui.gd")

@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _menu := UI.Menu.new()
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	UI.label(self, Vector2(200, 90), "E M B E R W A K E", 36, UI.COL_EMBER)
	UI.label(self, Vector2(160, 140), "The wells run warm. The mountain is waking.", 14, UI.COL_BLUE)
	var rows: Array = [{"label": "New Game", "data": "new"}]
	if not _game.save_slots().is_empty():
		rows.append({"label": "Continue", "data": "continue"})
	_menu.attach(self, Vector2(272, 210), 18)
	_menu.set_entries(rows)

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _menu.nav(_input) == "confirm":
		_leaving = true
		match _menu.selected().get("data", ""):
			"new":
				_game.goto_scene("party_builder", {})
			"continue":
				_game.goto_scene("save_load", {"mode": "load"})

func m8_scene_type() -> String:
	return "title"

func m8_detail() -> Dictionary:
	return {"cursor": _menu.cursor, "rows": _menu.entries.size()}
