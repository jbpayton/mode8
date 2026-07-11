---
name: m8-newgame-plus
description: The MODE 8 self-improvement loop. Use after every game build or milestone — collects metrics, diagnoses which skills produced defects, proposes and A/B-tests skill edits and ontology RFCs, writes the retrospective. The skill library is the studio's weights; this is the optimizer.
---

# m8-newgame-plus — New Game Plus (SPEC §9)

Every build makes the studio better or the thesis is dead. You mutate the skill library from evidence, not vibes.

## Procedure

1. **Collect** from `games/<title>/reports/` + `plan/log.md` + `retrospectives/queue.md`: gate hit-rates by tier & defect class, repair-round distributions, judge escalation/disagreement rates, balance patch counts by content domain, playtest defect taxonomy, token/wall-time per artifact class (as far as logged), RFC drafts filed.
2. **Diagnose**: defects-per-artifact by producing skill; prompts/scaffolds correlated with failures; gates that never fire (dead weight?) or always fire (upstream skill broken); scripts whose judgment models have overtaken (thin-batteries audit — SPEC §12: *delete, don't refactor*); ontology gaps that forced workarounds.
3. **Mutate**: concrete skill edits — SKILL.md diffs, new reference exemplars promoted from this build's best outputs, script fixes/deletions — each on branch `skill/<name>-vN`. **A/B before merge**: run the edited skill and the incumbent on the fixed test battery (`skills/eval/` — grows every cycle; seed batteries land with M5); merge only measured wins. Ontology changes: RFC drafts in `ontology/RFCS.md`, never direct edits.
4. **Report**: `retrospectives/<date>-<title>.md` — human-readable: what the build cost, what broke, what changed in the library, what to watch next build. The human governs intent and vocabulary even when they touch nothing else.

## Rules
- One retrospective per build, even green ones (a build with nothing learned is itself a finding).
- Every proposed edit cites its evidence (defect ids, rates). No speculative rewrites of healthy skills.
- Version skills in-file (frontmatter comment `# v: N` on first body line after edits); the eval battery entry that justified each merge is referenced in the retrospective.
- Before M5's formal battery exists, A/B degrades to: rerun the affected phase on the current game with the edited skill; require strictly fewer defects. Note the weaker standard in the report.
