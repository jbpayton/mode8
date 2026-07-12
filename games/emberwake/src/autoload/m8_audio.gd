# M8Audio — music slot player (work order 07; m8-soundsmith interface).
# Scenes call play_slot(slot_id); slots resolve through M8Assets to a "bgm"
# manifest entry. MP3 bytes load at runtime via AudioStreamMP3 (no import
# pipeline), loop on, volume modest. Missing slot / unresolved key / absent
# file = stop -> silence, NEVER an error (soundsmith rule: sound is
# progressive enhancement); the one trace-visible signal is the `detail`
# field, surfaced by the wired scenes' m8_detail(). Determinism (contract
# §3): no Rng use, no Game-state writes — audio cannot fork a trace.
extends Node

const VOLUME_DB := -6.0

# {"slot": String, "playing": bool} — updated on every play_slot/stop.
var detail: Dictionary = {"slot": "", "playing": false}

var _assets: Node = null
var _player: AudioStreamPlayer = null
var _slot := ""
var _streams: Dictionary = {}  # manifest key -> AudioStreamMP3 (loaded once)

func _ready() -> void:
	setup(get_node_or_null("/root/M8Assets"))

# Dependency seam (tests construct M8Audio with a fixture M8Assets).
func setup(p_assets: Node) -> void:
	_assets = p_assets
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.volume_db = VOLUME_DB
		add_child(_player)

# Play the slot's track (looped); the same slot keeps playing across scene
# changes (idempotent). Anything unresolvable = silence + detail record.
func play_slot(slot_id: String) -> void:
	if slot_id == _slot and _player.stream != null:
		return
	_slot = slot_id
	var stream := _load_stream(slot_id)
	if stream == null:
		_player.stop()
		_player.stream = null
		detail = {"slot": slot_id, "playing": false}
		return
	_player.stream = stream
	if _player.is_inside_tree():  # guard for out-of-tree test instances
		_player.play()
	detail = {"slot": slot_id, "playing": true}

func stop() -> void:
	_slot = ""
	_player.stop()
	_player.stream = null
	detail = {"slot": "", "playing": false}

func current_stream() -> AudioStream:
	return _player.stream

# bgm-class resolution through M8Assets; null on any miss (= silence).
func _load_stream(slot_id: String) -> AudioStream:
	if slot_id == "" or _assets == null:
		return null
	var r: Variant = _assets.resolve(slot_id)
	if r == null or str(r["class"]) != "bgm":
		return null
	var mkey: String = r["key"]
	if _streams.has(mkey):
		return _streams[mkey]
	var path: String = r["path"]
	if path == "" or not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var stream := AudioStreamMP3.load_from_buffer(bytes)
	if stream == null:
		return null
	stream.loop = true
	_streams[mkey] = stream
	return stream
