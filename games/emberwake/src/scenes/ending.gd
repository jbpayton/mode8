# scenes/ending.gd — ending playback (work order 03b 8; story node kind
# "ending"). Plays the node's dialogue like the dialogue scene (confirm
# advances, lines traced via M8Debug.trace_dialogue), completes the node,
# then shows the credits line and returns to title. Not a registry scene
# type of its own beyond the active GDD's needs; it renders dialogue state.
extends Control

const UI := preload("res://scenes/ui.gd")
const Story := preload("res://scenes/story.gd")
const CREDITS := "MODE 8 — built by the studio, not by hands"

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")
@onready var _m8d: Node = get_node("/root/M8Debug")

var _id := ""
var _lines: Array = []
var _line := -1
var _credits := false
var _speaker: Label = null
var _text: Label = null
var _center: Label = null
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
	_center = UI.label(self, Vector2(96, 150), "", 18, UI.COL_EMBER)
	_center.custom_minimum_size = Vector2(448, 0)
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advance()

func _advance() -> void:
	_line += 1
	if _line < _lines.size():
		var l: Dictionary = _lines[_line]
		var sp := str(l.get("speaker", "*"))
		_speaker.text = "" if sp == "*" else sp
		_text.text = str(l.get("text", ""))
		_m8d.trace_dialogue({"dialogue": _id, "line": _line, "speaker": sp})
		return
	if not _credits:
		_credits = true
		var n: Dictionary = Story.node(_db, str(_game.scene_args.get("story_node", "")))
		Story.complete(_game, n)
		_speaker.text = ""
		_text.text = ""
		_center.text = CREDITS
		_m8d.trace_line("dialogue", {"credits": true})
		return
	_leaving = true
	_game.goto_scene("title", {})

func _process(_delta: float) -> void:
	if _leaving:
		return
	if _input.is_just_pressed("confirm"):
		_advance()

func m8_scene_type() -> String:
	return "ending"

func m8_detail() -> Dictionary:
	return {"dialogue": _id, "line": _line, "credits": _credits}
