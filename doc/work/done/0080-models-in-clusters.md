# 0080: The models demo in clusters

Status: landed (2026-10-19, 03d3258)

Goal: the models demo arranged as the user judges it (user, 2026-10-19, after 0079): the base models as one row by triangle count, Tripo's low poly models as one column per technique with rows by triangle count, and Blender's decimations as a grid whose columns are the base model and whose rows are the target count. Follows 0079.

Verify:
- `./build.sh web models` builds and `./build.sh smoke` passes (its second run is the models demo).
- The projection of every model as a box and every plaque (two lines where a plaque names its column, one line for a count) through the scene's camera at 16:9 shows nothing cut off and no plaque over a model or another plaque, on the page and in the app at 1080p (`tmp/models_clusters.py`, untracked).

## Specification

The main agent wrote `data/demos/models/scene.sjson` (the clusters side by side on a diagonal, the base row back left, the low poly columns in the centre, the decimation grid front right, rows at z minus 5, 0 and 3, the camera from a search over pitch, target and plaque heights with the boxes projected) and the demo's description. No implementer runs; the builds and the projection verify it.
