# 0046: The art book entry round

Status: verified (2026-10-18)

Goal: a step before the brief in `doc/workflows/art_book.md`: a free round in which the image model invents the machine as a page of the game's art direction book (hero view, dimensioned elevations, named parts, named swatches, the figure), so the brief's parts, proportions and palette are read off a chosen entry instead of the press kit study. The user's idea and first two entries, 2026-10-18; the prompt shape settled on the smelter's trial under `work/art/smelter/explore-1/`. Refers to item 0043.

Verify:
- `tools/art/concept.py smelter --entry --round 1 --seeds 7 11` writes two 4:3 images with their `prompt.txt` under `work/art/smelter/entry-1/`, the printed prompt holding the pitch, the smelter's line with its envelope and figure, and the page sentence.

## Specification (main agent, 2026-10-18)

Binding facts: `tools/art/concept.py` (its `read_brief`, `read_style`, `call`, `hero_round`, `require_files` and `main`); the brief's `footprint = { cells, clearance, cell_metres }`, `height_metres`, `figure_metres`; the settled prompt text is `tmp/entry_prompt.txt`, the three parts below.

- `data/art/book.sjson`, new, two keys written once for the game. `pitch` = "A page of a game's art direction book. The game: a factory builder on planets, from the surface down into the caves and up to orbit: mining, refining, automation and logistics. Stylised realism: real light on real materials, simplified shapes, low texture detail, no outlines, no cartoon palette. Machines are compact and squat, packed into their box, one big readable feature each, painted panels chipped at the edges to the metal, grime in the seams, moss taking hold where it is cool and damp, lit by what glows." `page` = "The page holds one large three quarter hero view of the machine in its setting, a small front and a small side elevation sketch with the envelope dimensioned, callouts naming each major part, and four named colour swatches of its palette; the only lettering is the callouts, the dimensions and the swatch names."
- The brief gets `entry`, one string, the smelter's: "in a cave lit by its own hearth and the glowing flora, shown working, in slate blue painted panels with copper fittings". (The colour words also stand in the family's `style`; the two prompts share them until the prompts are composed from smaller atoms, a later item.)
- `concept.py <id> --entry --round <n> [--model <name>] [--seeds ...]`: the prompt is `pitch`, then "The entry shows the <id>, a machine filling a <x> by <y> metre footprint and <height_metres> metres tall, <entry>, beside a futuristic EVA suited astronaut <figure_metres> metres tall for scale." (the footprint in metres is `cells` times `cell_metres`, numbers printed without trailing zeros, `2` not `2.0`), then `page`. No reference, ratio 4:3, seeds default 7 11, one call per seed into `work/art/<id>/entry-<n>/`, the prompt printed first, `--dry-run` as the hero round has. `--entry` and `--turnaround` exclude each other.
- Short procedures: the book reading, the entry prompt as one procedure returning the string, the round, `main` gains the flag.
- `doc/workflows/art_book.md`: a step 0 of one or two sentences before "Write or edit the brief": the entry round when the machine's look is open, run on Banana (GPT drops the lettering and paints photographic grime, the 2026-10-18 trial), the chosen entry read into the brief's parts and the family's palette; the Files section gains `data/art/book.sjson` in one line.
