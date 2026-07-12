# MODE 8 — session entry points

This repo IS the studio (SPEC.md is the charter; read it once). There is no application: skills in `skills/` + this session = the system.

- **Building or resuming a game** (`"build the game in games/<title>/"` or similar): follow `skills/m8-conductor/SKILL.md`. All build state is files under `games/<title>/plan/` — trust files over memory, resume from the first phase not `done`.
- **Starting a new game design**: `skills/m8-design-compiler/SKILL.md` (stub mode for milestone builds, conversation mode for humans).
- **After any build**: queue metrics per `skills/m8-newgame-plus/SKILL.md`.

Ground rules that bind every session (SPEC §12): nothing ships unverified; schema changes only via `ontology/RFCS.md`; decisions get logged (studio: `DECISIONS.md`, game: `gdd/decisions.md`); appliances restored via `appliances/*/fetch.sh` (never re-pin silently); commit at phase boundaries.
