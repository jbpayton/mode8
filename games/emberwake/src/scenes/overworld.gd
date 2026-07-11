# scenes/overworld.gd — scene type "overworld" (scene-registry; engine
# contract §8): 4-dir tile movement, confirm interacts with the FACED tile
# (npc/chest/portal), triggers fire on step-on, encounter rolls per legend
# encounter_table through Rng. G-005: a trigger sharing the active spawn tile
# fires on placement (scene_args.arrive, set on new run + portal arrival).
# menu key opens the pause menu (scenes/pause_menu.gd component): Items /
# Status / town services (shop/inn/save from world place data) / Quit.
extends Control

const UI := preload("res://scenes/ui.gd")
const Story := preload("res://scenes/story.gd")
const PauseMenu := preload("res://scenes/pause_menu.gd")
const TILE := 16
const REPEAT_FRAMES := 8
const DIRS := {"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1),
		"move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0)}

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")
@onready var _rng: Node = get_node("/root/Rng")

var _map: Dictionary = {}
var _origin := Vector2.ZERO
var _player: Label = null
var _ent_nodes: Dictionary = {}   # entity id -> Label
var _facing := Vector2i(0, 1)
var _move_cd := 0
var _enc_steps := 0
var _pause := PauseMenu.new()
var _msg: Label = null
var _leaving := false

func _ready() -> void:
	_map = _db.map_def(_game.map)
	UI.fill(self, UI.COL_BG)
	var w: int = int(_map.get("width", 1))
	var h: int = int(_map.get("height", 1))
	_origin = Vector2(floorf((640 - w * TILE) / 2.0), floorf((360 - h * TILE) / 2.0) + 8)
	UI.label(self, Vector2(16, 6), str(_map.get("name", _game.map)), 14, UI.COL_BLUE)
	_draw_tiles()
	for e in _map.get("entities", []):
		_place_entity(e)
	_player = UI.label(self, _tile_px(Vector2i(_game.pos[0], _game.pos[1])), "@", 14, UI.COL_EMBER)
	_msg = UI.label(self, Vector2(16, 336), "", 14, UI.COL_WARM)
	_pause.setup(self, _db, _game, _input)
	var args: Dictionary = _game.scene_args
	if args.get("arrive", false) and _fire_triggers_at(Vector2i(_game.pos[0], _game.pos[1])):
		return
	if args.get("menu", false):
		_pause.open_menu(int(args.get("menu_cursor", 0)))

func _draw_tiles() -> void:
	var legend: Dictionary = _map.get("legend", {})
	var rows: Array = _map.get("tiles", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var leg: Dictionary = legend.get(row[x], {})
			var r := ColorRect.new()
			r.color = UI.tile_color(str(leg.get("tileset_key", "?")),
					bool(leg.get("walkable", false)), leg.has("encounter_table"))
			r.position = _origin + Vector2(x * TILE, y * TILE)
			r.size = Vector2(TILE - 1, TILE - 1)  # 1px soot seam as outline
			add_child(r)

func _place_entity(e: Dictionary) -> void:
	if not (e.get("kind", "") in ["npc", "chest", "portal"]):
		return
	var g: Array = UI.kind_glyph(e["kind"], e.get("id", "") in _game.opened)
	var l := UI.label(self, _tile_px(Vector2i(int(e["x"]), int(e["y"]))), g[0], 14, g[1])
	l.visible = _active(e)
	_ent_nodes[e["id"]] = l

func _tile_px(t: Vector2i) -> Vector2:
	return _origin + Vector2(t.x * TILE + 3, t.y * TILE - 3)

func _active(e: Dictionary) -> bool:
	if e.has("requires_flag") and not _game.has_flag(e["requires_flag"]):
		return false
	if e.has("blocked_by_flag") and _game.has_flag(e["blocked_by_flag"]):
		return false
	return true

func _legend_at(t: Vector2i) -> Dictionary:
	var rows: Array = _map.get("tiles", [])
	if t.y < 0 or t.y >= rows.size() or t.x < 0 or t.x >= str(rows[t.y]).length():
		return {}
	return _map.get("legend", {}).get(str(rows[t.y])[t.x], {})

func _entities_at(t: Vector2i) -> Array:
	return _map.get("entities", []).filter(func(e: Dictionary) -> bool:
		return int(e["x"]) == t.x and int(e["y"]) == t.y and _active(e))

func _solid_at(t: Vector2i) -> bool:
	return _entities_at(t).any(func(e: Dictionary) -> bool:
		return e.get("kind", "") in ["npc", "chest", "portal"])

# ------------------------------------------------------------------ process

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _pause.open:
		if _pause.process() == "leaving":
			_leaving = true
		return
	_walk_input()

func _walk_input() -> void:
	if _input.is_just_pressed("menu"):
		_pause.open_menu(0)
		return
	if _input.is_just_pressed("confirm"):
		_interact()
		return
	for action in DIRS:
		if _input.is_just_pressed(action):
			_step(DIRS[action])
			_move_cd = REPEAT_FRAMES
			return
	for action in DIRS:
		if _input.is_pressed(action):
			_move_cd -= 1
			if _move_cd <= 0:
				_step(DIRS[action])
				_move_cd = REPEAT_FRAMES
			return

func _step(dir: Vector2i) -> void:
	_facing = dir
	_msg.text = ""
	var t := Vector2i(_game.pos[0], _game.pos[1]) + dir
	if not bool(_legend_at(t).get("walkable", false)) or _solid_at(t):
		return
	_game.pos = [t.x, t.y]
	_player.position = _tile_px(t)
	if _fire_triggers_at(t):
		return
	_roll_encounter(t)

func _fire_triggers_at(t: Vector2i) -> bool:
	for e in _entities_at(t):
		if e.get("kind", "") == "trigger" and e.has("story_node"):
			if Story.fire(_game, _db, e["story_node"]):
				_leaving = true
				return true
	return false

func _roll_encounter(t: Vector2i) -> void:
	var table_id: String = str(_legend_at(t).get("encounter_table", ""))
	if table_id == "":
		return
	var enc: Dictionary = _db.encounter(table_id)
	_enc_steps += 1
	if _enc_steps < int(enc.get("steps_per_check", 4)):
		return
	_enc_steps = 0
	if _rng.randf() >= float(enc.get("encounter_chance", 0.0)):
		return
	var groups: Array = enc.get("groups", [])
	var idx: int = _rng.weighted_index(groups.map(func(g: Dictionary) -> float: return float(g["weight"])))
	if idx < 0:
		return
	_leaving = true
	_game.goto_scene("battle_menu", {"monsters": groups[idx]["monsters"]})

func _interact() -> void:
	if _msg.text != "":
		_msg.text = ""
		return
	var faced := Vector2i(_game.pos[0], _game.pos[1]) + _facing
	for e in _entities_at(faced):
		match e.get("kind", ""):
			"npc":
				_leaving = true
				var args := {"dialogue": e.get("dialogue", "")}
				if e.has("story_node"):
					args["npc_story_node"] = e["story_node"]
				if args["dialogue"] == "" and e.has("story_node"):
					if not Story.fire(_game, _db, e["story_node"]):
						_leaving = false
					return
				_game.goto_scene("dialogue", args)
				return
			"chest":
				_open_chest(e)
				return
			"portal":
				_leaving = true
				_game.map = str(e["to_map"])
				for s in _db.map_def(_game.map).get("entities", []):
					if s.get("id", "") == e.get("to_spawn", ""):
						_game.pos = [int(s["x"]), int(s["y"])]
				_game.goto_scene("overworld", {"arrive": true})
				return

func _open_chest(e: Dictionary) -> void:
	if e.get("id", "") in _game.opened:
		_msg.text = "The cache is empty."
		return
	var table: Dictionary = _db.treasure_table(e.get("treasure", ""))
	var rolls: Array = table.get("rolls", [])
	var entry: Dictionary = {}
	if table.get("guaranteed", false):
		entry = rolls[0]
	else:
		var idx: int = _rng.weighted_index(rolls.map(func(r: Dictionary) -> float: return float(r["weight"])))
		if idx >= 0:
			entry = rolls[idx]
	_game.opened.append(str(e["id"]))
	if entry.has("item"):
		_game.add_item(str(entry["item"]))
		var idef: Dictionary = _db.item(str(entry["item"]))
		if idef.is_empty():
			idef = _db.equip(str(entry["item"]))
		_msg.text = "Found %s!" % idef.get("name", entry["item"])
	elif entry.has("gold"):
		_game.gold += int(entry["gold"])
		_msg.text = "Found %d gold!" % int(entry["gold"])
	var g: Array = UI.kind_glyph("chest", true)
	_ent_nodes[e["id"]].text = g[0]
	_ent_nodes[e["id"]].add_theme_color_override("font_color", g[1])

# ------------------------------------------------------------------- debug

func m8_scene_type() -> String:
	return "overworld"

func m8_detail() -> Dictionary:
	return {"map": _game.map, "pos": _game.pos.duplicate(),
			"facing": [_facing.x, _facing.y], "menu_open": _pause.open,
			"menu_cursor": _pause.menu.cursor, "msg": _msg.text if _msg != null else ""}
