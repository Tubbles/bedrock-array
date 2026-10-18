# 0047: The entry round on the page template

Status: landed (2026-10-18, c56ba5e)

Goal: every entry page is painted into one kept template, an empty page of the book with the astronaut in it, so the presentation and the figure are the same on every machine's page and only the words decide the machine (user, 2026-10-18: a blank page as the reference rather than the smelter's page, which would carry its layout and its machine along). The drill's two first pages differed in page style and both made the machine a vehicle, so the drill's clause says it is placed. Refers to item 0046.

Verify:
- `tools/art/concept.py drill --entry --round 2 --dry-run` prints the page sentence below and two call lines with `references=['data/art/page.png']`.

## Specification (main agent, 2026-10-18)

Binding facts: `tools/art/concept.py` (`entry_round`, `entry_prompt`, `call`, `require_files`); `data/art/book.sjson` (`pitch`, `page`); `data/art/page.png`, the template kept by the main agent (made from the smelter's kept page by the image tool, its prompt in `data/art/page.txt`); `data/machines/drill/brief.sjson` (`entry`).

- `data/art/book.sjson`: `page` becomes "Paint the machine into the attached empty page of the book, keeping its paper, its layout, its drawing style and its astronaut: fill the hero frame with one large three quarter view of the machine in its setting beside the astronaut, fill the front and side elevation boxes with sketches with the envelope dimensioned, add callouts naming each major part, fill the four swatches with its palette colours and name them, and write the machine's name in the title band; the only lettering is the title, the callouts, the dimensions and the swatch names."
- `entry_round` sends `data/art/page.png` as the one reference, through `require_files` before any call, so a missing template fails before the first call. The call line's `references` shows it.
- `data/machines/drill/brief.sjson`: `entry` becomes "a coal powered mining drill, a placed machine on a fixed base, at an ore face in a cave lit by the glowing flora, shown working, its drill head pointing sideways into the rock and coal smoke rising from its stack, in slate blue painted panels with copper fittings".
- `doc/workflows/art_book.md`: step 0 gains that the page is painted into the kept template `data/art/page.png`, the astronaut included, and the Files section gains `data/art/page.png` and its `page.txt` in one line; nothing else in the doc changes.
- The machine sentence of `entry_prompt` ends ", beside the astronaut already on the page, who is <figure_metres> metres tall, for scale." instead of asking for a futuristic EVA suited astronaut, which with the template's figure could paint a second one (reviewer, 2026-10-18).
- The template as made: the model would not draw the figure small (a third asked, two thirds drawn, twice) and each edit pass drifted the paper pinker, so `tools/art/page_template.py` composes it: the pass 3 page with its figure erased by a masked fill of the paper's column tones, and the figure of `data/art/figure.png`, the user's own astronaut redrawn without its orange accents (user), placed at 40 percent of the frame height. The cave in the frame and the first, contemporary astronaut were rejected (user, 2026-10-18).
