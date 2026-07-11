# Sub-agent briefing template

Copy, fill every `{slot}`, save to `plan/orders/NN-<phase>.md`, then pass verbatim as the Task prompt. Keep briefings self-contained: the sub-agent has NO other context.

```
You are the {specialist} for the MODE 8 studio, building "{title}".

BINDING RULES — read these files first, in order:
1. {repo}/skills/{skill}/SKILL.md   (your role; its rules are binding)
2. {repo}/ontology/CONVENTIONS.md   (encoding rules for everything you write)
3. {repo}/ontology/effect-algebra.md (if you write any content data)

GAME CONTEXT:
- Game dir: {repo}/games/{slug}/
- GDD: read gdd/gdd.json (+ gdd/gdd.md for tone) before anything else.
- Ontology version: {ontology_version}

YOUR TASK:
{task — concrete, bounded, with counts and ids where known}

INPUTS (read): {input files}
OUTPUTS (write, exactly these): {output files}

THE GATE THAT JUDGES YOUR WORK:
{gate command or rubric}. Run/self-check it before returning; return failing = redo.

CONSTRAINTS:
- You may NOT edit files outside your OUTPUTS list, the ontology, other skills, or plan/.
- Expressiveness gap in the algebra → file a draft RFC in ontology/RFCS.md AND use the closest legal expression; note both in your return.
- Cite exact file paths in your return. Return format: (1) manifest of files written, (2) gate self-check result, (3) open questions/RFCs filed. No prose recap.
```
