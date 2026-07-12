# Emberwake build log (append-only)

- 2026-07-11 · phase 0 (gdd) done — design-compiler stub mode, fixed micro-GDD copied from skill assets.
- 2026-07-11 · plan initialized for M0: systems → content → engine → integration → balance → playtest → wrap.
- 2026-07-11 · phase 1 (systems) done — stat model/elements/statuses gate-clean; RFC-001/002 filed by specialist, adjudicated accepted (doc clarifications); ontology 0.1.1.
- 2026-07-11 · phase 2 (content) done — 13 content files + 4 maps, both gates GREEN (conductor re-verified). G-004 (120g purse), G-005 (spawn-trigger firing) recorded. No RFCs needed.
- 2026-07-11 · phase 3a (engine core) done — formula parser, algebra interpreter, battle engine, save, sim entrypoint; 428/428 unit tests headless (conductor re-verified); sim deterministic. Ambiguity list captured for retrospective queue. 03b (scenes) dispatched.
- 2026-07-11 · phase 3b (scenes) done — 10 scene types + shared helpers, zero content-id leaks; boot/tests/smoke green, deterministic; conductor re-verified. Notes: menu spellcasting unsurfaced (menu-wright M1), ending scene type + npc→service binding are registry/schema RFC candidates, G-003 save-point mismatch (town-only in data).
- 2026-07-11 · phase 4 (integration) done — all 5 build-warden gates green with evidence files. Conductor made one micro-edit as engine-smith: per-file summary lines in run_tests.gd (gate-2 evidence requirement); tests re-run green.
- 2026-07-11 · phase 5 (balance) done — sim caught boss over-lethality (wipe 23%), one data patch (eruption mag*3→mag*2+4, weight 2→1) brought it to 9%; all checkpoints green. The verification moat works.
- 2026-07-11 · phase 6 (playtest) done — rusher PASS end-to-end, deterministic; PT-001 found by persona, fixed by engine-smith, re-verified in repaired run. PT-002 deferred M1.
- 2026-07-11 · phase 7 (wrap) done — M0 build complete: all 7 phases green with evidence. Remaining for M0 sign-off per SPEC §12: fresh-session exit test.
