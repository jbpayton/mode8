# scenes/story.gd — story-graph dispatch shared by overworld / dialogue /
# battle_menu / ending (ontology story-graph.schema.json; work order 03b).
# Nodes fire from map triggers and NPC story_node refs; requires_flags /
# requires_items gate silently (ADDENDUM: node.vault_gate shows no barrier UI
# at M0); sets_flags / gives_items apply when the node COMPLETES (battle: on
# victory). Every id flows in from content via ContentDB — nothing here names
# content. Scene routing goes through Game.goto_scene (the trace choke point).
extends RefCounted

static func node(db: Node, id: String) -> Dictionary:
	for n in db.story().get("nodes", []):
		if n.get("id", "") == id:
			return n
	return {}

static func can_fire(game: Node, n: Dictionary) -> bool:
	for f in n.get("requires_flags", []):
		if not game.has_flag(f):
			return false
	for iid in n.get("requires_items", []):
		if game.item_count(iid) <= 0:
			return false
	return true

# Fire a node id. Returns true when it routed to another scene (the caller
# should stop processing); false = gated/unknown, silently.
static func fire(game: Node, db: Node, id: String) -> bool:
	var n := node(db, id)
	if n.is_empty() or not can_fire(game, n):
		return false
	match n.get("kind", ""):
		"scene":
			game.goto_scene("dialogue", {"dialogue": n.get("dialogue", ""), "story_node": id})
			return true
		"flag_gate":
			complete(game, n)  # a gate completes the instant it passes
			if n.has("next"):
				return fire(game, db, str(n["next"]))
			return false
		"battle":
			game.goto_scene("battle_menu", {"story_node": id, "monsters": n.get("monsters", [])})
			return true
		"ending":
			game.goto_scene("ending", {"dialogue": n.get("dialogue", ""), "story_node": id})
			return true
	push_warning("story: unsupported node kind " + str(n.get("kind", "")))
	return false

static func complete(game: Node, n: Dictionary) -> void:
	for f in n.get("sets_flags", []):
		game.set_flag(str(f))
	for iid in n.get("gives_items", []):
		game.add_item(str(iid))

# After a scene/battle node completed: chain to next, else back to the map.
static func follow_next(game: Node, db: Node, n: Dictionary) -> void:
	if n.has("next") and fire(game, db, str(n["next"])):
		return
	game.goto_scene("overworld", {})
