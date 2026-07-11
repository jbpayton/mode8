#!/usr/bin/env python3
# Thin-batteries test: DETERMINISM — this is gate #1 (content). Same inputs must
# produce bit-identical verdicts across sessions, so it is a script, not judgment.
# Scope: JSON Schema validation + cross-domain referential integrity + map/story
# structural checks. Formula DSL *parsing* is deliberately NOT duplicated here —
# the engine's load-time parser is the single source of truth (test_content.gd);
# we only token-check identifier scopes.
"""Usage: gate_content.py <game_dir> [--report <path>]  (exit 0 = green)"""
import json, re, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]
SCHEMA_ROOT = REPO / "ontology" / "schema"
BUILTIN_STATS = {"level", "hp", "max_hp", "hp_pct", "potency"}
FUNCS = {"min", "max", "floor", "ceil", "round", "abs", "clamp"}

def load(p):
    with open(p) as f: return json.load(f)

class Gate:
    def __init__(self, game_dir):
        self.dir = pathlib.Path(game_dir)
        self.errors, self.warnings = [], []
        self.ids = {}          # domain -> set of ids
        self.flags_set, self.flags_req = set(), set()

    def err(self, where, msg): self.errors.append(f"{where}: {msg}")
    def warn(self, where, msg): self.warnings.append(f"{where}: {msg}")

    # ---------- schema validation ----------
    def validate_schemas(self):
        from jsonschema import Draft202012Validator
        from referencing import Registry, Resource
        from referencing.jsonschema import DRAFT202012
        docs = {p: load(p) for p in sorted(SCHEMA_ROOT.rglob("*.schema.json"))}
        reg = Registry().with_resources(
            (d["$id"], Resource.from_contents(d, default_specification=DRAFT202012))
            for d in docs.values())
        def sid(name): return next(d for d in docs.values() if d["$id"].endswith(name))
        pairs = [
            ("gdd/gdd.json", "gdd"), ("gdd/style-bible.json", "style-bible"),
            ("content/stat-model.json", "stat-model"), ("content/elements.json", "elements"),
            ("content/statuses.json", "statuses"), ("content/items.json", "entities/item"),
            ("content/equipment.json", "entities/equipment"), ("content/spells.json", "entities/spell"),
            ("content/classes.json", "entities/class"), ("content/monsters.json", "entities/monster"),
            ("content/encounters.json", "entities/encounter"), ("content/world.json", "world/world"),
            ("content/story.json", "narrative/story-graph"), ("content/dialogue.json", "narrative/dialogue"),
        ]
        pairs += [(str(p.relative_to(self.dir)), "world/map") for p in sorted((self.dir / "content/maps").glob("*.json"))]
        self.docs = {}
        for rel, sname in pairs:
            p = self.dir / rel
            if not p.exists():
                self.err(rel, "required content file missing"); continue
            try: doc = load(p)
            except json.JSONDecodeError as e:
                self.err(rel, f"invalid JSON: {e}"); continue
            v = Draft202012Validator(sid(sname), registry=reg)
            for e in sorted(v.iter_errors(doc), key=lambda e: e.json_path):
                self.err(rel, f"{e.json_path}: {e.message[:200]}")
            self.docs[rel] = doc

    # ---------- id collection ----------
    def collect_ids(self):
        d = self.docs; g = lambda rel: d.get(rel, {})
        sm = g("content/stat-model.json")
        stats = {s["id"] for s in sm.get("stats", [])} | {r["id"] for r in sm.get("resources", [])} \
              | {x["id"] for x in sm.get("derived", [])}
        self.ids["stat"] = stats | BUILTIN_STATS | {f"max_{r['id']}" for r in sm.get("resources", [])}
        self.ids["curve"] = {c["id"] for c in sm.get("growth_curves", [])}
        self.ids["element"] = {e["id"] for e in g("content/elements.json").get("elements", [])}
        self.ids["status"] = {s["id"] for s in g("content/statuses.json").get("entries", [])}
        self.ids["item"] = {i["id"] for i in g("content/items.json").get("entries", [])}
        self.ids["equipment"] = {e["id"] for e in g("content/equipment.json").get("entries", [])}
        self.ids["spell"] = {s["ability"]["id"] for s in g("content/spells.json").get("entries", []) if "ability" in s}
        self.ids["class"] = {c["id"] for c in g("content/classes.json").get("entries", [])}
        self.ids["monster"] = {m["id"] for m in g("content/monsters.json").get("entries", [])}
        self.ids["encounter"] = {e["id"] for e in g("content/encounters.json").get("entries", [])}
        w = g("content/world.json")
        self.ids["treasure"] = {t["id"] for t in w.get("treasure_tables", [])}
        self.ids["shop"] = {s["id"] for s in w.get("shops", [])}
        self.ids["dialogue"] = {e["id"] for e in g("content/dialogue.json").get("entries", [])}
        self.ids["node"] = {n["id"] for n in g("content/story.json").get("nodes", [])}
        self.ids["map"] = {m["id"] for rel, m in d.items() if rel.startswith("content/maps/")}
        self.ids["obtainable"] = self.ids["item"] | self.ids["equipment"]
        for dom, ids in self.ids.items():
            if len(ids) != len(set(ids)): self.err(dom, "duplicate ids")

    def ref(self, where, domain, id_):
        if id_ not in self.ids[domain]:
            self.err(where, f"unknown {domain} id '{id_}'")

    # ---------- effect algebra walking ----------
    def walk_formula(self, where, expr):
        for scope, name in re.findall(r"\b(source|target|game)\.([a-z_][a-z0-9_]*)", expr):
            if scope == "game": self.flags_req.add(name)
            elif name not in self.ids["stat"]: self.err(where, f"formula reads unknown stat '{scope}.{name}'")
        for tok in re.findall(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", expr):
            if tok not in FUNCS: self.err(where, f"formula calls unknown function '{tok}'")

    def walk(self, where, node):
        if isinstance(node, list):
            for i, x in enumerate(node): self.walk(f"{where}[{i}]", x)
            return
        if not isinstance(node, dict): return
        op = node.get("op")
        if op == "formula": self.walk_formula(where, node.get("expr", ""))
        elif op == "stat" and node.get("ref") not in self.ids["stat"]: self.err(where, f"unknown stat '{node.get('ref')}'")
        elif op == "scaling": self.ref(where, "curve", node.get("curve"))
        elif op == "damage" and "element" in node: self.ref(where, "element", node["element"])
        elif op == "apply_status": self.ref(where, "status", node.get("status"))
        elif op == "cure_status":
            for s in node.get("statuses", []): self.ref(where, "status", s)
        elif op == "has_status": self.ref(where, "status", node.get("status"))
        elif op == "element_affinity": self.ref(where, "element", node.get("element"))
        elif op in ("modify_stat", "lowest") and node.get("stat") not in self.ids["stat"]:
            self.err(where, f"unknown stat '{node.get('stat')}'")
        elif op == "resource" and node.get("pool") not in self.ids["stat"]: self.err(where, f"unknown pool '{node.get('pool')}'")
        elif op in ("summon", "transform"): self.ref(where, "monster", node.get("entity"))
        elif op == "steal": self.ref(where, "treasure", node.get("table"))
        elif op == "set_flag": self.flags_set.add(node.get("id", ""))
        elif op == "flag": self.flags_req.add(node.get("id", ""))
        elif op == "combo":
            for pid in node.get("participants", []):
                if pid not in self.ids["class"]: self.err(where, f"combo participant '{pid}' not a class id")
        for k, v in node.items():
            if k != "op": self.walk(f"{where}.{k}", v)

    def walk_ability(self, where, ab):
        costs = ab.get("costs", {})
        if "item" in costs: self.ref(f"{where}.costs", "item", costs["item"])
        for c in costs.get("class_lock", []): self.ref(f"{where}.costs", "class", c)
        self.walk(where, {k: v for k, v in ab.items() if k in ("target", "effect", "trigger")})

    # ---------- per-domain checks ----------
    def check_domains(self):
        d = self.docs; g = lambda rel: d.get(rel, {})
        all_stats_model = {s["id"] for s in g("content/stat-model.json").get("stats", [])}
        for s in g("content/statuses.json").get("entries", []):
            if "tick" in s: self.walk(f"statuses.{s['id']}.tick", s["tick"]["effect"])
            for m in s.get("stat_mods", []):
                if m["stat"] not in self.ids["stat"]: self.err(f"statuses.{s['id']}", f"unknown stat '{m['stat']}'")
        for i in g("content/items.json").get("entries", []):
            if "use" in i: self.walk_ability(f"items.{i['id']}", i["use"])
        for e in g("content/equipment.json").get("entries", []):
            w = f"equipment.{e['id']}"
            if "attack" in e:
                self.walk(w + ".attack", e["attack"])
                if "element" in e["attack"]: self.ref(w, "element", e["attack"]["element"])
            for ab in e.get("granted_abilities", []): self.walk_ability(f"{w}.granted", ab)
            for r in e.get("resist", []): self.ref(w, "element", r["element"])
            for s in e.get("status_immunity", []): self.ref(w, "status", s)
            for c in e.get("class_lock", []): self.ref(w, "class", c)
        for s in g("content/spells.json").get("entries", []):
            ab = s.get("ability", {}); w = f"spells.{ab.get('id')}"
            self.walk_ability(w, ab)
            for l in s.get("learn", []): self.ref(w, "class", l["class"])
        for c in g("content/classes.json").get("entries", []):
            w = f"classes.{c['id']}"
            missing = all_stats_model - set(c.get("base_stats", {}))
            if missing: self.err(w, f"base_stats missing {sorted(missing)}")
            for st, cv in c.get("growth", {}).items():
                if st not in self.ids["stat"]: self.err(w, f"growth for unknown stat '{st}'")
                self.ref(w, "curve", cv)
            for ab in c.get("innate_abilities", []): self.walk_ability(w, ab)
            if "promotes_to" in c: self.ref(w, "class", c["promotes_to"])
        for m in g("content/monsters.json").get("entries", []):
            w = f"monsters.{m['id']}"
            missing = all_stats_model - set(m.get("stats", {}))
            if missing: self.err(w, f"stats missing {sorted(missing)}")
            own = {a["id"] for a in m.get("abilities", [])}
            for ab in m.get("abilities", []): self.walk_ability(f"{w}.{ab['id']}", ab)
            for r in m.get("ai", {}).get("rules", []):
                if r["ability"] not in own: self.err(w, f"ai rule references non-own ability '{r['ability']}'")
                if "when" in r: self.walk(f"{w}.ai", r["when"])
            for a in m.get("affinities", []): self.ref(w, "element", a["element"])
            for s in m.get("status_immunity", []): self.ref(w, "status", s)
            for dr in m.get("drops", []):
                if dr["item"] not in self.ids["obtainable"]: self.err(w, f"drop of unknown item '{dr['item']}'")
            if "steal_table" in m: self.ref(w, "treasure", m["steal_table"])
        for e in g("content/encounters.json").get("entries", []):
            for grp in e.get("groups", []):
                for mid in grp["monsters"]: self.ref(f"encounters.{e['id']}", "monster", mid)
        self.check_world(); self.check_maps(); self.check_story()

    def check_world(self):
        w = self.docs.get("content/world.json", {})
        start = w.get("start", {})
        self.ref("world.start", "map", start.get("map"))
        for r in w.get("regions", []):
            for p in r.get("places", []):
                for m in p.get("maps", []): self.ref(f"world.{p['id']}", "map", m)
                for s in p.get("services", {}).get("shops", []): self.ref(f"world.{p['id']}", "shop", s)
        for s in w.get("shops", []):
            for iid in s.get("stock", []):
                if iid not in self.ids["obtainable"]: self.err(f"world.shops.{s['id']}", f"stock of unknown '{iid}'")
                else:
                    ent = self.find_obtainable(iid)
                    if ent is not None and "price" not in ent: self.err(f"world.shops.{s['id']}", f"'{iid}' in stock but has no price")
        for t in w.get("treasure_tables", []):
            for roll in t.get("rolls", []):
                if "item" in roll and roll["item"] not in self.ids["obtainable"]:
                    self.err(f"world.treasure.{t['id']}", f"unknown item '{roll['item']}'")

    def find_obtainable(self, iid):
        for rel in ("content/items.json", "content/equipment.json"):
            for e in self.docs.get(rel, {}).get("entries", []):
                if e["id"] == iid: return e
        return None

    def check_maps(self):
        spawns = {}  # map id -> spawn entity ids
        for rel, m in sorted(self.docs.items()):
            if not rel.startswith("content/maps/"): continue
            w = f"map.{m.get('id')}"
            tiles, width, height = m.get("tiles", []), m.get("width"), m.get("height")
            if len(tiles) != height: self.err(w, f"{len(tiles)} rows, height says {height}")
            used = set()
            for i, row in enumerate(tiles):
                if len(row) != width: self.err(w, f"row {i} has {len(row)} chars, width says {width}")
                used |= set(row)
            legend = m.get("legend", {})
            for ch in sorted(used - set(legend)): self.err(w, f"tile char '{ch}' not in legend")
            for ch, t in legend.items():
                if "encounter_table" in t: self.ref(w, "encounter", t["encounter_table"])
            seen = set()
            for e in m.get("entities", []):
                ew = f"{w}.{e['id']}"
                if e["id"] in seen: self.err(w, f"duplicate entity id '{e['id']}'")
                seen.add(e["id"])
                if not (0 <= e["x"] < width and 0 <= e["y"] < height): self.err(ew, "out of bounds")
                k = e["kind"]
                if k == "chest":
                    if "treasure" not in e: self.err(ew, "chest without treasure table")
                    else: self.ref(ew, "treasure", e["treasure"])
                if k == "portal":
                    if "to_map" not in e or "to_spawn" not in e: self.err(ew, "portal needs to_map+to_spawn")
                if k == "npc" and "dialogue" not in e: self.err(ew, "npc without dialogue")
                if k == "trigger" and "story_node" not in e: self.err(ew, "trigger without story_node")
                if "dialogue" in e: self.ref(ew, "dialogue", e["dialogue"])
                if "story_node" in e: self.ref(ew, "node", e["story_node"])
                if "requires_flag" in e: self.flags_req.add(e["requires_flag"])
                if "blocked_by_flag" in e: self.flags_req.add(e["blocked_by_flag"])
                if k == "spawn": spawns.setdefault(m["id"], set()).add(e["id"])
        for rel, m in sorted(self.docs.items()):
            if not rel.startswith("content/maps/"): continue
            for e in m.get("entities", []):
                if e["kind"] == "portal" and "to_map" in e and "to_spawn" in e:
                    self.ref(f"map.{m['id']}.{e['id']}", "map", e["to_map"])
                    if e["to_spawn"] not in spawns.get(e["to_map"], set()):
                        self.err(f"map.{m['id']}.{e['id']}", f"no spawn '{e['to_spawn']}' on map '{e['to_map']}'")
        w = self.docs.get("content/world.json", {})
        if w.get("start", {}).get("spawn") not in spawns.get(w.get("start", {}).get("map"), set()):
            self.err("world.start", "spawn entity not found on start map")

    def check_story(self):
        s = self.docs.get("content/story.json", {})
        nodes = {n["id"]: n for n in s.get("nodes", [])}
        if s.get("start") not in nodes: self.err("story", f"start node '{s.get('start')}' missing")
        for e in s.get("endings", []):
            if e not in nodes: self.err("story", f"ending '{e}' missing")
            elif nodes[e]["kind"] != "ending": self.err("story", f"ending '{e}' has kind '{nodes[e]['kind']}'")
        for n in s.get("nodes", []):
            w = f"story.{n['id']}"
            if "dialogue" in n: self.ref(w, "dialogue", n["dialogue"])
            for mid in n.get("monsters", []): self.ref(w, "monster", mid)
            if "next" in n and n["next"] not in nodes: self.err(w, f"next '{n['next']}' missing")
            for o in n.get("options", []):
                if o["next"] not in nodes: self.err(w, f"option next '{o['next']}' missing")
                self.flags_req.update(o.get("requires_flags", []))
            self.flags_req.update(n.get("requires_flags", []))
            self.flags_set.update(n.get("sets_flags", []))
            for iid in n.get("requires_items", []) + n.get("gives_items", []):
                if iid not in self.ids["obtainable"]: self.err(w, f"unknown item '{iid}'")

    def check_flags(self):
        for f in sorted(self.flags_req - self.flags_set):
            self.err("flags", f"flag '{f}' is required somewhere but never set anywhere")

    def run(self):
        self.validate_schemas()
        if not self.errors:
            self.collect_ids(); self.check_domains(); self.check_flags()
        return {"gate": "content", "status": "green" if not self.errors else "red",
                "errors": self.errors, "warnings": self.warnings,
                "files_checked": sorted(self.docs)}

if __name__ == "__main__":
    game_dir = sys.argv[1]
    report_path = pathlib.Path(sys.argv[sys.argv.index("--report") + 1]) if "--report" in sys.argv \
        else pathlib.Path(game_dir) / "reports" / "gate_content.json"
    result = Gate(game_dir).run()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"content gate: {result['status'].upper()} "
          f"({len(result['errors'])} errors, {len(result['warnings'])} warnings) -> {report_path}")
    for e in result["errors"][:40]: print(" ", e)
    sys.exit(0 if result["status"] == "green" else 1)
