# scenes/save_load.gd — scene type "save_load" (scene-registry; contract §4).
# Three slots (user://saves/slot_<n>.json via Game.save_game/load_game).
# scene_args.mode: "save" (from the overworld pause menu / inn — save points
# per world place services) or "load" (from title Continue). Writing a slot
# always passes a confirm prompt (uniform for empty/occupied: never
# destructive without confirm, and scripts stay deterministic across reruns).
extends Control

const UI := preload("res://scenes/ui.gd")
const SLOTS := 3

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _mode := "save"
var _phase := "slots"     # slots | prompt
var _slots := UI.Menu.new()
var _prompt := UI.Menu.new()
var _msg: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	_mode = str(_game.scene_args.get("mode", "save"))
	UI.label(self, Vector2(24, 10), "Save" if _mode == "save" else "Load", 20, UI.COL_EMBER)
	UI.panel(self, Rect2(24, 44, 592, 220))
	_slots.attach(self, Vector2(40, 60), 15)
	_prompt.attach(self, Vector2(40, 280), 14)
	_prompt.set_visible(false)
	_msg = UI.label(self, Vector2(24, 332), "", 13, UI.COL_WARM)
	_rebuild()

func _slot_label(n: int) -> Dictionary:
	var snap: Dictionary = _game.peek_save(n)
	if snap.has("error"):
		return {"label": "Slot %d — empty" % n, "data": n, "disabled": _mode == "load"}
	var names: Array = snap.get("party", []).map(func(m: Dictionary) -> String:
		return "%s L%d" % [m.get("name", "?"), int(m.get("level", 1))])
	var place: String = str(_db.map_def(str(snap.get("map", ""))).get("name", snap.get("map", "")))
	return {"label": "Slot %d — %s · %s · %d g" % [n, ", ".join(names), place, int(snap.get("gold", 0))],
			"data": n}

func _rebuild() -> void:
	var rows: Array = []
	for n in range(1, SLOTS + 1):
		rows.append(_slot_label(n))
	_slots.set_entries(rows)

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _phase == "slots":
		_slots_input()
	else:
		_prompt_input()

func _slots_input() -> void:
	match _slots.nav(_input):
		"cancel":
			_leaving = true
			if _mode == "load":
				_game.goto_scene("title", {})
			else:
				_game.goto_scene("overworld", {"menu": true,
						"menu_cursor": int(_game.scene_args.get("menu_cursor", 0))})
		"confirm":
			var n := int(_slots.selected()["data"])
			if _mode == "load":
				if _game.load_game(n):
					_leaving = true
					_game.goto_scene("overworld", {})  # no arrival triggers on load
				else:
					_msg.text = "That slot won't read."
			else:
				_phase = "prompt"
				_prompt.cursor = 0
				_prompt.set_entries([{"label": "Write save to slot %d" % n, "data": n},
						{"label": "Not here", "data": -1}])
				_prompt.set_visible(true)

func _prompt_input() -> void:
	match _prompt.nav(_input):
		"cancel":
			_phase = "slots"
			_prompt.set_visible(false)
		"confirm":
			var n := int(_prompt.selected()["data"])
			if n > 0:
				_msg.text = "Saved." if _game.save_game(n) else "Could not write the slot."
				_rebuild()
			_phase = "slots"
			_prompt.set_visible(false)

func m8_scene_type() -> String:
	return "save_load"

func m8_detail() -> Dictionary:
	return {"mode": _mode, "phase": _phase, "cursor": _slots.cursor, "msg": _msg.text}
