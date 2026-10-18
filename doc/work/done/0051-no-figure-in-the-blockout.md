# 0051: No figure in the blockout

Status: landed (2026-10-19, d2d1a57)

Goal: item 0050 left the capsule in the hero render, and the painted astronaut in the hero reference walks into the turnaround's right view as a bust, three times out of three (user, 2026-10-19: "remove the figure from the hero as well"). The blockout renders no figure anywhere, the hero prompt names no capsule, and the scale stays with the entry round.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` renders into `work/art/smelter/blockout/`: no capsule in any of the five renders, the machine filling the hero frame wider than before, the four orthographic masks as before and the hero mask reframed with it.
- `python3 tools/art/concept.py smelter --round 8 --seeds 7 --dry-run` prints a prompt without the word capsule and without the astronaut.
- `python3 tools/art/concept.py smelter --entry --round 9 --dry-run` still prints the astronaut for scale.
- `python3 tools/art/sheet.py smelter --round 7` still runs.

## Specification

- `tools/art/blockout.py`: remove `FIGURE_RADIUS`, `FIGURE_GAP_METRES`, `grey_material`, `figure_location` and `add_figure`. `build_scene` returns `scene, parts, ground` and its docstring loses the figure. `add_cameras(scene, brief, parts)` fits the hero camera to `parts`. `render_all(scene, cameras, ground, directory)` renders every camera in one loop, then `prepare_mask(scene, [ground])` and the masks as now, docstring: every view of the machine alone. `main` follows.
- `tools/art/concept.py`: remove `figure_sentence`; `hero_prompt(style, brief)` loses its figure parameter and the sentence; `hero_round` calls it so. `read_book` stays for the entry round.
- `tools/art/sheet.py`, the docstring at line 139: "keeps the figure and stray sky edges out" becomes "keeps stray sky edges out".
- `doc/workflows/art_book.md`, The pipeline: "primitives of the right size in library materials with a 1.8 m figure beside them, and renders it from the hero camera, and without the figure in four orthographic views" becomes "primitives of the right size in library materials, and renders it from the hero camera and in four orthographic views". Step 3: "the prompt composed from the brief, the family style and the book's `figure`" becomes "the prompt composed from the brief and the family style", and the sentence "The prompt names the blockout's grey capsule a stand-in to be painted as that astronaut: told to keep the figure as it is, the model kept the capsule grey (smelter round 2, 2026-10-18)." becomes "No figure stands in the blockout: the scale is the entry's, and an astronaut painted into the hero walked into the turnaround's right view as a bust three times (round 7)."
