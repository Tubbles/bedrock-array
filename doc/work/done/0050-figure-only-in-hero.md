# 0050: The figure only in the hero render

Status: landed (2026-10-19, 6d8e5f3)

Goal: the capsule figure stands in the four orthographic blockout renders too, where it is a grey column the turnaround repaint keeps or paints an astronaut over (user, 2026-10-19: "remove the pillar figure from the front back left right images, its only needed on the hero"). The figure renders only in `hero.png`.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` renders into `work/art/smelter/blockout/`: `hero.png` shows the capsule beside the machine, `front.png`, `left.png`, `back.png` and `right.png` show no capsule, the five masks unchanged.
- `python3 tools/art/concept.py smelter --turnaround data/art/smelter/hero.png --round 6 --dry-run` prints a prompt without the word capsule.

## Specification

- `tools/art/blockout.py`, `render_all(scene, cameras, figure, ground, directory)`: render `hero.png` with the figure visible, then set `hide_render = True` on every object of `figure`, render the four views of `ORTHOGRAPHIC_VIEWS`, then `prepare_mask(scene, [ground])` and the five masks as now. A docstring: the figure only in the hero, for the repaint's scale. `prepare_mask`'s docstring loses the figure. `main` passes `figure, ground`. The hero camera is still fitted to parts and figure.
- `tools/art/concept.py`, `turnaround_prompt`: the sentence "Leave the grey capsule as it is where the first image has one, and add no astronaut." becomes "Add no astronaut."
- `doc/workflows/art_book.md`: The pipeline, "renders it from the hero camera and in four orthographic views" becomes "renders it from the hero camera, and without the figure in four orthographic views"; step 4, the clause on the right view keeping the capsule as a grey column gets no new text, the log holds it.
