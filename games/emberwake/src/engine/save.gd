# engine/save.gd — save-slot IO (engine contract §4).
# Slots live at user://saves/slot_<n>.json, pretty-printed JSON of
# Game.snapshot(). Game.restore() coerces JSON's widened numbers back to int
# so a slot round-trip snapshots deep-equal.
extends RefCounted

const SAVE_DIR := "user://saves"

static func slot_path(n: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, n]

static func save_slot(n: int, snap: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	if f == null:
		push_error("save: cannot write " + slot_path(n))
		return false
	f.store_string(JSON.stringify(snap, "  "))
	f.close()
	return true

# Returns the snapshot Dictionary, or {"error": ...} (engine error convention).
static func load_slot(n: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(n)):
		return {"error": "slot %d does not exist" % n}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(n)))
	if not (data is Dictionary):
		return {"error": "slot %d is corrupt" % n}
	return data

static func list_slots() -> Array:
	var out: Array = []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("slot_") and f.ends_with(".json"):
			out.append(int(f.trim_prefix("slot_").trim_suffix(".json")))
	out.sort()
	return out

static func delete_slot(n: int) -> void:
	if FileAccess.file_exists(slot_path(n)):
		DirAccess.remove_absolute(slot_path(n))
