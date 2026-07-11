# scenes/dialogue.gd — scene type "dialogue" (scene-registry; contract §6).
# Plays a linear dialogue script (speaker + text, confirm advances, text
# instant per ux_conventions v0.1). scene_args: {"dialogue": id,
# "story_node": id?    — this playback IS that node; complete + next on end,
#  "npc_story_node": id? — NPC bark; chain into the node after, if it fires}.
# Each shown line reports through M8Debug.trace_dialogue.
extends Control

const UI := preload("res://scenes/ui.gd")
const Story := preload("res://scenes/story.gd")

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")
@onready var _m8d: Node = get_node("/root/M8Debug")

var _id := ""
var _lines: Array = []
var _line := -1
var _speaker: Label = null
var _text: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	_id = str(_game.scene_args.get("dialogue", ""))
	_lines = _db.dialogue(_id).get("lines", [])
	UI.panel(self, Rect2(40, 220, 560, 110))
	_speaker = UI.label(self, Vector2(56, 228), "", 15, UI.COL_EMBER)
	_text = UI.label(self, Vector2(56, 252), "", 15)
	_text.custom_minimum_size = Vector2(528, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(self, Vector2(552, 310), "[+]", 12, UI.COL_BLUE)
	_advance()

func _advance() -> void:
	_line += 1
	if _line >= _lines.size():
		_finish()
		return
	var l: Dictionary = _lines[_line]
	var sp := str(l.get("speaker", "*"))
	_speaker.text = "" if sp == "*" else sp
	_text.text = str(l.get("text", ""))
	_m8d.trace_dialogue({"dialogue": _id, "line": _line, "speaker": sp})

func _finish() -> void:
	_leaving = true
	var args: Dictionary = _game.scene_args
	if args.has("story_node"):
		var n: Dictionary = Story.node(_db, str(args["story_node"]))
		Story.complete(_game, n)
		Story.follow_next(_game, _db, n)
		return
	if args.has("npc_story_node") and Story.fire(_game, _db, str(args["npc_story_node"])):
		return
	_game.goto_scene("overworld", {})

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _input.is_just_pressed("confirm"):
		_advance()

func m8_scene_type() -> String:
	return "dialogue"

func m8_detail() -> Dictionary:
	return {"dialogue": _id, "line": _line, "lines": _lines.size()}
