# 0064: Blender's decimation on the models page

Status: landed (2026-10-19, 3f1c459)

Goal: the workflow names Blender's decimation as the comparison for Tripo's reductions and it was never run (user, 2026-10-19). The full model decimated in Blender to the face limit variant's count stands fifth on the models page.

Verify:
- `./build.sh test` passes (the shipped scenes test parses the five item scene), `./build.sh check` passes, `./build.sh web models` builds.
- The installed page shows five models in a row with a plaque each.

## Specification

- `tools/models/decimate.py` and `data/demos/models/meshes/decimate.mesh` exist already (made by the main agent: 29 parts, 10680 triangles from a collapse at one ratio, 0.00732, across the parts).
- `data/demos/models/scene.sjson`: the slab `size = [13, 0.1, 4]`, the camera `fit_width = 13` and `distance = 9`, the items at x minus 5, minus 2.5, 0, 2.5, 5 in the order full, face limit 12000, face limit 12000 and smart low poly, smart low poly, decimate, the fifth `{ shape = "mesh", file = "decimate.mesh", scale = 1, position = [5, 0, 0], material = "painted_steel" }` and its label at `[5, 1.3, 0]` with the text `Blender decimate of full, 29 parts, 10680 triangles, no credits`; the other labels move with their models.
- `src/demos/models/description.txt`: `The smelter's generated model, its three Tripo reductions and Blender's decimation of it, a plaque over each, where a generated model is judged. Drag to orbit, pinch or wheel to zoom.`
- `src/engine/web_scene_page.odin`: `SCENE_PAGE_DISTANCE_MAXIMUM` 30, since fitting 13 m on a phone in portrait needs about 24.4 m (the review's projection) and the old 20 cut the outer models.
- `doc/workflows/models.md`, step 1: one sentence after the `--dry-run` sentence: `tools/models/decimate.py <in.glb> <out.glb> --triangles <n>` under Blender (`flatpak run org.blender.Blender -b --python "$PWD/tools/models/decimate.py" -- ...`) is the comparison, a collapse decimate at the one ratio that brings the whole model to the count, so every part keeps its share.
- `doc/log/2026-10-19.md` is the main agent's.
