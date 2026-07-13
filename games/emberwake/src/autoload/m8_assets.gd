# M8Assets — real-asset loading layer (work order 07, M1). Loads
# assets/manifest.json (the asset contract: entries {key, class, file,
# aliases?}) at boot and serves resolved textures to scenes. Progressive
# enhancement: absent manifest, unknown key, or missing file all degrade to
# null/{} (scenes keep their M0 glyph/rect placeholders) — never a hard
# dependency on an asset, never a crash. Images load at runtime via
# Image.load_from_file + ImageTexture (no import pipeline; assets/ stays
# loose files behind the src/assets symlink). Determinism (contract §3):
# this layer consumes no Rng and writes no Game state — read-only render
# supply, so traces are unaffected by which assets exist.
extends Node

const MANIFEST_PATH := "res://assets/manifest.json"
# sprite_sheet layout contract: 4 facing rows in this order x 4 walk-cycle
# columns; uniform frame box = image_size / 4 on each axis.
const SHEET_DIRS: Array = ["down", "left", "right", "up"]
const SHEET_COLS := 4
const ICON_CLASS := "item_icon"
const SHEET_CLASS := "sprite_sheet"
const BATTLE_CLASS := "battle_sprite"
const TILE_CLASS := "tile"       # overworld terrain tiles (work order 09)
const SPRITE_CLASS := "sprite"   # overworld entity-marker sprites (chest/portal/npc)
const BACKGROUND_CLASS := "battle_background"  # full-screen battle backdrops (work order 10)
const PORTRAIT_CLASS := "portrait"             # dialogue/status class portraits (work order 10)

var manifest_loaded := false
var entries: Dictionary = {}    # manifest key -> manifest entry

var _alias: Dictionary = {}     # alias -> manifest key
var _textures: Dictionary = {}  # manifest key -> Texture2D or null (miss cached)

func _ready() -> void:
	load_manifest(MANIFEST_PATH)

# Absent/malformed manifest = empty manifest: everything resolves to null and
# every scene falls back to placeholders (tests load fixture manifests).
func load_manifest(path := MANIFEST_PATH) -> void:
	manifest_loaded = false
	entries = {}
	_alias = {}
	_textures = {}
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()  # instance API: quiet on bad input (no engine error spam)
	var data: Variant = null
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		data = json.data
	if not (data is Dictionary) or not (data.get("assets") is Array):
		push_warning("M8Assets: malformed manifest %s — treating as empty" % path)
		return
	for e in data["assets"]:
		if not (e is Dictionary) or not e.has("key"):
			continue
		entries[str(e["key"])] = e
		for a in e.get("aliases", []):
			_alias[str(a)] = str(e["key"])
	manifest_loaded = true

# Resolution rule (asset contract): content sprite key -> manifest entry
# whose key equals it OR whose "aliases" array contains it. Returns
# {"key", "class", "path"} or null (= placeholder).
func resolve(key: String) -> Variant:
	var mkey := key
	if not entries.has(mkey):
		mkey = str(_alias.get(mkey, ""))
	if mkey == "" or not entries.has(mkey):
		return null
	var e: Dictionary = entries[mkey]
	return {"key": mkey, "class": str(e.get("class", "")), "path": _res_path(str(e.get("file", "")))}

# Manifest "file" fields are game-dir-relative ("assets/..."); the src/assets
# symlink maps them under res://. Absolute/res:///user:// paths pass through
# (test fixtures).
func _res_path(file: String) -> String:
	if file == "" or file.is_absolute_path():
		return file
	return "res://" + file

# Runtime-loaded texture for a resolved key; cached per manifest key
# (misses too, so a broken file is probed once). null = placeholder.
func texture(key: String) -> Texture2D:
	var r: Variant = resolve(key)
	if r == null:
		return null
	var mkey: String = r["key"]
	if _textures.has(mkey):
		return _textures[mkey]
	var tex: Texture2D = null
	var path: String = r["path"]
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_textures[mkey] = tex
	return tex

# Item-icon lookup for list rows: only ICON_CLASS entries qualify; anything
# else (unresolved key, wrong class, unreadable file) is null = glyph/text
# fallback as at M0.
func icon_texture(key: String) -> Texture2D:
	if key == "":
		return null
	var r: Variant = resolve(key)
	if r == null or str(r["class"]) != ICON_CLASS:
		return null
	return texture(key)

# Battle-sprite lookup for the battle scene (work order 08): only BATTLE_CLASS
# entries qualify. Class-gated exactly like icon_texture — anything else
# (unresolved key, wrong class, unreadable file) is null = glyph fallback, so
# the battle scene keeps its M0 ColorRect+glyph placeholder. Cached per key
# via texture(); consumes no Rng, writes no Game state (contract §3).
func battle_texture(key: String) -> Texture2D:
	if key == "":
		return null
	var r: Variant = resolve(key)
	if r == null or str(r["class"]) != BATTLE_CLASS:
		return null
	return texture(key)

# Overworld tile lookup for the terrain grid (work order 09): only TILE_CLASS
# entries qualify. Class-gated exactly like battle_texture — anything else
# (unresolved key, wrong class, unreadable file) is null = the overworld keeps
# its M0 ColorRect tile-color placeholder. Keys are the map legend's
# tileset_key (content/map data), so this consumes no Rng and writes no Game
# state (contract §3); cached per manifest key via texture().
func tile_texture(key: String) -> Texture2D:
	if key == "":
		return null
	var r: Variant = resolve(key)
	if r == null or str(r["class"]) != TILE_CLASS:
		return null
	return texture(key)

# Overworld entity-marker lookup (work order 09): only SPRITE_CLASS entries
# qualify (chest/portal/npc markers). Class-gated like tile_texture — anything
# else is null = the overworld keeps its M0 kind-glyph placeholder. The key is
# the map entity's kind (schema vocabulary from map data), so this consumes no
# Rng and writes no Game state (contract §3); cached per manifest key.
func sprite_texture(key: String) -> Texture2D:
	if key == "":
		return null
	var r: Variant = resolve(key)
	if r == null or str(r["class"]) != SPRITE_CLASS:
		return null
	return texture(key)

# Walk-sheet lookup: {} unless the key resolves to a loadable SHEET_CLASS
# entry. Frame box is image_size/4 per the layout contract above.
func sheet(key: String) -> Dictionary:
	if key == "":
		return {}
	var r: Variant = resolve(key)
	if r == null or str(r["class"]) != SHEET_CLASS:
		return {}
	var tex := texture(key)
	if tex == null:
		return {}
	return {"texture": tex,
			"frame_w": tex.get_width() / SHEET_COLS,
			"frame_h": tex.get_height() / SHEET_DIRS.size()}

# Frame region within a sheet() result: row by facing (SHEET_DIRS order),
# column = frame index modulo the 4-frame walk cycle. Pure math, no state.
func sheet_region(p_sheet: Dictionary, facing: String, frame: int) -> Rect2:
	var row := SHEET_DIRS.find(facing)
	if row < 0:
		row = 0
	var col := posmod(frame, SHEET_COLS)
	var fw := int(p_sheet.get("frame_w", 0))
	var fh := int(p_sheet.get("frame_h", 0))
	return Rect2(col * fw, row * fh, fw, fh)
