# 0102: The part mapping tool

Status: landed (2026-10-19, b4f3ea6)

Goal: the finish step's first part: each of the generator's parts is matched to a part of the brief by position, so every brief part gets its material, and the model is turned to the brief's front (user, 2026-10-19: "let's get started"). A survey of the smelter's full model found its 29 parts usable: the hearth, frame, lid, body, skirt and vents each fall inside their blockout boxes once the model is turned, since the generated front faces +x where the brief's faces +z; the louvre slats sit on both sides, away from the brief's one blockout, and the sill is merged into the frame.

Verify:
- `python3 -m unittest discover -s tools/models -p "*_test.py"` (the new tests pass); `tools/models/parts.py smelter` writes the eight blobs and prints the table; every blob 1 m scale in the brief's frame.

## Specification

- New `data/machines/smelter/generated.sjson`, hand written: `source = "work/models/smelter/model_7.glb"`, `front = "+x"` (the generated model's axis that becomes the brief's +z), `margin = 0.06` (metres a vertex may lie outside a blockout box and still count), `overrides = {}` (generated part name to brief part name).
- New `tools/models/parts.py <machine>` (plain Python, `python3 -I`, the SJSON reader from `tools/materials/sjson.py` as `tools/art/sheet.py` imports it, the GLB reading of `tools/models/mesh_blob.py` imported the same way): reads the brief and `generated.sjson`, gathers each root node's mesh with its normals, moves the whole model's bounding box bottom centre to the origin, scales it to the brief's `height_metres`, turns positions and normals by the quarter turns that bring `front` to +z (`+x`: `(x, y, z)` becomes `(-z, y, x)`; also `-x`, `-z` and `+z`), and assigns each part: the override if present, else the brief part with the largest share of the part's vertices inside one of its blockout boxes grown by `margin`, else the brief part whose nearest box centre is closest to the part's bounding box centre. Prints one line per generated part (name, triangles, the share, the brief part, `override` or `nearest` when so) and writes one blob per brief part, the merged meshes of its generated parts in the brief's frame, to `data/demos/parts/meshes/<brief part>.mesh` through `mesh_blob.write_blob`; a brief part with no generated part gets no blob and a printed line saying so. Pure procedures (the turn, the share, the assignment) take plain lists.
- New `tools/models/parts_test.py` (unittest): `test_turn_brings_the_front_to_plus_z` (each of the four fronts), `test_assign_prefers_the_override`, `test_assign_picks_the_largest_share`, `test_assign_falls_back_to_the_nearest_box`.
- `doc/workflows/models.md`, the finish step: the part mapping is by blockout boxes from `generated.sjson`, not by colour from the hero camera, and names the tool.
