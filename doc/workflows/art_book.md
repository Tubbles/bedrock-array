# The art book workflow

The second asset workflow (definition.md, lesson 3, pipeline 1): how a machine's concept images are made from its brief, and how they are judged. Decided 2026-10-18 with item 0038, the research behind it in `doc/log/2026-10-18.md`.

## The pipeline

A machine starts as a brief. A Blender script builds a blockout from it, primitives of the right size in library materials with a 1.8 m figure beside them, and renders it from the hero camera and in four orthographic views. An image model then repaints those renders into concept art, with the render as the reference image. The control comes from a flaw Mine oh Belowed's booklet found in repaints (`~/dev/mine-oh-belowed/doc/art/booklet.md`, How the images are made): a repaint with a reference keeps the reference's composition and geometry. Here that is the point. The blockout fixes silhouette, proportion and footprint, and its orthographic renders give a true turnaround, which text prompts alone never gave. A text only round comes first only when the silhouette itself is open.

The image model runs through OpenRouter (the key at `~/.config/openrouter/key`) with `tools/art/generate.py`, a copy of Mine oh Belowed's tool (references, seeds, a cost log). The default model is Google's Nano Banana Pro; the first machine runs GPT Image 2.5 beside it, and from then on each family has one fixed model and its accepted hero image as the style reference. Prompts are composed from the brief and the family's style paragraph, never appended by hand (the global rule on image prompts).

## Files

- `data/machines/<id>/brief.sjson`: `id`, `family`, `role`, `footprint = { cells, clearance, cell_metres }`, `height_metres`, `figure_metres`, `entry` (the entry page's clause: setting, state, colours), `silhouette` (one sentence), `feature` (the one readable feature), `parts` (name, library material, role), `cues` (name, the behaviour in words, the parts, sockets and pivot it needs), `art = { model, seeds }`. The brief drives the blockout, the prompts and later the model's finishing.
- `data/art/families.sjson`: one style paragraph per machine family, composed into every prompt of the family, and the family's `palette` for the review sheet.
- `data/art/book.sjson`: the art book's `pitch` and `page`, written once for the game, composed around each brief's `entry` in the entry round.
- `data/art/page.png`: the entry round's template, an empty page of the book, its hero frame over seven tenths of the paper and the elevation boxes and the swatches in a strip below, laid out by `tools/art/page_template.py layout` from the model's passes (its prompts and the layout in `data/art/page.txt`). `data/art/figure.png`: the astronaut alone, the player character's first portrait (its prompts in `data/art/figure.txt`), not on the page: the character gets its own design, so the figure for scale is asked for in words.
- `work/art/<id>/`: the rounds, each image beside its prompt file, untracked (DESIGN.md, Working files).
- `data/art/<id>/`: the kept hero and turnaround with their prompt sidecars, through Git LFS. Whether these pages ship in the game is still the open call of DESIGN.md.

## The steps

0. Entry round, when the machine's look is open: `tools/art/concept.py <id> --entry --round <n> [--seeds 7 11]` paints the machine as a page of the art book (hero view, dimensioned elevations, named parts, named swatches, the figure) into the kept template `data/art/page.png`, an empty page, so every entry shares the page (the figure for scale is asked for in words, the character will have its own design, user 2026-10-18); the pages land in `work/art/<id>/entry-<n>/`, on Banana (GPT drops the lettering and paints photographic grime, the 2026-10-18 trial). The chosen entry's parts and proportions are read into the brief and its swatches into the family's palette.
1. Write or edit the brief.
2. Blockout: `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- <id>` renders `hero.png`, `front.png`, `left.png`, `back.png`, `right.png` and a silhouette mask of each into `work/art/<id>/blockout/`.
3. Repaint: `tools/art/concept.py <id> --round <n> [--model <name>] [--seeds 7 11 19]` sends the hero render as the reference with the prompt composed from the brief and the family style, two or three seeds per model, into `work/art/<id>/round-<n>/`. The user picks the hero.
4. Turnaround: `tools/art/concept.py <id> --turnaround <hero image> --round <n>` repaints each orthographic render with the chosen hero as the second reference into `work/art/<id>/round-<n>/turnaround/`. The cue states (idle, working) as edits of the hero when the brief has them.
5. Review sheet: `tools/art/sheet.py <id> --round <n>` writes `round-<n>/review.png`: blockout, repaints, turnaround, a 64 pixel greyscale squint row, the height line. Per repaint against its mask, read from edges so horizon and shadows do not count: `SILHOUETTE` the share of the mask outline with an image edge near (ok above 0.85), `PALETTE` masked share near the family `palette` (above 0.6), `HEIGHT` the signed offset of the top edge from the mask's top over its height (within 0.05). The user's eye decides; the kept images go to `data/art/<id>/`.

## Rejected

- Text to image alone, as Mine oh Belowed did: good for exploring, no control of scale or views, every machine drifting in proportion.
- Midjourney: no public API.
- The blockout render as the finished art: programmer art, lesson 1. It is the control image and the placeholder.
