# scenes/pause_menu.gd — the overworld's pause-menu overlay (work order 03b
# item 3): Items / Status / town services / Save-at-save-point / Quit.
# Shop, inn and save rows come from the world place's services (the map
# schema has no npc->service binding, so services surface here). Destructive
# or gold-spending rows (inn, quit) go through a confirm prompt
# (ux_conventions: never destructive without confirm). Not a scene type: a
# component the overworld scene owns; transitions still go via Game.goto_scene.
extends RefCounted

const UI := preload("res://scenes/ui.gd")

var menu := UI.Menu.new()
var open := false

var _prompt := UI.Menu.new()
var _panel: ColorRect = null
var _gold: Label = null
var _in_prompt := false
var _db: Node
var _game: Node
var _input: Node

func setup(parent: Control, db: Node, game: Node, input: Node) -> void:
	_db = db
	_game = game
	_input = input
	_panel = UI.panel(parent, Rect2(420, 40, 200, 220))
	menu.attach(_panel, Vector2(14, 12), 16)
	_gold = UI.label(_panel, Vector2(14, 192), "", 14, UI.COL_WARM)
	_prompt.attach(_panel, Vector2(24, 150), 14)
	_panel.visible = false

func _place() -> Dictionary:
	for region in _db.world().get("regions", []):
		for place in region.get("places", []):
			if _game.map in place.get("maps", []):
				return place
	return {}

func open_menu(cursor: int) -> void:
	var svc: Dictionary = _place().get("services", {})
	var rows: Array = [{"label": "Items", "data": {"k": "items"}},
			{"label": "Status", "data": {"k": "status"}}]
	for sid in svc.get("shops", []):
		rows.append({"label": _db.shop(sid).get("name", "Shop"), "data": {"k": "shop", "id": sid}})
	if svc.has("inn_price"):
		rows.append({"label": "Inn — %d g" % int(svc["inn_price"]),
				"data": {"k": "inn", "price": int(svc["inn_price"])}})
	if svc.get("save_point", false):
		rows.append({"label": "Save", "data": {"k": "save"}})
	rows.append({"label": "Quit to Title", "data": {"k": "quit"}})
	menu.cursor = cursor
	menu.set_entries(rows)
	_gold.text = "Gold: %d" % _game.gold
	_prompt.set_visible(false)
	_in_prompt = false
	_panel.visible = true
	open = true

# One frame of input. Returns "" (still open), "closed", or "leaving"
# (a Game.goto_scene fired; the owner must stop processing).
func process() -> String:
	return _prompt_input() if _in_prompt else _menu_input()

func _menu_input() -> String:
	match menu.nav(_input):
		"cancel":
			_panel.visible = false
			open = false
			return "closed"
		"confirm":
			var d: Dictionary = menu.selected()["data"]
			match d.get("k", ""):
				"items":
					_game.goto_scene("inventory", {"menu_cursor": menu.cursor})
					return "leaving"
				"status":
					_game.goto_scene("status", {"menu_cursor": menu.cursor})
					return "leaving"
				"shop":
					_game.goto_scene("shop", {"shop": d["id"], "menu_cursor": menu.cursor})
					return "leaving"
				"save":
					_game.goto_scene("save_load", {"mode": "save", "menu_cursor": menu.cursor})
					return "leaving"
				"inn":
					_show_prompt([{"label": "Rest and save (%d g)" % d["price"], "data": "inn",
							"disabled": _game.gold < d["price"]},
							{"label": "Never mind", "data": "back"}])
				"quit":
					_show_prompt([{"label": "Quit — lose unsaved progress", "data": "quit"},
							{"label": "Stay", "data": "back"}])
	return ""

func _show_prompt(rows: Array) -> void:
	_prompt.cursor = 0
	_prompt.set_entries(rows)
	_prompt.set_visible(true)
	_in_prompt = true

func _prompt_input() -> String:
	match _prompt.nav(_input):
		"cancel":
			_close_prompt()
		"confirm":
			match _prompt.selected().get("data", ""):
				"back":
					_close_prompt()
				"quit":
					_game.goto_scene("title", {})
					return "leaving"
				"inn":
					_game.gold -= int(menu.selected()["data"]["price"])
					_game.rest_party()
					_game.goto_scene("save_load", {"mode": "save", "menu_cursor": menu.cursor})
					return "leaving"
	return ""

func _close_prompt() -> void:
	_prompt.set_visible(false)
	_in_prompt = false
