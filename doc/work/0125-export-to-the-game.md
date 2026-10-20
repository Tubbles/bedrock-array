# 0125: Export to the game's model

Status: designed (2026-10-20)

Goal: the pipeline's last step writes the model the game loads, and the game draws it: every level and part with its material and masks, the pivots and sockets.

Verify:
- `./build.sh test`; the smelter's export writes `data/models/smelter/`; a demo scene (the parts demo or the LOD demo) loads the model by its file and the shots show the masks in the shading (occlusion darkening cavities, the emissive hearth).

## Specification

- `export` op: writes `data/models/<id>/model.sjson` (the parts with their materials from the brief, the levels with their triangle counts and blob names, the pivots, the sockets) and one blob per level per part, `BAMESH02`: the 0111 layout plus four mask bytes per vertex.
- The engine reads `BAMESH02` beside `BAMESH01`; the forward shader takes the occlusion into the ambient term and the emissive mask times the material's emissive; a scene item `model = "smelter"` draws a model with its levels through 0097's level choice.
- `doc/workflows/models.md` and `doc/render.md`: the model files.
