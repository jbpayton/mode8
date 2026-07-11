# Design conversation guide (conversation mode)

The human's time is the scarcest resource in the whole studio. One focused conversation, then silence. Batch questions by section; never ask what you can infer and confirm.

## Sections, in order

1. **Premise & tone.** Ask for the seed ("what game is in your head?"). Reflect it back as a logline. Extract tone keywords from their language, propose the "never do this" list, draft the voice sample and read it aloud for reaction.
2. **Genre config (SPEC §3).** Three questions, one per axis: who is the party (built / fixed cast / recruits)? how do battles play (menus / grid)? how heavy is story? Map answers onto the matrix; name the closest touchstone game so the human can calibrate ("so, closer to FF1 than FF6?").
3. **World sketch.** One paragraph. Where does it start, what's underground/over the hill, what's the ending's shape. Enough for m8-cartographer and m8-loremaster to fan out; NOT a lore dump — depth is generated later, per tone bible.
4. **Scope.** Target hours first (it drives everything). Then propose content targets scaled from hours (rough guide per 5 hours: ~50 items, ~20 monsters, ~12 spells, 1–2 dungeons + overworld) and let them adjust.
5. **Difficulty philosophy → numbers.** Translate their words into: TTK band, boss TTK band, wipe-rate band, grind tolerance. Read the numbers back in plain language ("a normal fight ends in 3–4 rounds; you'll lose maybe 1 fight in 10").
6. **Style bible.** Resolution/pixel density (show the trade: 16px tiles = classic SNES feel), palette mood, character proportions. Tone keywords for art come from section 1.

## Compilation rules

- Fill `gdd.json` ONLY with things said or confirmed; everything else is a G-NNN decision with rationale, announced at the end ("I made 6 calls you can revisit: …").
- `gdd.md` is written for two readers: the human (to feel heard) and the specialist agents (tone bible is binding law).
- Validate both JSON files against schemas before declaring done.
- End by stating: "The conversation is compiled. From here the studio runs without you." — and mean it.
