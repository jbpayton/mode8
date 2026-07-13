# scenes/battle_menu.gd — scene type "battle_menu" (scene-registry; engine
# contract §8): front-end over engine/battle.gd. Party rows vs monster group;
# commands Attack/Spell/Item/Defend/Row/Flee with unavailable rows hidden;
# target picking per the ability's selector; battle-log events rendered as
# text AND forwarded to M8Debug.trace_battle_event. Victory applies rewards
# through engine code (Game.apply_battle_result banks gold only), then chains
# the story node (scene_args.story_node) or returns to the overworld.
# on_defeat game_over -> title (G-003: random encounters too). Cancel steps
# back exactly one level: target -> spell/item list -> command.
extends Control

const UI := preload("res://scenes/ui.gd")
const Story := preload("res://scenes/story.gd")
const BattleLog := preload("res://scenes/battle_log.gd")
const LOG_LINES := 7

# Battle-sprite layout (work order 08), 640x360 canvas. Enemies sit in the
# upper battlefield on a shared baseline; party members in a lower row; both
# left of the command panel (x>=420) and above the battle log (y>=214). Sizes:
# a 128px monster ~96px tall, the 224px boss ~150px and centered; party
# walk-frames ~64px tall.
const ENEMY_BASELINE_Y := 150.0
const ENEMY_CX := 200.0
const ENEMY_STEP := 116.0     # horizontal offset between same-area enemies
const ENEMY_SPAN := 300.0     # max total spread before the step tightens
const ENEMY_H := 96.0
const BOSS_H := 150.0
const PARTY_BASELINE_Y := 212.0
const PARTY_CX := 200.0
const PARTY_STEP := 92.0
const PARTY_SPAN := 320.0
const PARTY_H := 64.0

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")
@onready var _m8d: Node = get_node("/root/M8Debug")
@onready var _assets: Node = get_node("/root/M8Assets")
@onready var _audio: Node = get_node("/root/M8Audio")

var _battle: RefCounted = null
var _story_node_id := ""
var _phase := "command"       # command | spell | item | target | end
var _pending: Dictionary = {}
var _names: Dictionary = {}   # entity key -> display name
var _log: Array = []
var _cmd := UI.Menu.new()
var _spells := UI.Menu.new()
var _items := UI.Menu.new()
var _targets := UI.Menu.new()
var _log_label: Label = null
var _party_labels: Array = []
var _monster_labels: Array = []
var _monster_boxes: Array = []    # glyph-fallback ColorRects, parallel to monsters
var _monster_sprites: Array = []  # TextureRect or null, parallel to monsters
var _actor_label: Label = null
var _round_label: Label = null
var _end_label: Label = null
var _end_panel: ColorRect = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	_story_node_id = str(_game.scene_args.get("story_node", ""))
	# Battle music slots per the m8-soundsmith convention (skill interface,
	# not game content): music.boss when any monster in the group is a boss.
	var boss: bool = _game.scene_args.get("monsters", []).any(
			func(mid: Variant) -> bool: return bool(_db.monster(str(mid)).get("is_boss", false)))
	_audio.play_slot("music.boss" if boss else "music.battle")
	_battle = _game.start_battle(_game.scene_args.get("monsters", []), {})
	_battle.event_cb = _on_event
	for e in _battle.party + _battle.monsters:
		_names[e["key"]] = str(e["name"])
	_build_ui()
	_battle.begin()
	_sync()

func _build_ui() -> void:
	_round_label = UI.label(self, Vector2(16, 6), "", 14, UI.COL_BLUE)
	for i in _battle.monsters.size():
		var m: Dictionary = _battle.monsters[i]
		var box := ColorRect.new()
		box.color = UI.COL_DANGER.darkened(0.3)
		box.position = Vector2(40, 40 + i * 40)
		box.size = Vector2(24, 24)
		add_child(box)
		_monster_boxes.append(box)
		UI.label(box, Vector2(7, 1), str(m["name"]).left(1), 16, UI.COL_TEXT)
		_monster_labels.append(UI.label(self, Vector2(74, 42 + i * 40), "", 14))
	var pp := UI.panel(self, Rect2(340, 30, 284, 30 + _battle.party.size() * 22))
	for i in _battle.party.size():
		_party_labels.append(UI.label(pp, Vector2(10, 8 + i * 22), "", 13))
	UI.panel(self, Rect2(16, 214, 380, 130))
	_log_label = UI.label(self, Vector2(28, 220), "", 12, UI.COL_DIM)
	var cp := UI.panel(self, Rect2(420, 150, 204, 194))
	_actor_label = UI.label(cp, Vector2(12, 6), "", 14, UI.COL_WARM)
	for menu in [_cmd, _spells, _items, _targets]:
		menu.attach(cp, Vector2(12, 28), 13)
	_end_panel = UI.panel(self, Rect2(140, 90, 360, 170), UI.COL_PANEL, UI.COL_EDGE)
	_end_label = UI.label(_end_panel, Vector2(18, 12), "", 14)
	_end_panel.visible = false
	_build_sprites()

# Battle sprites (work order 08): enemies get their monster's battle_sprite in
# the upper battlefield (boss centered + larger), party members their walk-sheet
# down-frame-0 (front view) in a lower row. Pure visual dressing layered behind
# the existing glyph boxes / HP text / menus (move_child index 1) — reads sprite
# keys from ContentDB (no id literals), consumes no Rng, writes no Game state
# (contract §3). Missing/wrong-class assets resolve to null and the M0 glyph box
# placeholder stays.
func _build_sprites() -> void:
	var n: int = _battle.monsters.size()
	var estep: float = minf(ENEMY_STEP, ENEMY_SPAN / float(maxi(1, n)))
	var estart: float = ENEMY_CX - estep * float(n - 1) * 0.5
	for i in n:
		_monster_sprites.append(null)
		var mdef: Dictionary = _db.monster(str(_battle.monsters[i].get("id", "")))
		var tex: Texture2D = _assets.battle_texture(str(mdef.get("sprite", "")))
		if tex == null:
			continue  # keep this enemy's glyph box fallback
		var boss: bool = bool(mdef.get("is_boss", false))
		var cx: float = ENEMY_CX if boss else estart + estep * float(i)
		_monster_sprites[i] = _sprite_rect(tex, null, BOSS_H if boss else ENEMY_H, cx, ENEMY_BASELINE_Y)
		_monster_boxes[i].visible = false  # sprite replaces the glyph placeholder
	var pn: int = _battle.party.size()
	var pstep: float = minf(PARTY_STEP, PARTY_SPAN / float(maxi(1, pn)))
	var pstart: float = PARTY_CX - pstep * float(pn - 1) * 0.5
	for i in pn:
		var cdef: Dictionary = _db.cls(str(_battle.party[i].get("class", "")))
		var sh: Dictionary = _assets.sheet(str(cdef.get("sprite", "")))
		if sh.is_empty():
			continue  # no walk sheet -> party text panel only
		var region: Rect2 = _assets.sheet_region(sh, "down", 0)  # front-facing rest frame
		_sprite_rect(sh["texture"], region, PARTY_H, pstart + pstep * float(i), PARTY_BASELINE_Y)

# Bottom-center-anchored sprite, aspect preserved to target_h, nearest filter,
# layered just above the background so glyph HP text and menus draw on top.
# region null = whole texture; Rect2 = an atlas sub-frame (a walk-sheet cell).
func _sprite_rect(tex: Texture2D, region: Variant, target_h: float, cx: float, baseline_y: float) -> TextureRect:
	var draw_tex: Texture2D = tex
	var src_w: float = float(tex.get_width())
	var src_h: float = float(tex.get_height())
	if region is Rect2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region
		draw_tex = at
		src_w = region.size.x
		src_h = region.size.y
	var scale: float = target_h / maxf(1.0, src_h)
	var w: float = src_w * scale
	var tr := TextureRect.new()
	tr.texture = draw_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size = Vector2(w, target_h)
	tr.position = Vector2(cx - w * 0.5, baseline_y - target_h)
	add_child(tr)
	move_child(tr, 1)  # above the bg fill (child 0), behind all text/panels
	return tr

func _show_only(menu: Variant) -> void:
	for m in [_cmd, _spells, _items, _targets]:
		m.set_visible(m == menu)

# ------------------------------------------------------------------- events

func _on_event(ev: Dictionary) -> void:
	_m8d.trace_battle_event(ev)
	var line: String = BattleLog.line(ev, _names, _db, _battle)
	if line != "":
		_log.append(line)

# ------------------------------------------------------------------ redraw

func _sync() -> void:
	_round_label.text = "Round %d" % int(_battle.round_no)
	for i in _battle.monsters.size():
		var m: Dictionary = _battle.monsters[i]
		var hp: Dictionary = m["resources"]["hp"]
		_monster_labels[i].text = "%s  %d/%d%s" % [m["name"], int(hp["cur"]), int(hp["max"]),
				"" if m["alive"] else "  —down—"]
		_monster_labels[i].add_theme_color_override("font_color",
				UI.COL_TEXT if m["alive"] else UI.COL_DIM)
		if _monster_sprites[i] != null:
			_monster_sprites[i].modulate.a = 1.0 if m["alive"] else 0.35
	for i in _battle.party.size():
		var p: Dictionary = _battle.party[i]
		var bits := ""
		for rid in _db.resource_ids():
			var r: Dictionary = p["resources"][rid]
			bits += "  %s %d/%d" % [str(rid).to_upper(), int(r["cur"]), int(r["max"])]
		var acting: bool = not _battle.current_actor().is_empty() and _battle.current_actor()["key"] == p["key"]
		_party_labels[i].text = "%s %s [%s]%s" % [">" if acting else " ", p["name"],
				str(p["row"]).left(1).to_upper(), bits]
		_party_labels[i].add_theme_color_override("font_color",
				UI.COL_TEXT if p["alive"] else UI.COL_DANGER)
	_log_label.text = "\n".join(_log.slice(maxi(0, _log.size() - LOG_LINES)))
	if _battle.is_over():
		_show_end()
	elif _battle.needs_command():
		_enter_command()

# ------------------------------------------------------------------- menus

func _enter_command() -> void:
	_phase = "command"
	var actor: Dictionary = _battle.current_actor()
	_actor_label.text = str(actor["name"])
	var rows: Array = [{"label": "Attack", "data": "attack"}]
	if not _battle_spells(actor).is_empty():
		rows.append({"label": "Spell", "data": "spell"})
	if not _battle_items().is_empty():
		rows.append({"label": "Item", "data": "item"})
	rows.append({"label": "Defend", "data": "defend"})
	rows.append({"label": "Row", "data": "row"})
	rows.append({"label": "Flee", "data": "flee"})
	_cmd.set_entries(rows)
	_show_only(_cmd)

func _battle_spells(actor: Dictionary) -> Array:
	return actor.get("spells", []).filter(func(sid: String) -> bool:
		return "battle" in _db.spell(sid).get("usable_in", []))

func _battle_items() -> Array:
	return _game.inventory.keys().filter(func(iid: String) -> bool:
		return _game.item_count(iid) > 0 and _db.item(iid).has("use") \
				and "battle" in _db.item(iid).get("usable_in", []))

func _open_spells() -> void:
	_phase = "spell"
	var actor: Dictionary = _battle.current_actor()
	_spells.set_entries(_battle_spells(actor).map(func(sid: String) -> Dictionary:
		var ab: Dictionary = _db.spell(sid)["ability"]
		return {"label": "%s%s" % [ab.get("name", sid), _cost_tag(ab)], "data": sid,
				"disabled": not _battle.costs_payable(actor, ab)}))
	_show_only(_spells)

func _open_items() -> void:
	_phase = "item"
	_items.set_entries(_battle_items().map(func(iid: String) -> Dictionary:
		return {"label": "%s x%d" % [_db.item(iid).get("name", iid), _game.item_count(iid)],
				"data": iid,
				"icon": _assets.icon_texture(str(_db.item(iid).get("sprite", "")))}))
	_show_only(_items)

func _cost_tag(ab: Dictionary) -> String:
	var bits: Array = []
	for k in ab.get("costs", {}):
		if k in _db.resource_ids():
			bits.append("%d %s" % [int(ab["costs"][k]), str(k).to_upper()])
	return "" if bits.is_empty() else " — " + ", ".join(bits)

# Target list per the ability's selector; non-single selectors auto-resolve.
func _enter_target() -> void:
	var sel: Dictionary = _pending["ability"].get("target", {"op": "single", "side": "enemy"})
	var op := str(sel.get("op", "single"))
	if not (op in ["single", "dead"]):
		_submit_pending("")
		return
	var pool: Array = _battle.party if sel.get("side", "enemy") == "ally" or op == "dead" else _battle.monsters
	var cands: Array = pool.filter(func(e: Dictionary) -> bool:
		return (not e["alive"]) if op == "dead" else e["alive"])
	if cands.is_empty():
		_enter_command()
		return
	_phase = "target"
	_targets.cursor = 0
	_targets.set_entries(cands.map(func(e: Dictionary) -> Dictionary:
		var hp: Dictionary = e["resources"]["hp"]
		return {"label": "%s  %d/%d" % [e["name"], int(hp["cur"]), int(hp["max"])], "data": e["key"]}))
	_show_only(_targets)

# ------------------------------------------------------------------- input

func _process(_delta: float) -> void:
	if _leaving:
		return
	match _phase:
		"command":
			_command_input()
		"spell", "item":
			_list_input(_spells if _phase == "spell" else _items, _phase)
		"target":
			_target_input()
		"end":
			if _input.is_just_pressed("confirm"):
				_leave_battle()

func _command_input() -> void:
	if _cmd.nav(_input) != "confirm":
		return
	var actor: Dictionary = _battle.current_actor()
	match _cmd.selected()["data"]:
		"attack":
			_pending = {"kind": "attack", "ability": _battle.basic_attack_ability(actor)}
			_enter_target()
		"spell":
			_open_spells()
		"item":
			_open_items()
		"defend", "row", "flee":
			_submit({"kind": _cmd.selected()["data"]})

func _list_input(menu: RefCounted, kind: String) -> void:
	match menu.nav(_input):
		"cancel":
			_enter_command()
		"confirm":
			var id: String = menu.selected()["data"]
			var ability: Dictionary = _db.spell(id)["ability"] if kind == "spell" else _db.item(id)["use"]
			_pending = {"kind": kind, "id": id, "ability": ability}
			_enter_target()

func _target_input() -> void:
	match _targets.nav(_input):
		"cancel":  # back one level: to the list that opened the picker
			match str(_pending.get("kind", "")):
				"spell": _open_spells()
				"item": _open_items()
				_: _enter_command()
		"confirm":
			_submit_pending(str(_targets.selected()["data"]))

func _submit_pending(target: String) -> void:
	var act := {"kind": _pending["kind"], "target": target}
	if _pending.has("id"):
		act["id"] = _pending["id"]
	_submit(act)

func _submit(action: Dictionary) -> void:
	_pending = {}
	_battle.submit_command(action)
	_sync()

# ------------------------------------------------------------------ ending

func _show_end() -> void:
	_phase = "end"
	_show_only(null)
	_actor_label.text = ""
	var lines: Array = []
	match str(_battle.outcome):
		"win":
			var result: Dictionary = _battle.result()
			_game.apply_battle_result(result)
			var rw: Dictionary = result.get("rewards", {})
			lines = ["Victory!", "", "XP +%d    Gold +%d" % [int(rw.get("xp", 0)), int(rw.get("gold", 0))]]
			for iid in rw.get("drops", {}):
				lines.append("Found %s x%d" % [_db.item(iid).get("name", iid), int(rw["drops"][iid])])
			for key in rw.get("level_ups", {}):
				lines.append("%s reaches level %d!" % [_names.get(key, key), int(rw["level_ups"][key])])
		"wipe":
			lines = ["The party falls...", "", "The deep keeps its own."]
		"fled", "timeout":
			lines = ["Got away..." if _battle.outcome == "fled" else "The fight drags on; both sides withdraw."]
	lines.append("")
	lines.append("[confirm]")
	_end_label.text = "\n".join(lines)
	_end_panel.visible = true

func _leave_battle() -> void:
	_leaving = true
	var n: Dictionary = Story.node(_db, _story_node_id) if _story_node_id != "" else {}
	match str(_battle.outcome):
		"win":
			if n.is_empty():
				_game.goto_scene("overworld", {})
			else:
				Story.complete(_game, n)
				Story.follow_next(_game, _db, n)
		"wipe":
			if n.get("on_defeat", "game_over") == "continue":
				_game.goto_scene("overworld", {})
			else:  # game_over (G-003; "retry" unused at M0 falls back to title)
				_game.goto_scene("title", {})
		_:
			_game.goto_scene("overworld", {})

func m8_scene_type() -> String:
	return "battle_menu"

func m8_detail() -> Dictionary:
	var actor: Dictionary = _battle.current_actor() if _battle != null else {}
	var cursors := {"spell": _spells.cursor, "item": _items.cursor, "target": _targets.cursor}
	return {"phase": _phase, "round": int(_battle.round_no) if _battle != null else 0,
			"actor": actor.get("key", ""), "outcome": str(_battle.outcome) if _battle != null else "",
			"cursor": int(cursors.get(_phase, _cmd.cursor)), "story_node": _story_node_id,
			"music": _audio.detail.duplicate()}
