# Work order 01 — systems phase

You are the m8-systems-designer for the MODE 8 studio, building "Emberwake".

BINDING RULES — read these files first, in order:
1. /home/seraphius/mode8/skills/m8-systems-designer/SKILL.md   (your role; its rules are binding)
2. /home/seraphius/mode8/ontology/CONVENTIONS.md   (encoding rules for everything you write)
3. /home/seraphius/mode8/ontology/effect-algebra.md (formula DSL grammar + interpreter contract)

GAME CONTEXT:
- Game dir: /home/seraphius/mode8/games/emberwake/
- GDD: read gdd/gdd.json (+ gdd/gdd.md for tone and the expected level curve L1→L4 in gdd/decisions.md G-002) before anything else.
- Ontology version: 0.1.0

YOUR TASK:
Design Emberwake's mechanical foundation at M0 scope (0.5 target hours, party of 2, levels 1–5 relevant):
- stat-model.json: 5 stats (atk, def, mag, res, agi) + hp/mp resources with max_formulas from class stats; damage_formulas (physical, magical) per the baseline shapes in your SKILL.md, tuned so the GDD ttk_band [2,5] holds for an on-curve 2-member party vs. same-tier monsters (show your arithmetic for one L2-vs-floor-1 fight and the L4 boss fight in your return); growth curves as named formula curves over source.level (hp sturdy/caster variants, mp caster, atk/def/mag/res/agi variants as needed, xp curve = curve.xp_main with cumulative XP such that on-path encounter XP yields L2 at floor 1, L3 at floor 2, L4 at the boss — assume ~10 regular fights on the critical path at ~equal XP each, state your per-fight XP assumption for the bestiary author); xp_curve field set.
- elements.json: 3 elements — fire, frost, none (physical carrier); wheel: fire strong_against frost and vice versa; multipliers weak 2.0, resist 0.5, immune 0, absorb -1.0.
- statuses.json: exactly 2 statuses per GDD content_targets: 'burn' (damage-over-time tick on_turn_end using source.potency, stacking refresh, duration-limited) and 'guard_break' OR 'poison' — pick the one that creates the better decision for a 2-person party and say why. Each status needs a cure path possible with M0's 5-item budget (an item will cure it — name the expectation in your return).

INPUTS (read): gdd/gdd.json, gdd/gdd.md, gdd/decisions.md, ontology/schema/{stat-model,elements,statuses}.schema.json
OUTPUTS (write, exactly these): content/stat-model.json, content/elements.json, content/statuses.json

THE GATE THAT JUDGES YOUR WORK:
python3 /home/seraphius/mode8/skills/m8-build-warden/scripts/gate_content.py /home/seraphius/mode8/games/emberwake — it will report missing-file errors for content files owned by later phases; your three files must produce ZERO errors mentioning stat-model, elements, or statuses. Also validate each file against its schema with the snippet in CONVENTIONS.md. Run both before returning; failing = redo.

CONSTRAINTS:
- You may NOT edit files outside your OUTPUTS list, the ontology, other skills, or plan/.
- Expressiveness gap in the algebra → file a draft RFC in ontology/RFCS.md AND use the closest legal expression; note both in your return.
- Every formula string must parse under the formula DSL grammar (expr/term/unary/factor; funcs min max floor ceil round abs clamp; refs source.X/target.X/game.X only).
- Cite exact file paths in your return. Return format: (1) manifest of files written, (2) gate self-check result, (3) the two arithmetic walkthroughs (L2 floor-1 fight, L4 boss fight) + per-fight XP assumption, (4) open questions/RFCs filed. No prose recap.
