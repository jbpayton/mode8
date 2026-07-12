# scenes/ui.gd — shared scene-layer UI helpers (engine contract §8: placeholder
# art is ColorRect + Label only, tone colors from gdd/style-bible.json —
# "ember orange on soot black, warm highlights, cool shadow blues").
# Menu implements ontology/scene-registry.json ux_conventions: cursor memory
# per instance (one instance per menu per scene visit), input read only
# through M8Input. Not a scene type: a helper the ten scene scripts preload.
extends RefCounted

const COL_BG := Color("#141110")        # soot black
const COL_PANEL := Color("#1e1813")     # panel fill
const COL_EDGE := Color("#e08040")      # ember orange edge / cursor
const COL_TEXT := Color("#f0e2cc")      # warm parchment text
const COL_DIM := Color("#77695a")       # disabled / spent
const COL_EMBER := Color("#e08040")     # accent
const COL_WARM := Color("#ffd27f")      # warm highlight
const COL_BLUE := Color("#8fa3b8")      # cool shadow blue (bright)
const COL_BLUE_DIM := Color("#3a4a63")  # cool shadow blue (deep)
const COL_DANGER := Color("#c93c1e")    # low hp / defeat

# Small consistent tone set for tileset_key -> color hashing.
const TILE_TONES: Array = [
	Color("#2a2119"), Color("#33281d"), Color("#3d2f21"), Color("#26303f"),
	Color("#2c3a4e"), Color("#231d17"), Color("#453527"), Color("#1c2733"),
]

# Deterministic legend color: hash the tileset_key into the tone set; walls
# (walkable=false) darken, encounter tiles glow faintly ember (debuggable).
static func tile_color(tileset_key: String, walkable: bool, has_encounter: bool) -> Color:
	var h: int = tileset_key.hash()
	var c: Color = TILE_TONES[absi(h) % TILE_TONES.size()]
	c = c.lightened(float((absi(h) >> 8) % 12) * 0.01)
	if not walkable:
		c = c.darkened(0.45)
	if has_encounter:
		c = c.lerp(COL_EMBER, 0.12)
	return c

# Entity-kind glyph + color (schema vocabulary, not content ids).
static func kind_glyph(kind: String, opened := false) -> Array:
	match kind:
		"npc":
			return ["N", COL_WARM]
		"chest":
			return ["c" if opened else "C", COL_DIM if opened else COL_WARM]
		"portal":
			return ["O", COL_BLUE]
	return ["?", COL_DIM]

static func fill(parent: Node, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	return r

# Flat rect with the style-bible 1px darker outline.
static func panel(parent: Node, rect: Rect2, fill_col: Color = COL_PANEL, edge_col: Color = COL_BLUE_DIM) -> ColorRect:
	var edge := ColorRect.new()
	edge.color = edge_col
	edge.position = rect.position
	edge.size = rect.size
	parent.add_child(edge)
	var inner := ColorRect.new()
	inner.color = fill_col
	inner.position = Vector2.ONE
	inner.size = rect.size - Vector2(2, 2)
	edge.add_child(inner)
	return edge

static func label(parent: Node, pos: Vector2, text: String, size := 16, col: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

# Vertical cursor menu over Labels. nav() returns "confirm" | "cancel" | "";
# cursor wraps; disabled rows are selectable but refuse confirm (grayed).
# Optional entry key "icon" (Texture2D, work order 07): drawn before the
# label at ICON_PX square, nearest-scaled (project default filter); entries
# without one render exactly as at M0 (glyph/text fallback).
class Menu:
	const ICON_PX := 16

	var entries: Array = []  # {"label": String, "data": Variant, "disabled": bool, "icon": Texture2D?}
	var cursor := 0
	var font_size := 16
	var holder: VBoxContainer = null
	var _labels: Array = []
	var _rows: Array = []

	func attach(parent: Node, pos: Vector2, p_font_size := 16) -> void:
		holder = VBoxContainer.new()
		holder.position = pos
		parent.add_child(holder)
		font_size = p_font_size

	func set_entries(list: Array) -> void:
		entries = list
		cursor = clampi(cursor, 0, maxi(0, entries.size() - 1))
		for r in _rows:
			r.queue_free()
		_rows = []
		_labels = []
		for e in entries:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", font_size)
			var row: Control = l
			var icon: Variant = e.get("icon")
			if icon is Texture2D:
				var box := HBoxContainer.new()
				var tr := TextureRect.new()
				tr.texture = icon
				tr.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				box.add_child(tr)
				box.add_child(l)
				row = box
			holder.add_child(row)
			_rows.append(row)
			_labels.append(l)
		render()

	func render() -> void:
		for i in entries.size():
			var sel := i == cursor
			_labels[i].text = ("> " if sel else "  ") + str(entries[i].get("label", ""))
			var col := COL_DIM if entries[i].get("disabled", false) else (COL_EMBER if sel else COL_TEXT)
			_labels[i].add_theme_color_override("font_color", col)

	func nav(input: Node) -> String:
		if not entries.is_empty():
			if input.is_just_pressed("move_up"):
				cursor = (cursor - 1 + entries.size()) % entries.size()
				render()
			elif input.is_just_pressed("move_down"):
				cursor = (cursor + 1) % entries.size()
				render()
			if input.is_just_pressed("confirm") and not entries[cursor].get("disabled", false):
				return "confirm"
		if input.is_just_pressed("cancel"):
			return "cancel"
		return ""

	func selected() -> Dictionary:
		return {} if entries.is_empty() else entries[cursor]

	func set_visible(v: bool) -> void:
		if holder != null:
			holder.visible = v
