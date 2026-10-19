# 0079: The models demo in three rows

Status: landed (2026-10-19, 83bd147)

Goal: the models demo clusters the smelter's variants the way the user judges them (user, 2026-10-19): the base high poly models (full and the 700000 face limit) in one row, the low poly base models from Tripo (the 12000 run's three and the 24000 run's two, see below) in a second, and Blender's decimations in a third, now all four permutations: the full and the 700000 model each to 24000 and 10700 triangles. Follows 0066.

The 24000 run has two base models, not three: the plain smart low poly mode has no face limit, so it exists once (in the 12000 run's row), and the smart mode's limit is capped at 20000 by the API (doc/workflows/models.md).

Verify:
- `./build.sh web models` builds and `./build.sh smoke` passes (its second run is the models demo).
- A projection of the eleven plaques and models through the scene's camera at 16:9 shows every model inside the canvas and no plaque over a model or a plaque of the row behind, on the page (plaques wrap at 9rem) and in the app at 1080p (plaques wrap at 180 points). A phone in portrait is too narrow for five plaques in a row and is not a target here.

## Specification

The main agent made the two new blobs (`blender_700000_24000.mesh`, `blender_700000_10700.mesh`, from `work/models/smelter/model_7_faces700000.glb` through `tools/models/decimate.py` and `tools/models/mesh_blob.py`), renamed the full model's two (`blender_full_24000.mesh`, `blender_full_10700.mesh`) and wrote `data/demos/models/scene.sjson` (rows at z minus 6, 0 and 4.5, the camera at pitch 0.7, chosen by a projection of the rows at the two aspects) and the demo's description. A reviewer verifies the layout; no implementer runs.
