# 0061: The models demo

Status: landed (2026-10-19, 04ef572)

Goal: the smelter's four Tripo variants side by side under the engine's light with a plaque each (user, 2026-10-19), the page where generated models are judged from now on.

Verify:
- `./build.sh web models` builds; `./build.sh check` and `./build.sh test` pass; the installed page shows four models in a row on a concrete slab, orbit, pinch and wheel work, each with its label.

## Specification

- `data/demos/models/meshes/`: the four blobs made with item 0058's tool at `--height 1.0`: `full.mesh` from `model_7.glb`, `faces12000.mesh`, `faces12000_smart.mesh`, `smart.mesh` from their GLBs under `work/models/smelter/` (the main agent makes them before the item runs, committed through LFS).
- `data/demos/models/scene.sjson`: `camera = { target = [0, 0.5, 0], yaw = 0, pitch = 0.35, distance = 7.5 }` (head on, so the plaques spread evenly along the row), the light demo's `sun`, `exposure` and `ambient`, no lights, a concrete slab `[10, 0.1, 4]` at y minus 0.05, the four mesh items in `painted_steel` at x minus 3.75, minus 1.25, 1.25, 3.75 on y 0, scale 1, and four labels at y 1.3 above each with the text `full, 29 parts, 1.46 M triangles, 40 credits`, `face limit 12000, 16 parts, 10700 triangles, 40 credits`, `face limit 12000 and smart low poly, 1 part, 10409 triangles, 30 credits`, `smart low poly, 1 part, 10796 triangles, 30 credits`.
- `src/demos/models/main.odin` as the light demo's, with the mesh directory `#load_directory("../../../data/demos/models/meshes")`; `description.txt`: `The smelter's generated model beside its three reductions, a plaque over each, where a generated model is judged. Drag to orbit, pinch or wheel to zoom.`
- `src/engine/scene_test.odin`: the example scene test list gains `data/demos/models/scene.sjson`.
- `web/style.css`: the plaque wraps at `max-width: 9rem`, centred, instead of running as one line, so four plaques in a row stay apart.
- `PLAN.md`, D4's state: replace `Next the modelling, which waits on a Tripo account (SUGGESTIONS.md).` with `Then the modelling's first step (0056, 0057): the four kept views to Tripo, the full model and three reductions, judged side by side on the models page (0058 to 0061). Next the finish step of the modelling workflow.`; `doc/workflows/models.md`, step 3: one sentence first, that the generated variants are looked at on the models page (`src/demos/models/`, the blobs under `data/demos/models/meshes/`) before the review sheet exists.
