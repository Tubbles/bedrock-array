# The art book workflow

The second asset workflow (definition.md, lesson 3, pipeline 1): how a machine's concept images are made from its brief, and how they are judged. Decided 2026-10-18 with item 0038, the research behind it in `doc/log/2026-10-18.md`.

## The pipeline

A machine starts as a brief. A Blender script builds a blockout from it, primitives of the right size in library materials with a 1.8 m figure beside them, and renders it from the hero camera and in four orthographic views. An image model then repaints those renders into concept art, with the render as the reference image. The control comes from a flaw Mine oh Belowed's booklet found in repaints (`~/dev/mine-oh-belowed/doc/art/booklet.md`, How the images are made): a repaint with a reference keeps the reference's composition and geometry. Here that is the point. The blockout fixes silhouette, proportion and footprint, and its orthographic renders give a true turnaround, which text prompts alone never gave. A text only round comes first only when the silhouette itself is open.

The image model runs through OpenRouter (the key at `~/.config/openrouter/key`) with `tools/art/generate.py`, a copy of Mine oh Belowed's tool (references, seeds, a cost log). The default model is Google's Nano Banana Pro; the first machine runs GPT Image 2.5 beside it, and from then on each family has one fixed model and its accepted hero image as the style reference. Prompts are composed from the brief and the family's style paragraph, never appended by hand (the global rule on image prompts).

## Files

- `data/machines/<id>/brief.sjson`: `id`, `family`, `role`, `footprint = { cells, blocked }`, `height_m`, `figure_m`, `silhouette` (one sentence), `feature` (the one readable feature), `parts` (name, library material, role), `cues` (name, the behaviour in words, the parts, sockets and pivot it needs), `art = { model, seeds }`. The brief drives the blockout, the prompts and later the model's finishing.
- `data/art/families.sjson`: one style paragraph per machine family, composed into every prompt of the family.
- `work/art/<id>/`: the rounds, each image beside its prompt file, untracked (DESIGN.md, Working files).
- `data/art/<id>/`: the kept hero and turnaround with their prompt sidecars, through Git LFS. Whether these pages ship in the game is still the open call of DESIGN.md.

## The steps

1. Write or edit the brief.
2. Blockout: `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- <id>` renders `hero.png`, `front.png`, `left.png`, `back.png`, `right.png` and a silhouette mask of each into `work/art/<id>/blockout/`.
3. Repaint: `tools/art/generate.py` with the hero render as the reference, the composed prompt, two or three seeds per model, into the round's directory. The user picks the hero.
4. Turnaround: each orthographic render repainted with the chosen hero as the second reference. The cue states (idle, working) as edits of the hero when the brief has them.
5. Review sheet: `work/art/<id>_review.png`, the blockout row over the repaint row, the turnaround, a 64 pixel greyscale thumbnail row (the squint test for the readable feature) and the figure line. The checks: the silhouette overlap of each repaint against its blockout mask (above about 0.85), the dominant colours within a distance of the family palette, consistent sizes. The user's eye decides; the kept images go to `data/art/<id>/`.

## Rejected

- Text to image alone, as Mine oh Belowed did: good for exploring, no control of scale or views, every machine drifting in proportion.
- Midjourney: no public API.
- The blockout render as the finished art: programmer art, lesson 1. It is the control image and the placeholder.
