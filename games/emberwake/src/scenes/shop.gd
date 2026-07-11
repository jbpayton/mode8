# scenes/shop.gd — scene type "shop" (scene-registry: buy/sell). Stock from
# world.json (scene_args.shop, passed by the overworld service menu); prices
# from the item/equipment entities; sell = floor(price/2) (work order 03b);
# unpriced goods (key items) are unsellable. Infinite stock (world schema
# v0.1). Cancel: list -> Buy/Sell menu -> back to the overworld pause menu.
extends Control

const UI := preload("res://scenes/ui.gd")

@onready var _db: Node = get_node("/root/ContentDB")
@onready var _game: Node = get_node("/root/Game")
@onready var _input: Node = get_node("/root/M8Input")

var _shop: Dictionary = {}
var _phase := "top"       # top | buy | sell
var _top := UI.Menu.new()
var _buy := UI.Menu.new()
var _sell := UI.Menu.new()
var _gold: Label = null
var _msg: Label = null
var _leaving := false

func _ready() -> void:
	UI.fill(self, UI.COL_BG)
	_shop = _db.shop(str(_game.scene_args.get("shop", "")))
	UI.label(self, Vector2(24, 10), str(_shop.get("name", "Shop")), 20, UI.COL_EMBER)
	_gold = UI.label(self, Vector2(500, 10), "", 14, UI.COL_WARM)
	var left := UI.panel(self, Rect2(24, 44, 150, 100))
	_top.attach(left, Vector2(14, 12), 16)
	_top.set_entries([{"label": "Buy", "data": "buy"}, {"label": "Sell", "data": "sell"},
			{"label": "Leave", "data": "leave"}])
	UI.panel(self, Rect2(198, 44, 418, 280))
	_buy.attach(self, Vector2(212, 56), 14)
	_sell.attach(self, Vector2(212, 56), 14)
	_msg = UI.label(self, Vector2(24, 332), "", 13, UI.COL_WARM)
	_refresh()
	_show_phase("top")

func _goods_def(id: String) -> Dictionary:
	var d: Dictionary = _db.item(id)
	return d if not d.is_empty() else _db.equip(id)

func _refresh() -> void:
	_gold.text = "Gold: %d" % _game.gold
	var buy_rows: Array = []
	for id in _shop.get("stock", []):
		var d := _goods_def(id)
		var price := int(d.get("price", 0))
		buy_rows.append({"label": "%-24s %4d g" % [d.get("name", id), price], "data": id,
				"disabled": _game.gold < price})
	_buy.set_entries(buy_rows)
	var sell_rows: Array = []
	for id in _game.inventory:
		var d := _goods_def(id)
		if int(d.get("price", 0)) <= 0:
			continue  # unpriced (key items): not sellable
		var sp := int(d.get("price", 0)) / 2  # ints: floor(price/2)
		sell_rows.append({"label": "%-20s x%d  %4d g" % [d.get("name", id), _game.item_count(id), sp],
				"data": id})
	if sell_rows.is_empty():
		sell_rows.append({"label": "(nothing to sell)", "data": "", "disabled": true})
	_sell.set_entries(sell_rows)

func _show_phase(p: String) -> void:
	_phase = p
	_buy.set_visible(p == "buy")
	_sell.set_visible(p == "sell")

func _process(_delta: float) -> void:
	if _leaving:
		return
	match _phase:
		"top":
			_top_input()
		"buy":
			_buy_input()
		"sell":
			_sell_input()

func _top_input() -> void:
	match _top.nav(_input):
		"cancel":
			_leave()
		"confirm":
			match _top.selected()["data"]:
				"buy":
					_show_phase("buy")
				"sell":
					_show_phase("sell")
				"leave":
					_leave()

func _leave() -> void:
	_leaving = true
	_game.goto_scene("overworld", {"menu": true,
			"menu_cursor": int(_game.scene_args.get("menu_cursor", 0))})

func _buy_input() -> void:
	match _buy.nav(_input):
		"cancel":
			_show_phase("top")
		"confirm":
			var id: String = _buy.selected()["data"]
			var d := _goods_def(id)
			_game.gold -= int(d.get("price", 0))
			_game.add_item(id)
			_msg.text = "Bought %s." % d.get("name", id)
			var cur := _buy.cursor
			_refresh()
			_buy.cursor = cur
			_buy.render()

func _sell_input() -> void:
	match _sell.nav(_input):
		"cancel":
			_show_phase("top")
		"confirm":
			var id: String = _sell.selected()["data"]
			var d := _goods_def(id)
			if not _game.remove_item(id):  # PT-001: never credit gold for a phantom stack
				_msg.text = "Nothing to sell."
				return
			_game.gold += int(d.get("price", 0)) / 2
			_msg.text = "Sold %s." % d.get("name", id)
			var cur := _sell.cursor
			_refresh()
			_sell.cursor = clampi(cur, 0, _sell.entries.size() - 1)
			_sell.render()

func m8_scene_type() -> String:
	return "shop"

func m8_detail() -> Dictionary:
	var cursor := _top.cursor
	match _phase:
		"buy": cursor = _buy.cursor
		"sell": cursor = _sell.cursor
	return {"phase": _phase, "cursor": cursor, "gold": _game.gold,
			"shop": _shop.get("id", "")}
