# Rng — THE random source (engine contract §3).
# Wraps one RandomNumberGenerator. Every gameplay roll (encounters, variance,
# crits, AI weights, treasure, targeting) goes through this seam; no
# randi()/randf() globals anywhere else. Seed: --m8-seed if given, else
# randomized. Same content + seed + actions => identical run.
extends Node

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0

func _ready() -> void:
	var seeded := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--m8-seed="):
			set_seed(int(arg.get_slice("=", 1)))
			seeded = true
	if not seeded:
		_rng.randomize()
		seed_value = int(_rng.seed)

func set_seed(s: int) -> void:
	seed_value = s
	_rng.seed = s

func randf() -> float:
	return _rng.randf()

func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

# Weighted pick: returns the index of the chosen weight (weights > 0).
# One randf_range consumption per call; -1 if the pool is empty/zero.
func weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var roll := _rng.randf_range(0.0, total)
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if roll < acc:
			return i
	return weights.size() - 1

# Uniform pick from a non-empty array (one randi_range consumption).
func choice(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]
