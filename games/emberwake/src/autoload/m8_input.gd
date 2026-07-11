# M8Input — input wrapper seam (engine contract §6).
# ALL scenes read input through is_just_pressed/is_pressed; nobody calls
# Input directly. In script mode (M8Debug --m8-script) reads come from the
# injected schedule instead of the OS, which is the debug driver's override
# seam. Actions: move_up move_down move_left move_right confirm cancel menu.
extends Node

var script_mode := false

var _pressed: Dictionary = {}
var _just: Dictionary = {}

func is_just_pressed(action: String) -> bool:
	if script_mode:
		return _just.get(action, false)
	return Input.is_action_just_pressed(action)

func is_pressed(action: String) -> bool:
	if script_mode:
		return _pressed.get(action, false)
	return Input.is_action_pressed(action)

# ------------------------------------------------ driver seam (M8Debug only)

func begin_script_mode() -> void:
	script_mode = true

# Called once per frame before the driver schedules this frame's step.
func new_frame() -> void:
	for a in _just:
		_just[a] = false

func drive(action: String, pressed: bool) -> void:
	_just[action] = pressed and not _pressed.get(action, false)
	_pressed[action] = pressed
