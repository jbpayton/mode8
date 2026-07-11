# M8Debug — CLI args, script driver, trace writer (engine contract §6).
# Args (after --): --m8-script=<actions.json> --m8-trace=<trace.jsonl>
# --m8-seed=<n> --m8-max-frames=<n>.
# Steps, consumed one per frame group: {"do":"press","action":a} (press, then
# release next frame) · {"do":"hold","action":a,"frames":n} · {"do":"wait",
# "frames":n}. Trace: one JSONL line per executed step / scene transition /
# battle event: {"frame","event","scene","detail","state" (snapshot minus
# playtime)}. Script exhausted -> "quit" line + quit(0); frame cap hit ->
# "timeout" line + quit(0). The frame cap (default 20000) is armed only when
# an --m8-* arg is present, so normal desktop runs never self-terminate.
extends Node

var frame := 0
var max_frames := 20000
var script_mode := false
var trace_path := ""
var seed_value := -1

var _steps: Array = []
var _step_idx := 0
var _trace: FileAccess = null
var _idle_left := 0
var _release_action := ""
var _hold_action := ""
var _armed := false
var _quitting := false

func _ready() -> void:
	process_priority = -1000  # drive input before any scene processes
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--m8-script="):
			_armed = true
			var path := arg.get_slice("=", 1)
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Array:
				_steps = data
				script_mode = true
			else:
				push_error("M8Debug: cannot read script " + path)
		elif arg.begins_with("--m8-trace="):
			trace_path = arg.get_slice("=", 1)
			_trace = FileAccess.open(trace_path, FileAccess.WRITE)
			if _trace == null:
				push_error("M8Debug: cannot open trace " + trace_path)
		elif arg.begins_with("--m8-seed="):
			_armed = true
			seed_value = int(arg.get_slice("=", 1))
			get_node("/root/Rng").set_seed(seed_value)
		elif arg.begins_with("--m8-max-frames="):
			_armed = true
			max_frames = int(arg.get_slice("=", 1))
	if script_mode:
		get_node("/root/M8Input").begin_script_mode()

func _process(_delta: float) -> void:
	if _quitting:
		return
	frame += 1
	if _armed and frame >= max_frames:
		trace_line("timeout", {"frames": frame})
		_quit()
		return
	if not script_mode:
		return
	var m8i := get_node("/root/M8Input")
	m8i.new_frame()
	if _release_action != "":  # release frame after a press/hold
		m8i.drive(_release_action, false)
		_release_action = ""
		return
	if _idle_left > 0:  # inside a hold or wait
		_idle_left -= 1
		if _idle_left == 0 and _hold_action != "":
			_release_action = _hold_action
			_hold_action = ""
		return
	if _step_idx >= _steps.size():
		trace_line("quit", {"steps": _step_idx})
		_quit()
		return
	var step: Dictionary = _steps[_step_idx]
	_step_idx += 1
	match step.get("do", ""):
		"press":
			m8i.drive(str(step.get("action", "")), true)
			_release_action = str(step.get("action", ""))
		"hold":
			m8i.drive(str(step.get("action", "")), true)
			_hold_action = str(step.get("action", ""))
			_idle_left = maxi(1, int(step.get("frames", 1))) - 1
			if _idle_left == 0:
				_release_action = _hold_action
				_hold_action = ""
		"wait":
			_idle_left = maxi(1, int(step.get("frames", 1))) - 1
		_:
			push_error("M8Debug: bad step " + str(step))
	trace_line("step", step)

# ------------------------------------------------------------------ traces

func trace_line(event: String, detail: Dictionary) -> void:
	if _trace == null:
		return
	var state := {}
	var g := get_node_or_null("/root/Game")
	if g != null and g.has_method("snapshot") and g.db() != null:
		state = g.snapshot()
		state.erase("playtime_s")
	_trace.store_line(JSON.stringify({"frame": frame, "event": event,
			"scene": _scene_type(), "detail": detail, "state": state}))
	_trace.flush()

func trace_scene(type: String, args: Dictionary) -> void:
	trace_line("scene", {"to": type, "args": args})

func trace_battle_event(ev: Dictionary) -> void:
	trace_line("battle_event", ev)

func trace_dialogue(detail: Dictionary) -> void:
	trace_line("dialogue", detail)

func _scene_type() -> String:
	var cs := get_tree().current_scene
	if cs != null and cs.has_method("m8_scene_type"):
		return cs.m8_scene_type()
	return "none"

func _quit() -> void:
	_quitting = true
	if _trace != null:
		_trace.flush()
		_trace.close()
		_trace = null
	get_tree().quit(0)
