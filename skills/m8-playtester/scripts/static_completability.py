#!/usr/bin/env python3
# Thin-batteries test: DETERMINISM — completability is a proof, not an opinion;
# identical content must yield an identical verdict in every session.
#
# Method: monotone fixpoint over (reachable maps, flags, obtainable items,
# fired story nodes). Sound under monotonicity: flags only accrue, key items
# are never consumed, portals never close. Non-monotone constructs
# (blocked_by_flag on portals) are excluded from the proof (treated as never
# usable) and surfaced as warnings — if the game completes without them, the
# proof stands. Only GUARANTEED treasure counts toward required items;
# random drops/steals count for orphan analysis, not the proof.
"""Usage: static_completability.py <game_dir> [--report <path>]  (exit 0 = completable)"""
import json, sys, pathlib

def load(p):
    with open(p) as f: return json.load(f)

def main(game_dir):
    d = pathlib.Path(game_dir)
    story = load(d / "content/story.json")
    world = load(d / "content/world.json")
    items_doc = load(d / "content/items.json")
    maps = {m["id"]: m for m in (load(p) for p in sorted((d / "content/maps").glob("*.json")))}
    monsters = {m["id"]: m for m in load(d / "content/monsters.json")["entries"]}
    equipment_ids = {e["id"] for e in load(d / "content/equipment.json")["entries"]}
    nodes = {n["id"]: n for n in story["nodes"]}
    treasure = {t["id"]: t for t in world.get("treasure_tables", [])}
    warnings, errors = [], []

    # --- item sources (for orphan analysis) ---
    sources = {}
    def add_source(iid, s): sources.setdefault(iid, set()).add(s)
    for shop in world.get("shops", []):
        for iid in shop.get("stock", []): add_source(iid, f"shop:{shop['id']}")
    for m in monsters.values():
        for dr in m.get("drops", []): add_source(dr["item"], f"drop:{m['id']}")
    for n in nodes.values():
        for iid in n.get("gives_items", []): add_source(iid, f"story:{n['id']}")

    # --- proof state ---
    flags, items, fired = set(), set(), set()
    reachable = {world["start"]["map"]}
    gold_access = False  # any reachable shop ⇒ purchasable stock counts as obtainable

    def treasure_items(tid):
        t = treasure.get(tid, {})
        if t.get("guaranteed"):
            roll = t["rolls"][0]
            return {roll["item"]} if "item" in roll else set()
        return set()

    def fire_chain(nid, depth=0):
        if depth > 200: errors.append(f"story chain depth >200 at '{nid}' (cycle?)"); return
        n = nodes.get(nid)
        if n is None or nid in fired: return
        if not set(n.get("requires_flags", [])) <= flags: return
        if not set(n.get("requires_items", [])) <= items: return
        fired.add(nid)
        flags.update(n.get("sets_flags", []))
        items.update(n.get("gives_items", []))
        if n["kind"] == "choice":
            for o in n.get("options", []):
                if set(o.get("requires_flags", [])) <= flags: fire_chain(o["next"], depth + 1)
        elif "next" in n:
            fire_chain(n["next"], depth + 1)

    changed = True
    while changed:
        before = (len(flags), len(items), len(fired), len(reachable), gold_access)
        for mid in sorted(reachable):
            for e in maps[mid].get("entities", []):
                if e.get("requires_flag") and e["requires_flag"] not in flags: continue
                if e.get("blocked_by_flag"):
                    warnings.append(f"non-monotone: {mid}/{e['id']} has blocked_by_flag "
                                    f"'{e['blocked_by_flag']}' — excluded from proof")
                    continue
                if e["kind"] == "portal": reachable.add(e["to_map"])
                if e["kind"] == "chest" and "treasure" in e: items.update(treasure_items(e["treasure"]))
                if "story_node" in e: fire_chain(e["story_node"])
        for r in world.get("regions", []):
            for p in r.get("places", []):
                if p.get("services", {}).get("shops") and set(p["maps"]) & reachable:
                    gold_access = True
        if gold_access:
            for shop in world.get("shops", []):
                items.update(shop.get("stock", []))  # purchasable = obtainable (economy sanity is m8-balancer's job)
        # re-fire map triggers: new flags/items may unlock previously blocked nodes
        for mid in sorted(reachable):
            for e in maps[mid].get("entities", []):
                if "story_node" in e and (not e.get("requires_flag") or e["requires_flag"] in flags) \
                        and not e.get("blocked_by_flag"):
                    fire_chain(e["story_node"])
        changed = (len(flags), len(items), len(fired), len(reachable), gold_access) != before

    endings_reached = sorted(set(story["endings"]) & fired)
    completable = bool(endings_reached)

    # --- defect analyses ---
    unreached_nodes = sorted(set(nodes) - fired)
    unreached_maps = sorted(set(maps) - reachable)
    all_item_ids = {i["id"] for i in items_doc["entries"]} | equipment_ids
    orphaned_items = sorted(iid for iid in all_item_ids
                            if iid not in items and iid not in sources)
    for n in nodes.values():  # consumable key-gates: soft-lock hazard
        for iid in n.get("requires_items", []):
            it = next((i for i in items_doc["entries"] if i["id"] == iid), None)
            if it and it.get("kind") == "consumable":
                errors.append(f"story '{n['id']}' requires consumable item '{iid}' — soft-lock hazard")

    report = {"gate": "static_completability", "completable": completable,
              "endings_reached": endings_reached,
              "fired_nodes": sorted(fired), "unreached_nodes": unreached_nodes,
              "reachable_maps": sorted(reachable), "unreached_maps": unreached_maps,
              "obtainable_items": sorted(items), "orphaned_items": orphaned_items,
              "errors": errors, "warnings": sorted(set(warnings)),
              "status": "green" if completable and not errors else "red"}
    return report

if __name__ == "__main__":
    game_dir = sys.argv[1]
    report = main(game_dir)
    out = pathlib.Path(sys.argv[sys.argv.index("--report") + 1]) if "--report" in sys.argv \
        else pathlib.Path(game_dir) / "reports" / "completability.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"completability: {report['status'].upper()} — endings {report['endings_reached']}, "
          f"{len(report['unreached_nodes'])} orphan nodes, {len(report['orphaned_items'])} orphan items -> {out}")
    for e in report["errors"]: print(" ", e)
    sys.exit(0 if report["status"] == "green" else 1)
