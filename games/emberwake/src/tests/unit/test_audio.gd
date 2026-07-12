# test_audio.gd — work order 07: M8Audio music slots resolve through
# M8Assets (bgm class); missing slot / unresolved key / absent file = stop ->
# silence, never an error, with the miss recorded in the one detail field.
# The playable fixture is a synthetic silent MP3 (valid MPEG-1 Layer III
# frames) built by the test itself — no dependency on real assets existing.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const AssetsScript := preload("res://autoload/m8_assets.gd")
const AudioScript := preload("res://autoload/m8_audio.gd")

const FIX_DIR := "user://m8fixtures_wo07_audio"
const MANIFEST := FIX_DIR + "/manifest.json"

var _nodes: Array = []
var _files: Array = []

func cleanup() -> void:
	for f in _files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIX_DIR))
	for n in _nodes:
		n.free()

# ------------------------------------------------------------- fixtures

# Silent MPEG-1 Layer III mono 128kbps 44.1kHz frames (417 bytes each,
# zero payload) — decodes as ~0.2s of silence.
static func _silent_mp3() -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(417)
	frame[0] = 0xFF
	frame[1] = 0xFB
	frame[2] = 0x90
	frame[3] = 0xC0
	var data := PackedByteArray()
	for i in 8:
		data.append_array(frame)
	return data

func _audio_over_fixture() -> Node:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIX_DIR))
	var f := FileAccess.open(FIX_DIR + "/fx_bgm.mp3", FileAccess.WRITE)
	f.store_buffer(_silent_mp3())
	f.close()
	_files.append(FIX_DIR + "/fx_bgm.mp3")
	var entries := [
		{"key": "music.fixture", "class": "bgm", "file": FIX_DIR + "/fx_bgm.mp3"},
		{"key": "music.gone", "class": "bgm", "file": FIX_DIR + "/nope.mp3"},
		{"key": "fx_not_music", "class": "item_icon", "file": FIX_DIR + "/fx_bgm.mp3"},
	]
	var mf := FileAccess.open(MANIFEST, FileAccess.WRITE)
	mf.store_string(JSON.stringify({"assets": entries}))
	mf.close()
	_files.append(MANIFEST)
	var assets: Node = AssetsScript.new()
	assets.load_manifest(MANIFEST)
	var audio: Node = AudioScript.new()
	audio.setup(assets)
	_nodes.append(assets)
	_nodes.append(audio)
	return audio

# ------------------------------------------------------------ soft-fail

func test_missing_slot_is_silence() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.never_generated")
	T.ok(audio.current_stream() == null, "unresolved slot -> no stream (silence)")
	T.eq(audio.detail, {"slot": "music.never_generated", "playing": false},
			"miss recorded in the trace-visible detail field")

func test_missing_file_is_silence() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.gone")
	T.ok(audio.current_stream() == null, "bgm entry with absent file -> silence")
	T.eq(audio.detail["playing"], false, "detail shows not playing")

func test_wrong_class_is_silence() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("fx_not_music")
	T.ok(audio.current_stream() == null, "non-bgm class never plays (class-gated)")

func test_empty_slot_and_no_assets() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("")
	T.ok(audio.current_stream() == null, "empty slot id (map without music) -> silence")
	var bare: Node = AudioScript.new()
	bare.setup(null)  # no M8Assets at all
	_nodes.append(bare)
	bare.play_slot("music.fixture")
	T.ok(bare.current_stream() == null, "no asset layer -> silence, not a crash")

# ------------------------------------------------------------ happy path

func test_bgm_plays_looped_from_bytes() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.fixture")
	var s: AudioStream = audio.current_stream()
	T.ok(s is AudioStreamMP3, "MP3 stream built from bytes at runtime")
	T.ok(s.loop, "bgm loops")
	T.ok(float(s.get_length()) > 0.0, "stream decoded to a nonzero length")
	T.eq(audio.detail, {"slot": "music.fixture", "playing": true}, "detail shows the slot playing")

func test_same_slot_is_idempotent() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.fixture")
	var s1: AudioStream = audio.current_stream()
	audio.play_slot("music.fixture")
	T.ok(audio.current_stream() == s1, "replaying the current slot keeps the track (no restart)")

func test_missing_slot_stops_current_track() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.fixture")
	audio.play_slot("music.never_generated")
	T.ok(audio.current_stream() == null, "moving to a silent slot stops the old track")
	audio.play_slot("music.fixture")
	T.eq(audio.detail["playing"], true, "and the track can come back after (stream cached)")

func test_stop() -> void:
	var audio := _audio_over_fixture()
	audio.play_slot("music.fixture")
	audio.stop()
	T.ok(audio.current_stream() == null, "stop clears the stream")
	T.eq(audio.detail, {"slot": "", "playing": false}, "stop resets detail")
