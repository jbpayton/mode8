# test_save.gd — contract §7: snapshot/restore deep-equality, slot IO
# round-trip. Uses real loaded content but derives every id from the data.
extends RefCounted

const T := preload("res://tests/unit/_t.gd")
const DbScript := preload("res://autoload/content_db.gd")
const GameScript := preload("res://autoload/game.gd")
const Save := preload("res://engine/save.gd")

const TEST_SLOT := 97  # fixture slot, deleted after the test

var _nodes: Array = []

func cleanup() -> void:
	Save.delete_slot(TEST_SLOT)
	for n in _nodes:
		n.free()

func _game() -> Node:
	var db: Node = DbScript.new()
	db.load_all()
	var g: Node = GameScript.new()
	g.setup(db)
	_nodes.append(db)
	_nodes.append(g)
	return g

func _populate(g: Node) -> void:
	g.new_game()
	var class_ids: Array = g.db().classes.keys()
	class_ids.sort()
	g.add_party_member(class_ids[0], "Testa")
	g.add_party_member(class_ids[class_ids.size() - 1], "Testo")
	var item_ids: Array = g.db().items.keys()
	item_ids.sort()
	g.add_item(item_ids[0], 3)
	var equip_ids: Array = g.db().equipment.keys()
	equip_ids.sort()
	g.party[0]["equipment"]["weapon"] = equip_ids[0]
	g.party[1]["row"] = "back"
	g.party[1]["xp"] = 42
	g.gold = 123
	g.set_flag("flag.fixture_save_test")
	g.pos = [3, 4]
	g.opened.append("chest.fixture")
	g.playtime_s = 12.5

func test_snapshot_shape() -> void:
	var g := _game()
	_populate(g)
	var snap: Dictionary = g.snapshot()
	for k in ["party", "inventory", "gold", "flags", "map", "pos", "opened", "playtime_s"]:
		T.ok(snap.has(k), "snapshot has contract key " + k)
	T.eq(snap["party"].size(), 2, "both members present")
	var member: Dictionary = snap["party"][0]
	for k in ["class", "name", "level", "xp", "equipment", "spells", "row"]:
		T.ok(member.has(k), "member has contract key " + k)
	for rid in g.db().resource_ids():
		T.ok(member.has(rid), "member carries resource current " + str(rid))
	T.ok(snap["map"] != "", "start map set by new_game")
	T.ok(g.pos != [0, 0], "spawn position resolved from world start")
	var text := JSON.stringify(snap)
	T.ok(text != "", "snapshot is pure JSON-serializable")

func test_restore_roundtrip_deep_equal() -> void:
	var g := _game()
	_populate(g)
	var snap1: Dictionary = g.snapshot()
	g.restore(snap1)
	var snap2: Dictionary = g.snapshot()
	T.eq(snap2, snap1, "restore(snapshot()) then snapshot() is deep-equal (build-warden gate)")
	snap1["party"][0]["level"] = 99  # snapshot must be detached from live state
	T.eq(int(g.party[0]["level"]), 1, "snapshot mutation does not touch the run")

func test_restore_rebuilds_exactly() -> void:
	var g := _game()
	_populate(g)
	var snap: Dictionary = g.snapshot()
	var g2 := _game()
	g2.new_game()
	g2.restore(snap)
	T.eq(g2.snapshot(), snap, "restore rebuilds an identical run on a fresh Game")
	T.eq(g2.gold, 123, "gold restored")
	T.ok(g2.has_flag("flag.fixture_save_test"), "flags restored")
	T.eq(g2.party[1]["row"], "back", "row restored")

func test_slot_io_roundtrip() -> void:
	var g := _game()
	_populate(g)
	var snap1: Dictionary = g.snapshot()
	T.ok(g.save_game(TEST_SLOT), "save_game writes the slot")
	T.ok(FileAccess.file_exists(Save.slot_path(TEST_SLOT)), "slot file exists")
	T.ok(TEST_SLOT in Save.list_slots(), "slot listed")
	var g2 := _game()
	T.ok(g2.load_game(TEST_SLOT), "load_game reads the slot")
	T.eq(g2.snapshot(), snap1, "slot IO round-trip is lossless (ints re-narrowed)")
	var pretty := FileAccess.get_file_as_string(Save.slot_path(TEST_SLOT))
	T.ok("\n" in pretty, "slot JSON is pretty-printed")

func test_missing_slot_errors() -> void:
	T.err(func() -> Variant: return Save.load_slot(9999), "missing slot returns error result")
	var g := _game()
	_populate(g)
	T.ok(not g.load_game(9999), "load_game(missing) fails cleanly")

func test_inventory_helpers() -> void:
	var g := _game()
	g.new_game()
	g.add_item("item.fixture_x", 2)
	T.eq(g.item_count("item.fixture_x"), 2, "add_item")
	T.ok(g.remove_item("item.fixture_x", 1), "remove_item")
	T.eq(g.item_count("item.fixture_x"), 1, "count after remove")
	T.ok(not g.remove_item("item.fixture_x", 5), "cannot remove more than held")
	g.remove_item("item.fixture_x", 1)
	T.ok(not g.inventory.has("item.fixture_x"), "zero-count entries are dropped")
